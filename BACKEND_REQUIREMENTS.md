# CityGo Supervisor App - Backend Requirements

This document outlines all backend endpoints and requirements needed for the Flutter Supervisor app.

## Table of Contents
1. [Authentication](#authentication)
2. [Bus & Route Management](#bus--route-management)
3. [NFC Operations](#nfc-operations)
4. [Manual Tickets](#manual-tickets)
5. [Bus Bookings](#bus-bookings)
6. [Registered Cards](#registered-cards)
7. [Reports](#reports)
8. [Offline Sync](#offline-sync)

---

## Authentication

### POST `/supervisor-auth`
**Status**: ✅ Already implemented

**Request:**
```json
{
  "email": "supervisor@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "success": true,
  "token": "jwt_token_here",
  "user": {
    "id": "user-uuid",
    "email": "supervisor@example.com",
    "name": "Supervisor Name",
    "role": "supervisor"
  }
}
```

---

## Bus & Route Management

### GET `/supervisor-bus`
**Status**: ✅ Fixed - Returns stops with proper format, skips invalid coordinates

**Response Format:**
```json
{
  "success": true,
  "is_active": true,
  "bus": {
    "id": "bus-uuid",
    "bus_number": "DHK-BUS-102",
    "capacity": 40,
    "status": "active",
    "route_id": "route-uuid"
  },
  "route": {
    "id": "route-uuid",
    "name": "Route 42",
    "route_number": "42",
    "distance": 25.5,
    "base_fare": 20.0,
    "fare_per_km": 1.5,
    "stops": [
      {
        "id": "stop-uuid-1",
        "name": "Gulshan Bus Stop",
        "latitude": 23.7947,
        "longitude": 90.4144,
        "order": 1
      },
      {
        "id": "stop-uuid-2",
        "name": "Banani Bus Stop",
        "latitude": 23.8000,
        "longitude": 90.4200,
        "order": 2
      },
      {
        "id": "stop-uuid-3",
        "name": "Uttara Bus Stop",
        "latitude": 23.8700,
        "longitude": 90.4000,
        "order": 3
      }
    ]
  }
}
```

**Requirements:**
- ✅ Must return bus assigned to supervisor
- ✅ Must include route information
- ✅ **FIXED**: Route now includes `stops` array with proper format
- ✅ Each stop has: `id`, `name`, `latitude`, `longitude`, `order`
- ✅ **IMPROVED**: Backend now skips stops with invalid/missing coordinates (not defaulting to 0)
- ✅ Stops are sorted by `order` field
- ✅ Backend logs skipped stops for debugging

**Why this is needed:**
- Map polyline requires at least 2 stops with valid coordinates
- Without stops, the map shows empty/water area
- Stops are used to calculate route center and zoom level

---

## NFC Operations

### POST `/nfc-tap-in`
**Status**: ✅ Should be implemented

**Request:**
```json
{
  "card_id": "RC-d4a290fc",
  "bus_id": "bus-uuid",
  "location": {
    "lat": 23.7947,
    "lng": 90.4144
  },
  "offline_id": "optional-offline-id"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Tap-in successful",
  "name": "John Doe",
  "card_id": "RC-d4a290fc",
  "balance": 150.50,
  "fare": null,
  "co2_saved": null
}
```

**Backend Requirements:**
- Validate card exists and is registered
- Check card balance (should have minimum balance)
- Record tap-in with:
  - Card ID
  - Bus ID
  - Location (lat/lng)
  - Timestamp
  - Supervisor ID (from JWT)
- Return passenger name and current balance
- **Do NOT charge fare yet** (fare calculated on tap-out)

---

### POST `/nfc-tap-out`
**Status**: ✅ Should be implemented

**Request:**
```json
{
  "card_id": "RC-d4a290fc",
  "bus_id": "bus-uuid",
  "location": {
    "lat": 23.8000,
    "lng": 90.4200
  },
  "offline_id": "optional-offline-id"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Tap-out successful. Fare deducted.",
  "name": "John Doe",
  "card_id": "RC-d4a290fc",
  "fare": 25.50,
  "balance": 125.00,
  "co2_saved": 0.5
}
```

**Backend Requirements:**
- Find matching tap-in record for this card and bus
- Calculate distance between tap-in and tap-out locations
- Calculate fare using route pricing:
  ```javascript
  const route = await getRouteForBus(busId);
  const distance = calculateDistance(tapInLocation, tapOutLocation);
  const fare = route.baseFare + (distance * route.farePerKm);
  
  // Apply minimum/maximum fare limits if needed
  const finalFare = Math.max(route.baseFare, Math.min(fare, maxFare));
  ```
- Check if card has sufficient balance
- Deduct fare from card balance
- Update card balance in database
- Record tap-out with fare information
- Calculate CO₂ saved (optional, based on distance)
- Return calculated fare, updated balance, and CO₂ saved

**Fare Calculation Logic:**
1. Get route for the bus
2. Calculate distance (Haversine formula or Google Directions API)
3. Apply formula: `baseFare + (distance × farePerKm)`
4. Apply any discounts or limits
5. Deduct from balance
6. Log transaction

---

## Manual Tickets

### POST `/supervisor-manual-ticket` or `/manual-ticket`
**Status**: ⚠️ Needs implementation

**Request:**
```json
{
  "bus_id": "bus-uuid",
  "passenger_count": 2,
  "fare": 50.00,
  "latitude": 23.7947,
  "longitude": 90.4144,
  "issued_at": "2024-01-15T08:00:00Z",
  "notes": "Optional notes",
  "offline_id": "optional-offline-id",
  "ticket_type": "single",
  "payment_method": "cash"
}
```

**Response:**
```json
{
  "success": true,
  "ticket_id": "ticket-uuid",
  "message": "Ticket issued successfully"
}
```

**Backend Requirements:**
- Verify supervisor is assigned to the bus
- Validate supervisor role (from JWT)
- Record manual ticket with:
  - Bus ID
  - Supervisor ID (from JWT)
  - Passenger count
  - Fare amount
  - Location (lat/lng)
  - Timestamp
  - Payment method (cash)
  - Notes (optional)
- Return ticket ID
- Include in daily reports

---

## Bus Bookings

### GET `/supervisor-bookings`
**Status**: ✅ Already implemented by you

**Query Parameters:**
- `bus_id` (optional): Filter by bus ID
- `date` (optional): Filter by travel date (YYYY-MM-DD)

**Response:**
```json
{
  "success": true,
  "bus_id": "bus-uuid",
  "bus_number": "DHK-BUS-102",
  "total_seats": 40,
  "available_seats": 25,
  "booked_seats": 15,
  "bookings": [
    {
      "id": "booking-uuid",
      "bus_id": "bus-uuid",
      "seat_number": 1,
      "passenger_name": "John Doe",
      "card_id": "RC-d4a290fc",
      "status": "confirmed",
      "booked_at": "2024-01-15T08:00:00Z",
      "travel_date": "2024-01-15T10:00:00Z",
      "booking_type": "online",
      "fare": 25.50,
      "payment_status": "paid"
    }
  ]
}
```

**Backend Requirements:**
- ✅ Verify supervisor is assigned to the bus
- ✅ Filter bookings by assigned bus
- ✅ Return bookings with seat numbers
- ✅ Calculate stats (total, booked, available)
- ✅ Include passenger names and card IDs
- ✅ Support date filtering

**Note**: Status should be `"confirmed"` or `"booked"` - app normalizes `"confirmed"` to `"booked"`

---

## Registered Cards

### GET `/registered-cards`
**Status**: ✅ Already implemented

**Response:**
```json
{
  "success": true,
  "cards": [
    {
      "card_id": "RC-d4a290fc",
      "passenger_name": "John Doe",
      "balance": 150.50,
      "status": "active",
      "registered_at": "2024-01-01T00:00:00Z",
      "last_used": "2024-01-15T08:00:00Z"
    }
  ]
}
```

**Backend Requirements:**
- ✅ Verify supervisor/admin role
- ✅ Return all registered cards
- ✅ Include balance, status, registration date
- ✅ Include last used timestamp from NFC logs

---

## Reports

### GET `/supervisor-reports`
**Status**: ✅ Should be implemented

**Query Parameters:**
- `date` (required): Date in YYYY-MM-DD format

**Response:**
```json
{
  "success": true,
  "date": "2024-01-15",
  "trip_count": 25,
  "passenger_count": 150,
  "total_fare": 3750.00,
  "total_distance": 125.5,
  "co2_saved": 25.1,
  "manual_tickets": 12,
  "hourly_breakdown": [
    {
      "hour": 8,
      "passengers": 20,
      "revenue": 500.00
    }
  ]
}
```

**Backend Requirements:**
- Filter by supervisor ID (from JWT)
- Filter by date
- Calculate statistics:
  - Total trips (completed tap-in/tap-out pairs)
  - Total passengers
  - Total fare collected
  - Total distance traveled
  - CO₂ saved
  - Manual tickets issued
- Optional: Hourly breakdown

---

## Offline Sync

### POST `/nfc-sync`
**Status**: ✅ Should be implemented

**Request:**
```json
{
  "events": [
    {
      "type": "nfc",
      "offline_id": "offline-uuid-1",
      "card_id": "RC-d4a290fc",
      "bus_id": "bus-uuid",
      "action": "tap_in",
      "latitude": 23.7947,
      "longitude": 90.4144,
      "timestamp": 1705312800000
    },
    {
      "type": "manual_ticket",
      "offline_id": "offline-uuid-2",
      "bus_id": "bus-uuid",
      "passenger_count": 2,
      "fare": 50.00,
      "latitude": 23.7947,
      "longitude": 90.4144,
      "timestamp": 1705313000000
    }
  ]
}
```

**Response:**
```json
{
  "success": true,
  "synced": 2,
  "failed": 0,
  "results": [
    {
      "offline_id": "offline-uuid-1",
      "success": true,
      "server_id": "server-uuid-1"
    },
    {
      "offline_id": "offline-uuid-2",
      "success": true,
      "server_id": "server-uuid-2"
    }
  ]
}
```

**Backend Requirements:**
- Process batch of offline events
- Handle duplicate detection (by offline_id)
- Process each event type:
  - `nfc`: Create tap-in/tap-out record
  - `manual_ticket`: Create manual ticket record
- Return sync results with server IDs
- Handle errors gracefully (don't fail entire batch)

---

## Database Schema Requirements

### Required Tables:

1. **buses**
   - `id`, `bus_number`, `capacity`, `route_id`, `supervisor_id`, `status`

2. **routes**
   - `id`, `name`, `route_number`, `distance`, `base_fare`, `fare_per_km`

3. **stops** (or embedded in routes)
   - `id`, `route_id`, `name`, `latitude`, `longitude`, `order`

4. **nfc_logs**
   - `id`, `card_id`, `bus_id`, `supervisor_id`, `tap_in_time`, `tap_out_time`, `tap_in_location`, `tap_out_location`, `fare`, `distance`, `created_at`

5. **profiles** (for cards)
   - `user_id`, `card_id`, `full_name`, `card_balance`, `created_at`, `updated_at`

6. **manual_tickets**
   - `id`, `bus_id`, `supervisor_id`, `passenger_count`, `fare`, `latitude`, `longitude`, `issued_at`, `notes`, `payment_method`

7. **bookings**
   - `id`, `bus_id`, `user_id`, `seat_no`, `booking_status`, `booking_date`, `travel_date`, `payment_method`, `payment_status`, `fare`

8. **user_roles**
   - `user_id`, `role` (supervisor/admin)

---

## Critical Issues to Fix

### 1. Route Stops Data ✅ **FIXED**
**Problem**: Map polyline not showing because route stops are missing or invalid

**Solution**: ✅ **IMPLEMENTED**
- ✅ `/supervisor-bus` now returns route with `stops` array
- ✅ Each stop has: `id`, `name`, `latitude`, `longitude`, `order`
- ✅ Stops are sorted by `order` field
- ⚠️ **Note**: Ensure stops in database have valid coordinates (not 0,0)
  - Backend code defaults to 0 if missing, but Flutter app filters these out
  - For best results, ensure all stops have real coordinates in database

**Implementation Details**:
- ✅ Backend formats stops array with proper structure
- ✅ **IMPROVED**: Skips stops with invalid/missing coordinates (no longer defaults to 0)
- ✅ Filters out invalid stops before returning
- ✅ Sorts stops by order before returning
- ✅ Logs skipped stops for debugging: `[supervisor-bus] Skipping stop with invalid coordinates: ...`
- ✅ Logs summary: `[supervisor-bus] Formatted X valid stops out of Y total`

### 2. Manual Ticket Endpoint ✅ **ALREADY WORKING**
**Status**: Endpoint exists and is working

### 3. NFC Fare Calculation ✅ **ALREADY IMPLEMENTED**
**Problem**: Need to ensure fare calculation works correctly

**Solution**:
- Verify `/nfc-tap-out` calculates fare correctly
- Use route `baseFare` and `farePerKm`
- Calculate distance between tap-in and tap-out
- Deduct from card balance
- Return fare and updated balance

---

## Testing Checklist

- [x] `/supervisor-bus` returns route with valid stops (2+ stops) ✅ **FIXED**
- [ ] `/nfc-tap-in` records location and timestamp
- [ ] `/nfc-tap-out` calculates fare and deducts balance
- [x] `/supervisor-manual-ticket` creates ticket record ✅ **WORKING**
- [x] `/supervisor-bookings` returns bookings for assigned bus ✅ **WORKING**
- [x] `/registered-cards` returns all cards ✅ **WORKING**
- [ ] `/supervisor-reports` calculates daily statistics
- [ ] `/nfc-sync` processes offline events

---

## API Response Format Standards

All endpoints should follow this format:

**Success:**
```json
{
  "success": true,
  "data": { ... }
}
```

**Error:**
```json
{
  "success": false,
  "error": "Error message here"
}
```

**Authentication:**
- All endpoints (except `/supervisor-auth`) require `Authorization: Bearer <token>` header
- Verify supervisor role from JWT token
- Verify supervisor is assigned to requested bus

---

## Notes

1. **Coordinates**: All latitude/longitude must be valid (not 0,0)
2. **Timestamps**: Use ISO 8601 format or Unix timestamps
3. **Currency**: All fare amounts in Taka (৳)
4. **Offline Support**: Endpoints should handle `offline_id` for sync
5. **Error Handling**: Return meaningful error messages
6. **CORS**: Enable CORS for all endpoints

