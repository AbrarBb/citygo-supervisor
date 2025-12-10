/// Seat Booking model
class SeatBooking {
  final String id;
  final String busId;
  final int seatNumber;
  final String? passengerName;
  final String? passengerId;
  final String? cardId;
  final String status; // 'booked', 'occupied', 'available'
  final DateTime? bookedAt;
  final DateTime? tripDate;
  final String? bookingType; // 'online', 'nfc', 'manual'

  SeatBooking({
    required this.id,
    required this.busId,
    required this.seatNumber,
    this.passengerName,
    this.passengerId,
    this.cardId,
    required this.status,
    this.bookedAt,
    this.tripDate,
    this.bookingType,
  });

  factory SeatBooking.fromJson(Map<String, dynamic> json) {
    return SeatBooking(
      id: json['id'] as String? ?? json['booking_id'] as String? ?? '',
      busId: json['bus_id'] as String,
      seatNumber: json['seat_number'] as int? ?? json['seat'] as int? ?? 0,
      passengerName: json['passenger_name'] as String? ?? 
                     json['name'] as String? ??
                     json['full_name'] as String?,
      passengerId: json['passenger_id'] as String? ?? 
                   json['user_id'] as String?,
      cardId: json['card_id'] as String? ?? json['nfc_id'] as String?,
      status: json['status'] as String? ?? 
              (json['is_booked'] == true ? 'booked' : 'available'),
      bookedAt: json['booked_at'] != null
          ? DateTime.parse(json['booked_at'] as String)
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null),
      tripDate: json['trip_date'] != null
          ? DateTime.parse(json['trip_date'] as String)
          : (json['date'] != null
              ? DateTime.parse(json['date'] as String)
              : null),
      bookingType: json['booking_type'] as String? ?? 
                   json['type'] as String? ?? 'online',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus_id': busId,
      'seat_number': seatNumber,
      if (passengerName != null) 'passenger_name': passengerName,
      if (passengerId != null) 'passenger_id': passengerId,
      if (cardId != null) 'card_id': cardId,
      'status': status,
      if (bookedAt != null) 'booked_at': bookedAt!.toIso8601String(),
      if (tripDate != null) 'trip_date': tripDate!.toIso8601String(),
      if (bookingType != null) 'booking_type': bookingType,
    };
  }
}

/// Bus Bookings Response
class BusBookings {
  final String busId;
  final String? busNumber;
  final int totalSeats;
  final int availableSeats;
  final int bookedSeats;
  final List<SeatBooking> bookings;
  final DateTime? tripDate;

  BusBookings({
    required this.busId,
    this.busNumber,
    required this.totalSeats,
    required this.availableSeats,
    required this.bookedSeats,
    required this.bookings,
    this.tripDate,
  });

  factory BusBookings.fromJson(Map<String, dynamic> json) {
    final bookingsList = (json['bookings'] as List<dynamic>? ?? 
                         json['seats'] as List<dynamic>? ?? 
                         json['data'] as List<dynamic>? ?? [])
        .map((e) => SeatBooking.fromJson(e as Map<String, dynamic>))
        .toList();

    final totalSeats = json['total_seats'] as int? ?? 
                      json['capacity'] as int? ?? 
                      json['total_capacity'] as int? ?? 
                      40;
    
    final bookedSeats = json['booked_seats'] as int? ?? 
                       bookingsList.where((b) => 
                         b.status == 'booked' || b.status == 'occupied'
                       ).length;
    
    final availableSeats = json['available_seats'] as int? ?? 
                           (totalSeats - bookedSeats);

    return BusBookings(
      busId: json['bus_id'] as String? ?? json['id'] as String,
      busNumber: json['bus_number'] as String?,
      totalSeats: totalSeats,
      availableSeats: availableSeats,
      bookedSeats: bookedSeats,
      bookings: bookingsList,
      tripDate: json['trip_date'] != null
          ? DateTime.parse(json['trip_date'] as String)
          : (json['date'] != null
              ? DateTime.parse(json['date'] as String)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bus_id': busId,
      if (busNumber != null) 'bus_number': busNumber,
      'total_seats': totalSeats,
      'available_seats': availableSeats,
      'booked_seats': bookedSeats,
      'bookings': bookings.map((e) => e.toJson()).toList(),
      if (tripDate != null) 'trip_date': tripDate!.toIso8601String(),
    };
  }
}

