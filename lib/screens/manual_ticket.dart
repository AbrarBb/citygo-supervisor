import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';
import '../models/ticket.dart';
import '../providers/bookings_provider.dart';
import '../providers/bus_provider.dart';
import '../models/booking.dart';

/// Manual Ticket Screen - Form for issuing manual tickets
class ManualTicketScreen extends ConsumerStatefulWidget {
  final String busId;

  const ManualTicketScreen({
    super.key,
    required this.busId,
  });

  @override
  ConsumerState<ManualTicketScreen> createState() => _ManualTicketScreenState();
}

class _ManualTicketScreenState extends ConsumerState<ManualTicketScreen> {
  final ApiService _apiService = ApiService();
  final LocalDB _localDB = LocalDB();
  final _formKey = GlobalKey<FormState>();
  
  int _passengerCount = 1;
  double _farePerPassenger = 2.50;
  String _notes = '';
  int? _selectedSeat;
  String? _selectedDropStopId;
  bool _isSubmitting = false;

  double get _totalFare => _passengerCount * _farePerPassenger;
  
  /// Get available seats from bookings
  List<int> _getAvailableSeats(BusBookings? bookings) {
    if (bookings == null) {
      // If no bookings data, assume all seats 1-40 are available
      return List.generate(40, (index) => index + 1);
    }
    
    final bookedSeatNumbers = bookings.bookings
        .where((b) => b.seatNumber > 0 && b.seatNumber <= bookings.totalSeats)
        .map((b) => b.seatNumber)
        .toSet();
    
    final availableSeats = <int>[];
    for (int i = 1; i <= bookings.totalSeats; i++) {
      if (!bookedSeatNumbers.contains(i)) {
        availableSeats.add(i);
      }
    }
    
    return availableSeats;
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) {
      // Show error message if validation fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all required fields correctly'),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get current location with timeout and error handling
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            // Use a default location if timeout
            throw TimeoutException('Location request timed out');
          },
        );
      } on TimeoutException {
        // If location times out, use last known position or default
        try {
          position = await Geolocator.getLastKnownPosition() ?? Position(
            latitude: 23.7947, // Default: Dhaka
            longitude: 90.4144,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
          print('⚠️ Using last known position or default location');
        } catch (e) {
          // Use default location
          position = Position(
            latitude: 23.7947,
            longitude: 90.4144,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
          print('⚠️ Using default location (Dhaka)');
        }
      } catch (e) {
        print('❌ Location error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location error: ${e.toString()}. Using default location.'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // Use default location
        position = Position(
          latitude: 23.7947,
          longitude: 90.4144,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }

      // Issue ticket
      final ticket = ManualTicket(
        busId: widget.busId,
        passengerCount: _passengerCount,
        fare: _totalFare,
        latitude: position.latitude,
        longitude: position.longitude,
        notes: _notes.isEmpty ? null : _notes,
        seatNumber: _selectedSeat,
        dropStopId: _selectedDropStopId,
        timestamp: DateTime.now(),
      );
      
      print('🎫 Issuing manual ticket...');
      print('📦 Ticket data: busId=${ticket.busId}, passengers=${ticket.passengerCount}, fare=${ticket.fare}');
      print('📦 Seat: ${ticket.seatNumber ?? "none"}, Drop Stop: ${ticket.dropStopId ?? "none"}');
      print('📍 Location: ${ticket.latitude}, ${ticket.longitude}');
      
      final result = await _apiService.issueManualTicket(ticket);

      print('✅ Ticket issued successfully: ${result.ticketId}');
      print('✅ Status: ${result.status ?? "created"}');
      if (result.booking != null) {
        print('✅ Booking created: Seat ${result.booking!['seat_number']}, Status: ${result.booking!['status']}');
        print('✅ Booking ID: ${result.booking!['id']}');
      } else if (ticket.seatNumber != null) {
        print('⚠️ WARNING: Seat ${ticket.seatNumber} was selected but no booking info in response');
        print('⚠️ Backend should create a booking when seat_number is provided');
        print('⚠️ This may be a backend issue - check the manual-ticket edge function');
        
        // Show warning to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ticket issued but booking not created. Seat ${ticket.seatNumber} may still be available.'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
      
      // Always refresh bookings after issuing a ticket to show updated seat status
      // Backend now returns booking info in response, so we can refresh immediately
      print('🔄 Refreshing bookings to reflect new ticket...');
      Future.delayed(const Duration(milliseconds: 500), () {
        // Only invalidate if widget is still mounted
        if (mounted) {
          // Invalidate bookings provider to force refresh on next access
          ref.invalidate(busBookingsProvider(widget.busId));
          print('✅ Bookings provider invalidated - will refresh on next access');
        } else {
          print('⚠️ Widget disposed, skipping bookings refresh');
        }
      });

      if (mounted) {
        final message = _selectedSeat != null
            ? 'Ticket issued! Seat $_selectedSeat has been booked.'
            : (result.message ?? 'Ticket issued successfully!');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, result);
      }
    } catch (e, stackTrace) {
      print('❌ Error issuing ticket: $e');
      print('❌ Stack trace: $stackTrace');
      
      // Extract error message
      String errorMessage = 'Failed to issue ticket';
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }
      
      // Show error to user immediately
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      // Save to offline storage on error
      try {
        print('💾 Attempting to save ticket offline...');
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final ticket = ManualTicket(
          busId: widget.busId,
          passengerCount: _passengerCount,
          fare: _totalFare,
          latitude: position.latitude,
          longitude: position.longitude,
          notes: _notes.isEmpty ? null : _notes,
          seatNumber: _selectedSeat,
          dropStopId: _selectedDropStopId,
          timestamp: DateTime.now(),
        );
        
        await _localDB.saveManualTicket(ticket);
        print('✅ Ticket saved offline successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved offline. Will sync when connection is available.\nError: $errorMessage'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
        }
      } catch (locationError) {
        print('❌ Failed to save offline: $locationError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(busBookingsProvider(widget.busId));
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: TopBar(
        title: 'Manual Ticket',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Passenger Counter
              PassengerCounter(
                value: _passengerCount,
                onChanged: (value) {
                  setState(() {
                    _passengerCount = value;
                    // Clear seat selection if passenger count changes
                    _selectedSeat = null;
                  });
                },
                label: 'Number of Passengers',
              ),
              
              // Seat Selection
              bookingsAsync.when(
                data: (bookings) {
                  final availableSeats = _getAvailableSeats(bookings);
                  return _buildSeatSelection(availableSeats, bookings?.totalSeats ?? 40);
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppTheme.spacingMD),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Drop Stop Selection (only show if seat is selected)
              if (_selectedSeat != null)
                _buildDropStopSelection(),

              // Fare per Passenger Input
              CityGoCard(
                margin: const EdgeInsets.all(AppTheme.spacingMD),
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fare per Passenger',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    TextFormField(
                      initialValue: _farePerPassenger.toStringAsFixed(2),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        prefixText: '৳ ',
                        prefixStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      onChanged: (value) {
                        final fare = double.tryParse(value);
                        if (fare != null && fare > 0) {
                          setState(() => _farePerPassenger = fare);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter fare';
                        }
                        final fare = double.tryParse(value);
                        if (fare == null || fare <= 0) {
                          return 'Please enter a valid fare';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // Total Fare Preview Card
              CityGoCard(
                margin: const EdgeInsets.all(AppTheme.spacingMD),
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Fare',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '৳${_totalFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),

              // Notes Input
              CityGoCard(
                margin: const EdgeInsets.all(AppTheme.spacingMD),
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    TextFormField(
                      maxLines: 3,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Add any additional notes...',
                        hintStyle: TextStyle(color: AppTheme.textTertiary),
                      ),
                      onChanged: (value) {
                        setState(() => _notes = value);
                      },
                    ),
                  ],
                ),
              ),

              // Issue Ticket Button
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: PrimaryButton(
                  text: 'Issue Ticket',
                  icon: Icons.check_circle,
                  onPressed: _isSubmitting ? null : _submitTicket,
                  isLoading: _isSubmitting,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSeatSelection(List<int> availableSeats, int totalSeats) {
    return CityGoCard(
      margin: const EdgeInsets.all(AppTheme.spacingMD),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Seat (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${availableSeats.length} available',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          
          // Seat Grid
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final seatsPerRow = (screenWidth / 70).floor().clamp(5, 8); // 5-8 seats per row
              final availableWidth = screenWidth - (AppTheme.spacingMD * 2) - (AppTheme.spacingSM * (seatsPerRow - 1));
              final seatSize = (availableWidth / seatsPerRow) - 4;
              final width = seatSize.clamp(45.0, 60.0);
              
              return Wrap(
                spacing: AppTheme.spacingSM,
                runSpacing: AppTheme.spacingSM,
                children: List.generate(totalSeats, (index) {
                  final seatNum = index + 1;
                  final isAvailable = availableSeats.contains(seatNum);
                  final isBooked = !isAvailable;
                  final isSelected = _selectedSeat == seatNum;
                  
                  return GestureDetector(
                    onTap: () {
                      // Only allow selecting available seats
                      // Booked seats cannot be selected for new tickets
                      if (isBooked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Seat $seatNum is already booked. Please select an available seat.'),
                            backgroundColor: AppTheme.warningColor,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                        return;
                      }
                      
                      setState(() {
                        _selectedSeat = isSelected ? null : seatNum;
                      });
                    },
                    child: Container(
                      width: width,
                      height: width,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryGreen
                            : isAvailable
                                ? AppTheme.surfaceDark
                                : AppTheme.primaryGreen.withOpacity(0.3), // Booked seats - lighter green
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : isAvailable
                                  ? AppTheme.borderColor
                                  : AppTheme.primaryGreen.withOpacity(0.6), // Booked seats - green border
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$seatNum',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : isAvailable
                                        ? AppTheme.textPrimary
                                        : Colors.white, // Booked seats - white text
                              ),
                            ),
                            if (isBooked && !isSelected) ...[
                              const SizedBox(height: 2),
                              Icon(
                                Icons.person,
                                size: 10,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          
          if (_selectedSeat != null) ...[
            const SizedBox(height: AppTheme.spacingMD),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(color: AppTheme.primaryGreen),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_seat, color: AppTheme.primaryGreen, size: 20),
                  const SizedBox(width: AppTheme.spacingSM),
                  Text(
                    'Seat $_selectedSeat selected',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: AppTheme.primaryGreen,
                    onPressed: () {
                      setState(() => _selectedSeat = null);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropStopSelection() {
    final busAsync = ref.watch(busProvider);
    
    return busAsync.when(
      data: (busInfo) {
        if (busInfo?.route?.stops == null || busInfo!.route!.stops.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final stops = busInfo.route!.stops;
        
        return CityGoCard(
          margin: const EdgeInsets.all(AppTheme.spacingMD),
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Drop-Off Stop',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              DropdownButtonFormField<String>(
                initialValue: _selectedDropStopId,
                decoration: InputDecoration(
                  hintText: 'Select drop-off stop',
                  hintStyle: const TextStyle(color: AppTheme.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                ),
                dropdownColor: AppTheme.surfaceDark,
                style: const TextStyle(color: AppTheme.textPrimary),
                items: stops.map((stop) {
                  return DropdownMenuItem<String>(
                    value: stop.id,
                    child: Text(
                      stop.name,
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDropStopId = value;
                  });
                },
                // Drop stop is optional, but recommended when seat is selected
                // Backend will handle booking creation even without drop stop
                validator: (value) {
                  // Drop stop is optional - backend can handle null
                  return null;
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

