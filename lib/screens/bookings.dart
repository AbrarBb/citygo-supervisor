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
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_seat,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      'Total Seats',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  '${bookings.totalSeats}',
                  style: const TextStyle(
                    fontSize: 24,
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
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      'Booked',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  '${bookings.bookedSeats}',
                  style: const TextStyle(
                    fontSize: 24,
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
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      color: AppTheme.accentCyanReal,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      'Available',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  '${bookings.availableSeats}',
                  style: const TextStyle(
                    fontSize: 24,
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
    // Create a map of seat numbers to bookings
    final seatMap = <int, SeatBooking?>{};
    for (int i = 1; i <= bookings.totalSeats; i++) {
      try {
        seatMap[i] = bookings.bookings.firstWhere(
          (b) => b.seatNumber == i,
        );
      } catch (e) {
        // Seat is available - no booking found
        seatMap[i] = null;
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
              _buildLegendItem('Available', AppTheme.surfaceDark),
              _buildLegendItem('Booked', AppTheme.primaryGreen),
              _buildLegendItem('Occupied', AppTheme.primaryBlue),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          const Divider(),
          const SizedBox(height: AppTheme.spacingMD),
          
          // Seat Grid (2 columns, typical bus layout)
          Wrap(
            spacing: AppTheme.spacingSM,
            runSpacing: AppTheme.spacingSM,
            children: seatMap.entries.map((entry) {
              final seatNum = entry.key;
              final booking = entry.value;
              final isBooked = booking != null && 
                             (booking.status == 'booked' || booking.status == 'occupied');
              
              return _buildSeatWidget(seatNum, booking, isBooked);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSeatWidget(int seatNum, SeatBooking? booking, bool isBooked) {
    final width = 60.0;
    final height = 60.0;
    
    Color seatColor;
    if (isBooked) {
      seatColor = booking?.status == 'occupied' 
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
            Text(
              '$seatNum',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isBooked ? Colors.white : AppTheme.textPrimary,
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
    final bookedSeats = bookings.bookings
        .where((b) => b.status == 'booked' || b.status == 'occupied')
        .toList()
      ..sort((a, b) => a.seatNumber.compareTo(b.seatNumber));

    if (bookedSeats.isEmpty) {
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
            itemCount: bookedSeats.length,
            itemBuilder: (context, index) {
              final booking = bookedSeats[index];
              return _buildBookingItem(booking);
            },
          ),
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
                      Text(
                        booking.cardId!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                          fontFamily: 'monospace',
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
                      Text(
                        DateFormat('MMM dd, HH:mm').format(booking.bookedAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
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
            ),
          ),
        ],
      ),
    );
  }
}

