/// Stop model
class Stop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int? order;

  Stop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.order,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['id'] as String? ?? json['id'].toString(),
      name: json['name'] as String? ?? 'Unknown Stop',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      order: json['order'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      if (order != null) 'order': order,
    };
  }
}

/// Route model
class RouteInfo {
  final String id;
  final String name;
  final String? routeNumber;
  final List<Stop> stops;
  final double? distance;
  final double? baseFare;
  final double? farePerKm;

  RouteInfo({
    required this.id,
    required this.name,
    this.routeNumber,
    required this.stops,
    this.distance,
    this.baseFare,
    this.farePerKm,
  });

  factory RouteInfo.fromJson(Map<String, dynamic> json) {
    return RouteInfo(
      id: json['id'] as String? ?? json['id'].toString(),
      name: json['name'] as String? ?? 'Unknown Route',
      routeNumber: json['route_number'] as String? ?? 
                   json['routeNumber'] as String?,
      stops: (json['stops'] as List<dynamic>?)
              ?.map((e) {
                try {
                  return Stop.fromJson(e as Map<String, dynamic>);
                } catch (err) {
                  print('⚠️ Error parsing stop: $e, error: $err');
                  return null;
                }
              })
              .whereType<Stop>()
              .where((stop) => 
                  stop.latitude != 0.0 && 
                  stop.longitude != 0.0 &&
                  stop.latitude.abs() <= 90 &&
                  stop.longitude.abs() <= 180)
              .toList() ??
          [],
      distance: (json['distance'] as num?)?.toDouble(),
      baseFare: (json['base_fare'] as num?)?.toDouble(),
      farePerKm: (json['fare_per_km'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (routeNumber != null) 'route_number': routeNumber,
      'stops': stops.map((e) => e.toJson()).toList(),
      if (distance != null) 'distance': distance,
      if (baseFare != null) 'base_fare': baseFare,
      if (farePerKm != null) 'fare_per_km': farePerKm,
    };
  }
}

/// Bus info model
class BusInfo {
  final String id;
  final String licensePlate; // bus_number from API
  final String? routeNumber;
  final RouteInfo? route;
  final String? status;
  final int? capacity;
  final Map<String, double>? currentLocation;
  final Map<String, dynamic>? driverInfo;
  final bool isActive; // Whether the bus trip is currently active

  BusInfo({
    required this.id,
    required this.licensePlate,
    this.routeNumber,
    this.route,
    this.status,
    this.capacity,
    this.currentLocation,
    this.driverInfo,
    this.isActive = false,
  });

  factory BusInfo.fromJson(Map<String, dynamic> json) {
    return BusInfo(
      id: json['id'] as String? ?? json['id'].toString(),
      licensePlate: json['bus_number'] as String? ?? 
                     json['license_plate'] as String? ?? 
                     json['licensePlate'] as String? ?? 
                     'N/A',
      routeNumber: json['route_number'] as String? ?? 
                   json['routeNumber'] as String?,
      route: json['route'] != null
          ? RouteInfo.fromJson(json['route'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String?,
      // Always use 40 seats to match webapp, regardless of what backend returns
      capacity: 40,
      currentLocation: _parseCurrentLocation(json['current_location']),
      driverInfo: json['driverInfo'] as Map<String, dynamic>? ?? 
                  json['driver_info'] as Map<String, dynamic>?,
      isActive: (json['is_active'] as bool?) ?? 
                (json['isActive'] as bool?) ?? 
                ((json['status'] as String?) == 'active'),
    );
  }

  /// Helper method to parse current_location in various formats
  static Map<String, double>? _parseCurrentLocation(dynamic locationData) {
    if (locationData == null) return null;
    
    try {
      // Handle Map format: {lat: x, lng: y} or {latitude: x, longitude: y}
      if (locationData is Map) {
        final lat = (locationData['lat'] ?? locationData['latitude']) as num?;
        final lng = (locationData['lng'] ?? locationData['longitude']) as num?;
        
        if (lat != null && lng != null) {
          final latVal = lat.toDouble();
          final lngVal = lng.toDouble();
          
          // Validate coordinates
          if (latVal.abs() <= 90 && lngVal.abs() <= 180 && 
              latVal != 0.0 && lngVal != 0.0) {
            return {'lat': latVal, 'lng': lngVal};
          }
        }
      }
      
      // Handle Array format: [lat, lng] or [lng, lat]
      if (locationData is List && locationData.length >= 2) {
        final first = (locationData[0] as num?)?.toDouble();
        final second = (locationData[1] as num?)?.toDouble();
        
        if (first != null && second != null) {
          // Assume [lat, lng] format (most common)
          // If coordinates seem reversed (lat > 180), swap them
          double lat, lng;
          if (first.abs() <= 90 && second.abs() <= 180) {
            lat = first;
            lng = second;
          } else if (second.abs() <= 90 && first.abs() <= 180) {
            lat = second;
            lng = first;
          } else {
            return null; // Invalid coordinates
          }
          
          if (lat != 0.0 && lng != 0.0) {
            return {'lat': lat, 'lng': lng};
          }
        }
      }
    } catch (e) {
      print('⚠️ Error parsing current_location: $e');
    }
    
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus_number': licensePlate,
      if (routeNumber != null) 'route_number': routeNumber,
      if (route != null) 'route': route!.toJson(),
      if (status != null) 'status': status,
      if (capacity != null) 'capacity': capacity,
      if (currentLocation != null) 'current_location': currentLocation,
      if (driverInfo != null) 'driverInfo': driverInfo,
    };
  }
}

