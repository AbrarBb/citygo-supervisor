import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';
import '../models/auth.dart';
import '../models/user.dart';
import '../models/bus.dart';
import '../models/nfc.dart';
import '../models/ticket.dart';
import '../models/sync.dart';
import '../models/report.dart';
import '../models/pagination.dart';

/// API Service for CityGo Supervisor backend
class ApiService {
  static const String baseUrl = API_BASE_URL;
  static const _storage = FlutterSecureStorage();
  
  late final Dio _dio;
  String? _jwtToken;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Always include API key header
        options.headers['apikey'] = SUPABASE_API_KEY;
        options.headers['Content-Type'] = 'application/json';

        // Don't add Authorization header for login endpoint
        if (options.path.endsWith('/supervisor-auth') || 
            options.uri.path.contains('/supervisor-auth')) {
          return handler.next(options);
        }

        // Load JWT from secure storage for authenticated endpoints
        _jwtToken ??= await _storage.read(key: 'jwt_token');

        // Add Authorization header if JWT exists (for authenticated endpoints only)
        if (_jwtToken != null) {
          options.headers['Authorization'] = 'Bearer $_jwtToken';
        }

        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 - clear auth and surface error
        if (error.response?.statusCode == 401) {
          await clearAuth();
        }
        return handler.next(error);
      },
    ));
  }

  /// Store authentication credentials
  Future<void> setAuth(String jwtToken, String userId) async {
    _jwtToken = jwtToken;
    await _storage.write(key: 'jwt_token', value: jwtToken);
    await _storage.write(key: 'user_id', value: userId);
  }

  /// Clear authentication credentials
  Future<void> clearAuth() async {
    _jwtToken = null;
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_id');
    // Also clear any other possible JWT keys
    await _storage.delete(key: 'citygo_jwt');
  }

  /// Get stored JWT token
  Future<String?> getStoredToken() async {
    _jwtToken ??= await _storage.read(key: 'jwt_token');
    return _jwtToken;
  }

  /// Check if we're in demo mode
  Future<bool> isDemoMode() async {
    final token = await getStoredToken();
    return token != null && token.startsWith('demo_');
  }

  /// Login - POST /supervisor-auth
  Future<LoginResponse> login(String email, String password) async {
    try {
      // DEMO MODE: Check for demo credentials (for UI testing without backend)
      if (ENABLE_DEMO_MODE && 
          email.trim().toLowerCase() == DEMO_EMAIL && 
          password == DEMO_PASSWORD) {
        print('🎭 DEMO MODE: Using mock credentials');
        
        // Create mock response
        final mockToken = 'demo_jwt_token_${DateTime.now().millisecondsSinceEpoch}';
        final mockUser = User(
          id: 'demo-user-123',
          email: DEMO_EMAIL,
          name: 'Demo Supervisor',
          role: 'supervisor',
        );
        
        final mockResponse = LoginResponse(
          token: mockToken,
          apiKey: SUPABASE_API_KEY,
          user: mockUser,
        );
        
        // Store mock token
        await setAuth(mockToken, mockUser.id);
        
        return mockResponse;
      }
      
      // Create a new Dio instance for login to avoid interceptor adding Authorization header
      final loginDio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));
      
      // Add logging to see actual request
      loginDio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
        error: true,
      ));
      
      // Login endpoint needs apikey AND Authorization header with anon key
      // Authorization header uses the anon key as Bearer token for unauthenticated requests
      final response = await loginDio.post(
        '/supervisor-auth',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
        options: Options(
          headers: {
            'apikey': SUPABASE_API_KEY,
            'Authorization': 'Bearer $SUPABASE_API_KEY',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 600, // Allow all status codes to handle manually
        ),
      );
      
      // Debug: Print response for troubleshooting
      print('=== LOGIN DEBUG ===');
      print('Request URL: ${response.requestOptions.uri}');
      print('Request headers: ${response.requestOptions.headers}');
      print('Request data: ${response.requestOptions.data}');
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');
      print('Response headers: ${response.headers}');
      print('==================');
      
      // Check for error response
      if (response.statusCode != null && response.statusCode! >= 400) {
        // Handle 500 errors specifically
        if (response.statusCode == 500) {
          throw Exception(
            'Server error: The authentication service is temporarily unavailable. '
            'Please try again in a few moments, or use demo mode to test the app.'
          );
        }
        
        // Handle 401 - Invalid credentials
        if (response.statusCode == 401) {
          final errorMsg = response.data?['message'] ?? 
              response.data?['error'] ?? 
              'Invalid email or password. Please check your credentials and try again.';
          throw Exception(errorMsg);
        }
        
        // Handle other 4xx errors
        final errorMsg = response.data?['message'] ?? 
            response.data?['error'] ?? 
            response.data?['detail'] ??
            'Authentication failed. Please try again.';
        throw Exception(errorMsg);
      }
      
      // Handle different response formats
      final data = response.data;
      String token;
      String userId;
      User user;
      
      // Try different token field names
      if (data['token'] != null) {
        token = data['token'] as String;
      } else if (data['access_token'] != null) {
        token = data['access_token'] as String;
      } else if (data['jwt'] != null) {
        token = data['jwt'] as String;
      } else {
        throw Exception('No token found in response');
      }
      
      // Handle user object
      if (data['user'] != null) {
        user = User.fromJson(data['user'] as Map<String, dynamic>);
        userId = user.id;
      } else if (data['id'] != null) {
        // If user object is not nested, create from root
        userId = data['id'] as String;
        user = User(
          id: userId,
          email: data['email'] as String? ?? email,
          name: data['name'] as String?,
          role: data['role'] as String?,
        );
      } else {
        throw Exception('No user information found in response');
      }
      
      final loginResponse = LoginResponse(
        token: token,
        apiKey: data['api_key'] as String? ?? data['apikey'] as String? ?? SUPABASE_API_KEY,
        user: user,
      );
      
      await setAuth(token, userId);
      return loginResponse;
    } on DioException catch (e) {
      // Handle 500 errors in login specifically with helpful message
      if (e.response?.statusCode == 500) {
        throw Exception(
          'Server error: The authentication service is temporarily unavailable. '
          'Please try again in a few moments, or use demo mode to test the app.'
        );
      }
      throw _handleError(e);
    } catch (e) {
      // Re-throw non-DioException errors
      throw e is Exception ? e : Exception(e.toString());
    }
  }

  /// Get Assigned Bus - GET /supervisor-bus
  Future<BusInfo> getAssignedBus() async {
    // Check if we're in demo mode
    if (await isDemoMode()) {
      print('🎭 DEMO MODE: Returning mock bus data');
      // Return mock bus data for demo
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
    
    try {
      final response = await _dio.get('/supervisor-bus');
      if (response.data == null) {
        throw Exception('No bus data received from server');
      }
      try {
        return BusInfo.fromJson(response.data as Map<String, dynamic>);
      } catch (e) {
        print('Error parsing bus data: $e');
        print('Response data: ${response.data}');
        throw Exception('Failed to parse bus data: $e');
      }
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unexpected error: $e');
    }
  }

  /// NFC Tap-In - POST /nfc-tap-in
  Future<NfcTapResponse> tapIn(NfcEvent event) async {
    try {
      final response = await _dio.post(
        '/nfc-tap-in',
        data: {
          'nfc_id': event.cardId,
          'card_id': event.cardId,
          'bus_id': event.busId,
          'latitude': event.latitude,
          'longitude': event.longitude,
        },
      );
      return NfcTapResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// NFC Tap-Out - POST /nfc-tap-out
  Future<NfcTapResponse> tapOut(NfcEvent event) async {
    try {
      final response = await _dio.post(
        '/nfc-tap-out',
        data: {
          'nfc_id': event.cardId,
          'card_id': event.cardId,
          'bus_id': event.busId,
          'latitude': event.latitude,
          'longitude': event.longitude,
        },
      );
      return NfcTapResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Manual Ticket - POST /manual-ticket
  Future<TicketResponse> issueManualTicket(ManualTicket ticket) async {
    try {
      final response = await _dio.post(
        '/manual-ticket',
        data: {
          'bus_id': ticket.busId,
          'passenger_count': ticket.passengerCount,
          'fare': ticket.fare,
          'latitude': ticket.latitude,
          'longitude': ticket.longitude,
          if (ticket.notes != null) 'notes': ticket.notes,
        },
      );
      return TicketResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Sync Events - POST /nfc-sync
  Future<SyncResponse> syncEvents(List<NfcEvent> events) async {
    try {
      final response = await _dio.post(
        '/nfc-sync',
        data: {
          'events': events.map((e) => e.toJson()).toList(),
          'logs': events.map((e) => e.toJson()).toList(), // Support both formats
        },
      );
      return SyncResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get Daily Reports - GET /supervisor-reports
  Future<ReportResponse> getReport({required DateTime date}) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await _dio.get(
        '/supervisor-reports',
        queryParameters: {'date': dateStr},
      );
      return ReportResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Generic cursor pagination method
  Future<PaginatedResponse<T>> getWithCursor<T>({
    required String path,
    Map<String, dynamic>? query,
    String cursorParam = 'cursor',
    String nextCursorKey = 'next_cursor',
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    try {
      final queryParams = Map<String, dynamic>.from(query ?? {});
      
      final response = await _dio.get(
        path,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? data['data'] as List<dynamic>? ?? [])
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();

      final nextCursor = data[nextCursorKey] as String?;
      final hasMore = nextCursor != null;

      return PaginatedResponse<T>(
        items: items,
        nextCursor: nextCursor,
        hasMore: hasMore,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle API errors with proper messages
  Exception _handleError(DioException error) {
    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;
      
      // Handle specific error codes
      if (statusCode == 401) {
        final message = data?['message'] ?? 
            data?['error'] ?? 
            data?['detail'] ??
            'Authentication failed. Please login again.';
        return Exception(message);
      } else if (statusCode == 402) {
        return Exception('Insufficient balance. Please top up your card.');
      } else if (statusCode == 403) {
        return Exception('Insufficient permissions. Please contact admin.');
      } else if (statusCode == 404) {
        return Exception('Card not registered. Please register your card first.');
      } else if (statusCode == 500) {
        // Server error - provide helpful message
        final message = data?['message'] ?? 
            data?['error'] ?? 
            'Server error: The service is temporarily unavailable. Please try again in a few moments.';
        return Exception(message);
      } else if (statusCode != null && statusCode >= 500) {
        // Other 5xx errors
        return Exception(
          'Server error: The service is experiencing issues. '
          'Please try again later or contact support if the problem persists.'
        );
      }
      
      final message = data?['message'] ?? 
          data?['error'] ?? 
          data?['detail'] ??
          'An error occurred';
      return Exception('Error $statusCode: $message');
    } else if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return Exception('Connection timeout. Please check your internet connection.');
    } else if (error.type == DioExceptionType.connectionError) {
      return Exception('No internet connection. Please check your network.');
    } else {
      return Exception(error.message ?? 'An unexpected error occurred');
    }
  }
}
