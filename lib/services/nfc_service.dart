import 'package:nfc_manager/nfc_manager.dart';
import 'package:geolocator/geolocator.dart';
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
      String? nfcId;

      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
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
                              // Skip first byte (language code length)
                              final textBytes = payload.skip(1).toList();
                              final text = String.fromCharCodes(textBytes);
                              
                              // Check if text contains RC- format (card ID)
                              if (text.startsWith('RC-')) {
                                nfcId = text.trim();
                                print('✅ Found card ID in NDEF text record: $nfcId');
                                break;
                              } else if (text.contains('RC-')) {
                                // Extract RC-XXXXX from text
                                final match = RegExp(r'RC-[A-Fa-f0-9]+').firstMatch(text);
                                if (match != null) {
                                  nfcId = match.group(0);
                                  print('✅ Extracted card ID from NDEF text: $nfcId');
                                  break;
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
                            final textBytes = payload.skip(1).toList();
                            final text = String.fromCharCodes(textBytes);
                            if (text.startsWith('RC-')) {
                              nfcId = text.trim();
                              print('✅ Found card ID in NDEF: $nfcId');
                              break;
                            } else if (text.contains('RC-')) {
                              final match = RegExp(r'RC-[A-Fa-f0-9]+').firstMatch(text);
                              if (match != null) {
                                nfcId = match.group(0);
                                print('✅ Extracted card ID from NDEF: $nfcId');
                                break;
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
            
            // If NDEF didn't work, try reading tag identifier as fallback
            if (nfcId == null) {
              // Access tag data - nfc_manager exposes data through tag.data
              final tagData = (tag as dynamic).data as Map<String, dynamic>?;
              
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

            // If still no ID found, generate fallback
            if (nfcId == null) {
              final hash = tag.hashCode.toRadixString(16).toUpperCase();
              nfcId = 'RC-$hash';
              print('⚠️ No card ID found, using fallback: $nfcId');
            }

            print('📱 Final card ID: $nfcId');
          } catch (e) {
            print('❌ Error processing tag: $e');
          } finally {
            // Stop session after reading
            await NfcManager.instance.stopSession();
          }
        },
      );

      return nfcId;
    } catch (e) {
      print('❌ Error in readNFCTag: $e');
      await NfcManager.instance.stopSession();
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
        onError?.call('No NFC tag detected');
        return null;
      }

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
      } catch (e) {
        // Save to offline storage
        onProgress?.call('Saving offline...');
        await _localDB.saveNFCLog(event);
        onError?.call('Saved offline: ${e.toString()}');
        return event;
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
