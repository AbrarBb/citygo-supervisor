import 'dart:async';
import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../models/nfc.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';

/// NFC Service for reading NFC tags
class NFCService {
  final ApiService _apiService;
  final LocalDB _localDB;
  
  Function(NfcTapResponse)? onSuccess;
  Function(String)? onError;
  Function(String)? onProgress;

  NFCService(this._apiService, this._localDB);
  
  // Expose for access in screens
  ApiService get apiService => _apiService;
  LocalDB get localDB => _localDB;

  /// Check if NFC is available on device
  Future<bool> isAvailable() async {
    return await NfcManager.instance.isAvailable();
  }

  /// Read NFC tag and convert to card ID format
  /// Supports both NDEF records (for NTAG216) and tag identifiers
  Future<String?> readNFCTag() async {
    try {
      // Check if NFC is available first
      final isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        print('❌ NFC is not available on this device');
        return null;
      }
      
      // Stop any existing session first to avoid conflicts
      try {
        await NfcManager.instance.stopSession();
        print('📱 Stopped any existing NFC session');
        // Small delay to ensure session is fully stopped
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        print('📱 No existing session to stop (or error stopping): $e');
      }
      
      print('📱 Starting NFC session...');
      print('📱 Waiting for NFC tag - please tap your card now');
      print('📱 Session will remain active for 30 seconds or until tag is detected');
      
      // Use Completer to wait for tag discovery
      final completer = Completer<String?>();
      String? nfcId;
      bool tagProcessed = false;

      // Start the session
      try {
        await NfcManager.instance.startSession(
          pollingOptions: {
            NfcPollingOption.iso14443,
            NfcPollingOption.iso15693,
            NfcPollingOption.iso18092,
          },
          onDiscovered: (NfcTag tag) async {
            print('📱 ========== NFC TAG DETECTED ==========');
            print('📱 Tag type: ${tag.runtimeType}');
            print('📱 Tag data: ${tag.toString()}');
            
            // Prevent processing the same tag multiple times
            if (tagProcessed) {
              print('⚠️ Tag already processed, ignoring duplicate');
              return;
            }
            tagProcessed = true;
            
            print('📱 NFC tag discovered! Processing...');
            
            try {
              // First, try to read NDEF records (for NTAG216 and other NDEF-formatted tags)
            // This is where the actual card ID like "RC-d4a290fc" is stored
            print('📱 Attempting to read NDEF records from tag...');
            
            // Method 1: Try using Ndef.from() - this is the recommended way
            try {
              // Access Ndef class dynamically from nfc_manager
              final NdefClass = (NfcManager.instance as dynamic).Ndef;
              final ndef = NdefClass != null ? NdefClass.from(tag) : null;
              if (ndef != null) {
                print('✅ NDEF handler found via Ndef.from()');
                try {
                  final ndefMessage = await ndef.read();
                  print('📱 NDEF message read: ${ndefMessage != null ? "success" : "null"}');
                  
                  if (ndefMessage != null && ndefMessage.records != null) {
                    final records = ndefMessage.records as List;
                    print('📱 Found ${records.length} NDEF record(s)');
                    
                    for (int i = 0; i < records.length; i++) {
                      final record = records[i];
                      print('📱 Processing record $i: ${record.runtimeType}');
                      
                      // Check if it's a text record
                      final recordType = record.type;
                      print('📱 Record type: ${recordType.map((e) => e.toRadixString(16)).join(":")}');
                      
                      // 0x54 = 'T' for Text record type
                      if (recordType.isNotEmpty && recordType[0] == 0x54) {
                        print('✅ Found text record!');
                        try {
                          final payload = record.payload;
                          print('📱 Payload length: ${payload.length} bytes');
                          print('📱 Payload bytes: ${payload.map((e) => e.toRadixString(16).padLeft(2, '0')).join(":")}');
                          
                          if (payload.isNotEmpty) {
                            // First byte is status byte (language code length + encoding)
                            // Bit 7 = 0 means UTF-8 encoding, 1 means UTF-16
                            // Bits 6-0 = language code length
                            final statusByte = payload[0];
                            final isUTF16 = (statusByte & 0x80) != 0;
                            final langCodeLength = statusByte & 0x3F; // Lower 6 bits
                            
                            print('📱 Status byte: 0x${statusByte.toRadixString(16)}');
                            print('📱 UTF-16: $isUTF16, Language code length: $langCodeLength');
                            
                            // Skip status byte and language code
                            final textStartIndex = 1 + langCodeLength;
                            if (textStartIndex < payload.length) {
                              final textBytes = payload.sublist(textStartIndex);
                              print('📱 Text bytes length: ${textBytes.length}');
                              
                              // Decode text based on encoding
                              String text;
                              try {
                                if (isUTF16) {
                                  // UTF-16 encoding (unlikely but handle it)
                                  text = String.fromCharCodes(textBytes);
                                } else {
                                  // UTF-8 encoding
                                  text = utf8.decode(textBytes);
                                }
                                print('📱 Decoded text: "$text" (length: ${text.length})');
                                
                                // Trim and extract card ID
                                final trimmedText = text.trim();
                                print('📱 Trimmed text: "$trimmedText"');
                                
                                // Try to extract RC-XXXXXXXX pattern (case-insensitive)
                                // Pattern 1: Exact match RC-XXXXXXXX (8 hex chars)
                                final exactMatch = RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]{8}$', caseSensitive: false).firstMatch(trimmedText);
                                if (exactMatch != null) {
                                  nfcId = exactMatch.group(0)!;
                                  print('✅ Found exact card ID match: "$nfcId"');
                                  break;
                                }
                                
                                // Pattern 2: Starts with RC- followed by hex
                                final startsWithMatch = RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]+', caseSensitive: false).firstMatch(trimmedText);
                                if (startsWithMatch != null) {
                                  nfcId = startsWithMatch.group(0)!;
                                  print('✅ Found card ID (starts with RC-): "$nfcId"');
                                  break;
                                }
                                
                                // Pattern 3: Contains RC- anywhere
                                final containsMatch = RegExp(r'[Rr][Cc]-[A-Fa-f0-9]{8}', caseSensitive: false).firstMatch(trimmedText);
                                if (containsMatch != null) {
                                  nfcId = containsMatch.group(0)!;
                                  print('✅ Extracted card ID (contains RC-): "$nfcId"');
                                  break;
                                }
                                
                                // Pattern 4: If text is just the card ID without RC- prefix, add it
                                if (RegExp(r'^[A-Fa-f0-9]{8}$').hasMatch(trimmedText)) {
                                  nfcId = 'RC-$trimmedText';
                                  print('✅ Added RC- prefix to card ID: "$nfcId"');
                                  break;
                                }
                                
                                print('⚠️ Text does not match expected card ID format: "$trimmedText"');
                              } catch (e) {
                                print('⚠️ Error decoding text: $e');
                                // Fallback to Latin-1
                                try {
                                  final fallbackText = String.fromCharCodes(textBytes);
                                  print('📱 Fallback decoded text: "$fallbackText"');
                                  final trimmedFallback = fallbackText.trim();
                                  if (RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]{8}$', caseSensitive: false).hasMatch(trimmedFallback)) {
                                    nfcId = trimmedFallback;
                                    print('✅ Found card ID via fallback: "$nfcId"');
                                    break;
                                  }
                                } catch (e2) {
                                  print('⚠️ Fallback decoding also failed: $e2');
                                }
                              }
                            } else {
                              print('⚠️ Text start index ($textStartIndex) >= payload length (${payload.length})');
                            }
                          }
                        } catch (e) {
                          print('⚠️ Error parsing NDEF text record: $e');
                          print('Stack trace: ${StackTrace.current}');
                        }
                      } else {
                        print('📱 Record is not a text record (type: ${recordType[0].toRadixString(16)})');
                      }
                    }
                  } else {
                    print('⚠️ NDEF message is null or has no records');
                  }
                } catch (e) {
                  print('⚠️ Error reading NDEF message: $e');
                  print('Stack trace: ${StackTrace.current}');
                }
              } else {
                print('⚠️ NDEF handler is null - tag may not support NDEF');
              }
            } catch (e) {
              print('⚠️ Error accessing NDEF via Ndef.from(): $e');
              print('Stack trace: ${StackTrace.current}');
            }
            
            // Method 2: Fallback to dynamic access if Ndef.from() didn't work
            if (nfcId == null) {
              print('📱 Trying fallback method: dynamic NDEF access...');
              try {
                final tagDynamic = tag as dynamic;
                
                // Check if tag has NDEF data
                if (tagDynamic.ndef != null) {
                  final ndef = tagDynamic.ndef;
                  print('✅ Found NDEF via dynamic access');
                  try {
                    final ndefMessage = await ndef.read();
                    if (ndefMessage != null && ndefMessage.records != null) {
                      final records = ndefMessage.records as List;
                      print('📱 Found ${records.length} NDEF record(s) via fallback');
                      
                      for (final record in records) {
                        final recordDynamic = record as dynamic;
                        final recordType = recordDynamic.type as List<int>?;
                        if (recordType != null && recordType.isNotEmpty && recordType[0] == 0x54) {
                          try {
                            final payload = recordDynamic.payload as List<int>?;
                            if (payload != null && payload.isNotEmpty) {
                              final statusByte = payload[0];
                              final langCodeLength = statusByte & 0x3F;
                              final textStartIndex = 1 + langCodeLength;
                              if (textStartIndex < payload.length) {
                                final textBytes = payload.sublist(textStartIndex);
                                String text;
                                try {
                                  text = utf8.decode(textBytes);
                                } catch (e) {
                                  text = String.fromCharCodes(textBytes);
                                }
                                
                                print('📱 NDEF text (fallback): "$text"');
                                final trimmedText = text.trim();
                                
                                // Try to extract card ID
                                final match = RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]{8}$', caseSensitive: false).firstMatch(trimmedText);
                                if (match != null) {
                                  nfcId = match.group(0)!;
                                  print('✅ Found card ID (fallback): "$nfcId"');
                                  break;
                                }
                                
                                final startsWithMatch = RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]+', caseSensitive: false).firstMatch(trimmedText);
                                if (startsWithMatch != null) {
                                  nfcId = startsWithMatch.group(0)!;
                                  print('✅ Found card ID (fallback, starts with): "$nfcId"');
                                  break;
                                }
                              }
                            }
                          } catch (e) {
                            print('⚠️ Error parsing NDEF text (fallback): $e');
                          }
                        }
                      }
                    }
                  } catch (e) {
                    print('⚠️ Error reading NDEF message (fallback): $e');
                  }
                }
              } catch (e) {
                print('⚠️ Error in dynamic NDEF access: $e');
              }
            }
            
