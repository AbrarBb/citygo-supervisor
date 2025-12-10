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

  RouteInfo({
    required this.id,
    required this.name,
    this.routeNumber,
    required this.stops,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (routeNumber != null) 'route_number': routeNumber,
      'stops': stops.map((e) => e.toJson()).toList(),
    };
  }
}

/// Bus info model
class BusInfo {
  final String id;
  final String licensePlate;
  final String? routeNumber;
  final RouteInfo? route;
  final String? status;

  BusInfo({
    required this.id,
    required this.licensePlate,
    this.routeNumber,
    this.route,
    this.status,
  });

  factory BusInfo.fromJson(Map<String, dynamic> json) {
    return BusInfo(
      id: json['id'] as String? ?? json['id'].toString(),
      licensePlate: json['license_plate'] as String? ?? 
                     json['licensePlate'] as String? ?? 
                     'N/A',
      routeNumber: json['route_number'] as String? ?? 
                   json['routeNumber'] as String?,
      route: json['route'] != null
          ? RouteInfo.fromJson(json['route'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'license_plate': licensePlate,
      if (routeNumber != null) 'route_number': routeNumber,
      if (route != null) 'route': route!.toJson(),
      if (status != null) 'status': status,
    };
  }
}

