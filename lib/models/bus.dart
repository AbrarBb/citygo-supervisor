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
              ?.map((e) => Stop.fromJson(e as Map<String, dynamic>))
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

  BusInfo({
    required this.id,
    required this.licensePlate,
    this.routeNumber,
    this.route,
    this.status,
    this.capacity,
    this.currentLocation,
    this.driverInfo,
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
      capacity: json['capacity'] as int?,
      currentLocation: json['current_location'] != null
          ? {
              'lat': (json['current_location']['lat'] as num?)?.toDouble() ?? 0.0,
              'lng': (json['current_location']['lng'] as num?)?.toDouble() ?? 0.0,
            }
          : null,
      driverInfo: json['driverInfo'] as Map<String, dynamic>? ?? 
                  json['driver_info'] as Map<String, dynamic>?,
    );
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

