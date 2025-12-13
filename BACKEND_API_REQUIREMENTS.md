# Backend API Requirements for CityGo Supervisor App

## Base URL
```
https://ziouzevpbnigvwcacpqw.supabase.co/functions/v1
```

## Authentication
- All requests (except login) require JWT token in `Authorization: Bearer <token>` header
- API key required in `apikey` header: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

---

## 1. Manual Ticket Endpoint

### Current App Behavior
The app tries these endpoints in order:
1. `POST /supervisor-manual-ticket` ⭐ (Primary)
2. `POST /manual-ticket`
3. `POST /tickets`

### Request Payload
```json
{
  "bus_id": "uuid-string",
  "passenger_count": 1,
  "fare": 2.50,
  "timestamp": "2025-12-13T10:30:00.000Z",  // ⚠️ Backend expects 'timestamp' not 'issued_at'
  "notes": "Optional notes",
  "offline_id": "optional-offline-id",
  "seat_number": 5,  // ⚠️ IMPORTANT: When provided, should CREATE a booking
  "drop_stop_id": "stop-uuid",  // ⚠️ NEW: Drop-off stop ID for the booking
  "ticket_type": "single",
  "payment_method": "cash",
  "location": {
    "lat": 23.8103,
    "lng": 90.4125
  }
}
```

### Expected Response
```json
{
  "success": true,
  "ticket_id": "ticket-uuid",
  "message": "Ticket issued successfully",
  "qr_code": "optional-qr-code"
}
```

### ⚠️ CRITICAL: Seat Booking Behavior
**Current Issue**: When `seat_number` is provided, the backend should:
1. ✅ **CREATE a booking** for that seat (not release/unbook it)
2. ✅ Mark the seat as `booked` or `occupied` status
3. ✅ Return the booking in the response so the app can refresh

**Expected Backend Logic**:
```sql
-- When seat_number is provided:
INSERT INTO bookings (
  bus_id, 
  route_id,
  seat_no,  -- Note: Backend uses 'seat_no' not 'seat_number'
  user_id,  -- Use supervisor_id as proxy user
  drop_stop_id,  -- ⚠️ NEW: Include drop_stop_id if provided
  fare,
  booking_status, 
  payment_method,
  payment_status,
  travel_date
) VALUES (
  bus_id,
  route_id,
  seat_number,
  supervisor_id,
  drop_stop_id,  -- From request if provided
  fare,
  'booked',  -- or 'occupied'
  'cash',
  'completed',
  NOW()
);
```

### Response Should Include Booking Info
```json
{
  "success": true,
  "status": "created",
  "ticket_id": "ticket-uuid",
  "bus_number": "BUS-001",
  "passenger_count": 1,
  "total_fare": 2.50,
  "payment_method": "cash",
  "issued_at": "2025-12-13T10:30:00.000Z",
  "booking": {
    "id": "booking-uuid",
    "seat_number": 5,
    "status": "booked",
    "bus_id": "bus-uuid"
  },
  "message": "Ticket issued for 1 passenger(s). Total: ৳2.50"
}
```

### ⚠️ CRITICAL: Drop Stop Support
**NEW Requirement**: When `drop_stop_id` is provided in the request:
1. ✅ Include `drop_stop_id` in the booking creation
2. ✅ The booking should have the drop-off stop set
3. ✅ This allows the backend to auto-release bookings when bus arrives at that stop

**Updated Backend Logic**:
```javascript
// When seat_number is provided, create booking with drop_stop_id
if (seat_number && bus.route_id) {
  const { data: newBooking, error: bookingError } = await supabase
    .from("bookings")
    .insert({
      bus_id,
      route_id: bus.route_id,
      user_id: supervisorId,
      seat_no: seat_number,
      drop_stop_id: drop_stop_id || null,  // ⚠️ Include drop_stop_id if provided
      fare,
      booking_status: "booked",
      payment_method: "cash",
      payment_status: "completed",
      travel_date: issuedAt.toISOString(),
    });
}
```

---

## 2. NFC Card Registration Check

### Current App Behavior
The app tries multiple endpoints with different formats:

**Path Parameter Format**:
1. `GET /cards/{card_id}`
2. `GET /registered-cards/{card_id}`
3. `GET /nfc-cards/{card_id}`
4. `GET /passenger-cards/{card_id}`

**Query Parameter Format** (fallback):
1. `GET /cards?card_id={card_id}`
2. `GET /cards?nfc_id={card_id}`
3. `GET /registered-cards?card_id={card_id}`
4. `GET /registered-cards?nfc_id={card_id}`

**Card ID Format**: `RC-d4a290fc` (case-sensitive, lowercase hex)

### Expected Response
```json
{
  "card_id": "RC-d4a290fc",
  "nfc_id": "RC-d4a290fc",  // Alternative field name
  "passenger_name": "John Doe",
  "balance": 100.50,
  "status": "active",
  "registered_at": "2025-01-01T00:00:00Z",
  "last_used": "2025-12-13T10:00:00Z"
}
```

### ⚠️ IMPORTANT: Case Sensitivity
- Card IDs from NFC tags: `RC-d4a290fc` (lowercase hex)
- Backend should handle both `RC-d4a290fc` and `RC-D4A290FC`
- Or normalize to one format consistently

