/// App Constants and Configuration
library;

const String API_BASE_URL = 'https://ziouzevpbnigvwcacpqw.supabase.co/functions/v1';

// Supabase API Key (anon key - safe for mobile)
const String SUPABASE_API_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inppb3V6ZXZwYm5pZ3Z3Y2FjcHF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNDA3ODIsImV4cCI6MjA3NjgxNjc4Mn0.b01QNzxi1PyURNYZysjlLL6lc2WJniz7WFlA9ozB9L8';

// Google Maps API Key - use --dart-define in production
const String GOOGLE_MAPS_API_KEY = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY',
  defaultValue: 'AIzaSyANU6LkHDgyHNjIIYfQV3YsnQ9Do_5uMGE', // Dev fallback
);

// Test Credentials
const String TEST_EMAIL = 'testsup@gmail.com';
const String TEST_PASSWORD = 'Test123!';

// Demo Credentials (for UI testing without backend)
const String DEMO_EMAIL = 'demo@citygo.app';
const String DEMO_PASSWORD = 'demo123';
const bool ENABLE_DEMO_MODE = true; // Set to false to disable demo mode

// Test NFC Card IDs
const List<String> TEST_NFC_CARDS = [
  'RC-d4a290fc',
  'RC-198b42de',
  'RC-47b8dbab',
];

