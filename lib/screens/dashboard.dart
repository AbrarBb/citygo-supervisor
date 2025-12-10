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
import '../models/report.dart';
import 'nfc_reader.dart';
import 'manual_ticket.dart';
import 'package:intl/intl.dart';

/// Dashboard Screen - Main screen matching CityGo webapp
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isTripActive = false;
  Position? _currentPosition;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    // Set default location immediately so map can render
    _currentPosition = Position(
      latitude: 23.8103, // Dhaka default
      longitude: 90.4125,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    // Try to get actual location in background
    _getCurrentLocation();
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
            latitude: 23.8103,
            longitude: 90.4125,
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
          latitude: 23.8103,
          longitude: 90.4125,
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
    setState(() => _isTripActive = !_isTripActive);
  }

  void _openNFCReader(String busId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NFCReaderScreen(
          busId: busId,
          isTapIn: !_isTripActive,
        ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final busAsync = ref.watch(busProvider);
    final unsyncedCount = ref.watch(syncStatusProvider);
    final todayReport = ref.watch(todayReportProvider);

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
            return const Center(child: Text('No bus assigned'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(busProvider);
              await ref.read(busProvider.future);
            },
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bus Card
                  _buildBusCard(busInfo),

                  // Stats Row
                  _buildStatsRow(todayReport),

                  // Trip Progress Card
                  _buildTripProgressCard(),

                  // Map Container
                  _buildMapContainer(busInfo),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Column(
                      children: [
                        PrimaryButton(
                          text: _isTripActive ? 'End Trip' : 'Start Trip',
                          icon: _isTripActive ? Icons.stop : Icons.play_arrow,
                          onPressed: _toggleTrip,
                          width: double.infinity,
                        ),
                        const SizedBox(height: AppTheme.spacingMD),
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                text: 'Manual Ticket',
                                icon: Icons.receipt,
                                onPressed: () => _openManualTicket(busInfo.id),
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
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${error.toString()}'),
              const SizedBox(height: AppTheme.spacingMD),
              ElevatedButton(
                onPressed: () => ref.invalidate(busProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: busAsync.when(
        data: (busInfo) => FloatingNFCAction(
          onPressed: busInfo != null ? () => _openNFCReader(busInfo.id) : null,
          isScanning: false,
        ),
        loading: () => null,
        error: (_, __) => null,
      ),
    );
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
              color: _isTripActive
                  ? AppTheme.successColor.withOpacity(0.2)
                  : AppTheme.textTertiary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Text(
              _isTripActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isTripActive
                    ? AppTheme.successColor
                    : AppTheme.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(AsyncValue<ReportResponse?> reportAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
      child: reportAsync.when(
        data: (report) {
          final tripCount = report?.tripCount ?? 0;
          final passengerCount = report?.passengerCount ?? 0;
          final revenue = report?.totalFare ?? 0.0;
          
          // Format revenue with taka sign
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

  Widget _buildTripProgressCard() {
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
            value: 0.65,
            backgroundColor: AppTheme.surfaceDark,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '65% Complete',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '13 / 20 Stops',
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

  Widget _buildMapContainer(busInfo) {
    final stops = busInfo.route?.stops ?? [];
    final polylinePoints = stops
        .map<LatLng>((stop) => LatLng(stop.latitude, stop.longitude))
        .toList();

    final defaultLat = _currentPosition?.latitude ?? 23.8103;
    final defaultLng = _currentPosition?.longitude ?? 90.4125;

    return MapContainer(
      height: 300,
      child: SizedBox(
        width: double.infinity,
        height: 300,
        child: Builder(
          builder: (context) {
            try {
              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(defaultLat, defaultLng),
                  zoom: 15,
                ),
                zoomControlsEnabled: false,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: true,
                onMapCreated: (controller) {
                  _mapController = controller;
                  print('✅ Google Map created successfully');
                  // Update camera to show route if available
                  if (polylinePoints.isNotEmpty && polylinePoints.length > 1) {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      try {
                        controller.animateCamera(
                          CameraUpdate.newLatLngBounds(
                            _boundsFromLatLngList(polylinePoints),
                            50,
                          ),
                        );
                      } catch (e) {
                        print('Error animating camera: $e');
                        // If bounds calculation fails, just center on first point
                        if (polylinePoints.isNotEmpty) {
                          controller.animateCamera(
                            CameraUpdate.newLatLng(polylinePoints.first),
                          );
                        }
                      }
                    });
                  }
                },
                myLocationEnabled: !kIsWeb,
                myLocationButtonEnabled: false,
                mapType: MapType.normal,
                markers: <Marker>{
                  // Add current location marker if available
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
                      infoWindow: const InfoWindow(title: 'Current Location'),
                    ),
                  // Add all stop markers
                  ...stops.asMap().entries.map<Marker>((entry) {
                    final stop = entry.value;
                    return Marker(
                      markerId: MarkerId('stop_${stop.id}'),
                      position: LatLng(stop.latitude, stop.longitude),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue,
                      ),
                      infoWindow: InfoWindow(
                        title: stop.name,
                        snippet: 'Stop ${entry.key + 1}',
                      ),
                    );
                  }),
                },
                polylines: polylinePoints.length > 1
                    ? <Polyline>{
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: polylinePoints,
                          color: AppTheme.primaryGreen,
                          width: 4,
                          patterns: [],
                          geodesic: true,
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
      ),
    );
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

