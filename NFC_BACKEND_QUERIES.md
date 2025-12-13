# NFC Backend API Queries

This document lists all NFC-related API endpoints and queries that the mobile app makes to the backend.

## NFC API Endpoints

### 1. NFC Tap-In
**Endpoint**: `POST /nfc-tap-in`

**Purpose**: Record a passenger's tap-in event when they board the bus.

**Request Body**:
```json
{
  "card_id": "RC-d4a290fc",  // Card ID from NFC tag (trimmed, preserves case)
  "bus_id": "e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b",
  "location": {
    "lat": 23.7753367,
    "lng": 90.4237213
  },
  "timestamp": "2025-12-13T05:38:24.551Z"
}
```

**Behavior**:
- First tries with original case card ID (e.g., "RC-d4a290fc")
- If 404 "Card not registered" error, automatically retries with lowercase (e.g., "rc-d4a290fc")
- Creates a booking for the passenger
- Deducts fare from card balance

**Response**: `NfcTapResponse` with booking info, fare, balance, etc.

---

### 2. NFC Tap-Out
**Endpoint**: `POST /nfc-tap-out`

**Purpose**: Record a passenger's tap-out event when they exit the bus.

**Request Body**:
```json
{
  "card_id": "RC-d4a290fc",  // Card ID from NFC tag (trimmed, preserves case)
  "bus_id": "e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b",
  "location": {
    "lat": 23.7753367,
    "lng": 90.4237213
  },
  "timestamp": "2025-12-13T05:38:24.551Z"
}
```

**Behavior**:
- First tries with original case card ID
- If 404 "Card not registered" error, automatically retries with lowercase
- Completes the booking
- May calculate final fare based on distance traveled

**Response**: `NfcTapResponse` with booking completion info, final fare, balance, etc.

---

### 3. Check Card Registration
**Endpoint**: `GET /registered-cards/{cardId}` (Primary)
**Alternative Endpoints**:
- `GET /registered-cards?card_id={cardId}`
- `GET /registered-cards?nfc_id={cardId}`
- `GET /cards/{cardId}`
- `GET /nfc-cards/{cardId}`
- `GET /passenger-cards/{cardId}`

**Purpose**: Check if an NFC card is registered and get card information.

**Request**:
- Path parameter: `/registered-cards/RC-d4a290fc` (URL-encoded)
- Query parameter: `/registered-cards?card_id=RC-d4a290fc`

**Behavior**:
1. Tries path parameter endpoints first (with URL encoding)
2. Tries query parameter endpoints
3. If original case fails, tries lowercase version
4. Backend supports case-insensitive matching

**Response**: `RegisteredCard` object with:
- `cardId`: Card ID
- `passengerName`: Passenger name
- `balance`: Current balance
- `status`: Card status (active/inactive)
- `registeredAt`: Registration timestamp
- `lastUsed`: Last usage timestamp

**Returns**: `null` if card is not registered

---

### 4. Get All Registered Cards
**Endpoint**: `GET /registered-cards` (Primary)
**Alternative Endpoints**:
- `GET /cards`
- `GET /nfc-cards`
- `GET /passenger-cards`
- `GET /supervisor-cards`

**Purpose**: Get a list of all registered NFC cards (used in Settings screen).

**Request**: No parameters (returns all cards)

**Response**: Array of `RegisteredCard` objects

---

### 5. Sync Offline NFC Events
**Endpoint**: `POST /nfc-sync`

**Purpose**: Batch synchronize offline NFC events that were saved when network was unavailable.

**Request Body**:
```json
{
  "events": [
    {
      "card_id": "RC-d4a290fc",
      "bus_id": "e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b",
      "event_type": "tap_in",
      "latitude": 23.7753367,
      "longitude": 90.4237213,
      "timestamp": "2025-12-13T05:38:24.551Z",
      "offline_id": "unique-offline-id-123"
    },
    // ... more events
  ]
}
```

**Response**: Sync response with success/failure status for each event

---

## Card ID Format

- **Format**: `RC-XXXXXXXX` (8 hexadecimal characters)
- **Example**: `RC-d4a290fc`
- **Case Sensitivity**: 
  - App preserves original case from NFC tag
  - Backend supports case-insensitive matching
  - App has fallback to lowercase if original case fails

---

## Error Handling

### Network Errors
- **Connection timeout**: Saved to offline storage
- **No connection**: Saved to offline storage
- **Receive timeout**: Saved to offline storage

### Validation Errors
- **Card not registered (404)**: 
  - Shown immediately to user
  - NOT saved to offline storage
  - App retries with lowercase card ID automatically

### Other Errors
- **401 Unauthorized**: Token expired, user needs to re-login
- **403 Forbidden**: User doesn't have permission
- **500 Server Error**: Shown to user, not saved offline

---

## Offline Storage

When network errors occur, NFC events are saved to local SQLite database:
- **Table**: `nfc_logs`
- **Fields**: `card_id`, `bus_id`, `event_type`, `latitude`, `longitude`, `timestamp`, `offline_id`, `synced`
- **Sync**: Events are synced when network is available via `/nfc-sync` endpoint

---

## Request/Response Examples

### Tap-In Request
```http
POST /nfc-tap-in
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "card_id": "RC-d4a290fc",
  "bus_id": "e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b",
  "location": {
    "lat": 23.7753367,
    "lng": 90.4237213
  }
}
```

### Tap-In Response
```json
{
  "success": true,
  "message": "Tap-in successful",
  "booking": {
    "id": "booking-id-123",
    "seat_number": 5,
    "status": "confirmed",
    "fare": 15.50
  },
  "card_balance": 84.50,
  "fare_deducted": 15.50
}
```

### Card Registration Check Request
```http
GET /registered-cards/RC-d4a290fc
Authorization: Bearer <jwt_token>
```

### Card Registration Check Response
```json
{
  "card_id": "RC-d4a290fc",
  "passenger_name": "John Doe",
  "balance": 100.00,
  "status": "active",
  "registered_at": "2025-01-01T00:00:00Z",
  "last_used": "2025-12-13T05:38:24Z"
}
```

---

## Notes

1. **Case Sensitivity**: The app preserves the original case from the NFC tag, but has automatic fallback to lowercase if the backend returns a 404 error.

2. **URL Encoding**: Card IDs are URL-encoded when used in path parameters to handle special characters.

3. **Multiple Endpoint Support**: The app tries multiple endpoint variations to ensure compatibility with different backend configurations.

4. **Offline Support**: NFC events are saved locally when network is unavailable and synced later.

5. **Error Distinction**: The app distinguishes between network errors (saved offline) and validation errors (shown immediately).

