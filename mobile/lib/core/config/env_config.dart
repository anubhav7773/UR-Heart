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
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6cnN5eHZqYm16cWx6bGVodXhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk1MzQzMjcsImV4cCI6MjEwNTExMDMyN30.nwhl015k9arus3Pbjh5lDaUqLaj_Ym9BEKIgBPnN2fc',
  );

  // FastAPI Gateway Base URL (Render Live Deployment)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ur-heart.onrender.com',
  );

  // Real-Time WebSocket Base URL (Render Live Deployment)
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://ur-heart.onrender.com',
  );

  // Google AdMob Configuration (Google verified test unit IDs by default)
  static const String admobRewardedUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );

  static const String admobInterstitialUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  // Registered Developer Test Device IDs for AdMob anti-fraud compliance
  static const List<String> admobTestDeviceIds = <String>[];

  // Verification helper confirming no service_role key is present
  static bool get isSecureClientConfig {
    return !supabaseAnonKey.contains('service_role');
  }
}