---

## 3. NFC Tap-In/Tap-Out

### Endpoints
- `POST /nfc-tap-in`
- `POST /nfc-tap-out`

### Request Payload
```json
{
  "card_id": "RC-d4a290fc",
  "bus_id": "uuid-string",
  "location": {
    "lat": 23.8103,
    "lng": 90.4125
  },
  "offline_id": "optional-offline-id"
}
```

### Expected Response
```json
{
  "success": true,
  "card_id": "RC-d4a290fc",
  "user_name": "John Doe",
  "fare": 2.50,
  "balance": 98.00,
  "co2_saved": 0.5,
  "message": "Tap-in successful"
}
```

### Error Response (Card Not Registered)
```json
{
  "success": false,
  "error": "Card not registered",
  "message": "Card not registered. Please register your card first."
}
```
**Status Code**: `404` or `400`

---

## 4. Get Bus Bookings

### Endpoint
- `GET /supervisor-bookings?bus_id={bus_id}`

### Query Parameters
- `bus_id` (required): UUID of the bus
- `date` (optional): Filter by date (YYYY-MM-DD format)

### Expected Response
```json
{
  "bus_id": "uuid-string",
  "bus_number": "BUS-001",
  "total_seats": 40,
  "booked_seats": 5,
  "available_seats": 35,
  "bookings": [
    {
      "id": "booking-uuid",
      "bus_id": "uuid-string",
      "seat_number": 1,
      "passenger_name": "John Doe",
      "card_id": "RC-d4a290fc",
      "status": "booked",  // or "confirmed", "occupied"
      "booking_type": "online",  // or "nfc", "manual"
      "booked_at": "2025-12-13T10:00:00Z",
      "trip_date": "2025-12-13T00:00:00Z",
      "route_id": "route-uuid",
      "trip_id": "trip-uuid",
      "drop_stop": "stop-uuid"  // Optional: drop-off stop
    }
  ],
  "trip_date": "2025-12-13T00:00:00Z"
}
```

### ⚠️ IMPORTANT: Filtering
- Backend should **exclude** bookings with `status = 'completed'`
- **CRITICAL**: Backend must mark bookings as `completed` when a journey/route ends
- **CRITICAL**: Backend must include `route_id` in all booking responses
- **CRITICAL**: When a new route is assigned, old bookings from previous routes should be marked as `completed`
- Backend should only return bookings with `status IN ('confirmed', 'booked', 'occupied')`
- This is already implemented in the backend according to previous messages

---

## 5. Get Assigned Bus

### Endpoint
- `GET /supervisor-bus`

### Expected Response
```json
{
  "id": "bus-uuid",
  "license_plate": "ABC-123",
  "route_number": "Route 42",
  "route": {
    "id": "route-uuid",
    "name": "Route Name",
    "route_number": "42",
    "stops": [
      {
        "id": "stop-uuid",
        "name": "Stop Name",
        "latitude": 23.8103,
        "longitude": 90.4125,
        "order": 1
      }
    ]
  },
  "status": "active",
  "capacity": 40,
  "is_active": true,
  "current_location": {
    "latitude": 23.8103,
    "longitude": 90.4125
  }
}
```

---

## Common Issues & Solutions

### Issue 1: Manual Ticket Doesn't Show as Booked
**Problem**: When issuing a manual ticket with `seat_number`, the seat doesn't appear as booked.

**Solution**: 
- Backend must **CREATE a booking** when `seat_number` is provided
- Booking status should be `'booked'` or `'occupied'`
- Booking type should be `'manual'`

### Issue 2: NFC Card Shows "Not Registered"
**Problem**: Card `RC-d4a290fc` exists but shows as not registered.

**Possible Causes**:
1. Card ID case mismatch (backend expects uppercase: `RC-D4A290FC`)
2. Card not actually registered in database
3. Wrong endpoint being used
4. Card ID format mismatch (extra spaces, different format)

**Solution**:
- Normalize card IDs to lowercase: `RC-d4a290fc`
- Ensure card is registered in database
- Use consistent endpoint: `/cards/{card_id}` or `/registered-cards/{card_id}`

### Issue 3: Bookings Not Refreshing
**Problem**: After issuing manual ticket, bookings don't update.

**Solution**:
- Backend should return booking info in ticket response
- Or app will refresh bookings after 1 second delay
- Ensure `/supervisor-bookings` endpoint returns latest data

---

## Testing Checklist

### Manual Ticket
- [ ] Issue ticket without seat → Should work
- [ ] Issue ticket with seat → Should create booking
- [ ] Check bookings endpoint → Should show new booking
- [ ] Seat should appear as "booked" in seat map

### NFC Card
- [ ] Scan registered card → Should show passenger info
- [ ] Scan unregistered card → Should show "not registered" error
- [ ] Tap-in with registered card → Should succeed
- [ ] Tap-out with registered card → Should succeed

### Bookings
- [ ] Get bookings → Should exclude completed bookings
- [ ] Get bookings → Should only show active bookings
- [ ] After manual ticket → Should show new booking immediately

---

## Contact
If backend team needs clarification on any endpoint or behavior, please refer to this document or check the app logs for exact request/response formats.

