import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';
import '../models/bus.dart';

/// Bus provider
final busProvider = FutureProvider<BusInfo?>((ref) async {
  final apiService = ApiService();
  
  // First, quickly check if we're in demo mode
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
  
  // If demo mode, return mock data immediately
  if (isDemo) {
    print('🎭 DEMO MODE: Returning mock bus data immediately');
    return _getMockBusData();
  }
  
  // Otherwise, try to get bus data from API
  try {
    final busInfo = await apiService.getAssignedBus().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        // If timeout, check if demo mode and return mock data
        throw TimeoutException('Request timeout', const Duration(seconds: 5));
      },
    );
    
    // If not assigned, return null
    if (busInfo == null) {
      return null;
    }
    
    // Cache it asynchronously (don't wait)
    try {
      final localDB = LocalDB();
      localDB.cacheBusInfo(busInfo).catchError((e) {
        // Ignore cache errors
      });
    } catch (e) {
      // Ignore cache errors
    }
    
    return busInfo;
  } on TimeoutException {
    // On timeout, check if demo mode and return mock data
    try {
      final isDemo = await apiService.isDemoMode().timeout(
        const Duration(seconds: 1),
        onTimeout: () => false,
      );
      if (isDemo) {
        return _getMockBusData();
      }
    } catch (e) {
      // Ignore
    }
    
    // Try cache as fallback
    try {
      final localDB = LocalDB();
      final cached = await localDB.getCachedBusInfo().timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
      if (cached != null) return cached;
    } catch (e) {
      // Ignore
    }
    
    rethrow;
  } catch (e) {
    // Check if demo mode on any error
    try {
      final isDemo = await apiService.isDemoMode().timeout(
        const Duration(seconds: 1),
        onTimeout: () => false,
      );
      if (isDemo) {
        return _getMockBusData();
      }
    } catch (e) {
      // Ignore
    }
    
    // Try cache as fallback
    try {
      final localDB = LocalDB();
      final cached = await localDB.getCachedBusInfo().timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
      if (cached != null) return cached;
    } catch (e) {
      // Ignore
    }
    
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
  );
}

/// Bus cache provider
final busCacheProvider = FutureProvider<BusInfo?>((ref) async {
  final localDB = LocalDB();
  return await localDB.getCachedBusInfo();
});

