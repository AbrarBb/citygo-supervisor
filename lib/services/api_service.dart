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
import '../models/card.dart';
import '../models/booking.dart';

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
  Future<BusInfo?> getAssignedBus() async {
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
      
      final data = response.data as Map<String, dynamic>;
      
      // Check if supervisor is assigned
      final isActive = data['is_active'] as bool? ?? false;
      final success = data['success'] as bool? ?? true;
      
      if (!isActive || !success) {
        final message = data['message'] as String? ?? 
            'You are not currently assigned to any bus. Please wait for a driver to assign you.';
        print('⚠️ Supervisor not assigned: $message');
        return null;
      }
      
      // Parse bus and route from separate objects
      final busData = data['bus'] as Map<String, dynamic>?;
      final routeData = data['route'] as Map<String, dynamic>?;
      
      if (busData == null) {
        // If no bus data but is_active is true, still return null gracefully
        print('⚠️ No bus data in response despite is_active=true');
        return null;
      }
      
      // Combine bus and route data for BusInfo
      final combinedData = Map<String, dynamic>.from(busData);
      if (routeData != null) {
        combinedData['route'] = routeData;
      }
      
      try {
        return BusInfo.fromJson(combinedData);
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
          'card_id': event.cardId,
          'bus_id': event.busId,
          'location': {
            'lat': event.latitude,
            'lng': event.longitude,
          },
          if (event.offlineId != null) 'offline_id': event.offlineId,
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
          'card_id': event.cardId,
          'bus_id': event.busId,
          'location': {
            'lat': event.latitude,
            'lng': event.longitude,
          },
          if (event.offlineId != null) 'offline_id': event.offlineId,
        },
      );
      return NfcTapResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Manual Ticket - POST /manual-ticket or /supervisor-manual-ticket
  Future<TicketResponse> issueManualTicket(ManualTicket ticket) async {
    try {
      // Try different possible endpoints
      List<String> possibleEndpoints = [
        '/supervisor-manual-ticket',
        '/manual-ticket',
        '/tickets',
      ];
      
      // Prepare request data with multiple format options
      final requestData = {
        'bus_id': ticket.busId,
        'passenger_count': ticket.passengerCount,
        'fare': ticket.fare,
        'latitude': ticket.latitude,
        'longitude': ticket.longitude,
        'issued_at': ticket.timestamp.toIso8601String(),
        if (ticket.notes != null && ticket.notes!.isNotEmpty) 'notes': ticket.notes,
        if (ticket.offlineId != null) 'offline_id': ticket.offlineId,
        // Additional fields that might be expected
        'ticket_type': 'single',
        'payment_method': 'cash',
        'location': {
          'lat': ticket.latitude,
          'lng': ticket.longitude,
        },
      };
      
      DioException? lastError;
      
      for (final endpoint in possibleEndpoints) {
        try {
          print('🎫 Trying manual ticket endpoint: $endpoint');
          print('📦 Request data: $requestData');
          
          final response = await _dio.post(
            endpoint,
            data: requestData,
          );
          
          print('✅ Manual ticket response status: ${response.statusCode}');
          print('📋 Response data: ${response.data}');
          
          if (response.data != null) {
            final data = response.data;
            
            // Handle different response formats
            if (data is Map) {
              final dataMap = data as Map<String, dynamic>;
              
              // Check for success flag
              if (dataMap['success'] == false) {
                final errorMsg = dataMap['error'] as String? ?? 
                               dataMap['message'] as String? ?? 
                               'Failed to issue ticket';
                throw Exception(errorMsg);
              }
              
              // Return response
              return TicketResponse.fromJson(dataMap);
            } else {
              // If response is not a map, try to parse as TicketResponse
              return TicketResponse.fromJson({'success': true, 'ticket_id': data.toString()});
            }
          }
        } on DioException catch (e) {
          print('❌ Endpoint $endpoint failed: ${e.response?.statusCode}');
          print('❌ Error: ${e.message}');
          print('❌ Response: ${e.response?.data}');
          
          lastError = e;
          
          // If 404, try next endpoint
          if (e.response?.statusCode == 404) {
            continue;
          }
          
          // If 401/403, don't try other endpoints
          if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
            throw _handleError(e);
          }
          
          // For other errors, try next endpoint
          continue;
        } catch (e) {
          print('❌ Error with endpoint $endpoint: $e');
          lastError = DioException(
            requestOptions: RequestOptions(path: endpoint),
            error: e,
          );
          continue;
        }
      }
      
      // If all endpoints failed, throw the last error
      if (lastError != null) {
        throw _handleError(lastError);
      }
      
      throw Exception('No manual ticket endpoint available');
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      print('Error issuing manual ticket: $e');
      rethrow;
    }
  }

  /// Sync Events - POST /nfc-sync
  Future<SyncResponse> syncEvents(List<Map<String, dynamic>> events) async {
    try {
      final response = await _dio.post(
        '/nfc-sync',
        data: {
          'events': events,
        },
      );
      return SyncResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Get Registered Cards - GET /registered-cards or /cards
  Future<List<RegisteredCard>> getRegisteredCards() async {
    try {
      // Try different possible endpoints
      List<String> possibleEndpoints = [
        '/registered-cards',
        '/cards',
        '/nfc-cards',
        '/passenger-cards',
        '/supervisor-cards',
      ];
      
      for (final endpoint in possibleEndpoints) {
        try {
          print('🔍 Trying endpoint: $endpoint');
          final response = await _dio.get(endpoint);
          print('✅ Response status: ${response.statusCode}');
          print('📦 Response data type: ${response.data.runtimeType}');
          
          if (response.data != null) {
            final data = response.data;
            print('📋 Response data: $data');
            
            // Handle different response formats
            List<dynamic> cardsList;
            if (data is List) {
              print('📝 Data is a List with ${data.length} items');
              cardsList = data;
            } else if (data is Map && data['cards'] != null) {
              print('📝 Data has "cards" key');
              cardsList = data['cards'] as List<dynamic>;
            } else if (data is Map && data['items'] != null) {
              print('📝 Data has "items" key');
              cardsList = data['items'] as List<dynamic>;
            } else if (data is Map && data['data'] != null) {
              print('📝 Data has "data" key');
              cardsList = data['data'] as List<dynamic>;
            } else if (data is Map && data['success'] == true && data['cards'] != null) {
              print('📝 Data has success=true and "cards" key');
              cardsList = data['cards'] as List<dynamic>;
            } else if (data is Map && data['success'] != false) {
              // Try to find cards array even without explicit success flag
              if (data['cards'] != null) {
                print('📝 Data has "cards" key (without explicit success check)');
                cardsList = data['cards'] as List<dynamic>;
              } else {
                print('⚠️ Unknown data format, trying next endpoint');
                print('📋 Full response: $data');
                continue;
              }
            } else {
              print('⚠️ Unknown data format, trying next endpoint');
              print('📋 Full response: $data');
              continue; // Try next endpoint
            }
            
            print('✅ Found ${cardsList.length} cards');
            final cards = cardsList
                .map((json) {
                  try {
                    return RegisteredCard.fromJson(json as Map<String, dynamic>);
                  } catch (e) {
                    print('❌ Error parsing card: $e');
                    print('📋 Card data: $json');
                    rethrow;
                  }
                })
                .toList();
            
            print('✅ Successfully parsed ${cards.length} cards from $endpoint');
            return cards;
          }
        } on DioException catch (e) {
          print('❌ Endpoint $endpoint failed: ${e.response?.statusCode} - ${e.message}');
          if (e.response?.statusCode == 404) {
            print('   404 - Endpoint not found, trying next...');
            continue;
          }
          // For other errors, try next endpoint
          continue;
        } catch (e) {
          print('❌ Error with endpoint $endpoint: $e');
          continue;
        }
      }
      
      // If all endpoints fail, return empty list
      print('⚠️ All endpoints failed. No registered cards endpoint found.');
      print('💡 Tried endpoints: ${possibleEndpoints.join(", ")}');
      return [];
    } on DioException catch (e) {
      print('❌ DioException in getRegisteredCards: ${e.response?.statusCode}');
      // If 404, return empty list (endpoint might not exist)
      if (e.response?.statusCode == 404) {
        print('⚠️ Registered cards endpoint not found (404)');
        return [];
      }
      throw _handleError(e);
    } catch (e) {
      print('❌ Error fetching registered cards: $e');
      return [];
    }
  }

  /// Get Bus Bookings for Supervisor
  /// 
  /// Expected endpoint: GET /supervisor-bookings?bus_id=<busId>&date=<YYYY-MM-DD>
  /// 
  /// Expected response format:
  /// {
  ///   "success": true,
  ///   "bus_id": "uuid",
  ///   "bus_number": "DHK-BUS-102",
  ///   "total_seats": 40,
  ///   "available_seats": 25,
  ///   "booked_seats": 15,
  ///   "bookings": [
  ///     {
  ///       "id": "booking-uuid",
  ///       "bus_id": "bus-uuid",
  ///       "seat_number": 1,
  ///       "passenger_name": "John Doe",
  ///       "card_id": "RC-d4a290fc",
  ///       "status": "booked", // or "occupied", "available"
  ///       "booked_at": "2024-01-15T08:00:00Z",
  ///       "booking_type": "online" // or "nfc", "manual"
  ///     }
  ///   ]
  /// }
  Future<BusBookings> getBusBookings({String? busId, DateTime? date}) async {
    try {
      // Try different possible endpoints (prioritize supervisor-specific)
      List<String> possibleEndpoints = [
        '/supervisor-bookings',
        '/bus-bookings',
        '/bookings',
        '/seat-bookings',
      ];
      
      final queryParams = <String, dynamic>{};
      if (busId != null) {
        queryParams['bus_id'] = busId;
      }
      if (date != null) {
        queryParams['date'] = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }
      
      for (final endpoint in possibleEndpoints) {
        try {
          print('🔍 Trying bookings endpoint: $endpoint');
          final response = await _dio.get(
            endpoint,
            queryParameters: queryParams.isEmpty ? null : queryParams,
          );
          print('✅ Response status: ${response.statusCode}');
          
          if (response.data != null) {
            final data = response.data;
            print('📋 Response data type: ${data.runtimeType}');
            
            // Handle different response formats
            Map<String, dynamic> bookingsData;
            if (data is Map) {
              final dataMap = data as Map<String, dynamic>;
              if (dataMap['success'] == true && dataMap['bookings'] != null) {
                bookingsData = dataMap;
              } else if (dataMap['bus_id'] != null || dataMap['bookings'] != null) {
                bookingsData = dataMap;
              } else if (dataMap['seats'] != null) {
                // Alternative format with 'seats' key
                bookingsData = {
                  'bus_id': dataMap['bus_id'] ?? busId ?? 'unknown',
                  'bookings': dataMap['seats'],
                  'total_seats': dataMap['total_seats'] ?? 40,
                  'available_seats': dataMap['available_seats'] ?? 0,
                  'booked_seats': dataMap['booked_seats'] ?? 0,
                };
              } else {
                print('⚠️ Unknown data format, trying next endpoint');
                print('📋 Full response: $dataMap');
                continue;
              }
            } else {
              continue;
            }
            
            print('✅ Found bookings data');
            return BusBookings.fromJson(bookingsData);
          }
        } on DioException catch (e) {
          print('❌ Endpoint $endpoint failed: ${e.response?.statusCode}');
          if (e.response?.statusCode == 404) {
            continue; // Try next endpoint
          }
          continue;
        } catch (e) {
          print('❌ Error with endpoint $endpoint: $e');
          continue;
        }
      }
      
      // If all endpoints fail, return empty bookings
      print('⚠️ No bookings endpoint found, returning empty bookings');
      return BusBookings(
        busId: busId ?? 'unknown',
        totalSeats: 40, // Default capacity
        availableSeats: 40,
        bookedSeats: 0,
        bookings: [],
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Return empty bookings if endpoint doesn't exist
        return BusBookings(
          busId: busId ?? 'unknown',
          totalSeats: 40,
          availableSeats: 40,
          bookedSeats: 0,
          bookings: [],
        );
      }
      throw _handleError(e);
    } catch (e) {
      print('Error fetching bookings: $e');
      // Return empty bookings on error
      return BusBookings(
        busId: busId ?? 'unknown',
        totalSeats: 40,
        availableSeats: 40,
        bookedSeats: 0,
        bookings: [],
      );
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
        // Check if this is a bus assignment endpoint
        final path = error.requestOptions.path;
        if (path.contains('supervisor-bus')) {
          return Exception('No bus assignment found. Please wait for a driver to assign you to a bus.');
        } else if (path.contains('nfc') || path.contains('card')) {
          return Exception('Card not registered. Please register your card first.');
        }
        return Exception('Resource not found. Please try again.');
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
