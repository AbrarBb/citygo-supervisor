# Message for Backend Team - Manual Ticket & Drop Stop Updates

## Summary
The mobile app has been updated to support drop stop selection for manual tickets. The backend needs two updates to fully support this feature.

---

## Issue 1: Manual Tickets Not Creating Bookings

**Current Behavior**: When a manual ticket is issued with a `seat_number`, the backend creates a booking, but it's not appearing in the bookings list.

**Root Cause**: The booking might be created but not returned in the response, or the booking status/format doesn't match what the mobile app expects.

**Required Fix**:
1. ✅ Ensure booking is created when `seat_number` is provided (this is already working)
2. ✅ Include `drop_stop_id` in booking creation (see Issue 2 below)
3. ✅ Return booking info in the ticket response (already implemented)
4. ⚠️ **Verify booking appears in `/supervisor-bookings` endpoint** - The booking should have:
   - `booking_status` = `'booked'` or `'occupied'` (NOT `'completed'`)
   - `seat_number` field matches the requested seat
   - `booking_type` = `'manual'` (if applicable)

**Test**: Issue a manual ticket with `seat_number: 5`, then check `/supervisor-bookings?bus_id={busId}` - the booking should appear.

---

## Issue 2: Drop Stop Support Missing

**Current Status**: 
- ✅ Mobile app now sends `drop_stop_id` in manual ticket requests
- ❌ Backend doesn't include `drop_stop_id` in booking creation

**Required Fix**: Update the `manual-ticket` edge function to:

1. **Accept `drop_stop_id` from request**:
```javascript
const { 
  bus_id, 
  passenger_count = 1, 
  fare, 
  seat_number,
  drop_stop_id,  // ⚠️ ADD THIS
  // ... other fields
} = await req.json();
```

2. **Include `drop_stop_id` in booking creation**:
```javascript
if (seat_number && bus.route_id) {
  const { data: newBooking, error: bookingError } = await supabase
    .from("bookings")
    .insert({
      bus_id,
      route_id: bus.route_id,
      user_id: supervisorId,
      seat_no: seat_number,
      drop_stop_id: drop_stop_id || null,  // ⚠️ ADD THIS LINE
      fare,
      booking_status: "booked",
      payment_method: "cash",
      payment_status: "completed",
      travel_date: issuedAt.toISOString(),
    })
    .select("id, seat_no, booking_status, drop_stop_id")  // ⚠️ Include drop_stop_id in select
    .single();
    
  // ... rest of code
}
```

3. **Return `drop_stop_id` in booking response** (if you want to show it in the app):
```javascript
booking = {
  id: newBooking.id,
  seat_number: newBooking.seat_no,
  status: newBooking.booking_status,
  drop_stop_id: newBooking.drop_stop_id,  // ⚠️ ADD THIS
  bus_id,
};
```

---

## Updated Request Format

The mobile app now sends:
```json
{
  "bus_id": "uuid",
  "passenger_count": 1,
  "fare": 2.50,
  "timestamp": "2025-12-13T10:30:00.000Z",
  "seat_number": 5,
  "drop_stop_id": "stop-uuid",  // ⚠️ NEW FIELD
  "ticket_type": "single",
  "payment_method": "cash",
  "location": {
    "lat": 23.8103,
    "lng": 90.4125
  }
}
```

---

## Expected Response Format

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
    "drop_stop_id": "stop-uuid",  // ⚠️ NEW FIELD
    "bus_id": "bus-uuid"
  },
  "message": "Ticket issued for 1 passenger(s). Total: ৳2.50"
}
```

---

## Testing Checklist

After backend updates:

1. **Manual Ticket with Seat**:
   - [ ] Issue ticket with `seat_number: 5` and `drop_stop_id: "stop-123"`
   - [ ] Verify booking is created in database
   - [ ] Verify booking has `drop_stop_id` set
   - [ ] Verify booking appears in `/supervisor-bookings` endpoint
   - [ ] Verify booking status is `'booked'` (not `'completed'`)

2. **Manual Ticket without Seat**:
   - [ ] Issue ticket without `seat_number`
   - [ ] Verify no booking is created (correct behavior)

3. **Bookings Endpoint**:
   - [ ] Call `/supervisor-bookings?bus_id={busId}`
   - [ ] Verify manual ticket booking appears in the list
   - [ ] Verify `drop_stop_id` is included in booking data

---

## Questions?

If you need clarification on:
- Request/response formats → See `BACKEND_API_REQUIREMENTS.md`
- Field names or data types → Check the mobile app logs (they show exact request data)
- Booking status values → Use `'booked'` or `'occupied'` (NOT `'completed'`)

---

## Priority

**High Priority**: 
- Fix booking creation to include `drop_stop_id`
- Ensure bookings appear in `/supervisor-bookings` endpoint

**Medium Priority**:
- Return `drop_stop_id` in booking response (nice to have for UI display)

---

Thank you! Let me know if you need any clarification or have questions about the mobile app's expectations.

