import '../services/api_service.dart';
import '../services/local_db.dart';
import '../models/nfc.dart';
import '../models/sync.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Sync Service for batch syncing offline data
class SyncService {
  final ApiService _apiService;
  final LocalDB _localDB;
  final Connectivity _connectivity = Connectivity();
  static const int batchSize = 50;

  SyncService(this._apiService, this._localDB);
  
  // Expose for access
  LocalDB get localDB => _localDB;

  /// Sync all offline data
  Future<SyncResponse> syncNow() async {
    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return SyncResponse(
        success: false,
        message: 'No internet connection',
        syncedCount: 0,
        failedCount: 0,
        results: [],
      );
    }

    try {
      // Get unsynced NFC logs
      final nfcEvents = await _localDB.getUnsyncedNFCLogs();
      
      // Get unsynced manual tickets
      final manualTickets = await _localDB.getUnsyncedManualTickets();

      if (nfcEvents.isEmpty && manualTickets.isEmpty) {
        return SyncResponse(
          success: true,
          message: 'No data to sync',
          syncedCount: 0,
          failedCount: 0,
          results: [],
        );
      }

      // Convert manual tickets to NFC events format for sync
      final allEvents = <NfcEvent>[];
      
      // Add NFC events
      allEvents.addAll(nfcEvents);

      // Sync in batches
      int syncedCount = 0;
      int failedCount = 0;
      final results = <SyncResult>[];

      for (int i = 0; i < allEvents.length; i += batchSize) {
        final batch = allEvents.skip(i).take(batchSize).toList();
        
        try {
          final syncResponse = await _apiService.syncEvents(batch);
          
          // Process results
          for (var event in batch) {
            if (event.offlineId != null) {
              final result = syncResponse.results.firstWhere(
                (r) => r.offlineId == event.offlineId,
                orElse: () => SyncResult(
                  offlineId: event.offlineId!,
                  success: true,
                  status: 'success',
                ),
              );
              
              results.add(result);
              
              if (result.success || result.status == 'success' || result.status == 'duplicate') {
                await _localDB.markNFCLogSynced(event.offlineId!, null);
                syncedCount++;
              } else {
                failedCount++;
              }
            }
          }
        } catch (e) {
          // Mark entire batch as failed
          for (var event in batch) {
            if (event.offlineId != null) {
              results.add(SyncResult(
                offlineId: event.offlineId!,
                success: false,
                status: 'error',
                error: e.toString(),
              ));
              failedCount++;
            }
          }
        }
      }

      // Sync manual tickets separately (if API supports it)
      // For now, we'll include them in the events sync above
      // If needed, add separate endpoint call here

      return SyncResponse(
        success: failedCount == 0,
        message: 'Synced $syncedCount items, $failedCount failed',
        syncedCount: syncedCount,
        failedCount: failedCount,
        results: results,
      );
    } catch (e) {
      return SyncResponse(
        success: false,
        message: 'Sync error: ${e.toString()}',
        syncedCount: 0,
        failedCount: 0,
        results: [],
      );
    }
  }

  /// Get sync status
  Future<int> getUnsyncedCount() async {
    return await _localDB.getUnsyncedCount();
  }

  /// Auto-sync when connectivity is restored
  Stream<ConnectivityResult> watchConnectivity() {
    return _connectivity.onConnectivityChanged;
  }
}
