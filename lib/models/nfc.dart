/// NFC Event model
class NfcEvent {
  final String? offlineId;
  final String cardId;
  final String busId;
  final String eventType; // 'tap_in' or 'tap_out'
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  NfcEvent({
    this.offlineId,
    required this.cardId,
    required this.busId,
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory NfcEvent.fromJson(Map<String, dynamic> json) {
    return NfcEvent(
      offlineId: json['offline_id'] as String?,
      cardId: json['card_id'] as String? ?? json['nfc_id'] as String,
      busId: json['bus_id'] as String,
      eventType: json['event_type'] as String? ?? json['action'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int? ?? json['created_at'] as int? ?? 0,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (offlineId != null) 'offline_id': offlineId,
      'nfc_id': cardId,
      'card_id': cardId,
      'bus_id': busId,
      'action': eventType,
      'event_type': eventType,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// NFC Tap Response model
class NfcTapResponse {
  final bool success;
  final String? message;
  final String? userName;
  final double? fare;
  final double? balance;
  final double? co2Saved;
  final String? cardId;

  NfcTapResponse({
    required this.success,
    this.message,
    this.userName,
    this.fare,
    this.balance,
    this.co2Saved,
    this.cardId,
  });

  factory NfcTapResponse.fromJson(Map<String, dynamic> json) {
    return NfcTapResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String?,
      userName: json['name'] as String? ?? json['user_name'] as String?,
      fare: json['fare'] != null ? (json['fare'] as num).toDouble() : null,
      balance: json['balance'] != null ? (json['balance'] as num).toDouble() : null,
      co2Saved: json['co2_saved'] != null ? (json['co2_saved'] as num).toDouble() : null,
      cardId: json['card_id'] as String? ?? json['nfc_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (message != null) 'message': message,
      if (userName != null) 'name': userName,
      if (fare != null) 'fare': fare,
      if (balance != null) 'balance': balance,
      if (co2Saved != null) 'co2_saved': co2Saved,
      if (cardId != null) 'card_id': cardId,
    };
  }
}

/// NFC Log model (for sync)
class NfcLog {
  final String? offlineId;
  final String cardId;
  final String busId;
  final String eventType;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool synced;

  NfcLog({
    this.offlineId,
    required this.cardId,
    required this.busId,
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.synced = false,
  });

  factory NfcLog.fromJson(Map<String, dynamic> json) {
    return NfcLog(
      offlineId: json['offline_id'] as String?,
      cardId: json['card_id'] as String? ?? json['nfc_id'] as String,
      busId: json['bus_id'] as String,
      eventType: json['event_type'] as String? ?? json['action'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int,
      ),
      synced: (json['synced'] as int? ?? json['synced'] as bool? ?? false) == 1 || 
              (json['synced'] as bool? ?? false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (offlineId != null) 'offline_id': offlineId,
      'nfc_id': cardId,
      'card_id': cardId,
      'bus_id': busId,
      'action': eventType,
      'event_type': eventType,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'synced': synced ? 1 : 0,
    };
  }
}

