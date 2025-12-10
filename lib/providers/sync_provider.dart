import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';
import '../models/sync.dart';

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ApiService(), LocalDB());
});

/// Sync status provider
final syncStatusProvider = FutureProvider<int>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  try {
    return await syncService.getUnsyncedCount().timeout(
      const Duration(seconds: 5),
      onTimeout: () => 0, // Return 0 if timeout
    );
  } catch (e) {
    // Return 0 on any error
    return 0;
  }
});

/// Sync notifier
final syncNotifierProvider = StateNotifierProvider<SyncNotifier, AsyncValue<SyncResponse?>>((ref) {
  return SyncNotifier(ref.watch(syncServiceProvider));
});

class SyncNotifier extends StateNotifier<AsyncValue<SyncResponse?>> {
  final SyncService _syncService;

  SyncNotifier(this._syncService) : super(const AsyncValue.data(null));

  /// Trigger sync
  Future<void> syncNow() async {
    state = const AsyncValue.loading();
    try {
      final response = await _syncService.syncNow();
      state = AsyncValue.data(response);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

