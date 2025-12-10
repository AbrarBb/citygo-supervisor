/// Report Response model
class ReportResponse {
  final DateTime date;
  final int tapInCount;
  final int tapOutCount;
  final int manualTickets;
  final double totalFare;
  final double totalDistance;
  final double co2Saved;
  final int tripCount;
  final int passengerCount;
  final String? busNumber;
  final List<HourlyData>? hourlyData;

  ReportResponse({
    required this.date,
    required this.tapInCount,
    required this.tapOutCount,
    required this.manualTickets,
    required this.totalFare,
    required this.totalDistance,
    required this.co2Saved,
    required this.tripCount,
    required this.passengerCount,
    this.busNumber,
    this.hourlyData,
  });

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    // Handle nested report object from API
    final reportData = json['report'] as Map<String, dynamic>? ?? json;
    
    return ReportResponse(
      date: reportData['report_date'] != null
          ? DateTime.parse(reportData['report_date'] as String)
          : (reportData['date'] != null
              ? DateTime.parse(reportData['date'] as String)
              : DateTime.now()),
      tapInCount: reportData['total_tap_ins'] as int? ?? 
                 reportData['tap_in_count'] as int? ?? 
                 reportData['tap_ins'] as int? ?? 0,
      tapOutCount: reportData['total_tap_outs'] as int? ?? 
                   reportData['tap_out_count'] as int? ?? 
                   reportData['tap_outs'] as int? ?? 0,
      manualTickets: reportData['total_manual_tickets'] as int? ?? 0,
      totalFare: (reportData['total_fare_collected'] as num?)?.toDouble() ?? 
                 (reportData['total_fare'] as num?)?.toDouble() ?? 
                 (reportData['fare'] as num?)?.toDouble() ?? 0.0,
      totalDistance: (reportData['total_distance_km'] as num?)?.toDouble() ?? 
                    (reportData['total_distance'] as num?)?.toDouble() ?? 
                    (reportData['distance_km'] as num?)?.toDouble() ?? 0.0,
      co2Saved: (reportData['total_co2_saved'] as num?)?.toDouble() ?? 
                (reportData['co2_saved'] as num?)?.toDouble() ?? 0.0,
      tripCount: reportData['trip_count'] as int? ?? 
                 reportData['trips'] as int? ?? 0,
      passengerCount: reportData['passenger_count'] as int? ?? 
                      reportData['passengers'] as int? ?? 0,
      busNumber: reportData['bus_number'] as String?,
      hourlyData: (reportData['hourly_data'] as List<dynamic>?)
          ?.map((e) => HourlyData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'total_tap_ins': tapInCount,
      'total_tap_outs': tapOutCount,
      'total_manual_tickets': manualTickets,
      'total_fare_collected': totalFare,
      'total_distance_km': totalDistance,
      'total_co2_saved': co2Saved,
      'passenger_count': passengerCount,
      if (busNumber != null) 'bus_number': busNumber,
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

