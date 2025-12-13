/// Manual Ticket model
class ManualTicket {
  final String? offlineId;
  final String busId;
  final int passengerCount;
  final double fare;
  final double latitude;
  final double longitude;
  final String? notes;
  final int? seatNumber;
  final String? dropStopId; // Drop-off stop ID
  final DateTime timestamp;

  ManualTicket({
    this.offlineId,
    required this.busId,
    required this.passengerCount,
    required this.fare,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.seatNumber,
    this.dropStopId,
    required this.timestamp,
  });

  factory ManualTicket.fromJson(Map<String, dynamic> json) {
    return ManualTicket(
      offlineId: json['offline_id'] as String?,
      busId: json['bus_id'] as String,
      passengerCount: json['passenger_count'] as int,
      fare: (json['fare'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      notes: json['notes'] as String?,
      seatNumber: json['seat_number'] as int?,
      dropStopId: json['drop_stop_id'] as String? ?? json['dropStopId'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] as int? ?? json['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (offlineId != null) 'offline_id': offlineId,
      'bus_id': busId,
      'passenger_count': passengerCount,
      'fare': fare,
      'latitude': latitude,
      'longitude': longitude,
      if (notes != null) 'notes': notes,
      if (seatNumber != null) 'seat_number': seatNumber,
      if (dropStopId != null) 'drop_stop_id': dropStopId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

/// Ticket Response model
class TicketResponse {
  final bool success;
  final String ticketId;
  final String? qrCode;
  final String? message;
  final String? status; // 'created' or 'duplicate'
  final Map<String, dynamic>? booking; // Booking info if seat was booked

  TicketResponse({
    required this.success,
    required this.ticketId,
    this.qrCode,
    this.message,
    this.status,
    this.booking,
  });

  factory TicketResponse.fromJson(Map<String, dynamic> json) {
    return TicketResponse(
      success: json['success'] as bool? ?? true,
      ticketId: json['ticket_id'] as String? ?? json['id'] as String,
      qrCode: json['qr_code'] as String?,
      message: json['message'] as String?,
      status: json['status'] as String?,
      booking: json['booking'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'ticket_id': ticketId,
      if (qrCode != null) 'qr_code': qrCode,
      if (message != null) 'message': message,
      if (status != null) 'status': status,
      if (booking != null) 'booking': booking,
    };
  }
}

