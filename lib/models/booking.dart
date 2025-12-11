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
    // Normalize status: 'confirmed' -> 'booked'
    String status = json['status'] as String? ?? 
                    json['booking_status'] as String? ?? 
                    'available';
    if (status == 'confirmed') {
      status = 'booked';
    }
    
    // Try multiple field names for seat number
    int? seatNumber;
    if (json['seat_number'] != null) {
      seatNumber = (json['seat_number'] as num?)?.toInt();
    } else if (json['seat_no'] != null) {
      seatNumber = (json['seat_no'] as num?)?.toInt();
    } else if (json['seat'] != null) {
      seatNumber = (json['seat'] as num?)?.toInt();
    } else if (json['seatNumber'] != null) {
      seatNumber = (json['seatNumber'] as num?)?.toInt();
    }
    
    if (seatNumber == null || seatNumber == 0) {
      print('⚠️ Warning: Seat number is missing or 0 in booking');
      print('   JSON keys: ${json.keys.toList()}');
      print('   Full booking data: $json');
    } else if (seatNumber < 1 || seatNumber > 40) {
      print('⚠️ Warning: Seat number $seatNumber is out of valid range (1-40)');
      print('   Full booking data: $json');
    }
    
    // Try multiple field names for passenger name
    String? passengerName;
    if (json['passenger_name'] != null) {
      passengerName = json['passenger_name'] as String?;
    } else if (json['name'] != null) {
      passengerName = json['name'] as String?;
    } else if (json['full_name'] != null) {
      passengerName = json['full_name'] as String?;
    } else if (json['profiles'] != null) {
      // Handle nested profile object
      final profiles = json['profiles'];
      if (profiles is Map) {
        passengerName = profiles['full_name'] as String?;
      }
    }
    
    return SeatBooking(
      id: json['id'] as String? ?? json['booking_id'] as String? ?? '',
      busId: json['bus_id'] as String? ?? json['busId'] as String? ?? '',
      seatNumber: seatNumber ?? 0,
      passengerName: passengerName,
      passengerId: json['passenger_id'] as String? ?? 
                   json['user_id'] as String?,
      cardId: json['card_id'] as String? ?? 
              json['nfc_id'] as String? ??
              json['cardId'] as String?,
      status: status,
      bookedAt: json['booked_at'] != null
          ? DateTime.tryParse(json['booked_at'] as String)
          : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : (json['booking_date'] != null
                  ? DateTime.tryParse(json['booking_date'] as String)
                  : null)),
      tripDate: json['trip_date'] != null
          ? DateTime.tryParse(json['trip_date'] as String)
          : (json['travel_date'] != null
              ? DateTime.tryParse(json['travel_date'] as String)
              : (json['date'] != null
                  ? DateTime.tryParse(json['date'] as String)
                  : null)),
      bookingType: json['booking_type'] as String? ?? 
                   json['type'] as String? ?? 
                   (json['payment_method'] == 'rapid_card' ? 'rapid_card' : 'online'),
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
    
    // Calculate booked seats - include 'confirmed', 'booked', and 'occupied' statuses
    final bookedSeats = json['booked_seats'] as int? ?? 
                       bookingsList.where((b) {
                         final status = b.status.toLowerCase();
                         return status == 'booked' || 
                                status == 'occupied' || 
                                status == 'confirmed';
                       }).length;
    
    print('📊 BusBookings.fromJson: total_seats=$totalSeats, booked_seats=$bookedSeats, bookings_count=${bookingsList.length}');
    
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
          : (json['travel_date'] != null
              ? DateTime.parse(json['travel_date'] as String)
              : (json['date'] != null
                  ? DateTime.parse(json['date'] as String)
                  : null)),
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

