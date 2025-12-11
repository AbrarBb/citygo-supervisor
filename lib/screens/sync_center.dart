import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../providers/sync_provider.dart';

/// Sync Center Screen - View and sync offline logs
class SyncCenterScreen extends ConsumerStatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  ConsumerState<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends ConsumerState<SyncCenterScreen> {
  List<Map<String, dynamic>> _offlineLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOfflineLogs();
  }

  Future<void> _loadOfflineLogs() async {
    setState(() => _isLoading = true);
    try {
      final syncService = ref.read(syncServiceProvider);
      final localDB = syncService.localDB;
      final logs = await localDB.getAllOfflineLogs();
      setState(() {
        _offlineLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading logs: $e')),
        );
      }
    }
  }

  Future<void> _syncNow() async {
    await ref.read(syncNotifierProvider.notifier).syncNow();
    await _loadOfflineLogs();
  }

  int get _unsyncedCount {
    return _offlineLogs.where((log) => log['synced'] == 0).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: TopBar(
        title: 'Sync Center',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Sync Button Card
          CityGoCard(
            margin: const EdgeInsets.all(AppTheme.spacingMD),
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offline Items',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          '$_unsyncedCount unsynced',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: const Icon(
                        Icons.cloud_sync,
                        size: 32,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMD),
                Consumer(
                  builder: (context, ref, child) {
                    final syncState = ref.watch(syncNotifierProvider);
                    return syncState.when(
                      data: (response) => PrimaryButton(
                        text: 'Sync Now',
                        icon: Icons.sync,
                        onPressed: _syncNow,
                        width: double.infinity,
                      ),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppTheme.spacingMD),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, __) => PrimaryButton(
                        text: 'Retry Sync',
                        icon: Icons.sync,
                        onPressed: _syncNow,
                        width: double.infinity,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Offline Logs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _offlineLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            Text(
                              'No offline logs',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOfflineLogs,
                        child: ListView.builder(
                          itemCount: _offlineLogs.length,
                          itemBuilder: (context, index) {
                            final log = _offlineLogs[index];
                            return _buildLogItem(log);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final isSynced = log['synced'] == 1;
    final type = log['type'] as String;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(log['timestamp'] as int);
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return CityGoCard(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      backgroundColor: isSynced
          ? AppTheme.surfaceDark
          : AppTheme.cardBackground,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (type == 'nfc' ? AppTheme.primaryBlue : AppTheme.primaryGreen)
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Icon(
              type == 'nfc' ? Icons.nfc : Icons.receipt,
              color: type == 'nfc' ? AppTheme.primaryBlue : AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == 'nfc'
                      ? 'NFC ${log['action']}'
                      : 'Manual Ticket',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  dateFormat.format(timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (type == 'nfc') ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'NFC: ${log['nfc_id']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ] else ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    '${log['passenger_count']} passengers • ৳${log['fare']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSM,
              vertical: AppTheme.spacingXS,
            ),
            decoration: BoxDecoration(
              color: isSynced
                  ? AppTheme.successColor.withOpacity(0.2)
                  : AppTheme.warningColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Text(
              isSynced ? 'Synced' : 'Pending',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSynced ? AppTheme.successColor : AppTheme.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

