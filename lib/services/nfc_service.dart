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
          // Extract NFC ID from tag
          final tagData = tag.data as Map<String, dynamic>?;
          
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
                }
              }
            }
          }

          // If no ID found, generate fallback
          if (nfcId == null) {
            final hash = tag.hashCode.toRadixString(16).toUpperCase();
            nfcId = 'RC-$hash';
          }

          // Stop session after reading
          await NfcManager.instance.stopSession();
        },
      );

      return nfcId;
    } catch (e) {
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
