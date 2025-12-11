import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';
import '../models/bus.dart';

/// Bus provider
final busProvider = FutureProvider<BusInfo?>((ref) async {
  print('🚌 Bus provider started');
  final apiService = ApiService();
  
  // First, quickly check if we're in demo mode
  bool isDemo = false;
  try {
    final token = await apiService.getStoredToken().timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => null,
    );
    isDemo = token != null && token.startsWith('demo_');
    print('🚌 Demo mode check: $isDemo');
  } catch (e) {
    print('⚠️ Error checking demo mode: $e');
    isDemo = false;
  }
  
  // If demo mode, return mock data immediately
  if (isDemo) {
    print('🎭 DEMO MODE: Returning mock bus data immediately');
    return _getMockBusData();
  }
  
  // Otherwise, try to get bus data from API
  try {
    print('🚌 Fetching bus data from API...');
    final busInfo = await apiService.getAssignedBus().timeout(
      const Duration(seconds: 10), // Increased timeout
      onTimeout: () {
        print('⏱️ Bus API request timed out');
        throw TimeoutException('Request timeout', const Duration(seconds: 10));
      },
    );
    
    print('🚌 Bus API response received: ${busInfo != null ? "has bus" : "null"}');
    
    // If not assigned, return null
    if (busInfo == null) {
      print('⚠️ No bus assigned to supervisor');
      return null;
    }
    
    // Cache it asynchronously (don't wait)
    try {
      final localDB = LocalDB();
      localDB.cacheBusInfo(busInfo).catchError((e) {
        print('⚠️ Error caching bus info: $e');
      });
    } catch (e) {
      print('⚠️ Error creating LocalDB: $e');
    }
    
    print('✅ Bus provider returning bus info');
    return busInfo;
  } on TimeoutException catch (e) {
    print('⏱️ TimeoutException in bus provider: $e');
    // On timeout, check if demo mode and return mock data
    try {
      final isDemo = await apiService.isDemoMode().timeout(
        const Duration(seconds: 1),
        onTimeout: () => false,
      );
      if (isDemo) {
        print('🎭 Demo mode detected after timeout, returning mock data');
        return _getMockBusData();
      }
    } catch (e) {
      print('⚠️ Error checking demo mode after timeout: $e');
    }
    
    // Try cache as fallback
    try {
      print('💾 Trying to load cached bus info...');
      final localDB = LocalDB();
      final cached = await localDB.getCachedBusInfo().timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          print('⏱️ Cache read timed out');
          return null;
        },
      );
      if (cached != null) {
        print('✅ Returning cached bus info');
        return cached;
      }
    } catch (e) {
      print('⚠️ Error reading cache: $e');
    }
    
    print('❌ Bus provider throwing TimeoutException');
    rethrow;
  } catch (e, stackTrace) {
    print('❌ Error in bus provider: $e');
    print('Stack trace: $stackTrace');
    
    // Check if demo mode on any error
    try {
      final isDemo = await apiService.isDemoMode().timeout(
        const Duration(seconds: 1),
        onTimeout: () => false,
      );
      if (isDemo) {
        print('🎭 Demo mode detected after error, returning mock data');
        return _getMockBusData();
      }
    } catch (e) {
      print('⚠️ Error checking demo mode after error: $e');
    }
    
    // Try cache as fallback
    try {
      print('💾 Trying to load cached bus info after error...');
      final localDB = LocalDB();
      final cached = await localDB.getCachedBusInfo().timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          print('⏱️ Cache read timed out');
          return null;
        },
      );
      if (cached != null) {
        print('✅ Returning cached bus info after error');
        return cached;
      }
    } catch (e) {
      print('⚠️ Error reading cache after error: $e');
    }
    
    print('❌ Bus provider rethrowing error');
    rethrow;
  }
});

/// Mock bus data for demo mode
BusInfo _getMockBusData() {
  return BusInfo(
    id: 'demo-bus-123',
    licensePlate: 'DEMO-001',
    routeNumber: 'Route 42',
    route: RouteInfo(
      id: 'demo-route-123',
      name: 'Demo Route',
      routeNumber: '42',
      stops: [
        Stop(
          id: 'stop-1',
          name: 'Start Station',
          latitude: 23.8103,
          longitude: 90.4125,
          order: 1,
        ),
        Stop(
          id: 'stop-2',
          name: 'City Center',
          latitude: 23.8150,
          longitude: 90.4200,
          order: 2,
        ),
        Stop(
          id: 'stop-3',
          name: 'End Station',
          latitude: 23.8250,
          longitude: 90.4300,
          order: 3,
        ),
      ],
    ),
    status: 'active',
    isActive: true,
  );
}

/// Bus cache provider
final busCacheProvider = FutureProvider<BusInfo?>((ref) async {
  final localDB = LocalDB();
  return await localDB.getCachedBusInfo();
});

