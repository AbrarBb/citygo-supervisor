# Backend Bookings Debug Guide

## Problem
No bookings are showing in the supervisor app, even though bookings exist in the database.

## What the App Expects

### Endpoint
```
GET /supervisor-bookings?bus_id=<bus-uuid>
```

**Note**: The app does NOT send a `date` parameter by default - it wants ALL bookings for the bus.

### Expected Response Format

```json
{
  "success": true,
  "bus_id": "bus-uuid-here",
  "bus_number": "DHK-BUS-102",
  "total_seats": 40,
  "available_seats": 25,
  "booked_seats": 15,
  "bookings": [
    {
      "id": "booking-uuid-1",
      "bus_id": "bus-uuid-here",
      "seat_number": 1,
      "passenger_name": "John Doe",
      "card_id": "RC-d4a290fc",
      "status": "confirmed",
      "booked_at": "2024-01-15T08:00:00Z",
      "travel_date": "2024-01-15T10:00:00Z",
      "booking_type": "online"
    },
    {
      "id": "booking-uuid-2",
      "bus_id": "bus-uuid-here",
      "seat_number": 2,
      "passenger_name": "Jane Smith",
      "card_id": "RC-198b42de",
      "status": "confirmed",
      "booked_at": "2024-01-15T09:00:00Z",
      "travel_date": "2024-01-15T10:00:00Z",
      "booking_type": "online"
    }
  ]
}
```

## Critical Field Requirements

### 1. **seat_number** (REQUIRED)
- **Must be**: An integer between 1 and 40
- **Field names accepted**: `seat_number`, `seat_no`, `seat`, `seatNumber`
- **Common issues**:
  - ❌ `seat_number: 0` → Will be filtered out
  - ❌ `seat_number: null` → Will be filtered out
  - ❌ `seat_number: 41` → Will be filtered out (out of range)
  - ✅ `seat_number: 1` → Valid
  - ✅ `seat_number: 40` → Valid

### 2. **status** (REQUIRED)
- **Accepted values**: `"confirmed"`, `"booked"`, `"occupied"`
- **Note**: App normalizes `"confirmed"` to `"booked"` automatically
- **Common issues**:
  - ❌ `status: "pending"` → Will not show as booked
  - ❌ `status: "cancelled"` → Will not show as booked
  - ✅ `status: "confirmed"` → Will show as booked
  - ✅ `status: "booked"` → Will show as booked

### 3. **bus_id** (REQUIRED)
- Must match the bus assigned to the supervisor
- Must be included in each booking object

### 4. **passenger_name** (OPTIONAL but recommended)
- Field names accepted: `passenger_name`, `name`, `full_name`
- Can be nested in `profiles` object: `profiles.full_name`

## Backend Checklist

### ✅ Verify These in Your Backend:

1. **Endpoint exists and is accessible**
   ```bash
   # Test with curl:
   curl -H "Authorization: Bearer <supervisor-token>" \
        "https://your-api.com/supervisor-bookings?bus_id=<bus-uuid>"
   ```

2. **Response includes `bookings` array**
   - Even if empty, should return: `"bookings": []`
   - Not `"bookings": null`

3. **Each booking has valid `seat_number`**
   - Check: `booking.seat_no` or `booking.seat_number` is 1-40
   - Not 0, not null, not > 40

4. **Status is correct**
   - Check: `booking.booking_status` or `booking.status` is `"confirmed"` or `"booked"`
   - Not `"pending"`, `"cancelled"`, etc.

5. **Bus ID matches**
   - Check: All bookings have `bus_id` matching the requested bus
   - Supervisor is assigned to this bus

6. **Date filtering**
   - The app does NOT send a date parameter
   - Backend should return ALL bookings for the bus (not just today's)
   - If you filter by date, use `travel_date` or `booking_date`

## Common Backend Issues

### Issue 1: Wrong Field Names
**Problem**: Backend uses `seat_no` but app expects `seat_number`

**Solution**: Backend should return BOTH or use `seat_number`:
```json
{
  "seat_number": 1,  // App looks for this first
  "seat_no": 1       // Fallback
}
```

### Issue 2: Status Not "confirmed" or "booked"
**Problem**: Backend returns `status: "pending"` or `status: "active"`

**Solution**: Backend should return:
```json
{
  "status": "confirmed"  // App will normalize to "booked"
}
```

### Issue 3: Empty Bookings Array
**Problem**: Backend returns `"bookings": []` even though bookings exist

**Possible causes**:
- Date filter is too restrictive
- Bus ID doesn't match
- Status filter excludes bookings
- Supervisor not assigned to bus

**Solution**: Check backend query:
```sql
-- Example query (adjust for your schema):
SELECT 
  id,
  bus_id,
  seat_no as seat_number,  -- Map to seat_number
  booking_status as status,  -- Map to status
  user_id,
  booking_date as booked_at,
  travel_date,
  payment_method as booking_type
FROM bookings
WHERE bus_id = $1
  AND booking_status IN ('confirmed', 'booked', 'occupied')
  -- Don't filter by date unless app sends date parameter
ORDER BY seat_no;
```

### Issue 4: Nested Profile Data
**Problem**: Passenger name is in a joined `profiles` table

**Solution**: Backend should flatten the response:
```json
{
  "id": "booking-1",
  "seat_number": 1,
  "passenger_name": "John Doe",  // Flatten from profiles.full_name
  "card_id": "RC-123",           // Flatten from profiles.card_id
  "status": "confirmed"
}
```

## Testing the Endpoint

### Test Request
```bash
curl -X GET \
  "https://your-api.com/supervisor-bookings?bus_id=<bus-uuid>" \
  -H "Authorization: Bearer <supervisor-jwt-token>" \
  -H "Content-Type: application/json"
```

### Expected Response Structure
```json
{
  "success": true,
  "bus_id": "uuid",
  "bus_number": "DHK-BUS-102",
  "total_seats": 40,
  "available_seats": 25,
  "booked_seats": 15,
  "bookings": [
    {
      "id": "uuid",
      "bus_id": "uuid",
      "seat_number": 1,
      "passenger_name": "John Doe",
      "card_id": "RC-123",
      "status": "confirmed",
      "booked_at": "2024-01-15T08:00:00Z",
      "travel_date": "2024-01-15T10:00:00Z",
      "booking_type": "online"
    }
  ]
}
```

## What to Share for Debugging

If bookings still don't show, please share:

1. **Raw API Response** (from browser DevTools or Postman):
   ```json
   {
     "success": true,
     "bus_id": "...",
     "bookings": [...]
   }
   ```

2. **Backend Query/Code**:
   - How you're querying bookings
   - What filters you're applying
   - What field names you're using

3. **Database Schema**:
   - Table name for bookings
   - Column names (especially seat number and status)
   - Sample booking record

4. **Console Logs from App**:
   - Look for lines starting with `🔍`, `📋`, `✅`, `❌`
   - These show what the app is receiving

## Quick Fix Checklist

- [ ] Endpoint `/supervisor-bookings` exists
- [ ] Returns `bookings` array (even if empty)
- [ ] Each booking has `seat_number` between 1-40
- [ ] Each booking has `status` = `"confirmed"` or `"booked"`
- [ ] `bus_id` matches the supervisor's assigned bus
- [ ] No date filter (or only filters if `date` parameter is sent)
- [ ] Passenger name is in `passenger_name` field (or flattened from profiles)
- [ ] Response includes `success: true`
- [ ] Response includes `total_seats: 40`
- [ ] Response includes `booked_seats` count

