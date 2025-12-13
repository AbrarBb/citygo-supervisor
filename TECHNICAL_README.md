# CityGo Supervisor - Technical Documentation

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Authentication Flow](#authentication-flow)
4. [Data Flow](#data-flow)
5. [Dashboard Data Flow](#dashboard-data-flow)
6. [Core Services](#core-services)
7. [State Management](#state-management)
8. [NFC Integration](#nfc-integration)
9. [Offline Sync Mechanism](#offline-sync-mechanism)
10. [API Integration](#api-integration)
11. [Database Schema](#database-schema)
12. [UI Components](#ui-components)
13. [Platform-Specific Configuration](#platform-specific-configuration)
14. [Build & Deployment](#build--deployment)
15. [Troubleshooting](#troubleshooting)
16. [Manual Ticket Feature](#manual-ticket-feature)
17. [Reports Screen](#reports-screen)
18. [Profile & Help Support](#profile--help-support)
19. [Testing](#testing)

---

## Overview

**CityGo Supervisor** is a Flutter mobile application designed for bus supervisors to manage passenger tap-ins/tap-outs using NFC cards, issue manual tickets, and generate daily reports. The app operates in both online and offline modes, with automatic synchronization when connectivity is restored.

### Key Features

- 🔐 **JWT-based Authentication** with secure token storage
- 🚌 **Bus & Route Management** with real-time status tracking
- 📍 **NFC Card Reading** (NTAG216 and other formats)
- 🔍 **Card Registration Check** - Verify card registration and view passenger info
- 🎫 **Manual Ticket Issuance** with passenger count and seat selection (1-40)
- 🔄 **Offline-First Architecture** with automatic sync
- 📊 **Daily Reports** with statistics and hourly breakdown (with force refresh)
- 🗺️ **Google Maps Integration** for route visualization
- 📈 **Real-Time Trip Progress** - Calculated from actual bus location and stops
- 👥 **Real-Time Passenger Counting** - Prioritizes API `bookedSeats`, combines with bookings and manual tickets
- 👤 **Profile Screen** - View user information and details
- ❓ **Help & Support** - FAQs and developer contact
- 📱 **Cross-Platform Support** (Android, iOS, Web, Desktop)

### Technology Stack

| Technology | Purpose | Version |
|------------|---------|---------|
| Flutter | UI Framework | 3.10.3+ |
| Dart | Programming Language | 3.10.3+ |
| Riverpod | State Management | 2.0.0 |
| Dio | HTTP Client | 5.0.3 |
| SQLite (sqflite) | Local Database | 2.2.0 |
| NFC Manager | NFC Tag Reading | 4.0.0 |
| Google Maps Flutter | Maps Integration | 2.3.0 |
| Flutter Secure Storage | Token Storage | 8.0.1 |
| url_launcher | External URL Opening | 6.3.0 |

---

## Architecture

### Project Structure

```
lib/
├── main.dart                 # App entry point, route configuration
├── constants.dart            # API keys, configuration constants
│
├── models/                   # Data models (immutable classes)
│   ├── auth.dart            # LoginResponse, AuthUser
│   ├── user.dart            # User profile model
│   ├── bus.dart             # BusInfo, Route, Stop models
│   ├── nfc.dart             # NFCEvent, NfcTapResponse
│   ├── ticket.dart          # ManualTicket model
│   ├── sync.dart            # SyncRequest, SyncResponse
│   ├── report.dart          # DailyReport, ReportStats
│   ├── card.dart            # Card model
│   ├── booking.dart         # Booking model
│   └── pagination.dart      # Pagination metadata
│
├── providers/               # Riverpod state providers
│   ├── auth_provider.dart   # Authentication state
│   ├── bus_provider.dart    # Bus & route state
│   ├── nfc_provider.dart    # NFC logs state
│   ├── sync_provider.dart   # Sync status state
│   ├── report_provider.dart # Reports state
│   └── bookings_provider.dart # Bookings state
│
├── services/                # Business logic layer
│   ├── api_service.dart     # REST API client (Dio)
│   ├── local_db.dart        # SQLite database operations
│   ├── nfc_service.dart     # NFC tag reading logic
│   └── sync_service.dart    # Offline sync orchestration
│
├── screens/                  # UI screens (StatelessWidget/StatefulWidget)
│   ├── login.dart           # Login screen
│   ├── dashboard.dart        # Main dashboard with map, stats, trip progress
│   ├── nfc_reader.dart       # NFC scanning interface with card check
│   ├── manual_ticket.dart   # Manual ticket form with seat selection
│   ├── bookings.dart        # Bus bookings and seat map
│   ├── sync_center.dart     # Offline sync management
│   ├── reports.dart         # Daily reports view with date picker
│   ├── settings.dart        # App settings
│   ├── profile.dart         # User profile screen
│   ├── help_support.dart    # Help & Support screen with FAQs
│   └── registered_cards.dart # Registered cards list
│
├── widgets/                 # Reusable UI components
│   └── components.dart       # CityGoCard, PrimaryButton, StatCard, etc.
│
└── theme/                   # App theming
    └── app_theme.dart       # Dark theme configuration
```

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interface Layer                    │
│  ┌──────────┐  ┌───────────┐   ┌──────────┐   ┌──────────┐  │
│  │  Login   │  │ Dashboard │   │ NFC Scan │   │  Reports │  │
│  └────┬─────┘  └────┬──────┘   └────┬─────┘   └────┬─────┘  │
└───────┼─────────────┼───────────────┼──────────────┼────────┘
        │             │               │              │
        ▼             ▼               ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│                State Management Layer (Riverpod)            │
│  ┌──────────┐  ┌───────────┐   ┌──────────┐   ┌──────────┐  │
│  │   Auth   │  │   Bus     │   │   NFC    │   │  Sync    │  │
│  │ Provider │  │ Provider  │   │ Provider │   │ Provider │  │
│  └────┬─────┘  └────┬──────┘   └────┬─────┘   └────┬─────┘  │
└───────┼─────────────┼───────────────┼──────────────┼────────┘
        │             │               │              │
        ▼             ▼               ▼              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                          │
│  ┌──────────────┐  ┌──────────────┐      ┌──────────────┐   │
│  │  ApiService  │  │   LocalDB    │      │  NFCService  │   │
│  │  (Dio HTTP)  │  │  (SQLite)    │      │  (NFC Tag)   │   │
│  └──────┬───────┘  └──────┬───────┘      └──────┬───────┘   │
└─────────┼─────────────────┼─────────────────────┼───────────┘
          │                 │                     │
          ▼                 ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Dependencies                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Backend    │  │  SQLite DB   │  │  NFC Device  │       │
│  │   (Supabase) │  │  (Local)     │  │  (Hardware)  │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Design Patterns

1. **Provider Pattern (Riverpod)**: State management with dependency injection
2. **Repository Pattern**: Services abstract data sources (API, LocalDB)
3. **Singleton Pattern**: ApiService, LocalDB instances
4. **Observer Pattern**: Riverpod providers notify UI of state changes
5. **Strategy Pattern**: Platform-specific database initialization

---

## Authentication Flow

### Flow Diagram

```
┌─────────────┐
│  User Input │
│ (Email/Pwd) │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│  Login Screen   │
│  (UI Layer)     │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐        ┌────────────────────────┐
│ Auth Provider   │─────▶ │   ApiService           │ 
│ (Riverpod)      │        │  POST /supervisor-auth │
└─────────────────┘        └──────┬─────────────────┘
                                 │
                                 ▼
                        ┌──────────────────┐
                        │  Backend API     │
                        │  (Supabase)      │
                        └──────┬───────────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
                    ▼                     ▼
            ┌──────────────┐    ┌──────────────┐
            │   Success    │    │    Error     │
            │  (JWT Token) │    │  (401/400)   │
            └──────┬───────┘    └──────┬───────┘
                   │                   │
                   ▼                   ▼
        ┌──────────────────┐  ┌──────────────────┐
        │ Flutter Secure   │  │  Error Snackbar  │
        │ Storage (JWT)    │  │  (UI Feedback)   │
        └──────┬───────────┘  └──────────────────┘
               │
               ▼
        ┌──────────────────┐
        │  Navigate to     │
        │  Dashboard       │
        └──────────────────┘
```

### Authentication Code Flow

```dart
// 1. User enters credentials in LoginScreen
class LoginScreen extends ConsumerStatefulWidget {
  // ... UI code
  void _handleLogin() async {
    // 2. Call auth provider
    await ref.read(authProvider.notifier).login(email, password);
  }
}

// 3. Auth Provider calls ApiService
class AuthNotifier extends StateNotifier<AsyncValue<AuthUser?>> {
  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      // 4. ApiService makes HTTP request
      final response = await _apiService.login(email, password);
      
      // 5. Store JWT in secure storage
      await _apiService.setAuth(response.token, response.user.id);
      
      // 6. Update state
      state = AsyncValue.data(response.user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// 7. ApiService implementation
class ApiService {
  Future<LoginResponse> login(String email, String password) async {
    final response = await _dio.post(
      '/supervisor-auth',
      data: {'email': email, 'password': password},
    );
    return LoginResponse.fromJson(response.data);
  }
  
  Future<void> setAuth(String jwtToken, String userId) async {
    _jwtToken = jwtToken;
    await _storage.write(key: 'jwt_token', value: jwtToken);
    await _storage.write(key: 'user_id', value: userId);
  }
}
```

### JWT Token Management

| Storage Location | Key | Purpose |
|-----------------|-----|---------|
| Flutter Secure Storage | `jwt_token` | JWT authentication token |
| Flutter Secure Storage | `user_id` | User ID for quick access |
| Memory (ApiService) | `_jwtToken` | Runtime token cache |

**Token Injection**: The Dio interceptor automatically adds the JWT token to all authenticated requests:

```dart
_dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) async {
    // Load JWT from secure storage
    _jwtToken ??= await _storage.read(key: 'jwt_token');
    
    // Add Authorization header
    if (_jwtToken != null) {
      options.headers['Authorization'] = 'Bearer $_jwtToken';
    }
    
    return handler.next(options);
  },
  onError: (error, handler) async {
    // Handle 401 - clear auth
    if (error.response?.statusCode == 401) {
      await clearAuth();
    }
    return handler.next(error);
  },
));
```

---

## Data Flow

### NFC Tap-In/Tap-Out Flow

```
┌──────────────┐
│ User Taps    │
│ NFC Card     │
└──────┬───────┘
       │
       ▼
┌─────────────────┐
│ NFCReaderScreen │
│ (UI)            │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│  NFCService     │
│  readNFCTag()   │
└──────┬──────────┘
       │
       ├─────────────────┐
       │                 │
       ▼                 ▼
┌──────────────┐  ┌──────────────┐
│ Read NDEF    │  │ Read Tag ID  │
│ (NTAG216)    │  │ (Fallback)   │
└──────┬───────┘  └──────┬───────┘
       │                 │
       └────────┬────────┘
                │
                ▼
        ┌──────────────┐
        │ Extract Card │
        │ ID (RC-XXXX) │
        └──────┬───────┘
               │
               ▼
        ┌──────────────┐
        │ Get Location │
        │ (Geolocator) │
        └──────┬───────┘
               │
               ▼
        ┌──────────────────┐
        │  Check Internet  │
        │  Connectivity    │
        └──────┬───────────┘
               │
       ┌───────┴───────┐
       │               │
       ▼               ▼
┌──────────┐    ┌──────────┐
│ Online   │    │ Offline  │
└────┬─────┘    └────┬─────┘
     │               │
     ▼               ▼
┌───────────┐     ┌──────────┐
│ API Call  │     │  Save to │
│ (Tap-In)  │     │  LocalDB │
└────┬──────┘     └────┬─────┘
     │                 │
     ▼                 ▼
┌───────────┐     ┌──────────┐
│ Show      │     │ Mark as  │
│ Success   │     │ Unsynced │
└───────────┘     └──────────┘
```

### Offline Sync Flow

```
┌─────────────────┐
│ User Opens      │
│ Sync Center     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ SyncService     │
│ syncAllEvents() │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ LocalDB         │
│ Get Unsynced    │
│ Events          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Batch Events    │
│ (Max 50)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ ApiService      │
│ POST /nfc-sync  │
└────────┬────────┘
         │
         ├─────────────────┐
         │                 │
         ▼                 ▼
┌──────────────┐    ┌──────────────┐
│ Success      │    │ Error        │
│ (200)        │    │ (4xx/5xx)    │
└──────┬───────┘    └──────┬───────┘
       │                   │
       ▼                   ▼
┌──────────────┐    ┌──────────────┐
│ Mark as      │    │ Keep as      │
│ Synced       │    │ Unsynced     │
└──────────────┘    └──────────────┘
```

### Data Models

#### NFCEvent Model

```dart
class NFCEvent {
  final String offlineId;      // UUID generated locally
  final String cardId;         // RC-XXXXX format
  final String busId;          // Bus identifier
  final String eventType;      // 'tap_in' or 'tap_out'
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool synced;            // Sync status
  final Map<String, dynamic>? responseData; // API response cache
}
```

#### ManualTicket Model

```dart
class ManualTicket {
  final String offlineId;
  final String busId;
  final int passengerCount;
  final double fare;
  final double latitude;
  final double longitude;
  final String? notes;
  final int? seatNumber;        // Selected seat (1-40, optional)
  final DateTime timestamp;
  final bool synced;
}
```

---

## Core Services

### ApiService

**Purpose**: Centralized HTTP client for all backend API calls.

**Key Features**:
- JWT token injection via Dio interceptors
- Automatic token refresh on 401 errors
- Request/response logging for debugging
- Timeout handling (30 seconds)
- Error transformation to user-friendly messages

**Key Methods**:

```dart
class ApiService {
  // Authentication
  Future<LoginResponse> login(String email, String password);
  Future<void> setAuth(String jwtToken, String userId);
  Future<void> clearAuth();
  
  // Bus Management
  Future<BusInfo> getAssignedBus();
  
  // NFC Operations
  Future<NfcTapResponse> tapIn(NFCEvent event);
  Future<NfcTapResponse> tapOut(NFCEvent event);
  
  // Manual Tickets
  Future<ManualTicketResponse> issueManualTicket(ManualTicket ticket);
  
  // Card Registration Check
  Future<RegisteredCard?> checkCardRegistration(String cardId);
  
  // Bus Bookings
  Future<BusBookings> getBusBookings({String? busId, DateTime? date});
  
  // Sync
  Future<SyncResponse> syncEvents(List<NFCEvent> events);
  
  // Reports
  Future<DailyReport> getDailyReport(String date, {bool forceRefresh = false});
}
```

**Request Interceptor Logic**:

```dart
onRequest: (options, handler) async {
  // Always include API key
  options.headers['apikey'] = SUPABASE_API_KEY;
  
  // Skip auth for login endpoint
  if (options.path.endsWith('/supervisor-auth')) {
    return handler.next(options);
  }
  
  // Load JWT from secure storage
  _jwtToken ??= await _storage.read(key: 'jwt_token');
  
  // Add Authorization header
  if (_jwtToken != null) {
    options.headers['Authorization'] = 'Bearer $_jwtToken';
  }
  
  return handler.next(options);
}
```

### LocalDB Service

**Purpose**: SQLite database for offline storage and caching.

**Database Schema**:

| Table | Columns | Purpose |
|-------|---------|---------|
| `nfc_logs` | id, offline_id, card_id, bus_id, event_type, latitude, longitude, timestamp, synced, response_data | Store NFC tap events |
| `manual_tickets` | id, offline_id, bus_id, passenger_count, fare, latitude, longitude, notes, timestamp, synced, response_data | Store manual tickets |
| `bus_cache` | id, bus_data, route_data, updated_at | Cache bus/route info |

**Key Methods**:

```dart
class LocalDB {
  // NFC Logs
  Future<void> saveNFCLog(NFCEvent event);
  Future<List<NFCEvent>> getUnsyncedNFCLogs();
  Future<void> markNFCLogAsSynced(String offlineId, Map<String, dynamic> response);
  
  // Manual Tickets
  Future<void> saveManualTicket(ManualTicket ticket);
  Future<List<ManualTicket>> getUnsyncedTickets();
  Future<void> markTicketAsSynced(String offlineId, Map<String, dynamic> response);
  
  // Bus Cache
  Future<void> cacheBusInfo(BusInfo busInfo);
  Future<BusInfo?> getCachedBusInfo();
}
```

**Database Initialization** (Platform-Specific):

```dart
// In main.dart
void main() {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb; // IndexedDB for web
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
             defaultTargetPlatform == TargetPlatform.linux ||
             defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit(); // FFI for desktop
    databaseFactory = databaseFactoryFfi;
  }
  // Android/iOS use default sqflite (no initialization needed)
}
```

### NFCService

**Purpose**: Handle NFC tag reading and event creation.

**Supported NFC Formats**:
1. **NTAG216 with NDEF**: Reads text records containing "RC-XXXXX"
2. **Tag Identifier Fallback**: Uses tag handle/identifier if NDEF fails

**Card ID Normalization**:
- Trims whitespace from card ID
- Preserves original case (backend may be case-sensitive)
- Fallback to lowercase if original case fails

**Key Methods**:

```dart
class NFCService {
  Future<bool> isAvailable();              // Check NFC hardware
  Future<String?> readNFCTag();             // Read card ID
  Future<void> processTapIn(String cardId); // Process tap-in
  Future<void> processTapOut(String cardId); // Process tap-out
}
```

**NFC Reading Flow**:

```dart
Future<String?> readNFCTag() async {
  final completer = Completer<String?>();
  
  await NfcManager.instance.startSession(
    onDiscovered: (NfcTag tag) async {
      // 1. Try NDEF reading (for NTAG216)
      if (tag.ndef != null) {
        final ndefMessage = await tag.ndef.read();
        // Extract "RC-XXXXX" from text records
        nfcId = extractCardIdFromNDEF(ndefMessage);
      }
      
      // 2. Fallback to tag identifier
      if (nfcId == null) {
        nfcId = tag.handle?.toString() ?? tag.id;
      }
      
      // 3. Normalize (trim, preserve case)
      nfcId = nfcId?.trim();
      
      completer.complete(nfcId);
    },
  );
  
  return completer.future.timeout(Duration(seconds: 30));
}
```

### SyncService

**Purpose**: Orchestrate offline event synchronization.

**Sync Strategy**:
- Batches events (max 50 per request)
- Handles duplicate prevention (using `offline_id`)
- Retries failed events
- Updates sync status in LocalDB

**Key Methods**:

```dart
class SyncService {
  Future<SyncResult> syncAllEvents();           // Sync all unsynced events
  Future<SyncResult> syncNFCEvents();          // Sync only NFC events
  Future<SyncResult> syncManualTickets();       // Sync only tickets
}
```

---

## State Management

### Riverpod Providers

| Provider | Type | Purpose |
|----------|------|---------|
| `authProvider` | `StateNotifierProvider<AuthNotifier, AsyncValue<AuthUser?>>` | Authentication state |
| `busProvider` | `FutureProvider<BusInfo?>` | Assigned bus information |
| `nfcLogsProvider` | `StateNotifierProvider<NfcLogsNotifier, List<NFCEvent>>` | NFC event logs |
| `syncProvider` | `StateNotifierProvider<SyncNotifier, SyncState>` | Sync status |
| `todayReportProvider` | `FutureProvider<ReportResponse?>` | Today's daily report |
| `busBookingsProvider` | `FutureProvider.family<BusBookings?, String>` | Bus bookings (by busId) |

### Provider Usage Example

```dart
// In a widget
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch bus provider (auto-rebuilds on change)
    final busAsync = ref.watch(busProvider);
    
    return busAsync.when(
      data: (busInfo) => BusInfoWidget(busInfo),
      loading: () => LoadingWidget(),
      error: (err, stack) => ErrorWidget(err),
    );
  }
}

// Update state
void _refreshBus() {
  ref.read(busProvider.notifier).refresh();
}
```

---

## Dashboard Data Flow

### Passenger Count Calculation

The dashboard calculates total passengers from multiple sources with **real-time updates**:

1. **Bookings Data** (from `/supervisor-bookings` endpoint) - **PRIORITY SOURCE**
   - Uses `bookedSeats` from API response (most reliable)
   - Falls back to counting confirmed/booked bookings from array
2. **Report Data** (from `/supervisor-reports` endpoint) - Fallback if bookings unavailable
3. **Manual Tickets** (sum of `passengerCount` from today's manual tickets) - Added to total

**Real-Time Calculation Logic**:

```dart
// Synchronous calculation from bookings (already loaded via ref.watch)
int _calculatePassengersFromBookings(BusBookings? bookings, int reportPassengerCount) {
  if (bookings == null) {
    return reportPassengerCount; // Fallback to report
  }
  
  // PRIORITY: Use bookedSeats from API first (most reliable)
  final bookedSeatsCount = bookings.bookedSeats;
  if (bookedSeatsCount > 0) {
    return bookedSeatsCount; // Most accurate source
  }
  
  // Fallback: Count from bookings array if bookedSeats is 0
  if (bookings.bookings.isNotEmpty) {
    final confirmedBookings = bookings.bookings.where((b) {
      final status = b.status.toLowerCase();
      return status == 'confirmed' || status == 'booked';
    }).length;
    return confirmedBookings > 0 ? confirmedBookings : reportPassengerCount;
  }
  
  return reportPassengerCount;
}

// In dashboard build method - watches bookings provider for real-time updates
Widget _buildStatsRow(AsyncValue<ReportResponse?> reportAsync, BusInfo? busInfo) {
  return reportAsync.when(
    data: (report) {
      final bookingsAsync = ref.watch(busBookingsProvider(busInfo.id)); // Real-time watching
      
      return bookingsAsync.when(
        data: (bookings) {
          // Calculate synchronously from bookings
          int calculatedPassengers = _calculatePassengersFromBookings(bookings, report?.passengerCount ?? 0);
          
          // Add manual tickets asynchronously
          return FutureBuilder<Map<String, int>>(
            future: _getManualTicketStats(busInfo.id),
            builder: (context, snapshot) {
              final manualStats = snapshot.data ?? {'passengers': 0};
              calculatedPassengers += manualStats['passengers'] ?? 0;
              
              return StatCard(
                label: 'Passengers',
                value: calculatedPassengers.toString(),
              );
            },
          );
        },
        // ... loading/error states
      );
    },
  );
}
```

**Key Improvements**:
- **Real-time Updates**: Uses `ref.watch()` to automatically rebuild when bookings change
- **Priority-Based**: Prioritizes `bookedSeats` from API (most reliable), then bookings array, then report
- **Synchronous Calculation**: Bookings are calculated synchronously (no FutureBuilder delay)
- **Automatic Refresh**: Dashboard refreshes bookings every 10 seconds when bus is assigned

### Trip Progress Calculation

Trip progress is calculated from actual bus location and route stops:

1. **Get Bus Location**: From `busInfo.currentLocation` (lat/lng)
2. **Get Route Stops**: From `busInfo.route.stops` (sorted by order)
3. **Find Closest Stop**: Calculate distance to each stop using Haversine formula
4. **Calculate Progress**: `(currentStopIndex + 1) / totalStops`

**Progress Calculation Code**:

```dart
Widget _buildTripProgressCard(BusInfo? busInfo) {
  final stops = busInfo?.route?.stops ?? [];
  final totalStops = stops.length;
  
  // Find closest stop to bus location
  int currentStopIndex = 0;
  if (busInfo?.currentLocation != null && stops.isNotEmpty) {
    final busLat = busInfo.currentLocation!['lat'];
    final busLng = busInfo.currentLocation!['lng'];
    
    double minDistance = double.infinity;
    for (int i = 0; i < stops.length; i++) {
      final distance = _calculateDistance(busLat, busLng, stops[i].latitude, stops[i].longitude);
      if (distance < minDistance) {
        minDistance = distance;
        currentStopIndex = i;
      }
    }
  }
  
  final progress = totalStops > 0 ? (currentStopIndex + 1) / totalStops : 0.0;
  final progressPercent = (progress * 100).toInt();
  
  // Display: "$progressPercent% Complete" and "$currentStop / $totalStops Stops"
}
```

### Bus Capacity

**Fixed Capacity**: All buses use **40 seats** to match the webapp, regardless of backend response.

- BusInfo model always sets `capacity: 40`
- BusBookings model always uses `totalSeats: 40`
- Manual ticket seat selection shows seats 1-40

### Real-Time Data Updates

**Automatic Refresh Intervals**:
- **Bus Assignment**: Every 5 seconds when no bus assigned, 15 seconds when bus assigned
- **Bookings**: Every 10 seconds when bus is assigned (via `busBookingsProvider`)
- **Reports**: Refreshed on pull-to-refresh, date change, and after manual ticket issuance
- **Dashboard Stats**: Automatically updates when bookings provider changes (via `ref.watch()`)

**Refresh Triggers**:
- Pull-to-refresh gesture on dashboard
- Manual ticket issuance (invalidates bookings and report providers)
- Auto-refresh timer (periodic updates)
- Screen load (initial refresh)

---

## NFC Integration

### Android Configuration

**AndroidManifest.xml**:

```xml
<manifest>
  <uses-permission android:name="android.permission.NFC" />
  <uses-feature android:name="android.hardware.nfc" android:required="false" />
  
  <application>
    <!-- NFC Intent Filters -->
    <activity android:name=".MainActivity">
      <intent-filter>
        <action android:name="android.nfc.action.NDEF_DISCOVERED" />
        <category android:name="android.intent.category.DEFAULT" />
      </intent-filter>
      <intent-filter>
        <action android:name="android.nfc.action.TAG_DISCOVERED" />
        <category android:name="android.intent.category.DEFAULT" />
      </intent-filter>
      <intent-filter>
        <action android:name="android.nfc.action.TECH_DISCOVERED" />
        <category android:name="android.intent.category.DEFAULT" />
      </intent-filter>
      
      <!-- NFC Tech Filter -->
      <meta-data
        android:name="android.nfc.action.TECH_DISCOVERED"
        android:resource="@xml/nfc_tech_filter" />
    </activity>
  </application>
</manifest>
```

**nfc_tech_filter.xml**:

```xml
<resources>
  <tech-list>
    <tech>android.nfc.tech.NfcA</tech>
    <tech>android.nfc.tech.NfcB</tech>
    <tech>android.nfc.tech.NfcF</tech>
    <tech>android.nfc.tech.NfcV</tech>
    <tech>android.nfc.tech.Ndef</tech>
  </tech-list>
</resources>
```

**MainActivity.kt** (Handle NFC when app is running):

```kotlin
class MainActivity: FlutterActivity() {
  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    if (NfcAdapter.ACTION_TAG_DISCOVERED == intent.action) {
      // Handle NFC intent
    }
  }
}
```

### iOS Configuration

**Info.plist**:

```xml
<key>NFCReaderUsageDescription</key>
<string>Used to read CityGo NFC Rapid Cards for tap-in/tap-out.</string>
```

**Xcode Capabilities**:
- Enable "Near Field Communication Tag Reading"

### NFC Card Format

**NTAG216 Format**:
- NDEF Text Record: `"RC-198b42de"` (case may vary)
- Card ID Pattern: `RC-[A-Fa-f0-9]{8}`

**Reading Process**:
1. Start NFC session with polling options (ISO14443, ISO15693, ISO18092)
2. Wait for tag discovery (30-second timeout using `Completer` pattern)
3. Try reading NDEF records first
4. Extract card ID from text records (look for "RC-" prefix)
5. Fallback to tag identifier if NDEF fails
6. Normalize card ID (trim whitespace, preserve case)
7. Complete `Completer` with card ID or `null` on timeout

**Card Registration Check**:

The app includes a feature to check if an NFC card is registered without processing a tap-in/tap-out:

```dart
// In NFC Reader Screen
Future<void> _checkCardRegistration() async {
  // 1. Read NFC tag
  final cardId = await nfcService.readNFCTag();
  
  // 2. Check registration via API
  final registeredCard = await apiService.checkCardRegistration(cardId);
  
  // 3. Show user info if registered, or "not registered" dialog
  if (registeredCard != null) {
    _showCardInfoBottomSheet(registeredCard); // Shows passenger name, balance, status, etc.
  } else {
    _showCardNotRegisteredDialog(cardId);
  }
}
```

**API Endpoints for Card Check**:
- `/cards/{cardId}`
- `/registered-cards/{cardId}`
- `/nfc-cards/{cardId}`
- `/passenger-cards/{cardId}`

The API tries multiple endpoints and falls back to lowercase card ID if original case fails.

---

## Offline Sync Mechanism

### Sync Strategy

1. **Event Queue**: All offline events stored in LocalDB with `synced = 0`
2. **Batch Processing**: Sync up to 50 events per API call
3. **Duplicate Prevention**: Use `offline_id` (UUID) to prevent duplicates
4. **Retry Logic**: Failed events remain unsynced for retry
5. **Status Update**: Mark events as synced after successful API response

### Sync Endpoint

**POST /nfc-sync**

Request Body:
```json
{
  "events": [
    {
      "offline_id": "uuid-1",
      "card_id": "RC-198b42de",
      "bus_id": "bus-123",
      "event_type": "tap_in",
      "latitude": 40.7128,
      "longitude": -74.0060,
      "timestamp": "2024-01-15T10:30:00Z"
    }
  ]
}
```

Response:
```json
{
  "synced_count": 1,
  "failed_count": 0,
  "errors": []
}
```

### Sync Code Example

```dart
Future<SyncResult> syncAllEvents() async {
  // 1. Get unsynced events
  final nfcEvents = await _localDB.getUnsyncedNFCLogs();
  final tickets = await _localDB.getUnsyncedTickets();
  
  // 2. Batch events (max 50)
  final batches = _batchEvents(nfcEvents, 50);
  
  int syncedCount = 0;
  int failedCount = 0;
  
  for (final batch in batches) {
    try {
      // 3. Call API
      final response = await _apiService.syncEvents(batch);
      
      // 4. Mark as synced
      for (final event in batch) {
        await _localDB.markNFCLogAsSynced(
          event.offlineId,
          response.data,
        );
        syncedCount++;
      }
    } catch (e) {
      failedCount += batch.length;
    }
  }
  
  return SyncResult(
    syncedCount: syncedCount,
    failedCount: failedCount,
  );
}
```

---

## API Integration

### API Base URL

```
https://ziouzevpbnigvwcacpqw.supabase.co/functions/v1
```

### Endpoints

| Method | Endpoint | Purpose | Auth Required |
|--------|----------|---------|---------------|
| POST | `/supervisor-auth` | Login | No |
| GET | `/supervisor-bus` | Get assigned bus | Yes |
| POST | `/nfc-tap-in` | NFC tap-in | Yes |
| POST | `/nfc-tap-out` | NFC tap-out | Yes |
| POST | `/manual-ticket` | Issue manual ticket | Yes |
| GET | `/cards/{cardId}` or `/registered-cards/{cardId}` | Check card registration | Yes |
| GET | `/supervisor-bookings?bus_id={id}&date={date}` | Get bus bookings | Yes |
| POST | `/nfc-sync` | Sync offline events | Yes |
| GET | `/supervisor-reports?date=YYYY-MM-DD` | Daily reports | Yes |

### Request Headers

```dart
{
  'apikey': SUPABASE_API_KEY,           // Always required
  'Authorization': 'Bearer <JWT>',      // Required for authenticated endpoints
  'Content-Type': 'application/json',
}
```

### Error Handling

| Status Code | Handling |
|-------------|----------|
| 200 | Success |
| 400 | Bad Request - Show error message |
| 401 | Unauthorized - Clear auth, redirect to login |
| 404 | Not Found - Show "Card not registered" or "Bus not assigned" |
| 500 | Server Error - Retry or show error |

**Error Handling Code**:

```dart
String _handleError(DioException error) {
  if (error.response != null) {
    final statusCode = error.response!.statusCode;
    final data = error.response!.data;
    
    if (statusCode == 404) {
      if (data['message']?.contains('card') ?? false) {
        return 'Card not registered';
      } else if (data['message']?.contains('bus') ?? false) {
        return 'Bus not assigned';
      }
    }
    
    return data['message'] ?? 'An error occurred';
  }
  
  return 'Network error. Please check your connection.';
}
```

---

## Database Schema

### Tables

#### nfc_logs

```sql
CREATE TABLE nfc_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  offline_id TEXT UNIQUE NOT NULL,      -- UUID for duplicate prevention
  card_id TEXT NOT NULL,                -- RC-XXXXX format
  bus_id TEXT NOT NULL,
  event_type TEXT NOT NULL,             -- 'tap_in' or 'tap_out'
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  timestamp INTEGER NOT NULL,           -- Unix timestamp
  synced INTEGER DEFAULT 0,            -- 0 = unsynced, 1 = synced
  response_data TEXT                    -- JSON response from API
);

CREATE INDEX idx_nfc_logs_synced ON nfc_logs(synced);
CREATE INDEX idx_nfc_logs_offline_id ON nfc_logs(offline_id);
```

#### manual_tickets

```sql
CREATE TABLE manual_tickets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  offline_id TEXT UNIQUE NOT NULL,
  bus_id TEXT NOT NULL,
  passenger_count INTEGER NOT NULL,
  fare REAL NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  notes TEXT,
  seat_number INTEGER,           -- Selected seat (1-40, optional)
  timestamp INTEGER NOT NULL,
  synced INTEGER DEFAULT 0,
  response_data TEXT
);

CREATE INDEX idx_manual_tickets_synced ON manual_tickets(synced);
CREATE INDEX idx_manual_tickets_offline_id ON manual_tickets(offline_id);
```

#### bus_cache

```sql
CREATE TABLE bus_cache (
  id INTEGER PRIMARY KEY,
  bus_data TEXT NOT NULL,               -- JSON BusInfo
  route_data TEXT,                      -- JSON Route data
  updated_at INTEGER NOT NULL
);
```

---

## UI Components

### Reusable Widgets

#### CityGoCard

```dart
class CityGoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  
  // Dark theme card with rounded corners
}
```

#### PrimaryButton

```dart
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  
  // Primary action button with loading state
}
```

#### StatCard

```dart
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  
  // Statistics display card
}
```

#### NFCCircularButton

```dart
class NFCCircularButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isScanning;
  
  // Large circular NFC scan button
}
```

#### ProfileScreen

```dart
class ProfileScreen extends ConsumerWidget {
  // Displays user profile information
  // - User avatar with initials
  // - Name, email, role, user ID
  // - Accessible from Settings screen
}
```

#### HelpSupportScreen

```dart
class HelpSupportScreen extends StatelessWidget {
  // Comprehensive help and support section
  // - FAQ with expandable questions/answers
  // - Contact Developer button (opens Linktree URL)
  // - App version information
  // - Accessible from Settings screen
}
```

---

## Platform-Specific Configuration

### Android

**Minimum SDK**: 21 (Android 5.0)

**Permissions**:
- `INTERNET`
- `ACCESS_FINE_LOCATION`
- `NFC`

**Build Configuration** (`android/app/build.gradle.kts`):
```kotlin
android {
  compileSdk = 34
  defaultConfig {
    minSdk = 21
    targetSdk = 34
  }
}
```

### iOS

**Minimum Version**: iOS 11.0

**Capabilities**:
- Near Field Communication Tag Reading

**Info.plist Keys**:
- `NSLocationWhenInUseUsageDescription`
- `NFCReaderUsageDescription`
- `GMSApiKey` (Google Maps)

### Web

**Database**: Uses IndexedDB via `sqflite_common_ffi_web`

**Limitations**:
- NFC not supported (hardware limitation)
- Location requires HTTPS

### Desktop (Windows/Linux/macOS)

**Database**: Uses FFI implementation (`sqflite_common_ffi`)

**Limitations**:
- NFC not supported (hardware limitation)

---

## Build & Deployment

### Development Build

```bash
# Android
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# iOS
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY -d <device-id>
```

### Production Build

#### Android APK

```bash
flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

**Output**: `build/app/outputs/flutter-apk/app-release.apk`

#### Android App Bundle (AAB)

```bash
flutter build appbundle --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

**Output**: `build/app/outputs/bundle/release/app-release.aab`

#### iOS

```bash
flutter build ios --release --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

**Note**: Requires Xcode and Apple Developer account for signing.

### Windows Developer Mode

For Windows builds, enable Developer Mode (required for symlink support):

1. Open Settings → Update & Security → For developers
2. Enable "Developer Mode"
3. Restart if prompted

---

## Troubleshooting

### Common Issues

#### 1. NFC Not Reading

**Symptoms**: App cannot read NFC card, but phone's system can.

**Solutions**:
- Ensure NFC is enabled in device settings
- Check AndroidManifest.xml has NFC permissions
- Verify `nfc_tech_filter.xml` exists
- Test on physical device (emulators don't support NFC)
- Check card format (should contain "RC-XXXXX" in NDEF)

#### 2. "Card not registered" Error

**Symptoms**: Card is registered in backend but app shows error.

**Solutions**:
- Check card ID format (case-sensitive, no whitespace)
- Verify card ID in backend matches exactly
- Check API logs for exact card ID being sent
- Try lowercase version (fallback mechanism)

#### 3. Black Screen After Login

**Symptoms**: Login succeeds but dashboard is blank.

**Solutions**:
- Check bus assignment (GET /supervisor-bus)
- Verify JWT token is stored correctly
- Check console logs for API errors
- Ensure `busProvider` is being watched in dashboard

#### 4. Database Initialization Error

**Symptoms**: `SqfliteFfiException` on Android/iOS.

**Solutions**:
- Ensure `sqfliteFfiInit()` is NOT called on Android/iOS
- Only use FFI initialization for desktop/web platforms
- Check `main.dart` platform detection logic

#### 5. Map Tiles Not Showing

**Symptoms**: Google Maps shows blank/gray tiles.

**Solutions**:
- Verify Google Maps API key is set correctly
- Check API key has Maps SDK enabled
- Ensure API key is not restricted (or restrictions allow your app)
- Check AndroidManifest.xml has correct API key

#### 6. Offline Sync Not Working

**Symptoms**: Events remain unsynced after connectivity restored.

**Solutions**:
- Check internet connectivity (use ConnectivityPlus)
- Verify sync endpoint is accessible
- Check LocalDB for unsynced events (`synced = 0`)
- Review API response for errors
- Ensure `offline_id` is unique (UUID)

### Debug Logging

Enable verbose logging:

```dart
// In ApiService
print('📡 API Request: ${options.method} ${options.uri}');
print('📡 Request Data: ${options.data}');
print('📡 Response: ${response.statusCode} ${response.data}');

// In NFCService
print('📱 NFC Tag Discovered: ${tag.id}');
print('📱 Card ID Extracted: $nfcId');

// In LocalDB
print('💾 Saving NFC log: ${event.offlineId}');
print('💾 Synced status: ${event.synced}');
```

---

## Manual Ticket Feature

### Seat Selection

The manual ticket screen includes a seat selection feature:

- **Total Seats**: Always 40 (matches webapp)
- **Available Seats**: Calculated from bookings (excludes booked seats)
- **Visual Indicators**:
  - Available seats: Dark background, clickable
  - Selected seat: Green background with white text
  - Booked seats: Grayed out, not clickable
- **Optional**: Seat selection is optional (can issue ticket without seat)

**Seat Selection Code**:

```dart
Widget _buildSeatSelection(List<int> availableSeats, int totalSeats) {
  return Wrap(
    children: List.generate(totalSeats, (index) {
      final seatNum = index + 1;
      final isAvailable = availableSeats.contains(seatNum);
      final isSelected = _selectedSeat == seatNum;
      
      return GestureDetector(
        onTap: isAvailable ? () => setState(() {
          _selectedSeat = isSelected ? null : seatNum;
        }) : null,
        child: Container(
          // Visual styling based on availability and selection
        ),
      );
    }),
  );
}
```

### Manual Ticket Data Flow

```
┌─────────────────┐
│ User Fills Form │
│ (Passengers,    │
│  Fare, Seat)    │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Get GPS         │
│ Location        │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│ Try API Call    │
│ (Online)        │
└──────┬──────────┘
       │
   ┌───┴───┐
   │       │
   ▼       ▼
┌─────┐ ┌──────────┐
│Success│ │  Error   │
└───┬──┘ └────┬─────┘
    │         │
    │         ▼
    │    ┌──────────┐
    │    │ Save to  │
    │    │ LocalDB  │
    │    │ (Offline)│
    │    └────┬─────┘
    │         │
    └─────────┘
         │
         ▼
    ┌──────────┐
    │ Show     │
    │ Success  │
    └──────────┘
```

---

## Profile & Help Support

### Profile Screen

The Profile screen displays user information and details:

**Features**:
- User avatar with initials (generated from name or email)
- User name and email display
- Role information (Supervisor, Admin, etc.)
- User ID display
- Accessible from Settings screen via navigation

**Navigation**:
```dart
// In Settings screen
ListTile(
  leading: Icon(Icons.person),
  title: Text('Profile'),
  onTap: () => Navigator.pushNamed(context, '/profile'),
)
```

**Implementation**:
- Uses `authProvider` to get current user data
- Displays user information in a card-based layout
- Handles null/empty values gracefully

### Help & Support Screen

The Help & Support screen provides comprehensive assistance:

**Features**:
- **FAQ Section**: Expandable questions and answers covering:
  - How to start a trip
  - Why bookings not showing
  - How to issue a manual ticket
  - NFC card reading issues
- **Contact Section**:
  - Contact Support (placeholder for future implementation)
  - Contact Developer button (opens Linktree URL: https://linktr.ee/abrarlajim)
- **App Information**: Displays app version

**URL Launcher Integration**:
```dart
import 'package:url_launcher/url_launcher.dart';

Future<void> _contactDeveloper() async {
  final url = Uri.parse('https://linktr.ee/abrarlajim');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
```

**Navigation**:
```dart
// In Settings screen
ListTile(
  leading: Icon(Icons.help_outline),
  title: Text('Help & Support'),
  onTap: () => Navigator.pushNamed(context, '/help-support'),
)
```

**Route Configuration**:
```dart
// In main.dart
MaterialApp(
  routes: {
    '/profile': (context) => const ProfileScreen(),
    '/help-support': (context) => const HelpSupportScreen(),
  },
)
```

---

## Reports Screen

### Features

- **Date Selection**: Pick any date to view reports
- **Force Refresh**: Refresh button and pull-to-refresh with cache-busting
- **Statistics Display**:
  - CO₂ Saved
  - Total Distance
  - Total Fare
  - Trip Count
  - Passenger Count
- **Hourly Activity**: Placeholder for future chart implementation

### Refresh Mechanism

The reports screen includes multiple refresh mechanisms:

1. **Manual Refresh**: Tap refresh icon in app bar
2. **Pull-to-Refresh**: Swipe down on the screen
3. **Date Change**: Automatically refreshes when date is changed
4. **Cache-Busting**: Adds timestamp parameter (`_t`) to prevent HTTP caching
5. **HTTP Headers**: Sets `Cache-Control: no-cache` headers

**Refresh Implementation**:

```dart
Future<ReportResponse> _fetchReport(DateTime date) async {
  // Force refresh with cache-busting
  final report = await apiService.getReport(
    date: date, 
    forceRefresh: true, // Adds _t timestamp parameter
  );
  return report;
}
```

---

## Testing

### Test Credentials

| Email | Password | Role |
|-------|----------|------|
| `testsup@gmail.com` | `123456` | Supervisor |
| `ts@gmail.com` | `123456` | Supervisor |

### Test NFC Cards

- `RC-d4a290fc`
- `RC-198b42de`
- `RC-47b8dbab`

### Test Flow

1. **Login**: Use test credentials
2. **Dashboard**: Verify bus assignment, map rendering, and real-time stats
3. **NFC Scan**: Use test cards or "Simulate Tap-In" button
4. **Card Check**: Use "Check Card Registration" button to verify card info
5. **Manual Ticket**: Fill form, select seat (optional), and issue ticket
6. **Bookings**: View seat map and verify booked seats
7. **Offline Mode**: Turn off internet, create events, then sync
8. **Reports**: View daily reports with statistics, test refresh functionality
9. **Trip Progress**: Verify progress updates based on bus location

---

## Security Considerations

1. **JWT Storage**: Uses Flutter Secure Storage (encrypted)
2. **API Key**: Supabase anon key is safe for mobile (row-level security)
3. **HTTPS**: All API calls use HTTPS
4. **Token Expiry**: Backend handles JWT expiry (401 response)
5. **Card ID**: Card IDs are not sensitive (public identifiers)

---

## Recent Updates

### Version Updates

#### Card Registration Check (Latest)
- Added "Check Card Registration" button in NFC reader screen
- Displays passenger information if card is registered
- Shows "Card not registered" dialog if not found
- Supports multiple API endpoints with fallback

#### Seat Selection in Manual Tickets (Latest)
- Added seat selection grid (1-40 seats)
- Visual indicators for available/booked/selected seats
- Seat number included in manual ticket API request
- Database schema updated to store seat number

#### Enhanced Dashboard Statistics (Latest)
- Passenger count now includes bookings and manual tickets
- Real-time trip progress calculated from bus location
- Removed hardcoded progress values
- Accurate passenger counting across all sources

#### Reports Refresh (Latest)
- Added force refresh mechanism with cache-busting
- HTTP cache-control headers to prevent stale data
- Refresh button in app bar
- Pull-to-refresh support

#### Bus Capacity Fix (Latest)
- Fixed to always use 40 seats (matches webapp)
- Overrides backend capacity value if different
- Consistent across bookings, manual tickets, and seat selection

#### Real-Time Dashboard Passenger Count (Latest)
- **Prioritizes `bookedSeats` from API** (most reliable source)
- **Real-time updates** via `ref.watch()` on bookings provider
- **Synchronous calculation** from bookings (no FutureBuilder delay)
- **Automatic refresh** every 10 seconds when bus is assigned
- Falls back to counting bookings array, then report data
- Adds manual ticket passengers to total
- Enhanced logging for debugging passenger count calculation

#### Profile & Help & Support Screens (Latest)
- **Profile Screen**: Displays user information (name, email, role, user ID)
  - Shows user avatar with initials
  - Accessible from Settings screen
- **Help & Support Screen**: Comprehensive help section
  - FAQ section with expandable questions/answers
  - Contact Developer button (opens Linktree URL: https://linktr.ee/abrarlajim)
  - App version information
  - Accessible from Settings screen
- **URL Launcher Integration**: Uses `url_launcher` package to open external links

---

## Future Enhancements

- [ ] Push notifications for sync status
- [ ] Real-time bus location tracking (enhanced)
- [ ] QR code ticket scanning
- [ ] Multi-language support
- [ ] Dark/Light theme toggle
- [ ] Export reports to PDF
- [ ] Biometric authentication
- [ ] Offline map caching
- [ ] Hourly activity charts in reports
- [ ] Seat map visualization in dashboard

---

## License

[Your License Here]

---

## Contact & Support

For issues or questions, please contact the development team or create an issue in the repository.

