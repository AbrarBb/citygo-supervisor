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
      
      print('📱 Starting NFC session...');
      print('📱 Waiting for NFC tag - please tap your card now');
      
      // Use Completer to wait for tag discovery
      final completer = Completer<String?>();
      String? nfcId;
      bool tagProcessed = false;

      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          // Prevent processing the same tag multiple times
          if (tagProcessed) return;
          tagProcessed = true;
          
          print('📱 NFC tag discovered! Processing...');
          try {
            // First, try to read NDEF records (for NTAG216 and other NDEF-formatted tags)
            // This is where the actual card ID like "RC-198b42de" is stored
            try {
              // Try to access NDEF class from nfc_manager package
              // Using dynamic access to work around potential import issues
              final tagDynamic = tag as dynamic;
              
              // Check if tag has NDEF data
              if (tagDynamic.ndef != null) {
                final ndef = tagDynamic.ndef;
                try {
                  final ndefMessage = await ndef.read();
                  if (ndefMessage != null && ndefMessage.records != null) {
                    final records = ndefMessage.records as List;
                    if (records.isNotEmpty) {
                      // Read all NDEF records and look for text records containing card ID
                      for (final record in records) {
                        final recordDynamic = record as dynamic;
                        // Check if it's a text record
                        final recordType = recordDynamic.type as List<int>?;
                        if (recordType != null && 
                            recordType.isNotEmpty && 
                            recordType[0] == 0x54) { // 'T' for Text
                          try {
                            final payload = recordDynamic.payload as List<int>?;
                            if (payload != null && payload.isNotEmpty) {
                              // First byte is status byte (language code length + encoding)
                              // Bit 7 = 0 means UTF-8 encoding
                              // Bits 6-0 = language code length
                              final statusByte = payload[0];
                              final langCodeLength = statusByte & 0x3F; // Lower 6 bits
                              
                              // Skip status byte and language code
                              final textStartIndex = 1 + langCodeLength;
                              if (textStartIndex < payload.length) {
                                final textBytes = payload.sublist(textStartIndex);
                                
                                // Try UTF-8 decoding
                                String text;
                                try {
                                  text = utf8.decode(textBytes);
                                } catch (e) {
                                  // Fallback to Latin-1 if UTF-8 fails
                                  text = String.fromCharCodes(textBytes);
                                }
                                
                                print('📱 NDEF text record content: "$text" (length: ${text.length})');
                                
                                // Check if text contains RC- format (card ID)
                                // Preserve original case - backend might be case-sensitive
                                final trimmedText = text.trim();
                                print('📱 Processing NDEF text: "$trimmedText" (length: ${trimmedText.length})');
                                
                                // Try multiple patterns to extract card ID
                                // Pattern 1: Starts with RC- or rc-
                                if (trimmedText.startsWith('RC-') || trimmedText.startsWith('rc-')) {
                                  // Extract the full RC-XXXXXXXX format
                                  final match = RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]{8}').firstMatch(trimmedText);
                                  if (match != null) {
                                    nfcId = match.group(0)!; // Preserve original case
                                    print('✅ Found card ID (starts with RC-): "$nfcId"');
                                    break;
                                  }
                                  // If no match, use the whole text if it looks like RC-XXXXXXXX
                                  if (RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]+').hasMatch(trimmedText)) {
                                    nfcId = trimmedText;
                                    print('✅ Using whole text as card ID: "$nfcId"');
                                    break;
                                  }
                                }
                                
                                // Pattern 2: Contains RC- anywhere in text
                                if (nfcId == null && (trimmedText.contains('RC-') || trimmedText.contains('rc-'))) {
                                  final match = RegExp(r'[Rr][Cc]-[A-Fa-f0-9]{8}').firstMatch(trimmedText);
                                  if (match != null) {
                                    nfcId = match.group(0)!; // Preserve original case
                                    print('✅ Extracted card ID (contains RC-): "$nfcId"');
                                    break;
                                  }
                                }
                                
                                // Pattern 3: Whole text matches RC-XXXXXXXX format
                                if (nfcId == null) {
                                  if (RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]{8}$').hasMatch(trimmedText)) {
                                    nfcId = trimmedText;
                                    print('✅ Whole text matches card ID format: "$nfcId"');
                                    break;
                                  }
                                }
                              }
                            }
                          } catch (e) {
                            print('⚠️ Error parsing NDEF text record: $e');
                          }
                        }
                      }
                    }
                  }
                } catch (e) {
                  print('⚠️ Error reading NDEF message: $e');
                  // Continue to fallback methods
                }
              } else {
                // Try using Ndef.from() if available
                try {
                  // Access Ndef class through package
                  final ndefFromTag = (NfcManager.instance as dynamic).Ndef?.from(tag);
                  if (ndefFromTag != null) {
                    final ndefMessage = await ndefFromTag.read();
                    if (ndefMessage != null && ndefMessage.records != null) {
                      final records = ndefMessage.records as List;
                      for (final record in records) {
                        final recordDynamic = record as dynamic;
                        final recordType = recordDynamic.type as List<int>?;
                        if (recordType != null && recordType.isNotEmpty && recordType[0] == 0x54) {
                          final payload = recordDynamic.payload as List<int>?;
                          if (payload != null && payload.isNotEmpty) {
                            // First byte is status byte (language code length + encoding)
                            final statusByte = payload[0];
                            final langCodeLength = statusByte & 0x3F; // Lower 6 bits
                            
                            // Skip status byte and language code
                            final textStartIndex = 1 + langCodeLength;
                            if (textStartIndex < payload.length) {
                              final textBytes = payload.sublist(textStartIndex);
                              
                              // Try UTF-8 decoding
                              String text;
                              try {
                                text = utf8.decode(textBytes);
                              } catch (e) {
                                // Fallback to Latin-1 if UTF-8 fails
                                text = String.fromCharCodes(textBytes);
                              }
                              
                              print('📱 NDEF text record content (fallback method): "$text"');
                              
                              // Use same robust extraction logic as primary method
                              final trimmedText = text.trim();
                              print('📱 Processing NDEF text (fallback): "$trimmedText" (length: ${trimmedText.length})');
                              
                              // Try multiple patterns to extract card ID
                              if (trimmedText.startsWith('RC-') || trimmedText.startsWith('rc-')) {
                                final match = RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]{8}').firstMatch(trimmedText);
                                if (match != null) {
                                  nfcId = match.group(0)!;
                                  print('✅ Found card ID (fallback, starts with RC-): "$nfcId"');
                                  break;
                                }
                                if (RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]+').hasMatch(trimmedText)) {
                                  nfcId = trimmedText;
                                  print('✅ Using whole text as card ID (fallback): "$nfcId"');
                                  break;
                                }
                              }
                              
                              if (nfcId == null && (trimmedText.contains('RC-') || trimmedText.contains('rc-'))) {
                                final match = RegExp(r'[Rr][Cc]-[A-Fa-f0-9]{8}').firstMatch(trimmedText);
                                if (match != null) {
                                  nfcId = match.group(0)!;
                                  print('✅ Extracted card ID (fallback, contains RC-): "$nfcId"');
                                  break;
                                }
                              }
                              
                              if (nfcId == null) {
                                if (RegExp(r'^[Rr][Cc]-[A-Fa-f0-9]{8}$').hasMatch(trimmedText)) {
                                  nfcId = trimmedText;
                                  print('✅ Whole text matches card ID format (fallback): "$nfcId"');
                                  break;
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                } catch (e2) {
                  print('⚠️ NDEF not accessible: $e2');
                }
              }
            } catch (e) {
              print('⚠️ Error accessing NDEF: $e');
              // NDEF not available, will fall back to tag identifier
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
            // Stop session after reading
            try {
              await NfcManager.instance.stopSession();
            } catch (e) {
              print('⚠️ Error stopping session: $e');
            }
          }
        },
      );

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
  Future<NfcEvent?> readTag({
    required String busId,
    required bool isTapIn,
  }) async {
    onProgress?.call('Reading NFC tag...');
    
    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Read NFC tag
      final cardId = await readNFCTag();
      
      if (cardId == null || cardId.isEmpty) {
        print('❌ NFC tag read returned null or empty');
        onError?.call('No NFC card detected. Please ensure the card is properly formatted with an NDEF text record containing "RC-XXXXXXXX".');
        return null;
      }
      
      print('✅ NFC tag read successfully: "$cardId"');

      // Create event
      final event = NfcEvent(
        cardId: cardId,
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
    await NfcManager.instance.stopSession();
  }
}
