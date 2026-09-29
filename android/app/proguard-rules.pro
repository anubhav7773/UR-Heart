# ==============================================================================
# UR-Heart Sanctuary Production R8 / ProGuard Optimization & Obfuscation Rules
# Defect SEC-MED-04: R8 Code Shrinking, Resource Optimization & Obfuscation
# ==============================================================================

# 1. Flutter Core Framework & Plugin Registration
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# 2. Hardware Secure Storage & AndroidX Security Crypto (SEC-HIGH-05)
-keep class androidx.security.crypto.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn androidx.security.crypto.**
-dontwarn com.it_nomads.fluttersecurestorage.**

# 3. Cryptography Engine & Native Bindings (X25519 & ChaCha20-Poly1305)
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# 4. Google Mobile Ads SDK (AdMob, Mediation & Verification)
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.internal.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# 5. In-App Purchase & Google Play Billing Client
-keep class com.android.billingclient.api.** { *; }
-keep class com.android.vending.billing.** { *; }
-dontwarn com.android.billingclient.**

# 6. Firebase Infrastructure (Auth, Storage, Core)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# 7. Device Sensors, Camera & Geolocation
-keep class dev.fluttercommunity.plus.** { *; }
-keep class com.baseflow.geolocator.** { *; }
-keep class io.flutter.plugins.camera.** { *; }

# 8. Sentry Telemetry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# 9. Main Application Entrypoint
-keep class com.urheart.app.MainActivity { *; }

# 10. General ProGuard Attributes & Type Reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable

# 11. Serialization & JSON Enums Preservation
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# 12. Attack Surface Reduction & Obfuscation
-repackageclasses ''
-allowaccessmodification
