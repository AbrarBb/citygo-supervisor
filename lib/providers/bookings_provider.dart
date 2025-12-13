import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/booking.dart';
import '../models/bus.dart';
import 'bus_provider.dart';

/// Bus bookings provider
final busBookingsProvider = FutureProvider.family<BusBookings?, String>((ref, busId) async {
  print('🚀🚀🚀 BOOKINGS PROVIDER CALLED 🚀🚀🚀');
  print('🚀 Bus ID parameter: "$busId"');
  print('🚀 Provider is starting to fetch bookings...');
  
  final apiService = ApiService();
  
    // Get bus info to get capacity and route info
    BusInfo? busInfo;
    try {
      print('🚀 Attempting to read bus provider for route info...');
      busInfo = await ref.read(busProvider.future).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          print('⚠️ Bus provider timeout - using defaults');
          return null;
        },
      );
      print('🚀 Bus provider returned: ${busInfo != null ? "has data" : "null"}');
    } catch (e) {
      print('⚠️ Error reading bus provider: $e');
      // Ignore - will use default capacity
    }
    
    final busCapacity = busInfo?.capacity ?? 40;
    final busRouteId = busInfo?.route?.id;
    final isBusActive = busInfo?.isActive ?? false;
    
    print('🚌 Bus info: routeId=$busRouteId, isActive=$isBusActive, capacity=$busCapacity');
  
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
      // Get all bookings first - we'll filter for the most recent active journey
      print('📅 ========== FETCHING BOOKINGS ==========');
      print('📅 Bus ID: "$busId"');
      print('📅 Bus ID type: ${busId.runtimeType}');
      print('📅 Bus capacity: $busCapacity');
      print('📅 Bus route ID: $busRouteId');
      print('📅 Bus is active: $isBusActive');
      print('📅 Backend filters by status (confirmed only) - excludes completed');
      print('📅 Client-side: Deduplicates multiple bookings per seat');
      print('📅 ========================================');
      
      // Get all bookings first (don't filter on API side - backend might filter incorrectly)
      // Then filter client-side to show only the most recent active journey
      print('📅 Calling API to get all bookings for bus...');
      final allBookings = await apiService.getBusBookings(
        busId: busId,
        date: null, // Get all bookings - we'll filter client-side
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ API call timed out after 15 seconds');
          throw Exception('Request timeout: API did not respond in time');
        },
      );
      
      print('✅ ========== API RESPONSE RECEIVED ==========');
      print('✅ Total bookings received: ${allBookings.bookings.length}');
      print('✅ Bus ID in response: ${allBookings.busId}');
      print('✅ Booked seats (from API): ${allBookings.bookedSeats}');
      print('✅ Available seats (from API): ${allBookings.availableSeats}');
      if (allBookings.bookings.isNotEmpty) {
        print('✅ First booking sample: Seat ${allBookings.bookings.first.seatNumber}, Status: ${allBookings.bookings.first.status}');
        print('📋 All booking timestamps:');
        for (var booking in allBookings.bookings) {
          final time = booking.tripDate ?? booking.bookedAt;
          print('   - Seat ${booking.seatNumber}: ${time ?? "NO TIMESTAMP"} (status: ${booking.status})');
        }
      } else {
        print('⚠️ WARNING: API returned empty bookings array!');
        print('⚠️ This could mean:');
        print('   1. No bookings exist for this bus');
        print('   2. API endpoint is not working correctly');
        print('   3. Bus ID mismatch');
        print('   4. Authentication issue');
      }
      print('✅ ===========================================');
      
      // Backend already filters by status, so all bookings are active
      // Find the most recent booking date for display purposes
      DateTime? mostRecentDate;
      if (allBookings.bookings.isNotEmpty) {
        for (final booking in allBookings.bookings) {
          DateTime? bookingDate;
          if (booking.tripDate != null) {
            bookingDate = DateTime(
              booking.tripDate!.year,
              booking.tripDate!.month,
              booking.tripDate!.day,
            );
          } else if (booking.bookedAt != null) {
            bookingDate = DateTime(
              booking.bookedAt!.year,
              booking.bookedAt!.month,
              booking.bookedAt!.day,
            );
          }
          
          if (bookingDate != null) {
            if (mostRecentDate == null || bookingDate.isAfter(mostRecentDate)) {
              mostRecentDate = bookingDate;
            }
          }
        }
        print('📅 Most recent booking date found: ${mostRecentDate?.toString().split(' ')[0] ?? "none"}');
        print('📅 Note: Backend already filters by status (confirmed only), excluding completed');
      }
      
      // Filter bookings: exclude completed, filter by route if available, then deduplicate
      // First, explicitly filter out completed bookings (safety check)
      final activeBookings = allBookings.bookings.where((booking) {
        final status = booking.status.toLowerCase();
        if (status == 'completed') {
          print('   ⏭️ Filtered out booking: Seat ${booking.seatNumber} (status: completed)');
          return false;
        }
        return true;
      }).toList();
      
      print('📊 After filtering completed: ${activeBookings.length} active bookings (from ${allBookings.bookings.length} total)');
      
      // Filter by route_id - STRICT: Only show bookings matching current route
      // This ensures old bookings from previous routes/journeys are excluded
      final activeJourneyBookings = activeBookings.where((booking) {
        if (busRouteId != null) {
          // If bus has a route_id, bookings MUST match it
          if (booking.routeId == null) {
            print('   ⏭️ Filtered out booking: Seat ${booking.seatNumber} (no route_id, bus route: $busRouteId)');
            return false;
          }
          
          final routeMatches = booking.routeId == busRouteId;
          if (!routeMatches) {
            print('   ⏭️ Filtered out booking: Seat ${booking.seatNumber} (route_id mismatch: ${booking.routeId} != $busRouteId)');
            return false;
          }
          
          print('   ✅ Route match: Seat ${booking.seatNumber} (route_id: ${booking.routeId})');
          return true;
        }
        
        // If bus has no route_id, include all active bookings (fallback)
        // But log a warning as this shouldn't happen
        if (booking.routeId != null) {
          print('   ⚠️ Bus has no route_id but booking has route_id: ${booking.routeId} - including anyway');
        }
        print('   ✅ Including booking: Seat ${booking.seatNumber} (status: ${booking.status}, bus has no route_id)');
        return true;
      }).toList();
    
    print('📊 Backend returned ${allBookings.bookings.length} active bookings (status: confirmed only)');
    print('📊 After route filtering: ${activeJourneyBookings.length} bookings');
    
    // Backend already filters by status, so activeJourneyBookings should contain all active bookings
    // No need for fallback since backend handles status filtering
    final bookingsToShow = activeJourneyBookings;
    
    // Filter to show only the most recent booking per seat (webapp behavior)
    // Group bookings by seat number and keep only the most recent one per seat
    // Filter by date (today) to show all bookings from current active journey
    final Map<int, SeatBooking> uniqueSeatBookings = {};
    
    // Get today's date for filtering
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    print('📅 Today\'s date: ${today.toString().split(' ')[0]}');
    print('📅 Current time: $now');
    print('📅 Current bus route_id: $busRouteId');
    
    // Filter: Show all bookings from today (current active journey) that match current route
    // This includes both webapp bookings and manual tickets from today
    for (final booking in bookingsToShow) {
      if (booking.seatNumber > 0 && booking.seatNumber <= busCapacity) {
        // Double-check route_id match (should already be filtered, but extra safety)
        if (busRouteId != null && booking.routeId != null && booking.routeId != busRouteId) {
          print('   ⏭️ Filtered out booking: Seat ${booking.seatNumber} (route_id mismatch in date filter: ${booking.routeId} != $busRouteId)');
          continue;
        }
        
        // Filter by date - only show bookings from today
        DateTime? bookingTime = booking.tripDate ?? booking.bookedAt;
        if (bookingTime != null) {
          final bookingDay = DateTime(bookingTime.year, bookingTime.month, bookingTime.day);
          
          // Check if booking is from today
          if (!bookingDay.isAtSameMomentAs(today)) {
            // Check if booking is from yesterday but within last 24 hours (edge case for late night trips)
            final yesterday = today.subtract(const Duration(days: 1));
            if (bookingDay.isAtSameMomentAs(yesterday)) {
              final hoursSinceBooking = now.difference(bookingTime).inHours;
              if (hoursSinceBooking > 24) {
                print('   ⏭️ Filtered out booking: Seat ${booking.seatNumber} (from yesterday, ${hoursSinceBooking}h ago)');
                continue;
              } else {
                print('   ✅ Including booking: Seat ${booking.seatNumber} (from yesterday but within 24h, ${hoursSinceBooking}h ago, route: ${booking.routeId})');
              }
            } else {
              print('   ⏭️ Filtered out booking: Seat ${booking.seatNumber} (different day: ${bookingDay.toString().split(' ')[0]} vs ${today.toString().split(' ')[0]}, route: ${booking.routeId})');
              continue;
            }
          } else {
            print('   ✅ Including booking: Seat ${booking.seatNumber} (from today, route: ${booking.routeId})');
          }
        } else {
          // If booking has no timestamp, only include if route_id matches
          if (busRouteId != null && booking.routeId != null && booking.routeId == busRouteId) {
            print('   ⚠️ Booking for Seat ${booking.seatNumber} has no timestamp but route matches - including it');
          } else {
            print('   ⏭️ Filtered out booking: Seat ${booking.seatNumber} (no timestamp and route mismatch or missing)');
            continue;
          }
        }
        
        final seatNum = booking.seatNumber;
        if (!uniqueSeatBookings.containsKey(seatNum)) {
          // First booking for this seat
          uniqueSeatBookings[seatNum] = booking;
          print('   ✅ Added booking for Seat $seatNum: ${booking.passengerName ?? "Unknown"} (time: ${booking.tripDate ?? booking.bookedAt})');
        } else {
          // Compare timestamps to keep the most recent booking
          final existing = uniqueSeatBookings[seatNum]!;
          DateTime? existingTime = existing.tripDate ?? existing.bookedAt;
          DateTime? newTime = booking.tripDate ?? booking.bookedAt;
          
          if (newTime != null && existingTime != null) {
            if (newTime.isAfter(existingTime)) {
              // New booking is more recent, replace it
              uniqueSeatBookings[seatNum] = booking;
              print('   🔄 Replaced booking for Seat $seatNum (newer: ${booking.passengerName ?? "Unknown"}, time: $newTime vs $existingTime)');
            } else {
              print('   ⏭️ Skipped duplicate booking for Seat $seatNum (older: ${booking.passengerName ?? "Unknown"}, time: $newTime vs $existingTime)');
            }
          } else if (newTime != null) {
            // New booking has timestamp, existing doesn't - use new one
            uniqueSeatBookings[seatNum] = booking;
            print('   🔄 Replaced booking for Seat $seatNum (has timestamp, existing doesn\'t)');
          } else if (existingTime != null) {
            // Existing has timestamp, new doesn't - keep existing
            print('   ⏭️ Skipped booking for Seat $seatNum (no timestamp, existing has one)');
          }
          // If neither has timestamp, keep the existing one
        }
      }
    }
    
    final finalBookings = uniqueSeatBookings.values.toList();
    print('📊 After deduplication: ${finalBookings.length} unique seat bookings (from ${bookingsToShow.length} total)');
    
    // Recalculate booked seats count from unique bookings
    // Backend only uses 'confirmed' status, but app normalizes it to 'booked' for display
    final bookedSeatsCount = finalBookings.where((b) {
      final status = b.status.toLowerCase();
      // Check for both 'booked' (normalized) and 'confirmed' (if normalization didn't happen)
      return status == 'booked' || status == 'confirmed';
    }).length;
    
    print('📊 Booked seats (from filtered): $bookedSeatsCount, Available: ${busCapacity - bookedSeatsCount}');
    print('📊 Bus ID in response: ${allBookings.busId}');
    if (allBookings.busId != busId) {
      print('⚠️ WARNING: Bus ID mismatch! Requested: $busId, Received: ${allBookings.busId}');
    }
    
    // Return bookings (filtered if possible, otherwise all)
    // Use most recent date or today as fallback
    final tripDate = mostRecentDate ?? DateTime.now();
    return BusBookings(
      busId: allBookings.busId,
      busNumber: allBookings.busNumber,
      totalSeats: busCapacity,
      availableSeats: busCapacity - bookedSeatsCount,
      bookedSeats: bookedSeatsCount,
      bookings: finalBookings, // Use deduplicated bookings
      tripDate: tripDate,
    );
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

