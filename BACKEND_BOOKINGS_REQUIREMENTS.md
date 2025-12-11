# Backend Bookings Requirements - Quick Reference

## Endpoint
```
GET /supervisor-bookings?bus_id=<bus-uuid>
```

**Important**: Do NOT require or filter by `date` parameter unless the app sends it. The app wants ALL bookings for the bus.

## Required Response Format

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
      "id": "booking-uuid",
      "bus_id": "bus-uuid-here",
      "seat_number": 1,
      "passenger_name": "John Doe",
      "card_id": "RC-d4a290fc",
      "status": "confirmed",
      "booked_at": "2024-01-15T08:00:00Z",
      "travel_date": "2024-01-15T10:00:00Z",
      "booking_type": "online"
    }
  ]
}
```

## Critical Requirements

### 1. **seat_number** Field (MOST IMPORTANT)
- **Must be**: Integer between **1 and 40**
- **Field name**: Use `seat_number` (app also accepts `seat_no`, `seat`, `seatNumber` as fallback)
- **Cannot be**: 0, null, negative, or > 40
- **Example**: `"seat_number": 1` ✅ | `"seat_number": 0` ❌

### 2. **status** Field
- **Must be**: `"confirmed"` or `"booked"` (app normalizes "confirmed" to "booked")
- **Cannot be**: `"pending"`, `"cancelled"`, `"active"`, etc.
- **Example**: `"status": "confirmed"` ✅ | `"status": "pending"` ❌

### 3. **bookings** Array
- **Must exist**: Even if empty, return `"bookings": []`
- **Cannot be**: `null` or missing
- **Each item must have**: `id`, `bus_id`, `seat_number`, `status`

### 4. **bus_id** Matching
- All bookings must have `bus_id` matching the requested bus
- Supervisor must be assigned to this bus

## Field Name Mapping

If your database uses different column names, map them like this:

| Database Column | Response Field | Required |
|----------------|---------------|----------|
| `seat_no` | `seat_number` | ✅ YES |
| `booking_status` | `status` | ✅ YES |
| `user_id` | (not needed, but can be `passenger_id`) | ❌ |
| `full_name` (from profiles) | `passenger_name` | ⚠️ Recommended |
| `card_id` (from profiles) | `card_id` | ⚠️ Optional |
| `booking_date` | `booked_at` | ⚠️ Optional |
| `travel_date` | `travel_date` | ⚠️ Optional |
| `payment_method` | `booking_type` | ⚠️ Optional |

## Example Backend Query (PostgreSQL)

```sql
SELECT 
  b.id,
  b.bus_id,
  b.seat_no AS seat_number,  -- CRITICAL: Map to seat_number
  COALESCE(p.full_name, 'Unknown') AS passenger_name,
  p.card_id,
  CASE 
    WHEN b.booking_status = 'confirmed' THEN 'confirmed'
    WHEN b.booking_status = 'booked' THEN 'booked'
    ELSE 'confirmed'  -- Default to confirmed if other status
  END AS status,
  b.booking_date AS booked_at,
  b.travel_date,
  COALESCE(b.payment_method, 'online') AS booking_type
FROM bookings b
LEFT JOIN profiles p ON b.user_id = p.user_id
WHERE b.bus_id = $1
  AND b.booking_status IN ('confirmed', 'booked', 'occupied')
  -- Don't filter by date unless date parameter is provided
ORDER BY b.seat_no;
```

## Example Backend Code (Node.js/Deno)

```javascript
// Get supervisor's assigned bus
const { data: assignedBus } = await supabase
  .from('buses')
  .select('id, bus_number, capacity')
  .eq('supervisor_id', userId)
  .single();

if (!assignedBus) {
  return { success: false, error: 'No bus assigned' };
}

// Get bookings - CRITICAL: Map seat_no to seat_number
const { data: bookings } = await supabase
  .from('bookings')
  .select(`
    id,
    bus_id,
    seat_no,
    booking_status,
    booking_date,
    travel_date,
    payment_method,
    user_id,
    profiles:user_id (
      full_name,
      card_id
    )
  `)
  .eq('bus_id', assignedBus.id)
  .in('booking_status', ['confirmed', 'booked', 'occupied']);

// Transform to required format
const formattedBookings = bookings.map(booking => ({
  id: booking.id,
  bus_id: booking.bus_id,
  seat_number: booking.seat_no,  // CRITICAL: Map seat_no to seat_number
  passenger_name: booking.profiles?.full_name || 'Unknown',
  card_id: booking.profiles?.card_id || null,
  status: booking.booking_status === 'confirmed' ? 'confirmed' : 'booked',
  booked_at: booking.booking_date,
  travel_date: booking.travel_date,
  booking_type: booking.payment_method || 'online'
}));

// Calculate stats
const totalSeats = assignedBus.capacity || 40;
const bookedSeats = formattedBookings.length;
const availableSeats = totalSeats - bookedSeats;

return {
  success: true,
  bus_id: assignedBus.id,
  bus_number: assignedBus.bus_number,
  total_seats: totalSeats,
  available_seats: availableSeats,
  booked_seats: bookedSeats,
  bookings: formattedBookings
};
```

## Common Mistakes to Avoid

### ❌ Wrong: Missing seat_number
```json
{
  "id": "booking-1",
  "seat_no": 1,  // App looks for "seat_number" first
  "status": "confirmed"
}
```

### ✅ Correct: Use seat_number
```json
{
  "id": "booking-1",
  "seat_number": 1,  // App finds this immediately
  "status": "confirmed"
}
```

### ❌ Wrong: Invalid seat number
```json
{
  "seat_number": 0,  // Will be filtered out
  "seat_number": 41,  // Will be filtered out (out of range)
  "seat_number": null  // Will be filtered out
}
```

### ✅ Correct: Valid seat number
```json
{
  "seat_number": 1,  // Valid (1-40)
  "seat_number": 40  // Valid (1-40)
}
```

### ❌ Wrong: Wrong status
```json
{
  "status": "pending",  // Won't show as booked
  "status": "cancelled"  // Won't show as booked
}
```

### ✅ Correct: Valid status
```json
{
  "status": "confirmed",  // App normalizes to "booked"
  "status": "booked"  // Direct match
}
```

## Testing Checklist

Before deploying, verify:

- [ ] Endpoint returns `bookings` array (even if empty)
- [ ] Each booking has `seat_number` field (not `seat_no`)
- [ ] `seat_number` is between 1-40 (not 0, not null, not > 40)
- [ ] `status` is `"confirmed"` or `"booked"` (not "pending")
- [ ] `bus_id` matches supervisor's assigned bus
- [ ] Response includes `success: true`
- [ ] Response includes `total_seats: 40`
- [ ] Response includes `booked_seats` count

## Quick Test

```bash
curl -X GET \
  "https://your-api.com/supervisor-bookings?bus_id=<bus-uuid>" \
  -H "Authorization: Bearer <supervisor-token>"
```

Expected response should have:
- `"bookings": [...]` array
- Each booking with `"seat_number": 1-40`
- Each booking with `"status": "confirmed"` or `"booked"`

## Summary

**The 3 most critical things:**

1. ✅ **seat_number** field (1-40, not 0, not null)
2. ✅ **status** = "confirmed" or "booked" (not "pending")
3. ✅ **bookings** array exists (even if empty)

If these 3 are correct, bookings will show in the app!

