# Backend 500 Error - Troubleshooting Guide

## ✅ FIXED!
**Issue**: The `profiles:user_id` join was failing due to missing foreign key relationship.

**Solution**: Fetch profiles separately instead of using a join.

**Status**: ✅ Resolved - Backend now fetches profiles in a separate query and maps them.

---

## Problem (Historical)
The `/supervisor-bookings` endpoint was returning:
```json
{
  "success": false,
  "error": "Internal server error"
}
```

Status Code: **500**

## Common Causes & Fixes

### 1. **Profiles Join Issue** (Most Likely)

**Problem**: The `profiles:user_id` join might be failing if:
- The relationship isn't set up in Supabase
- Some bookings have `user_id` that doesn't exist in profiles
- The join syntax is incorrect

**Fix**: Add null handling and error checking:

```javascript
// In your backend code, wrap the profiles access:
const formattedBookings = validBookings.map(booking => {
  let passengerName = 'Unknown';
  let cardId = null;
  
  try {
    // Handle different profile formats
    if (booking.profiles) {
      if (Array.isArray(booking.profiles)) {
        passengerName = booking.profiles[0]?.full_name || 'Unknown';
        cardId = booking.profiles[0]?.card_id || null;
      } else if (typeof booking.profiles === 'object') {
        passengerName = booking.profiles.full_name || 'Unknown';
        cardId = booking.profiles.card_id || null;
      }
    }
  } catch (err) {
    console.error('Error accessing profiles:', err);
    // Use defaults
  }
  
  return {
    id: booking.id,
    bus_id: booking.bus_id,
    seat_number: booking.seat_no,
    passenger_name: passengerName,
    card_id: cardId,
    status: booking.booking_status || 'confirmed',
    booked_at: booking.booking_date,
    travel_date: booking.travel_date,
    booking_type: booking.payment_method === 'rapid_card' ? 'rapid_card' : 'online',
    fare: booking.fare,
    payment_status: booking.payment_status,
  };
});
```

### 2. **Null/Undefined Values**

**Problem**: If `booking.seat_no` is null or `booking.booking_status` is null, it might cause errors.

**Fix**: Add validation:

```javascript
const validBookings = (bookings || []).filter(b => {
  // Ensure seat_no exists and is valid
  if (b.seat_no === null || b.seat_no === undefined) {
    console.warn(`Booking ${b.id} has null seat_no, skipping`);
    return false;
  }
  // Ensure booking_status exists
  if (!b.booking_status) {
    console.warn(`Booking ${b.id} has no booking_status, skipping`);
    return false;
  }
  return b.seat_no >= 1 && b.seat_no <= totalSeats;
});
```

### 3. **Date Filtering Issue**

**Problem**: If `travel_date` is null for some bookings, the date filter might fail.

**Fix**: Add null check:

```javascript
// Only filter by travel_date if explicitly provided by app
if (date) {
  const startOfDay = `${date}T00:00:00.000Z`;
  const endOfDay = `${date}T23:59:59.999Z`;
  // Only apply filter if travel_date exists
  query = query
    .not('travel_date', 'is', null)  // Exclude null dates
    .gte('travel_date', startOfDay)
    .lte('travel_date', endOfDay);
}
```

### 4. **Type Mismatch**

**Problem**: `booking.seat_no` might be a string instead of number.

**Fix**: Convert to number:

```javascript
seat_number: Number(booking.seat_no) || 0,
```

### 5. **Missing Error Handling**

**Problem**: Unhandled exceptions in the try-catch block.

**Fix**: Add comprehensive error handling:

```javascript
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // ... existing code ...
    
    const { data: bookings, error } = await query;

    if (error) {
      console.error('Error fetching bookings:', error);
      console.error('Error details:', JSON.stringify(error, null, 2));
      throw error;
    }

    // Add validation before processing
    if (!bookings) {
      console.warn('Bookings query returned null');
      return new Response(JSON.stringify({
        success: true,
        bus_id: assignedBus.id,
        bus_number: assignedBus.bus_number,
        total_seats: totalSeats,
        available_seats: totalSeats,
        booked_seats: 0,
        bookings: [],
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // ... rest of code with try-catch around formatting ...
    
    const formattedBookings = validBookings.map(booking => {
      try {
        return {
          id: booking.id,
          bus_id: booking.bus_id,
          seat_number: Number(booking.seat_no) || 0,
          passenger_name: (booking.profiles as any)?.full_name || 'Unknown',
          card_id: (booking.profiles as any)?.card_id || null,
          status: booking.booking_status || 'confirmed',
          booked_at: booking.booking_date,
          travel_date: booking.travel_date,
          booking_type: booking.payment_method === 'rapid_card' ? 'rapid_card' : 'online',
          fare: booking.fare || 0,
          payment_status: booking.payment_status || 'pending',
        };
      } catch (err) {
        console.error(`Error formatting booking ${booking.id}:`, err);
        return null; // Will be filtered out
      }
    }).filter(b => b !== null);

    // ... rest of code ...
    
  } catch (error: unknown) {
    console.error('Error in supervisor-bookings:', error);
    console.error('Error stack:', error instanceof Error ? error.stack : 'No stack');
    const errorMessage = error instanceof Error ? error.message : 'Internal server error';
    return new Response(JSON.stringify({
      success: false,
      error: errorMessage,
      details: error instanceof Error ? error.stack : undefined
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
```

## Quick Debug Steps

1. **Check Supabase Logs**:
   - Go to Supabase Dashboard → Edge Functions → Logs
   - Look for the error message and stack trace
   - This will show exactly what's failing

2. **Test the Query Directly**:
   ```javascript
   // Add this before the query to log what you're querying
   console.log('Querying bookings for bus:', assignedBus.id);
   console.log('Bus capacity:', assignedBus.capacity);
   ```

3. **Test Profile Join**:
   ```javascript
   // Test if profiles join works
   const { data: testBooking } = await supabaseClient
     .from('bookings')
     .select('id, user_id, profiles:user_id (full_name, card_id)')
     .eq('bus_id', assignedBus.id)
     .limit(1)
     .single();
   
   console.log('Test booking with profiles:', testBooking);
   ```

4. **Check for Null Values**:
   ```javascript
   // Log booking data before processing
   console.log('Raw bookings:', JSON.stringify(bookings, null, 2));
   ```

## Most Likely Fix

Based on the error, the most likely issue is the **profiles join**. Try this fix:

```javascript
// Instead of:
profiles:user_id (full_name, card_id)

// Try:
profiles!inner(full_name, card_id)

// Or if that doesn't work, fetch profiles separately:
const userIds = bookings.map(b => b.user_id).filter(Boolean);
const { data: profiles } = await supabaseClient
  .from('profiles')
  .select('user_id, full_name, card_id')
  .in('user_id', userIds);

// Then map them:
const profileMap = new Map(profiles.map(p => [p.user_id, p]));
const formattedBookings = validBookings.map(booking => ({
  // ...
  passenger_name: profileMap.get(booking.user_id)?.full_name || 'Unknown',
  card_id: profileMap.get(booking.user_id)?.card_id || null,
  // ...
}));
```

## Check Backend Logs

The most important step is to check your Supabase Edge Function logs. They will show:
- The exact error message
- The line number where it failed
- The stack trace

This will tell you exactly what's wrong!