            // If NDEF didn't work, DO NOT fall back to tag identifier
            // Tag identifier creates random RC-XXXXX that doesn't match registered cards
            // Only use tag identifier if absolutely no NDEF data exists
            if (nfcId == null) {
              print('⚠️ No NDEF data found. Checking if tag has any readable data...');
              
              // Try multiple ways to access tag data
              Map<String, dynamic>? tagData;
              
              // Method 1: Try tag.handle
              try {
                final tagHandle = (tag as dynamic).handle;
                if (tagHandle is Map) {
                  tagData = tagHandle as Map<String, dynamic>;
                  print('✅ Got tag data from handle');
                }
              } catch (e) {
                print('⚠️ Could not access tag.handle: $e');
              }
              
              // Method 2: Try tag.data (if available)
              if (tagData == null) {
                try {
                  final tagDataProp = (tag as dynamic).data;
                  if (tagDataProp is Map) {
                    tagData = tagDataProp as Map<String, dynamic>;
                    print('✅ Got tag data from data property');
                  }
                } catch (e) {
                  print('⚠️ Could not access tag.data: $e');
                }
              }
              
              // Method 3: Try accessing directly
              if (tagData == null) {
                try {
                  final tagMap = Map<String, dynamic>.from(tag as Map);
                  tagData = tagMap;
                  print('✅ Got tag data by converting tag to map');
                } catch (e) {
                  print('⚠️ Could not convert tag to map: $e');
                }
              }
              
              print('📱 Tag data available: ${tagData != null}');
              if (tagData != null) {
                print('📱 Tag data keys: ${tagData.keys.toList()}');
              }
              
              if (tagData != null) {
                // Try to get ID from different tag technologies
                final nfca = tagData['nfca'] as Map<String, dynamic>?;
                if (nfca != null) {
                  final identifier = nfca['identifier'] as List<int>?;
                  if (identifier != null && identifier.isNotEmpty) {
                    // Convert to RC-XXXXXXXX format
                    final hexString = identifier
                        .map((e) => e.toRadixString(16).padLeft(2, '0'))
                        .join('')
                        .toUpperCase();
                    nfcId = 'RC-$hexString';
                    print('✅ Using tag identifier (NFCA): $nfcId');
                  }
                }
                
                if (nfcId == null) {
                  final nfcb = tagData['nfcb'] as Map<String, dynamic>?;
                  if (nfcb != null) {
                    final identifier = nfcb['identifier'] as List<int>?;
                    if (identifier != null && identifier.isNotEmpty) {
                      final hexString = identifier
                          .map((e) => e.toRadixString(16).padLeft(2, '0'))
                          .join('')
                          .toUpperCase();
                      nfcId = 'RC-$hexString';
                      print('✅ Using tag identifier (NFCB): $nfcId');
                    }
                  }
                }
                
                if (nfcId == null) {
                  final nfcf = tagData['nfcf'] as Map<String, dynamic>?;
                  if (nfcf != null) {
                    final identifier = nfcf['identifier'] as List<int>?;
                    if (identifier != null && identifier.isNotEmpty) {
                      final hexString = identifier
                          .map((e) => e.toRadixString(16).padLeft(2, '0'))
                          .join('')
                          .toUpperCase();
                      nfcId = 'RC-$hexString';
                      print('✅ Using tag identifier (NFCF): $nfcId');
                    }
                  }
                }
                
                if (nfcId == null) {
                  final nfcv = tagData['nfcv'] as Map<String, dynamic>?;
                  if (nfcv != null) {
                    final identifier = nfcv['identifier'] as List<int>?;
                    if (identifier != null && identifier.isNotEmpty) {
                      final hexString = identifier
                          .map((e) => e.toRadixString(16).padLeft(2, '0'))
                          .join('')
                          .toUpperCase();
                      nfcId = 'RC-$hexString';
                      print('✅ Using tag identifier (NFCV): $nfcId');
                    }
                  }
                }
              }
            }

