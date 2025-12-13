import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../providers/bus_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/report_provider.dart';
import '../providers/bookings_provider.dart';
import '../models/report.dart';
import '../models/bus.dart';
import '../models/booking.dart';
import '../services/local_db.dart';
import '../models/ticket.dart';
import 'nfc_reader.dart';
import 'manual_ticket.dart';
import 'bookings.dart';
import 'package:intl/intl.dart';

/// Dashboard Screen - Main screen matching CityGo webapp
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Position? _currentPosition;
  GoogleMapController? _mapController;
  Timer? _busLocationRefreshTimer;
  BitmapDescriptor? _busIcon;

  @override
  void initState() {
    super.initState();
    print('📱 Dashboard initState called');
    try {
      // Set default location immediately so map can render (Gulshan, Dhaka - on land)
      _currentPosition = Position(
        latitude: 23.7947, // Dhaka city center (Gulshan)
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
      print('✅ Default position set');
      
      // Try to get actual location in background (don't wait for it)
      _getCurrentLocation().catchError((e) {
        print('⚠️ Error getting current location: $e');
      });
      
      // Start periodic refresh of bus location (every 10 seconds)
      _startBusLocationRefresh();
      print('✅ Bus location refresh timer started');
      
      // Create custom bus icon (don't wait for it)
      _createBusIcon().catchError((e) {
        print('⚠️ Error creating bus icon: $e');
      });
      print('✅ Bus icon creation started');
    } catch (e, stackTrace) {
      print('❌ Error in initState: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Create a custom bus icon for the map marker
  Future<void> _createBusIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Size size = const Size(50, 50);
    
    // Draw background circle
    final Paint backgroundPaint = Paint()
      ..color = AppTheme.primaryGreen
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      backgroundPaint,
    );
    
    // Draw white border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 1,
      borderPaint,
    );
    
    // Draw bus icon using a simple shape
    final Paint busPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Draw bus body (rectangle with rounded corners)
    final RRect busBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.15, size.height * 0.25, size.width * 0.7, size.height * 0.5),
      const Radius.circular(5),
    );
    canvas.drawRRect(busBody, busPaint);
    
    // Draw windows (two rectangles)
    final Paint windowPaint = Paint()
      ..color = AppTheme.primaryGreen
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, size.height * 0.35, size.width * 0.2, size.height * 0.15),
        const Radius.circular(2),
      ),
      windowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.55, size.height * 0.35, size.width * 0.2, size.height * 0.15),
        const Radius.circular(2),
      ),
      windowPaint,
    );
    
    // Draw wheels (two circles)
    final Paint wheelPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.8), size.width * 0.08, wheelPaint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.8), size.width * 0.08, wheelPaint);
    
    // Convert to image
    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();
    
    // Create BitmapDescriptor
    _busIcon = BitmapDescriptor.fromBytes(uint8List);
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _busLocationRefreshTimer?.cancel();
    super.dispose();
  }

  void _startBusLocationRefresh() {
    // Refresh bus assignment and location more frequently when no bus is assigned
    // This ensures that if a bus becomes active, it will show up quickly
    _busLocationRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        final busAsync = ref.read(busProvider);
        final hasBus = busAsync.valueOrNull != null;
        
        // If no bus assigned, refresh every 5 seconds
        // If bus is assigned, refresh every 10 seconds (more frequent for real-time data)
        if (!hasBus) {
          print('🔄 Auto-refreshing bus provider (no bus assigned, every 5 seconds)...');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.invalidate(busProvider);
          });
        } else {
          // Refresh every 10 seconds if bus is assigned (every 2 ticks)
          if (timer.tick % 2 == 0) {
            print('🔄 Auto-refreshing bus provider (bus assigned, every 10 seconds)...');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.invalidate(busProvider);
              // Also refresh bookings and report if we have a bus
              busAsync.whenData((busInfo) {
                if (busInfo != null) {
                  print('🔄 Auto-refreshing bookings for bus ${busInfo.id} (REAL-TIME)...');
                  ref.invalidate(busBookingsProvider(busInfo.id));
                  print('🔄 Auto-refreshing today\'s report...');
                  ref.invalidate(todayReportProvider);
                }
              });
            });
          }
        }
      }
    });
    
    // Also refresh immediately when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔄 Initial refresh on screen load...');
      ref.invalidate(busProvider);
      ref.invalidate(todayReportProvider);
      // Also refresh bookings if we have a bus
      final busAsync = ref.read(busProvider);
      busAsync.whenData((busInfo) {
        if (busInfo != null) {
          print('🔄 Initial refresh of bookings for bus ${busInfo.id}...');
          ref.invalidate(busBookingsProvider(busInfo.id));
        }
      });
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Request location with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // Use default location (Dhaka) if location request times out
          return Position(
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
        },
      );
      setState(() => _currentPosition = position);
      
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );
      }
    } catch (e) {
      // Use default location (Dhaka) on error
      setState(() {
        _currentPosition = Position(
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
      });
    }
  }


  void _toggleTrip() {
    // Trip status is managed by the backend, so this is just for UI feedback
    // In a real implementation, this would call an API to start/end the trip
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Trip status is managed by the driver. Use NFC to record passenger taps.'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }

  void _openNFCReader(String busId, bool isActive) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NFCReaderScreen(
          busId: busId,
          isTapIn: !isActive, // If trip is active, allow tap-out, otherwise tap-in
        ),
      ),
    );
  }

  void _openBookings(String busId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingsScreen(busId: busId),
      ),
    );
  }

  void _openManualTicket(String busId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualTicketScreen(
          busId: busId,
        ),
      ),
    ).then((result) {
      // Refresh bookings and report when returning from manual ticket screen
      // This ensures that any new bookings from manual tickets are shown and stats are updated
      if (result != null) {
        print('🔄 Refreshing bookings and report after manual ticket...');
        ref.invalidate(busBookingsProvider(busId));
        ref.invalidate(todayReportProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print('📱 Dashboard build called');
    try {
      final busAsync = ref.watch(busProvider);
      final unsyncedCount = ref.watch(syncStatusProvider);
      final todayReport = ref.watch(todayReportProvider);
      
      print('📱 Bus provider state: ${busAsync.runtimeType}');
      busAsync.when(
        data: (data) => print('📱 Bus data: ${data != null ? "has bus" : "null"}'),
        loading: () => print('📱 Bus loading...'),
        error: (err, _) => print('📱 Bus error: $err'),
      );

      return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: TopBar(
        title: 'CityGo Supervisor',
        actions: [
          unsyncedCount.when(
            data: (count) {
              if (count > 0) {
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.sync),
                      onPressed: () {
                        Navigator.pushNamed(context, '/sync');
                      },
                      tooltip: 'Sync Center',
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
        ],
      ),
      body: busAsync.when(
        data: (busInfo) {
          if (busInfo == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_bus_outlined,
                      size: 80,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    Text(
                      'No Bus Assigned',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'You are not currently assigned to any bus.\nPlease wait for a driver to assign you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    PrimaryButton(
                      text: 'Refresh',
                      icon: Icons.refresh,
                      onPressed: () {
                        ref.invalidate(busProvider);
                      },
                      width: 200,
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              // Refresh all providers to get live data
              ref.invalidate(busProvider);
              ref.invalidate(todayReportProvider);
              ref.invalidate(busBookingsProvider(busInfo.id));
              await Future.wait([
                ref.read(busProvider.future),
                ref.read(todayReportProvider.future),
              ]);
            },
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bus Card
                  _buildBusCard(busInfo),

                  // Stats Row
                  _buildStatsRow(todayReport, busInfo),

                  // Trip Progress Card
                  _buildTripProgressCard(busInfo),

                  // Map Container
                  _buildMapContainer(busInfo),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Column(
                      children: [
                        PrimaryButton(
                          text: busInfo.isActive ? 'Trip Active' : 'Trip Inactive',
                          icon: busInfo.isActive ? Icons.check_circle : Icons.pause_circle,
                          onPressed: _toggleTrip,
                          width: double.infinity,
                        ),
                        const SizedBox(height: AppTheme.spacingMD),
                        Row(
                          children: [
                            Expanded(
                              child: _CompactButton(
                                text: 'View Bookings',
                                icon: Icons.event_seat,
                                isPrimary: false,
                                onPressed: () => _openBookings(busInfo.id),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Expanded(
                              child: _CompactButton(
                                text: 'Manual Ticket',
                                icon: Icons.receipt,
                                isPrimary: false,
                                onPressed: () => _openManualTicket(busInfo.id),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Expanded(
                              child: _CompactButton(
                                text: 'Scan NFC',
                                icon: Icons.nfc,
                                isPrimary: true,
                                onPressed: () => _openNFCReader(busInfo.id, busInfo.isActive),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          // Try to load cached bus info as fallback
          return FutureBuilder<BusInfo?>(
            future: LocalDB().getCachedBusInfo(),
            builder: (context, cacheSnapshot) {
              // If we have cached data, show it instead of error
              if (cacheSnapshot.hasData && cacheSnapshot.data != null) {
                print('✅ Using cached bus info from error state');
                final cachedBus = cacheSnapshot.data!;
                // Invalidate provider to trigger refresh in background
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.invalidate(busProvider);
                });
                // Show the cached bus data
                return RefreshIndicator(
                  onRefresh: () async {
                    // Refresh all providers to get live data
                    ref.invalidate(busProvider);
                    ref.invalidate(todayReportProvider);
                    ref.invalidate(busBookingsProvider(cachedBus.id));
                    await Future.wait([
                      ref.read(busProvider.future),
                      ref.read(todayReportProvider.future),
                    ]);
                  },
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Bus Card
                        _buildBusCard(cachedBus),
                        // Stats Row
                        _buildStatsRow(todayReport, cachedBus),
                        // Trip Progress Card
                        _buildTripProgressCard(cachedBus),
                        // Map Container
                        _buildMapContainer(cachedBus),
                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          child: Column(
                            children: [
                              PrimaryButton(
                                text: cachedBus.isActive ? 'Trip Active' : 'Trip Inactive',
                                icon: cachedBus.isActive ? Icons.check_circle : Icons.pause_circle,
                                onPressed: _toggleTrip,
                                width: double.infinity,
                              ),
                              const SizedBox(height: AppTheme.spacingMD),
                              Row(
                                children: [
                                  Expanded(
                                    child: _CompactButton(
                                      text: 'View Bookings',
                                      icon: Icons.event_seat,
                                      isPrimary: false,
                                      onPressed: () => _openBookings(cachedBus.id),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingXS),
                                  Expanded(
                                    child: _CompactButton(
                                      text: 'Manual Ticket',
                                      icon: Icons.receipt,
                                      isPrimary: false,
                                      onPressed: () => _openManualTicket(cachedBus.id),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingXS),
                                  Expanded(
                                    child: _CompactButton(
                                      text: 'Scan NFC',
                                      icon: Icons.nfc,
                                      isPrimary: true,
                                      onPressed: () => _openNFCReader(cachedBus.id, cachedBus.isActive),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Show a banner indicating we're using cached data
                        Container(
                          margin: const EdgeInsets.all(AppTheme.spacingMD),
                          padding: const EdgeInsets.all(AppTheme.spacingSM),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.warningColor),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 20),
                              const SizedBox(width: AppTheme.spacingSM),
                              Expanded(
                                child: Text(
                                  'Showing cached data. Refreshing in background...',
                                  style: TextStyle(
                                    color: AppTheme.warningColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // No cached data, show error
              return Center(
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
                        'Unable to Load Bus Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
                        child: Text(
                          error.toString().replaceFirst('Exception: ', ''),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.visible,
                          maxLines: 5,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingLG),
                      PrimaryButton(
                        text: 'Retry',
                        icon: Icons.refresh,
                        onPressed: () {
                          ref.invalidate(busProvider);
                          ref.invalidate(todayReportProvider);
                        },
                        width: 200,
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                      TextButton(
                        onPressed: () {
                          // Show message about waiting for assignment
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'If you are not assigned to a bus, please wait for a driver to assign you.',
                              ),
                              duration: const Duration(seconds: 4),
                              backgroundColor: AppTheme.primaryGreen,
                            ),
                          );
                        },
                        child: Text(
                          'Need Help?',
                          style: TextStyle(color: AppTheme.primaryGreen),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // FloatingActionButton removed - NFC scan is now in the action buttons row
    );
    } catch (e, stackTrace) {
      print('❌ Error in dashboard build: $e');
      print('Stack trace: $stackTrace');
      // Return a safe fallback UI
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: const Text('CityGo Supervisor'),
          backgroundColor: AppTheme.surfaceDark,
        ),
        body: Center(
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
                  'Dashboard Error',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Text(
                  'An error occurred while loading the dashboard.\nPlease try again.',
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
                    // Force rebuild
                    setState(() {});
                  },
                  width: 200,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildBusCard(busInfo) {
    return CityGoCard(
      margin: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: const Icon(
              Icons.directions_bus,
              size: 32,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  busInfo.routeNumber ?? busInfo.route?.name ?? 'Bus Route',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  busInfo.licensePlate,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMD,
              vertical: AppTheme.spacingSM,
            ),
            decoration: BoxDecoration(
              color: busInfo.isActive
                  ? AppTheme.successColor.withOpacity(0.2)
                  : AppTheme.textTertiary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Text(
              busInfo.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: busInfo.isActive
                    ? AppTheme.successColor
                    : AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(AsyncValue<ReportResponse?> reportAsync, BusInfo? busInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
      child: reportAsync.when(
        data: (report) {
          print('📊 Dashboard Report Data: tripCount=${report?.tripCount}, passengerCount=${report?.passengerCount}, totalFare=${report?.totalFare}');
          
          // Calculate trip count - use report if available, otherwise calculate from bookings
          int tripCount = report?.tripCount ?? 0;
          if (tripCount == 0 && busInfo != null) {
            // If report shows 0 trips but bus is active, show at least 1 trip
            if (busInfo.isActive) {
              tripCount = 1;
              print('📊 Trip count was 0 but bus is active, showing 1 trip');
            }
          }
          
          // Calculate revenue - use report if available, otherwise calculate from manual tickets
          double revenue = report?.totalFare ?? 0.0;
          
          // Start with report passenger count
          int passengerCount = report?.passengerCount ?? 0;
          
          // WATCH bookings provider for real-time updates
          if (busInfo != null) {
            final bookingsAsync = ref.watch(busBookingsProvider(busInfo.id));
            
            return bookingsAsync.when(
              data: (bookings) {
                // Calculate stats synchronously from bookings (already loaded)
                // Then add manual tickets asynchronously
                int calculatedPassengers = _calculatePassengersFromBookings(bookings, passengerCount);
                double calculatedRevenue = revenue;
                
                // Use FutureBuilder only for manual tickets (async operation)
                // Use bookings data as key to force rebuild when bookings change
                return FutureBuilder<Map<String, int>>(
                  key: ValueKey('${bookings?.bookedSeats ?? 0}-${bookings?.bookings.length ?? 0}'),
                  future: _getManualTicketStats(busInfo.id),
                  builder: (context, snapshot) {
                    final manualStats = snapshot.data ?? {'passengers': 0, 'revenue': 0};
                    final manualPassengers = manualStats['passengers'] ?? 0;
                    final manualRevenue = (manualStats['revenue'] ?? 0).toDouble();
                    
                    // Add manual ticket passengers
                    calculatedPassengers += manualPassengers;
                    
                    // Add manual revenue
                    if (calculatedRevenue == 0.0 && manualRevenue > 0.0) {
                      calculatedRevenue = manualRevenue;
                    } else if (manualRevenue > 0.0) {
                      calculatedRevenue += manualRevenue;
                    }
                    
                    final revenueFormatted = NumberFormat('#,##0').format(calculatedRevenue);
                    
                    return Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Today\'s Trips',
                            value: tripCount.toString(),
                            icon: Icons.route,
                            iconColor: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: StatCard(
                            label: 'Passengers',
                            value: calculatedPassengers.toString(),
                            icon: Icons.people,
                            iconColor: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: StatCard(
                            label: 'Revenue',
                            value: '৳$revenueFormatted',
                            icon: Icons.attach_money,
                            iconColor: AppTheme.accentCyanReal,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Today\'s Trips',
                      value: tripCount.toString(),
                      icon: Icons.route,
                      iconColor: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: StatCard(
                      label: 'Passengers',
                      value: '...',
                      icon: Icons.people,
                      iconColor: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: StatCard(
                      label: 'Revenue',
                      value: '৳${NumberFormat('#,##0').format(revenue)}',
                      icon: Icons.attach_money,
                      iconColor: AppTheme.accentCyanReal,
                    ),
                  ),
                ],
              ),
              error: (error, stack) => Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Today\'s Trips',
                      value: tripCount.toString(),
                      icon: Icons.route,
                      iconColor: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: StatCard(
                      label: 'Passengers',
                      value: passengerCount.toString(),
                      icon: Icons.people,
                      iconColor: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: StatCard(
                      label: 'Revenue',
                      value: '৳${NumberFormat('#,##0').format(revenue)}',
                      icon: Icons.attach_money,
                      iconColor: AppTheme.accentCyanReal,
                    ),
                  ),
                ],
              ),
            );
          } else {
            // No bus info, use report data only
            final revenueFormatted = NumberFormat('#,##0').format(revenue);
            return Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Today\'s Trips',
                    value: tripCount.toString(),
                    icon: Icons.route,
                    iconColor: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: StatCard(
                    label: 'Passengers',
                    value: passengerCount.toString(),
                    icon: Icons.people,
                    iconColor: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: StatCard(
                    label: 'Revenue',
                    value: '৳$revenueFormatted',
                    icon: Icons.attach_money,
                    iconColor: AppTheme.accentCyanReal,
                  ),
                ),
              ],
            );
          }
        },
        loading: () => Row(
          children: [
            Expanded(child: ShimmerCard()),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(child: ShimmerCard()),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(child: ShimmerCard()),
          ],
        ),
        error: (_, __) => Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Today\'s Trips',
                value: '0',
                icon: Icons.route,
                iconColor: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: StatCard(
                label: 'Passengers',
                value: '0',
                icon: Icons.people,
                iconColor: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: StatCard(
                label: 'Revenue',
                value: '৳0',
                icon: Icons.attach_money,
                iconColor: AppTheme.accentCyanReal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripProgressCard(BusInfo? busInfo) {
    final stops = busInfo?.route?.stops ?? [];
    final totalStops = stops.length;
    
    // Calculate current stop based on bus location
    int currentStopIndex = 0;
    double progress = 0.0;
    
    if (busInfo?.currentLocation != null && stops.isNotEmpty) {
      final busLat = busInfo!.currentLocation!['lat'];
      final busLng = busInfo.currentLocation!['lng'];
      
      if (busLat != null && busLng != null) {
        // Find the closest stop to current bus location
        double minDistance = double.infinity;
        for (int i = 0; i < stops.length; i++) {
          final stop = stops[i];
          final distance = _calculateDistance(
            busLat,
            busLng,
            stop.latitude,
            stop.longitude,
          );
          if (distance < minDistance) {
            minDistance = distance;
            currentStopIndex = i;
          }
        }
        
        // Calculate progress based on stop index
        if (totalStops > 0) {
          progress = (currentStopIndex + 1) / totalStops;
          // Clamp between 0 and 1
          progress = progress.clamp(0.0, 1.0);
        }
      }
    }
    
    // If no location or stops, show 0%
    if (totalStops == 0 || busInfo?.currentLocation == null) {
      progress = 0.0;
      currentStopIndex = 0;
    }
    
    final progressPercent = (progress * 100).toInt();
    final currentStop = currentStopIndex + 1;
    
    return CityGoCard(
      margin: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.surfaceDark,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$progressPercent% Complete',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                totalStops > 0 
                    ? '$currentStop / $totalStops Stops'
                    : 'No stops',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  /// Calculate distance between two coordinates in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth radius in kilometers
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = (dLat / 2) * (dLat / 2) +
        _degreesToRadians(lat1) * _degreesToRadians(lat2) *
        (dLon / 2) * (dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }
  
  /// Calculate passengers from bookings synchronously (bookings are already loaded)
  int _calculatePassengersFromBookings(BusBookings? bookings, int reportPassengerCount) {
    print('📊 ========== CALCULATING PASSENGERS FROM BOOKINGS ==========');
    print('📊 Bookings object: ${bookings != null ? "exists" : "null"}');
    
    if (bookings == null) {
      print('📊 No bookings data, using report count: $reportPassengerCount');
      return reportPassengerCount;
    }
    
    print('📊 Bookings array length: ${bookings.bookings.length}');
    print('📊 Booked seats from API: ${bookings.bookedSeats}');
    
    // Log all booking statuses for debugging
    for (var booking in bookings.bookings) {
      print('📊   - Seat ${booking.seatNumber}: status="${booking.status}", passenger="${booking.passengerName}"');
    }
    
    // PRIORITY: Use bookedSeats from API first (most reliable)
    final bookedSeatsCount = bookings.bookedSeats;
    if (bookedSeatsCount > 0) {
      print('📊 Using bookedSeats from API: $bookedSeatsCount (most reliable)');
      print('📊 ====================================================');
      return bookedSeatsCount;
    }
    
    // Fallback: Count from bookings array if bookedSeats is 0
    if (bookings.bookings.isNotEmpty) {
      // Count actual bookings (confirmed/booked status)
      final confirmedBookings = bookings.bookings.where((b) {
        final status = b.status.toLowerCase();
        final isConfirmed = status == 'confirmed' || status == 'booked';
        if (!isConfirmed) {
          print('📊   ⚠️ Filtered out booking: Seat ${b.seatNumber}, status="$status"');
        }
        return isConfirmed;
      }).length;
      
      print('📊 REAL-TIME Bookings: ${bookings.bookings.length} total, $confirmedBookings confirmed/booked');
      print('📊 Using confirmed bookings count: $confirmedBookings (report had: $reportPassengerCount)');
      print('📊 ====================================================');
      
      // Use confirmed bookings count
      return confirmedBookings > 0 ? confirmedBookings : reportPassengerCount;
    } else {
      // Bookings object exists but array is empty - use bookedSeats if available
      final bookedSeatsCount = bookings.bookedSeats;
      print('📊 Bookings array is empty, but bookedSeats=$bookedSeatsCount');
      if (bookedSeatsCount > 0) {
        print('📊 Using bookedSeats from API: $bookedSeatsCount');
        print('📊 ====================================================');
        return bookedSeatsCount;
      } else {
        print('📊 Bookings object exists but empty, using report count: $reportPassengerCount');
        print('📊 ====================================================');
        return reportPassengerCount;
      }
    }
  }
  
  /// Get manual ticket stats (passengers and revenue) asynchronously
  Future<Map<String, int>> _getManualTicketStats(String busId) async {
    try {
      final manualTickets = await _getTodayManualTickets(busId);
      final manualPassengers = manualTickets.fold<int>(
        0,
        (sum, ticket) => sum + ticket.passengerCount,
      );
      final manualRevenue = manualTickets.fold<double>(
        0.0,
        (sum, ticket) => sum + ticket.fare,
      ).toInt();
      
      print('📊 Manual tickets: $manualPassengers passengers, ৳$manualRevenue');
      
      return {
        'passengers': manualPassengers,
        'revenue': manualRevenue,
      };
    } catch (e) {
      print('⚠️ Error getting manual ticket stats: $e');
      return {'passengers': 0, 'revenue': 0};
    }
  }
  
  /// Get today's manual tickets for a bus
  Future<List<ManualTicket>> _getTodayManualTickets(String? busId) async {
    if (busId == null) return [];
    
    try {
      final localDB = LocalDB();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      
      // Get all manual tickets (synced and unsynced) for today
      final db = await localDB.database;
      final results = await db.query(
        'manual_tickets',
        where: 'bus_id = ? AND timestamp >= ? AND timestamp < ?',
        whereArgs: [
          busId,
          todayStart.millisecondsSinceEpoch,
          todayEnd.millisecondsSinceEpoch,
        ],
      );
      
      final todayTickets = results.map((row) {
        return ManualTicket(
          offlineId: row['offline_id'] as String?,
          busId: row['bus_id'] as String,
          passengerCount: row['passenger_count'] as int,
          fare: row['fare'] as double,
          latitude: row['latitude'] as double,
          longitude: row['longitude'] as double,
          notes: row['notes'] as String?,
          seatNumber: row['seat_number'] as int?,
          timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
        );
      }).toList();
      
      print('📊 Found ${todayTickets.length} manual tickets for today');
      return todayTickets;
    } catch (e) {
      print('⚠️ Error getting today\'s manual tickets: $e');
      return [];
    }
  }

  Widget _buildMapContainer(busInfo) {
    final stops = busInfo.route?.stops ?? [];
    
    // Filter out stops with invalid coordinates and sort by order
    final validStops = stops
        .where((stop) => 
            stop.latitude != 0.0 && 
            stop.longitude != 0.0 &&
            stop.latitude.abs() <= 90 &&
            stop.longitude.abs() <= 180)
        .toList();
    
    // Sort stops by order if available
    if (validStops.any((stop) => stop.order != null)) {
      validStops.sort((Stop a, Stop b) {
        final orderA = a.order ?? 999;
        final orderB = b.order ?? 999;
        return orderA.compareTo(orderB);
      });
    }
    
    final polylinePoints = validStops
        .map<LatLng>((stop) => LatLng(stop.latitude, stop.longitude))
        .toList();

    // Debug logging
    print('🗺️ Map Debug: BusInfo route: ${busInfo.route != null}');
    print('🗺️ Map Debug: Total stops: ${stops.length}');
    print('🗺️ Map Debug: Valid stops: ${validStops.length}');
    print('🗺️ Map Debug: Polyline points: ${polylinePoints.length}');
    if (validStops.isNotEmpty) {
      print('🗺️ Map Debug: First stop: ${validStops.first.name} at ${validStops.first.latitude}, ${validStops.first.longitude}');
      print('🗺️ Map Debug: Last stop: ${validStops.last.name} at ${validStops.last.latitude}, ${validStops.last.longitude}');
    } else if (stops.isNotEmpty) {
      print('⚠️ Map Debug: All stops have invalid coordinates!');
      for (var stop in stops) {
        print('   - ${stop.name}: lat=${stop.latitude}, lng=${stop.longitude}');
      }
    }

    // Determine map center - prioritize bus location, then stops, then current location, then default
    double centerLat;
    double centerLng;
    double zoomLevel = 15.0;
    
    // Check if bus has live location
    final busLocation = busInfo.currentLocation;
    final hasBusLocation = busLocation != null &&
        busLocation['lat'] != null &&
        busLocation['lng'] != null &&
        busLocation['lat'] != 0.0 &&
        busLocation['lng'] != 0.0;
    
    if (hasBusLocation) {
      // Prioritize bus location
      centerLat = busLocation['lat']!;
      centerLng = busLocation['lng']!;
      zoomLevel = 14.0; // Good zoom level to see bus and nearby stops
      
      // If we have stops, adjust zoom to show both bus and route
      if (validStops.isNotEmpty) {
        // Calculate bounds to include both bus location and all stops
        double minLat = centerLat;
        double maxLat = centerLat;
        double minLng = centerLng;
        double maxLng = centerLng;
        
        for (var stop in validStops) {
          minLat = minLat < stop.latitude ? minLat : stop.latitude;
          maxLat = maxLat > stop.latitude ? maxLat : stop.latitude;
          minLng = minLng < stop.longitude ? minLng : stop.longitude;
          maxLng = maxLng > stop.longitude ? maxLng : stop.longitude;
        }
        
        // Center on the midpoint
        centerLat = (minLat + maxLat) / 2;
        centerLng = (minLng + maxLng) / 2;
        
        // Adjust zoom based on bounds
        final latDiff = maxLat - minLat;
        final lngDiff = maxLng - minLng;
        final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
        
        if (maxDiff > 0.1) {
          zoomLevel = 11.0; // Wide view for long routes
        } else if (maxDiff > 0.05) {
          zoomLevel = 12.0;
        } else {
          zoomLevel = 13.0;
        }
      }
    } else if (validStops.isNotEmpty) {
      // Use first stop as center
      centerLat = validStops.first.latitude;
      centerLng = validStops.first.longitude;
      // If multiple stops, calculate center point
      if (validStops.length > 1) {
        double sumLat = 0, sumLng = 0;
        for (var stop in validStops) {
          sumLat += stop.latitude;
          sumLng += stop.longitude;
        }
        centerLat = sumLat / validStops.length;
        centerLng = sumLng / validStops.length;
        zoomLevel = 12.0; // Zoom out more for multiple stops
      }
    } else if (_currentPosition != null) {
      centerLat = _currentPosition!.latitude;
      centerLng = _currentPosition!.longitude;
    } else {
      // Default to Dhaka city center (Gulshan area - definitely on land)
      centerLat = 23.7947;
      centerLng = 90.4144;
      zoomLevel = 13.0; // City-level zoom to show streets
    }

    return MapContainer(
      height: 300,
      child: SizedBox(
        width: double.infinity,
        height: 300,
        child: Stack(
          children: [
            Builder(
              builder: (context) {
                try {
                  return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(centerLat, centerLng),
                  zoom: zoomLevel,
                ),
                zoomControlsEnabled: false,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: true,
                onMapCreated: (controller) {
                  _mapController = controller;
                  print('✅ Google Map created successfully');
                  print('🗺️ Map Debug: Polyline points count: ${polylinePoints.length}');
                  print('🗺️ Map Debug: Stops count: ${stops.length}');
                  
                  // Update camera to show route if available
                  if (polylinePoints.isNotEmpty) {
                    Future.delayed(const Duration(milliseconds: 800), () {
                      try {
                        if (polylinePoints.length > 1) {
                          // Multiple stops - show bounds
                          controller.animateCamera(
                            CameraUpdate.newLatLngBounds(
                              _boundsFromLatLngList(polylinePoints),
                              80,
                            ),
                          );
                          print('✅ Camera animated to show all stops');
                        } else {
                          // Single stop - center on it
                          controller.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              polylinePoints.first,
                              15,
                            ),
                          );
                          print('✅ Camera centered on single stop');
                        }
                      } catch (e) {
                        print('❌ Error animating camera: $e');
                        // If bounds calculation fails, just center on first point
                        if (polylinePoints.isNotEmpty) {
                          controller.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              polylinePoints.first,
                              15,
                            ),
                          );
                        }
                      }
                    });
                  } else {
                    print('⚠️ No polyline points available - centering on calculated location');
                    Future.delayed(const Duration(milliseconds: 500), () {
                      controller.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(centerLat, centerLng),
                          zoomLevel,
                        ),
                      );
                    });
                  }
                },
                myLocationEnabled: !kIsWeb,
                myLocationButtonEnabled: false,
                mapType: MapType.normal,
                mapToolbarEnabled: false,
                compassEnabled: true,
                liteModeEnabled: false,
                markers: <Marker>{
                  // Add bus live location marker if available
                  if (busInfo.currentLocation != null &&
                      busInfo.currentLocation!['lat'] != null &&
                      busInfo.currentLocation!['lng'] != null)
                    Marker(
                      markerId: const MarkerId('bus_location'),
                      position: LatLng(
                        busInfo.currentLocation!['lat']!,
                        busInfo.currentLocation!['lng']!,
                      ),
                      icon: _busIcon ?? BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                      infoWindow: InfoWindow(
                        title: 'Bus Location',
                        snippet: '${busInfo.licensePlate} - Live',
                      ),
                      anchor: const Offset(0.5, 0.5),
                    ),
                  // Add current location marker if available (supervisor's location)
                  if (_currentPosition != null)
                    Marker(
                      markerId: const MarkerId('current_location'),
                      position: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                      infoWindow: const InfoWindow(title: 'Your Location'),
                    ),
                  // Add all stop markers (only valid stops)
                  if (validStops.isNotEmpty)
                    ...validStops.asMap().entries.map<Marker>((entry) {
                      final stop = entry.value;
                      print('📍 Adding marker for stop: ${stop.name} at ${stop.latitude}, ${stop.longitude}');
                      return Marker(
                        markerId: MarkerId('stop_${stop.id}'),
                        position: LatLng(stop.latitude, stop.longitude),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueBlue,
                        ),
                        infoWindow: InfoWindow(
                          title: stop.name,
                          snippet: 'Stop ${entry.key + 1} of ${validStops.length}',
                        ),
                      );
                    })
                  else if (_currentPosition != null)
                    // Show current location if no stops
                    Marker(
                      markerId: const MarkerId('current_location_fallback'),
                      position: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                      infoWindow: const InfoWindow(title: 'Current Location'),
                    ),
                },
                polylines: polylinePoints.length >= 2
                    ? <Polyline>{
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: polylinePoints,
                          color: AppTheme.primaryGreen,
                          width: 5,
                          patterns: [],
                          geodesic: true,
                          jointType: JointType.round,
                          endCap: Cap.roundCap,
                          startCap: Cap.roundCap,
                        ),
                      }
                    : <Polyline>{},
                  );
                } catch (e, stackTrace) {
                  print('❌ Google Maps error: $e');
                  print('Stack trace: $stackTrace');
                  // Fallback: Show a placeholder with error message
                  return Container(
                    color: AppTheme.surfaceDark,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 48,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          Text(
                            'Map unavailable',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXS),
                          Text(
                            'Error: ${e.toString()}',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
            // Zoom Controls
            Positioned(
              right: 16,
              top: 16,
              child: Column(
                children: [
                  // Zoom In Button
                  Material(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 4,
                    child: InkWell(
                      onTap: () => _zoomIn(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.borderColor,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: AppTheme.textPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Zoom Out Button
                  Material(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 4,
                    child: InkWell(
                      onTap: () => _zoomOut(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.borderColor,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.remove,
                          color: AppTheme.textPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Zoom in on the map
  Future<void> _zoomIn() async {
    if (_mapController != null) {
      try {
        await _mapController!.animateCamera(CameraUpdate.zoomIn());
      } catch (e) {
        print('❌ Error zooming in: $e');
      }
    }
  }

  /// Zoom out on the map
  Future<void> _zoomOut() async {
    if (_mapController != null) {
      try {
        await _mapController!.animateCamera(CameraUpdate.zoomOut());
      } catch (e) {
        print('❌ Error zooming out: $e');
      }
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;
    for (var point in list) {
      minLat ??= point.latitude;
      maxLat ??= point.latitude;
      minLng ??= point.longitude;
      maxLng ??= point.longitude;

      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }
}

/// Compact button widget for action buttons row to prevent overflow
class _CompactButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _CompactButton({
    required this.text,
    required this.icon,
    required this.isPrimary,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final buttonStyle = isPrimary
        ? ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSM,
              vertical: AppTheme.spacingMD,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: AppTheme.borderColorLight),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSM,
              vertical: AppTheme.spacingMD,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
          );

    final button = isPrimary
        ? ElevatedButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );

    return SizedBox(
      width: double.infinity,
      child: button,
    );
  }
}

