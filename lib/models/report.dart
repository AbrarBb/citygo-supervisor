/// Report Response model
class ReportResponse {
  final DateTime date;
  final int tapInCount;
  final int tapOutCount;
  final double totalFare;
  final double totalDistance;
  final double co2Saved;
  final int tripCount;
  final int passengerCount;
  final List<HourlyData>? hourlyData;

  ReportResponse({
    required this.date,
    required this.tapInCount,
    required this.tapOutCount,
    required this.totalFare,
    required this.totalDistance,
    required this.co2Saved,
    required this.tripCount,
    required this.passengerCount,
    this.hourlyData,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      tapInCount: json['tap_in_count'] as int? ?? json['tap_ins'] as int? ?? 0,
      tapOutCount: json['tap_out_count'] as int? ?? json['tap_outs'] as int? ?? 0,
      totalFare: (json['total_fare'] as num? ?? json['fare'] as num? ?? 0).toDouble(),
      totalDistance: (json['total_distance'] as num? ?? json['distance_km'] as num? ?? 0).toDouble(),
      co2Saved: (json['co2_saved'] as num? ?? 0).toDouble(),
      tripCount: json['trip_count'] as int? ?? json['trips'] as int? ?? 0,
      passengerCount: json['passenger_count'] as int? ?? json['passengers'] as int? ?? 0,
      hourlyData: (json['hourly_data'] as List<dynamic>?)
          ?.map((e) => HourlyData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'tap_in_count': tapInCount,
      'tap_out_count': tapOutCount,
      'total_fare': totalFare,
      'total_distance': totalDistance,
      'co2_saved': co2Saved,
      'trip_count': tripCount,
      'passenger_count': passengerCount,
      if (hourlyData != null)
        'hourly_data': hourlyData!.map((e) => e.toJson()).toList(),
    };
  }
}

/// Hourly data for reports
class HourlyData {
  final int hour;
  final int count;
  final double fare;

  HourlyData({
    required this.hour,
    required this.count,
    required this.fare,
  });

  factory HourlyData.fromJson(Map<String, dynamic> json) {
    return HourlyData(
      hour: json['hour'] as int,
      count: json['count'] as int,
      fare: (json['fare'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'count': count,
      'fare': fare,
    };
  }
}