            // If still no ID found, return null instead of generating random ID
            // Random IDs don't match registered cards and cause confusion
            if (nfcId == null) {
              print('❌ No card ID found in NDEF records. Tag may not be formatted correctly.');
              print('❌ Expected NDEF text record with format: "RC-XXXXXXXX"');
              print('❌ Please ensure the NFC tag has an NDEF text record containing the card ID');
              // Don't generate fallback - return null so user knows card wasn't read
              if (!completer.isCompleted) {
                completer.complete(null);
              }
              return;
            }

            // Only trim whitespace, preserve original case from NFC tag
            // Backend might be case-sensitive and expect exact format from NFC tag
            final originalId = nfcId;
            final trimmedId = nfcId!.trim();
            nfcId = trimmedId;
            print('📱 Final card ID (trimmed, preserving case): "$trimmedId" (original: "$originalId")');
            print('📱 Card ID length: ${trimmedId.length} characters');
            print('📱 Card ID bytes: ${trimmedId.codeUnits}');
            
            // Validate card ID format
            if (!RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]{8}$').hasMatch(trimmedId)) {
              print('⚠️ Warning: Card ID format may be incorrect: "$trimmedId"');
              print('⚠️ Expected format: RC-XXXXXXXX (8 hex characters)');
            }
            
            // Complete the future with the card ID
            if (!completer.isCompleted) {
              completer.complete(nfcId);
            }
          } catch (e) {
            print('❌ Error processing tag: $e');
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          } finally {
            // Don't stop session here - let it continue listening
            // Session will be stopped when completer completes or timeout occurs
            print('📱 Tag processing complete, session still active');
          }
        },
      );
      
      print('✅ NFC session started successfully');
      
      } catch (sessionError) {
        print('❌ Error starting NFC session: $sessionError');
        print('Stack trace: ${StackTrace.current}');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        return null;
      }

      // Wait for tag to be discovered (with timeout)
      try {
        return await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⏱️ NFC read timeout - no tag detected within 30 seconds');
            NfcManager.instance.stopSession().catchError((e) {
              print('⚠️ Error stopping session on timeout: $e');
            });
            return null;
          },
        );
      } catch (e) {
        print('❌ Error waiting for tag: $e');
        // Make sure to complete the completer if it's not already completed
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        try {
          await NfcManager.instance.stopSession();
        } catch (stopError) {
          print('⚠️ Error stopping session: $stopError');
        }
        return null;
      }
    } catch (e) {
      print('❌ Error in readNFCTag: $e');
      try {
        await NfcManager.instance.stopSession();
      } catch (stopError) {
        print('⚠️ Error stopping session in catch: $stopError');
      }
      return null;
    }
  }

  /// Read tag and create NFC event
  /// If cardId is provided, skip reading and use it directly
  Future<NfcEvent?> readTag({
    required String busId,
    required bool isTapIn,
    String? cardId, // Optional: if provided, skip NFC reading
  }) async {
    onProgress?.call('Reading NFC tag...');
    
    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Read NFC tag (or use provided cardId)
      String? detectedCardId = cardId;
      if (detectedCardId == null) {
        detectedCardId = await readNFCTag();
      } else {
        print('📱 Using provided card ID: $detectedCardId');
      }
      
      if (detectedCardId == null || detectedCardId.isEmpty) {
        print('❌ NFC tag read returned null or empty');
        onError?.call('No NFC card detected. Please ensure the card is properly formatted with an NDEF text record containing "RC-XXXXXXXX".');
        return null;
      }
      
      print('✅ NFC tag read successfully: "$detectedCardId"');

      // Create event
      final event = NfcEvent(
        cardId: detectedCardId,
        busId: busId,
        eventType: isTapIn ? 'tap_in' : 'tap_out',
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );

      // Try to process online first
      try {
        onProgress?.call('Processing...');
        NfcTapResponse response;
        
        if (isTapIn) {
          response = await _apiService.tapIn(event);
        } else {
          response = await _apiService.tapOut(event);
        }

        onSuccess?.call(response);
        return event;
      } on DioException catch (e) {
        // Check DioException type to determine if it's a network error
        final isNetworkError = e.type == DioExceptionType.connectionTimeout ||
                              e.type == DioExceptionType.receiveTimeout ||
                              e.type == DioExceptionType.connectionError ||
                              e.type == DioExceptionType.sendTimeout;
        
        // Check error message for validation errors
        String errorMessage = e.toString();
        String errorLower = errorMessage.toLowerCase();
        final responseMessage = e.response?.data?['message']?.toString().toLowerCase() ?? 
                              e.response?.data?['error']?.toString().toLowerCase() ?? '';
        
        // Check for validation errors (card not registered, etc.)
        final isValidationError = errorLower.contains('card not registered') || 
                                 errorLower.contains('card not found') ||
                                 errorLower.contains('not registered') ||
                                 errorLower.contains('please register') ||
                                 responseMessage.contains('not registered') ||
                                 responseMessage.contains('card not found') ||
                                 (e.response?.statusCode == 404 && 
                                  (errorLower.contains('card') || responseMessage.contains('card')));
        
        print('🔍 Error analysis:');
        print('   DioException type: ${e.type}');
        print('   Status code: ${e.response?.statusCode}');
        print('   Error message: $errorMessage');
        print('   Response message: $responseMessage');
        print('   Is validation error: $isValidationError');
        print('   Is network error: $isNetworkError');
        
        // Only save to offline storage if it's a network error
        // Validation errors should be shown immediately without saving
        if (isNetworkError) {
          // Save to offline storage for network errors
          print('💾 Saving to offline storage (network error)');
          onProgress?.call('Saving offline...');
          await _localDB.saveNFCLog(event);
          onError?.call('Saved offline: No connection. Will sync when online.');
          return event;
        } else if (isValidationError) {
          // Show validation error immediately without saving offline
          print('❌ Validation error - not saving offline');
          onError?.call('Card not registered. Please register your card first.');
          return null; // Don't return event for validation errors
        } else {
          // Other errors - show error but don't save offline
          print('❌ Other error - not saving offline');
          final finalMessage = e.response?.data?['message']?.toString() ?? 
                              e.response?.data?['error']?.toString() ?? 
                              errorMessage;
          onError?.call(finalMessage);
          return null;
        }
      } catch (e) {
        // Handle non-DioException errors
        String errorMessage = e.toString();
        String errorLower = errorMessage.toLowerCase();
        
        // Check for network-related errors
        final isNetworkError = errorLower.contains('socketexception') ||
                              errorLower.contains('failed host lookup') ||
                              errorLower.contains('connection refused') ||
                              errorLower.contains('connection timed out') ||
                              errorLower.contains('network is unreachable') ||
                              errorLower.contains('no internet') ||
                              errorLower.contains('timeout');
        
        if (isNetworkError) {
          print('💾 Saving to offline storage (network error)');
          onProgress?.call('Saving offline...');
          await _localDB.saveNFCLog(event);
          onError?.call('Saved offline: No connection. Will sync when online.');
          return event;
        } else {
          print('❌ Other error - not saving offline');
          onError?.call(errorMessage);
          return null;
        }
      }
    } catch (e) {
      onError?.call('Error: ${e.toString()}');
      return null;
    }
  }

  /// Stop NFC session
  Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
      print('📱 NFC session stopped');
    } catch (e) {
      print('⚠️ Error stopping session: $e');
    }
  }

  bool _backgroundSessionActive = false;
  bool _shouldKeepListening = false;

  /// Start a continuous background session that listens for tags
  /// This is used when the screen loads to be ready immediately
  Future<void> startBackgroundSession({
    required Function(String cardId) onCardDetected,
    Function(String error)? onError,
  }) async {
    if (_backgroundSessionActive) {
      print('📱 Background session already active');
      return;
    }

    _shouldKeepListening = true;
    _backgroundSessionActive = true;

    // Start listening in a loop
    _listenForTagsLoop(onCardDetected, onError);
  }

  /// Stop the background session
  Future<void> stopBackgroundSession() async {
    _shouldKeepListening = false;
    _backgroundSessionActive = false;
    try {
      await NfcManager.instance.stopSession();
      print('📱 Background session stopped');
    } catch (e) {
      print('⚠️ Error stopping background session: $e');
    }
  }

  /// Continuously listen for tags in a loop
  Future<void> _listenForTagsLoop(
    Function(String cardId) onCardDetected,
    Function(String error)? onError,
  ) async {
    print('📱 ========== Starting NFC listening loop ==========');
    
    while (_shouldKeepListening) {
      try {
        final isAvailable = await NfcManager.instance.isAvailable();
        if (!isAvailable) {
          print('❌ NFC not available');
          onError?.call('NFC is not available on this device');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        // Stop any existing session first
        try {
          await NfcManager.instance.stopSession();
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('⚠️ Error stopping previous session: $e');
        }

        print('📱 ========== Starting new NFC session ==========');
        print('📱 Session will intercept NFC tags automatically');
        print('📱 nfc_manager enables foreground dispatch automatically');
        print('📱 Ready to detect tags - tap your card now!');

        // Start session - nfc_manager automatically enables foreground dispatch
        // This gives our app priority to intercept NFC tags when in foreground
        await NfcManager.instance.startSession(
          pollingOptions: {
            NfcPollingOption.iso14443,
            NfcPollingOption.iso15693,
            NfcPollingOption.iso18092,
          },
          // Add error handling callback if available
          onDiscovered: (NfcTag tag) async {
            if (!_shouldKeepListening) {
              print('📱 Background session stopped, ignoring tag');
              try {
                await NfcManager.instance.stopSession();
              } catch (e) {
                // Ignore
              }
              return;
            }

            print('📱 ========== TAG DETECTED IN BACKGROUND ==========');
            print('📱 Tag type: ${tag.runtimeType}');
            print('📱 Tag handle: ${(tag as dynamic).handle}');
            
            try {
              final cardId = await _extractCardIdFromTag(tag);
              if (cardId != null) {
                print('✅ Background session: Card ID extracted: $cardId');
                
                // Stop session before calling callback
                try {
                  await NfcManager.instance.stopSession();
                } catch (e) {
                  print('⚠️ Error stopping session after tag detection: $e');
                }
                
                onCardDetected(cardId);
              } else {
                print('⚠️ Background session: Could not extract card ID');
                onError?.call('Could not read card ID from tag');
                
                // Stop and restart
                try {
                  await NfcManager.instance.stopSession();
                } catch (e) {
                  // Ignore
                }
              }
            } catch (e) {
              print('❌ Background session: Error processing tag: $e');
              print('Stack trace: ${StackTrace.current}');
              onError?.call('Error reading tag: $e');
              
              // Stop and restart
              try {
                await NfcManager.instance.stopSession();
              } catch (e2) {
                // Ignore
              }
            }
          },
        );

        // If session completes without detecting a tag, restart
        if (_shouldKeepListening) {
          print('📱 Session completed, restarting...');
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } catch (e) {
        print('❌ Error in listen loop: $e');
        onError?.call('Error in NFC session: $e');
        
        // Wait before retrying
        if (_shouldKeepListening) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    
    print('📱 Background listening loop ended');
  }

  /// Extract card ID from tag (helper method)
  Future<String?> _extractCardIdFromTag(NfcTag tag) async {
    String? nfcId;

    // Try to read NDEF records
    try {
      final NdefClass = (NfcManager.instance as dynamic).Ndef;
      final ndef = NdefClass != null ? NdefClass.from(tag) : null;
      if (ndef != null) {
        final ndefMessage = await ndef.read();
        if (ndefMessage != null && ndefMessage.records != null) {
          final records = ndefMessage.records as List;
          for (final record in records) {
            final recordType = record.type;
            if (recordType.isNotEmpty && recordType[0] == 0x54) {
              final payload = record.payload;
              if (payload.isNotEmpty) {
                final statusByte = payload[0];
                final langCodeLength = statusByte & 0x3F;
                final textStartIndex = 1 + langCodeLength;
                if (textStartIndex < payload.length) {
                  final textBytes = payload.sublist(textStartIndex);
                  String text;
                  try {
                    text = utf8.decode(textBytes);
                  } catch (e) {
                    text = String.fromCharCodes(textBytes);
                  }
                  final trimmedText = text.trim();
                  final match = RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]{8}$', caseSensitive: false).firstMatch(trimmedText);
                  if (match != null) {
                    nfcId = match.group(0)!;
                    break;
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ Error extracting card ID: $e');
    }

    return nfcId;
  }
}
