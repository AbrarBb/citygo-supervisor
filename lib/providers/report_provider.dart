import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/report.dart';

/// Today's report provider
final todayReportProvider = FutureProvider<ReportResponse?>((ref) async {
  final apiService = ApiService();
  
  // Check if we're in demo mode
  bool isDemo = false;
  try {
    final token = await apiService.getStoredToken().timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => null,
    );
    isDemo = token != null && token.startsWith('demo_');
  } catch (e) {
    isDemo = false;
  }
  
  // If demo mode, return mock data
  if (isDemo) {
    return ReportResponse(
      date: DateTime.now(),
      tapInCount: 45,
      tapOutCount: 42,
      totalFare: 1234.0,
      totalDistance: 125.5,
      co2Saved: 12.3,
      tripCount: 12,
      passengerCount: 342,
      hourlyData: null,
    );
  }
  
  try {
    final report = await apiService.getReport(date: DateTime.now()).timeout(
      const Duration(seconds: 5),
    );
    return report;
  } catch (e) {
    print('Error loading today\'s report: $e');
    // Return empty report on error
    return ReportResponse(
      date: DateTime.now(),
      tapInCount: 0,
      tapOutCount: 0,
      totalFare: 0.0,
      totalDistance: 0.0,
      co2Saved: 0.0,
      tripCount: 0,
      passengerCount: 0,
      hourlyData: null,
    );
  }
});

