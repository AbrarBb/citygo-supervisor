import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/nfc_service.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';
import '../models/nfc.dart';
import '../models/pagination.dart';

/// NFC service provider
final nfcServiceProvider = Provider<NFCService>((ref) {
  return NFCService(ApiService(), LocalDB());
});

/// NFC logs provider with pagination
final nfcLogsProvider = StateNotifierProvider<NfcLogsNotifier, AsyncValue<PaginatedResponse<NfcLog>>>((ref) {
  return NfcLogsNotifier();
});

class NfcLogsNotifier extends StateNotifier<AsyncValue<PaginatedResponse<NfcLog>>> {
  final ApiService _apiService = ApiService();
  final LocalDB _localDB = LocalDB();
  String? _nextCursor;
  bool _hasMore = true;

  NfcLogsNotifier() : super(const AsyncValue.loading()) {
    loadLogs();
  }

  /// Load logs (from local DB or API)
  Future<void> loadLogs({bool refresh = false}) async {
    if (refresh) {
      _nextCursor = null;
      _hasMore = true;
    }

    state = const AsyncValue.loading();
    
    try {
      // Try API first, fallback to local DB
      try {
        final response = await _apiService.getWithCursor<NfcLog>(
          path: '/nfc-logs', // Adjust endpoint if different
          query: _nextCursor != null ? {'cursor': _nextCursor} : null,
          fromJson: (json) => NfcLog.fromJson(json),
        );
        
        _nextCursor = response.nextCursor;
        _hasMore = response.hasMore;
        
        state = AsyncValue.data(response);
      } catch (e) {
        // Fallback to local DB
        final logs = await _localDB.getAllOfflineLogs();
        final nfcLogs = logs
            .where((log) => log['type'] == 'nfc')
            .map((log) => NfcLog.fromJson({
              'offline_id': log['offline_id'],
              'card_id': log['card_id'] ?? log['nfc_id'],
              'bus_id': log['bus_id'],
              'event_type': log['event_type'] ?? log['action'],
              'latitude': log['latitude'],
              'longitude': log['longitude'],
              'timestamp': log['timestamp'],
              'synced': log['synced'],
            }))
            .toList();
        
        state = AsyncValue.data(PaginatedResponse<NfcLog>(
          items: nfcLogs,
          hasMore: false,
        ));
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Load more logs
  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;
    
    try {
      final current = state.value;
      if (current == null) return;

      final response = await _apiService.getWithCursor<NfcLog>(
        path: '/nfc-logs',
        query: _nextCursor != null ? {'cursor': _nextCursor} : null,
        fromJson: (json) => NfcLog.fromJson(json),
      );

      _nextCursor = response.nextCursor;
      _hasMore = response.hasMore;

      state = AsyncValue.data(PaginatedResponse<NfcLog>(
        items: [...current.items, ...response.items],
        nextCursor: response.nextCursor,
        hasMore: response.hasMore,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

