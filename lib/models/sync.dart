/// Sync Response model
class SyncResponse {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final List<SyncResult> results;

  SyncResponse({
    required this.success,
    required this.message,
    required this.syncedCount,
    required this.failedCount,
    required this.results,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String? ?? 'Sync completed',
      syncedCount: json['synced_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => SyncResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'synced_count': syncedCount,
      'failed_count': failedCount,
      'results': results.map((e) => e.toJson()).toList(),
    };
  }
}

/// Sync Result for individual event
class SyncResult {
  final String offlineId;
  final bool success;
  final String? status; // 'success', 'duplicate', 'error'
  final String? error;
  final String? message;

  SyncResult({
    required this.offlineId,
    required this.success,
    this.status,
    this.error,
    this.message,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      offlineId: json['offline_id'] as String,
      success: json['success'] as bool? ?? json['status'] == 'success',
      status: json['status'] as String?,
      error: json['error'] as String?,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'offline_id': offlineId,
      'success': success,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (message != null) 'message': message,
    };
  }
}

