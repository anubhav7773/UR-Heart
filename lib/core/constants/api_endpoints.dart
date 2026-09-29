/// API and R2 Storage Endpoints for UR-Heart
/// Keeps zero hardcoded route strings across the Flutter codebase
class ApiEndpoints {
  const ApiEndpoints._();

  // Official Production Domain (Asiverticals.me parent network)
  static const String officialDomain = 'urheart.asiverticals.me';
  static const String fallbackDomain = 'ur-heart.onrender.com';
  static const String webSanctuaryUrl = 'https://urheart.asiverticals.me';
  static const String privacyPolicyUrl = 'https://urheart.asiverticals.me/privacy';
  static const String termsOfServiceUrl = 'https://urheart.asiverticals.me/terms';
  static const String deleteAccountUrl = 'https://urheart.asiverticals.me/delete-account';

  // Base API URL injected via environment or defaulting to official domain
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://urheart.asiverticals.me',
  );

  // Core API Routes
  static const String healthCheck = '/api/v1/health';
  static const String authSessionHandshake = '/api/v1/auth/session';
  static const String mediaPresignedUrl = '/api/v1/media/presigned-url';
  static const String adMobRewardCallback = '/api/v1/ads/admob/callback';
  static const String appLovinRewardCallback = '/api/v1/ads/applovin/callback';
  static const String adminKycPending = '/api/v1/admin/kyc/pending';
  static const String adminKycAction = '/api/v1/admin/kyc/action';

  // Real-Time Render Activity Telemetry & Logging
  static const String telemetryActivity = '/api/v1/telemetry/activity';

  // AI Suite & Moderation Routes
  static const String aiPolishBio = '/api/v1/ai/bio-polish';
  static const String aiKycLiveness = '/api/v1/ai/kyc-liveness';
  static const String photoModeration = '/api/v1/moderation/photo';

  // Phase 8: Profile, Vault & Governance Routes
  static const String incinerateAccount = '/api/v1/auth/incinerate-account';
  static const String vaultExportData = '/api/v1/vault/export-data';
  static const String vaultNominee = '/api/v1/vault/nominee';
  static const String vaultGrievance = '/api/v1/vault/grievance';
  static const String vaultBlockedPerimeter = '/api/v1/vault/blocked';
  static const String userPreferences = '/api/v1/user/preferences';
  static const String userProfile = '/api/v1/user/profile';
  static const String rotateEncryptionKey = '/api/v1/crypto/rotate-key';

  // R2 Storage Hierarchy Configuration
  static const int maxPhotoSlots = 5;
  static const String r2BucketName = 'ur-heart-media';

  static String photoSlotKey(String userId, int slotNumber) {
    return 'users/$userId/photos/slot_$slotNumber.webp';
  }

  static String kycVideoKey(String userId) {
    return 'users/$userId/kyc/video.mp4';
  }
}
