import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/booking.dart';
import '../models/bus.dart';
import 'bus_provider.dart';

/// Bus bookings provider
final busBookingsProvider = FutureProvider.family<BusBookings?, String>((ref, busId) async {
  final apiService = ApiService();
  
  // Get bus info to get capacity
  BusInfo? busInfo;
  try {
    busInfo = await ref.read(busProvider.future).timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
  } catch (e) {
    // Ignore - will use default capacity
  }
  
  final busCapacity = busInfo?.capacity ?? 40;
  
  // Check if we're in demo mode
  bool isDemo = false;
  try {
    final token = await apiService.getStoredToken().timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => null,
    );
    isDemo = token != null && token.startsWith('demo_');
  } catch (e) {
    isDemo = false;
  }
  
  // If demo mode, return mock data
  if (isDemo) {
    return _getMockBookings(busId, busCapacity);
  }
  
  try {
    final bookings = await apiService.getBusBookings(
      busId: busId,
      date: DateTime.now(),
    ).timeout(
      const Duration(seconds: 5),
    );
    
    // Update total seats from bus capacity if not provided
    if (bookings.totalSeats == 0 || bookings.totalSeats != busCapacity) {
      return BusBookings(
        busId: bookings.busId,
        busNumber: bookings.busNumber,
        totalSeats: busCapacity,
        availableSeats: busCapacity - bookings.bookedSeats,
        bookedSeats: bookings.bookedSeats,
        bookings: bookings.bookings,
        tripDate: bookings.tripDate,
      );
    }
    
    return bookings;
  } catch (e) {
    print('Error loading bookings: $e');
    // Return empty bookings with correct capacity
    return BusBookings(
      busId: busId,
      totalSeats: busCapacity,
      availableSeats: busCapacity,
      bookedSeats: 0,
      bookings: [],
    );
  }
});

/// Mock bookings data for demo
BusBookings _getMockBookings(String busId, int capacity) {
  return BusBookings(
    busId: busId,
    busNumber: 'DEMO-001',
    totalSeats: capacity,
    availableSeats: capacity - 15,
    bookedSeats: 15,
    bookings: [
      SeatBooking(
        id: 'booking-1',
        busId: busId,
        seatNumber: 1,
        passengerName: 'John Doe',
        cardId: 'RC-d4a290fc',
        status: 'booked',
        bookedAt: DateTime.now().subtract(const Duration(hours: 2)),
        bookingType: 'online',
      ),
      SeatBooking(
        id: 'booking-2',
        busId: busId,
        seatNumber: 2,
        passengerName: 'Jane Smith',
        cardId: 'RC-198b42de',
        status: 'booked',
        bookedAt: DateTime.now().subtract(const Duration(hours: 1)),
        bookingType: 'nfc',
      ),
      SeatBooking(
        id: 'booking-3',
        busId: busId,
        seatNumber: 5,
        passengerName: 'Ahmed Khan',
        cardId: 'RC-47b8dbab',
        status: 'booked',
        bookedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        bookingType: 'online',
      ),
      SeatBooking(
        id: 'booking-4',
        busId: busId,
        seatNumber: 10,
        passengerName: 'Sarah Ali',
        status: 'booked',
        bookedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        bookingType: 'manual',
      ),
    ],
    tripDate: DateTime.now(),
  );
}

