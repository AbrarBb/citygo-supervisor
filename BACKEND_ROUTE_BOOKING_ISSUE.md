# Backend Issue: Old Bookings Showing After Route Change

## ✅ STATUS: RESOLVED

**Date Resolved**: Backend team has implemented all three fixes:
1. ✅ Database triggers to auto-complete bookings on route change
2. ✅ Endpoint filtering by route_id
3. ✅ route_id included in all booking responses

## Problem
When a new route is assigned to a bus, the mobile app is still showing old bookings from a previous journey that has already ended.

## Expected Behavior
When a journey/route ends:
1. All bookings for that journey should be marked as `booking_status = 'completed'`
2. The `supervisor-bookings` endpoint should **exclude** completed bookings
3. Only bookings for the **current active route** should be returned

## Current Backend Status
Based on the backend team's recent fixes:
- ✅ Database constraint only allows: `confirmed`, `cancelled`, `completed`
- ✅ `complete_journey_bookings()` function now correctly uses `confirmed` status
- ✅ `release_bookings_at_stop()` function now correctly uses `confirmed` status
- ✅ `supervisor-bookings` endpoint filters for `confirmed` status only

## Potential Issues

### Issue 1: Bookings Not Marked as Completed
**Symptom**: Old bookings still have `booking_status = 'confirmed'` even after journey ends.

**Root Cause**: The `complete_journey_bookings()` function is only called when `handleEndRoute` is executed. If the driver doesn't explicitly end the route, bookings remain `confirmed`.

**Solution**: 
- Ensure `complete_journey_bookings()` is called automatically when:
  - A new route is assigned to the bus
  - The bus status changes from `active` to `inactive`
  - A new journey starts

### Issue 2: Missing route_id in Booking Responses
**Symptom**: Bookings don't have `route_id` field, so app can't filter by route.

**Root Cause**: The `supervisor-bookings` endpoint might not be including `route_id` in the response.

**Solution**:
- Ensure all booking responses include `route_id` field
- The app uses `route_id` to filter out bookings from different routes

### Issue 3: Backend Not Filtering by Route
**Symptom**: Backend returns bookings from all routes for the bus, not just the current route.

**Root Cause**: The `supervisor-bookings` endpoint might not be filtering by `route_id`.

**Solution**:
- Add `route_id` filter to the `supervisor-bookings` endpoint
- Only return bookings where `route_id` matches the bus's current `route_id`

## Mobile App Filtering (Current)
The app currently:
1. ✅ Filters out `completed` bookings (safety check)
2. ✅ Filters by `route_id` if available (STRICT: bookings without route_id are excluded if bus has route_id)
3. ✅ Filters by date (today only)
4. ✅ Deduplicates by seat (keeps most recent)

## Recommended Backend Fixes

### Fix 1: Auto-Complete Bookings on Route Change
```sql
-- Trigger or function to mark bookings as completed when route changes
CREATE OR REPLACE FUNCTION public.auto_complete_bookings_on_route_change()
RETURNS TRIGGER AS $$
BEGIN
  -- If route_id changed, mark all confirmed bookings for old route as completed
  IF OLD.route_id IS DISTINCT FROM NEW.route_id THEN
    UPDATE bookings
    SET booking_status = 'completed'
    WHERE bus_id = NEW.id
    AND booking_status = 'confirmed'
    AND route_id = OLD.route_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_bus_route_change
  AFTER UPDATE OF route_id ON buses
  FOR EACH ROW
  WHEN (OLD.route_id IS DISTINCT FROM NEW.route_id)
  EXECUTE FUNCTION auto_complete_bookings_on_route_change();
```

### Fix 2: Filter by route_id in supervisor-bookings Endpoint
```typescript
// In supervisor-bookings edge function
const { data: bus } = await supabase
  .from('buses')
  .select('route_id')
  .eq('id', busId)
  .single();

// Filter bookings by route_id
const { data: bookings } = await supabase
  .from('bookings')
  .select('*')
  .eq('bus_id', busId)
  .eq('booking_status', 'confirmed')
  .eq('route_id', bus.route_id)  // ⚠️ ADD THIS: Filter by current route
  .order('booked_at', { ascending: false });
```

### Fix 3: Ensure route_id is Always Included
```typescript
// In supervisor-bookings edge function response
return {
  success: true,
  bus_id: busId,
  bookings: bookings.map(b => ({
    ...b,
    route_id: b.route_id,  // ⚠️ ENSURE THIS IS INCLUDED
    // ... other fields
  }))
};
```

## ✅ Backend Fixes Implemented

The backend team has implemented all three fixes:

1. **✅ Database Triggers**: 
   - `auto_complete_bookings_on_route_change()` - Auto-completes bookings when route changes
   - `auto_complete_bookings_on_status_idle()` - Auto-completes bookings when bus goes idle
   - Both triggers are active and will automatically mark old bookings as `completed`

2. **✅ Endpoint Filtering**: 
   - `supervisor-bookings` endpoint now filters by `route_id`
   - Only returns bookings for the current active route

3. **✅ Response Format**: 
   - All booking responses now include `route_id` field
   - Both at booking level and bus level

## Testing Checklist
- [x] ✅ Database triggers created and active
- [x] ✅ Endpoint filters by route_id
- [x] ✅ Response includes route_id field
- [ ] **TODO**: Test in production - Assign new route to bus → Old bookings should be marked as `completed`
- [ ] **TODO**: Test in production - Query `supervisor-bookings` → Should only return bookings for current route
- [ ] **TODO**: Test in production - Mobile app should only show bookings for current route

## Mobile App Logs to Check
When testing, check the console logs for:
- `📅 Current bus route_id: ...` - Should match current route
- `⏭️ Filtered out booking: Seat X (route_id mismatch: ...)` - Should filter out old route bookings
- `✅ Route match: Seat X (route_id: ...)` - Should only show current route bookings

