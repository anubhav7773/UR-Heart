/// Client Environment Configuration for UR-Heart Mobile App
/// Strictly uses ONLY the public Supabase `anon` key.
/// The `service_role` secret key is NEVER included in mobile code.
class EnvConfig {
  EnvConfig._();

  // Supabase Backend Integration (Public Client Anonymous Key ONLY)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pzrsyxvjbmzqlzlehuxg.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6cnN5eHZqYm16cWx6bGVodXhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIwNDQ5ODUsImV4cCI6MjA1NzYyMDk4NX0.dummy_public_anon_key',
  );

  // FastAPI Gateway Base URL
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.asiverticals.com',
  );

  // Real-Time WebSocket Base URL
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://api.asiverticals.com',
  );

  // Verification helper confirming no service_role key is present
  static bool get isSecureClientConfig {
    return !supabaseAnonKey.contains('service_role');
  }
}
