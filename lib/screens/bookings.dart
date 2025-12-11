import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../providers/bookings_provider.dart';
import '../models/booking.dart';

/// Bookings Screen - Display bus seat bookings
class BookingsScreen extends ConsumerWidget {
  final String busId;
  
  const BookingsScreen({
    super.key,
    required this.busId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(busBookingsProvider(busId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Bus Bookings'),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(busBookingsProvider(busId));
            },
          ),
        ],
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  Text(
                    'No Bookings Data',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    'Unable to load bookings.\nThe endpoint might not be available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          // Debug: Print booking data
          print('📊 BookingsScreen: Received ${bookings.bookings.length} bookings');
          print('📊 Total seats: ${bookings.totalSeats}, Booked: ${bookings.bookedSeats}, Available: ${bookings.availableSeats}');
          if (bookings.bookings.isNotEmpty) {
            print('📋 All bookings:');
            for (var b in bookings.bookings) {
              print('   - Seat ${b.seatNumber}: ${b.passengerName ?? "Unknown"} (${b.status})');
            }
          } else {
            print('⚠️ No bookings in the list!');
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(busBookingsProvider(busId));
              await ref.read(busBookingsProvider(busId).future);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Debug Info Card (always show for debugging)
                  _buildDebugCard(bookings),
                  
                  // Stats Cards
                  _buildStatsCards(bookings),
                  
                  const SizedBox(height: AppTheme.spacingLG),
                  
                  // Seat Map
                  _buildSeatMap(bookings),
                  
                  const SizedBox(height: AppTheme.spacingLG),
                  
                  // Bookings List
                  _buildBookingsList(bookings),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  'Error Loading Bookings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Text(
                  error.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLG),
                PrimaryButton(
                  text: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () {
                    ref.invalidate(busBookingsProvider(busId));
                  },
                  width: 200,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(BusBookings bookings) {
    return Row(
      children: [
        Expanded(
          child: CityGoCard(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_seat,
                      color: AppTheme.primaryBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Total Seats',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  '${bookings.totalSeats}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: CityGoCard(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Booked',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  '${bookings.bookedSeats}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingMD),
        Expanded(
          child: CityGoCard(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available,
                      color: AppTheme.accentCyanReal,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Available',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  '${bookings.availableSeats}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeatMap(BusBookings bookings) {
    print('🗺️ Building seat map: ${bookings.totalSeats} total seats, ${bookings.bookings.length} bookings');
    
    // Log all bookings with their details
    if (bookings.bookings.isNotEmpty) {
      print('📋 All bookings details:');
      for (var b in bookings.bookings) {
        print('   - ID: ${b.id}, Seat: ${b.seatNumber}, Name: ${b.passengerName ?? "N/A"}, Status: ${b.status}, BusId: ${b.busId}');
        
        // Warn if seat number is out of range
        if (b.seatNumber < 1 || b.seatNumber > bookings.totalSeats) {
          print('   ⚠️ WARNING: Seat ${b.seatNumber} is out of range (1-${bookings.totalSeats})');
        }
        if (b.seatNumber == 0) {
          print('   ⚠️ WARNING: Seat number is 0 (invalid)');
        }
      }
    } else {
      print('⚠️ No bookings found in the list!');
    }
    
    // Filter out bookings with invalid seat numbers (0 or out of range)
    final validBookings = bookings.bookings.where((b) => 
      b.seatNumber > 0 && b.seatNumber <= bookings.totalSeats
    ).toList();
    
    if (validBookings.length < bookings.bookings.length) {
      final invalidCount = bookings.bookings.length - validBookings.length;
      print('⚠️ Filtered out $invalidCount bookings with invalid seat numbers');
    }
    
    // Create a map of seat numbers to bookings
    final seatMap = <int, SeatBooking?>{}; 
    for (int i = 1; i <= bookings.totalSeats; i++) {
      try {
        final booking = validBookings.firstWhere(
          (b) => b.seatNumber == i,
        );
        seatMap[i] = booking;
        print('   ✅ Seat $i: ${booking.passengerName ?? "Unknown"} (${booking.status})');
      } catch (e) {
        // Seat is available - no booking found
        seatMap[i] = null;
      }
    }
    
    final bookedCount = seatMap.values.where((b) => b != null).length;
    print('🗺️ Seat map created: $bookedCount booked seats out of ${bookings.totalSeats} total');
    
    if (bookedCount == 0 && bookings.bookings.isNotEmpty) {
      print('⚠️ WARNING: Bookings exist but no seats matched!');
      print('   This might indicate a seat number mismatch.');
      print('   Valid bookings after filtering: ${validBookings.length}');
      if (validBookings.isNotEmpty) {
        print('   Valid booking seat numbers: ${validBookings.map((b) => b.seatNumber).join(", ")}');
      }
    }

    return CityGoCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seat Map',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(child: _buildLegendItem('Available', AppTheme.surfaceDark)),
              const SizedBox(width: AppTheme.spacingXS),
              Expanded(child: _buildLegendItem('Booked', AppTheme.primaryGreen)),
              const SizedBox(width: AppTheme.spacingXS),
              Expanded(child: _buildLegendItem('Occupied', AppTheme.primaryBlue)),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          const Divider(),
          const SizedBox(height: AppTheme.spacingMD),
          
          // Seat Grid (responsive layout)
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final seatsPerRow = (screenWidth / 80).floor().clamp(4, 6); // 4-6 seats per row
              final availableWidth = screenWidth - (AppTheme.spacingMD * 2) - (AppTheme.spacingSM * (seatsPerRow - 1));
              final seatSize = (availableWidth / seatsPerRow) - 4;
              final width = seatSize.clamp(50.0, 70.0);
              
              return Wrap(
                spacing: AppTheme.spacingSM,
                runSpacing: AppTheme.spacingSM,
                children: seatMap.entries.map((entry) {
                  final seatNum = entry.key;
                  final booking = entry.value;
                  final status = booking?.status.toLowerCase() ?? '';
                  final isBooked = booking != null && 
                                 (status == 'booked' || 
                                  status == 'occupied' || 
                                  status == 'confirmed');
                  
                  return _buildSeatWidget(seatNum, booking, isBooked, width);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderColor),
            ),
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatWidget(int seatNum, SeatBooking? booking, bool isBooked, double width) {
    final height = width; // Keep square
    
    Color seatColor;
    if (isBooked) {
      final status = booking?.status.toLowerCase() ?? '';
      seatColor = status == 'occupied' 
          ? AppTheme.primaryBlue 
          : AppTheme.primaryGreen;
    } else {
      seatColor = AppTheme.surfaceDark;
    }

    return Tooltip(
      message: booking?.passengerName ?? 'Seat $seatNum - Available',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: seatColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(
            color: isBooked ? seatColor : AppTheme.borderColor,
            width: isBooked ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$seatNum',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isBooked ? Colors.white : AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (isBooked && booking?.passengerName != null) ...[
              const SizedBox(height: 2),
              Icon(
                Icons.person,
                size: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsList(BusBookings bookings) {
    // Show ALL bookings, not just filtered ones - helps with debugging
    // Include all bookings regardless of status (booked, occupied, confirmed, or any other)
    final allBookings = bookings.bookings.toList()
      ..sort((a, b) {
        // Sort by seat number, but put invalid seats (0 or out of range) at the end
        if (a.seatNumber <= 0 || a.seatNumber > bookings.totalSeats) return 1;
        if (b.seatNumber <= 0 || b.seatNumber > bookings.totalSeats) return -1;
        return a.seatNumber.compareTo(b.seatNumber);
      });
    
    // Separate valid and invalid bookings
    final validBookings = allBookings.where((b) => 
      b.seatNumber > 0 && b.seatNumber <= bookings.totalSeats
    ).toList();
    final invalidBookings = allBookings.where((b) => 
      b.seatNumber <= 0 || b.seatNumber > bookings.totalSeats
    ).toList();
    
    print('📋 _buildBookingsList: ${allBookings.length} total bookings');
    print('   - Valid seat numbers (1-${bookings.totalSeats}): ${validBookings.length}');
    print('   - Invalid seat numbers: ${invalidBookings.length}');
    if (invalidBookings.isNotEmpty) {
      print('   - Invalid bookings: ${invalidBookings.map((b) => 'Seat ${b.seatNumber}').join(", ")}');
    }
    if (allBookings.isNotEmpty) {
      print('📋 All bookings: ${allBookings.map((b) => 'Seat ${b.seatNumber} (${b.status})').join(", ")}');
    }

    // Show message if no bookings at all
    if (allBookings.isEmpty) {
      return CityGoCard(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.event_available,
                size: 48,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                'No Bookings Yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'All seats are available',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CityGoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: const Text(
              'Booked Seats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allBookings.length,
            itemBuilder: (context, index) {
              final booking = allBookings[index];
              return _buildBookingItem(booking);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDebugCard(BusBookings bookings) {
    final validBookings = bookings.bookings.where((b) => 
      b.seatNumber > 0 && b.seatNumber <= bookings.totalSeats
    ).toList();
    final invalidBookings = bookings.bookings.where((b) => 
      b.seatNumber <= 0 || b.seatNumber > bookings.totalSeats
    ).toList();
    
    return CityGoCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: AppTheme.accentCyanReal, size: 20),
              const SizedBox(width: AppTheme.spacingXS),
              const Text(
                'Debug Info',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            'Bus ID: ${bookings.busId}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text(
            'Total Seats: ${bookings.totalSeats}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Total Bookings Received: ${bookings.bookings.length}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Valid Bookings (1-${bookings.totalSeats}): ${validBookings.length}',
            style: TextStyle(
              fontSize: 12, 
              color: validBookings.isEmpty ? AppTheme.errorColor : AppTheme.primaryGreen,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (invalidBookings.isNotEmpty)
            Text(
              'Invalid Bookings: ${invalidBookings.length}',
              style: const TextStyle(fontSize: 12, color: AppTheme.errorColor),
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            'Booked Seats (from API): ${bookings.bookedSeats}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'Available Seats: ${bookings.availableSeats}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
          if (bookings.bookings.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingSM),
            const Divider(),
            const SizedBox(height: AppTheme.spacingSM),
            const Text(
              'Raw Bookings Data:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            ...bookings.bookings.take(5).map((b) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seat ${b.seatNumber}: ${b.passengerName ?? "N/A"} (${b.status})',
                    style: TextStyle(
                      fontSize: 11, 
                      color: (b.seatNumber > 0 && b.seatNumber <= bookings.totalSeats) 
                          ? AppTheme.textSecondary 
                          : AppTheme.errorColor,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (b.seatNumber <= 0 || b.seatNumber > bookings.totalSeats)
                    Text(
                      '  ⚠️ Invalid seat number!',
                      style: const TextStyle(fontSize: 10, color: AppTheme.errorColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            )),
            if (bookings.bookings.length > 5)
              Text(
                '... and ${bookings.bookings.length - 5} more',
                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              ),
          ] else ...[
            const SizedBox(height: AppTheme.spacingSM),
            const Divider(),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              '⚠️ No bookings received from API',
              style: const TextStyle(fontSize: 12, color: AppTheme.errorColor),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              'Check:\n'
              '1. Backend endpoint /supervisor-bookings exists\n'
              '2. Bus ID matches supervisor\'s assigned bus\n'
              '3. Bookings exist in database for this bus\n'
              '4. Response includes "bookings" array\n'
              '5. Each booking has seat_number (1-40) and status="confirmed"',
              style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
              overflow: TextOverflow.visible,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingItem(SeatBooking booking) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Seat Number Badge
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: booking.status == 'occupied' 
                  ? AppTheme.primaryBlue.withOpacity(0.2)
                  : AppTheme.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: Border.all(
                color: booking.status == 'occupied' 
                    ? AppTheme.primaryBlue
                    : AppTheme.primaryGreen,
              ),
            ),
            child: Center(
              child: Text(
                '${booking.seatNumber}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: booking.status == 'occupied' 
                      ? AppTheme.primaryBlue
                      : AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          
          // Passenger Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.passengerName ?? 'Unknown Passenger',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (booking.cardId != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.credit_card,
                        size: 12,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          booking.cardId!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
                if (booking.bookedAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          DateFormat('MMM dd, HH:mm').format(booking.bookedAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSM,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: booking.status == 'occupied' 
                  ? AppTheme.primaryBlue.withOpacity(0.2)
                  : AppTheme.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Text(
              booking.status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: booking.status == 'occupied' 
                    ? AppTheme.primaryBlue
                    : AppTheme.primaryGreen,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

