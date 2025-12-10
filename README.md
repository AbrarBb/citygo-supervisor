# CityGo Supervisor Flutter App

A Flutter mobile application for CityGo bus supervisors to manage NFC tap-ins/tap-outs, issue manual tickets, sync offline data, and view daily reports.

## Features

- 🔐 **Authentication**: Secure login with JWT token storage
- 🚌 **Bus Management**: View assigned bus and route information
- 📍 **NFC Integration**: Tap-in/tap-out functionality with offline support
- 🎫 **Manual Tickets**: Issue tickets manually with passenger count
- 🔄 **Offline Sync**: Automatic sync of offline events when connectivity is restored
- 📊 **Reports**: Daily reports with statistics and hourly breakdown
- 🗺️ **Google Maps**: Route visualization with stop markers and polyline

## Setup

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / Xcode (for mobile development)
- Google Maps API key
- Supabase API key (anon key)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd flutter_application_1
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure API keys in `lib/constants.dart`:
```dart
const String API_BASE_URL = 'https://ziouzevpbnigvwcacpqw.supabase.co/functions/v1';
const String SUPABASE_API_KEY = 'your-supabase-anon-key';
// Google Maps key is loaded from --dart-define
```

### Android Configuration

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.NFC" />
  
  <application>
    <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
  </application>
</manifest>
```

**Note**: NFC requires a real Android device. Emulators generally do not support NFC.

### iOS Configuration

Edit `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Location required for route tracking and fare calculations.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Location required for route tracking.</string>
<key>NFCReaderUsageDescription</key>
<string>Used to read CityGo NFC Rapid Cards for tap-in/tap-out.</string>
<key>GMSApiKey</key>
<string>YOUR_GOOGLE_MAPS_API_KEY</string>
```

In Xcode, enable **Near Field Communication Tag Reading** capability.

## Running the App

### Development

Run with Google Maps API key:

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY
```

Or specify a device:

```bash
# Android
flutter run -d <android-device-id> --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# iOS
flutter run -d <ios-device-id> --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

### Production Build

For production builds, use `--dart-define` to inject keys:

```bash
# Android APK
flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY

# iOS
flutter build ios --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

## Test Credentials

- **Email**: `testsup@gmail.com`
- **Password**: `123456`

## Test NFC Cards

- `RC-d4a290fc`
- `RC-198b42de`
- `RC-47b8dbab`

## Architecture

### Project Structure

```
lib/
├── constants.dart          # API keys and configuration
├── main.dart              # App entry point
├── models/                # Data models
│   ├── auth.dart
│   ├── bus.dart
│   ├── nfc.dart
│   ├── ticket.dart
│   ├── sync.dart
│   └── report.dart
├── providers/             # Riverpod state management
│   ├── auth_provider.dart
│   ├── bus_provider.dart
│   ├── nfc_provider.dart
│   └── sync_provider.dart
├── screens/               # UI screens
│   ├── login.dart
│   ├── dashboard.dart
│   ├── nfc_reader.dart
│   ├── manual_ticket.dart
│   ├── sync_center.dart
│   ├── reports.dart
│   └── settings.dart
├── services/              # Business logic
│   ├── api_service.dart   # REST API client
│   ├── local_db.dart      # SQLite database
│   ├── nfc_service.dart  # NFC tag reading
│   └── sync_service.dart  # Offline sync
├── theme/                 # App theming
│   └── app_theme.dart
└── widgets/               # Reusable components
    └── components.dart
```

### Key Components

- **ApiService**: Handles all backend API calls with JWT authentication
- **LocalDB**: SQLite database for offline storage
- **NFCService**: NFC tag reading and event creation
- **SyncService**: Batch synchronization of offline events
- **Riverpod Providers**: State management for auth, bus, NFC logs, and sync

## API Endpoints

- `POST /supervisor-auth` - Login
- `GET /supervisor-bus` - Get assigned bus
- `POST /nfc-tap-in` - NFC tap-in
- `POST /nfc-tap-out` - NFC tap-out
- `POST /manual-ticket` - Issue manual ticket
- `POST /nfc-sync` - Sync offline events
- `GET /supervisor-reports?date=YYYY-MM-DD` - Daily reports

## Testing Flow

1. **Login**: Use test credentials to authenticate
2. **Assigned Bus**: Dashboard should display assigned bus and route
3. **Map & Trip**: Map should render with route polyline and stop markers
4. **NFC Scan**: 
   - Use real NFC card on physical device, or
   - Use "Simulate Tap-In" button for testing
5. **Manual Ticket**: Fill form and issue ticket
6. **Offline Sync**: 
   - Turn off internet
   - Create offline events
   - Turn on internet → Open Sync Center → Press "Sync Now"
7. **Reports**: View daily reports with statistics

## Troubleshooting

### Map tiles not showing
- Verify Google Maps API key is correctly set
- Check SHA-1 key registration for Android
- Ensure API key has Maps SDK enabled

### NFC not detected
- Ensure NFC is enabled on device
- App has NFC permission
- Test on physical device (emulators don't support NFC)

### 401 Authentication errors
- Verify JWT token is saved in secure storage
- Check `apikey` header is included in requests
- Test endpoint independently with curl

### Offline events not syncing
- Check local DB table `nfc_logs` for `synced=false`
- Validate `offline_id` uniqueness
- Check sync service logs

### RLS permission errors (403)
- Verify supervisor token has supervisor role
- Test with staging supervisor credentials

## CI/CD Configuration

In GitHub Actions or CI/CD pipeline, store secrets and inject via `--dart-define`:

```yaml
- name: Build APK
  run: |
    flutter build apk \
      --dart-define=GOOGLE_MAPS_API_KEY=${{ secrets.GOOGLE_MAPS_API_KEY }} \
      --dart-define=SUPABASE_API_KEY=${{ secrets.SUPABASE_API_KEY }}
```

## Dependencies

Key dependencies:
- `flutter_riverpod` - State management
- `dio` - HTTP client
- `sqflite` - SQLite database
- `nfc_manager` - NFC tag reading
- `google_maps_flutter` - Maps integration
- `geolocator` - Location services
- `flutter_secure_storage` - Secure credential storage
- `connectivity_plus` - Network connectivity monitoring

See `pubspec.yaml` for complete list.

## License

[Your License Here]
