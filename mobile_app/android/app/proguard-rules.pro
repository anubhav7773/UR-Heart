# Flutter & Engine Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Play In-App Billing
-keep class com.android.vending.billing.** { *; }
-keep class com.android.billingclient.api.** { *; }
-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# Firebase & Push Notifications
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-keepclassmembers class * {
    @com.google.firebase.database.IgnoreExtraProperties *;
}
-dontwarn com.google.android.gms.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }

# Sentry & Crash Reporting
-keepattributes LineNumberTable,SourceFile
-dontwarn io.sentry.**
-keep class io.sentry.** { *; }

# Secure Storage & Cryptography
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Google ML Kit Text Recognition & Commons
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }
-keep interface com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.common.**
-keep class com.google.mlkit.common.** { *; }
-dontwarn com.google_mlkit_text_recognition.**
-keep class com.google_mlkit_text_recognition.** { *; }

# Google Mobile Ads
-dontwarn com.google.android.gms.ads.**
-keep class com.google.android.gms.ads.** { *; }

# Gson & Model Serializers
-keepclassmembers enum * { *; }
-keepclassmembers class * implements java.io.Serializable { *; }

# Flutter Wrapper & Play Core Deferred Components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Obfuscate Everything Else
-repackageclasses
-allowaccessmodification
