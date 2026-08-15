# Flutter & Plugins Proguard Rules

# Google ML Kit Text Recognition & Commons
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }
-keep interface com.google.mlkit.vision.text.** { *; }

-dontwarn com.google.mlkit.common.**
-keep class com.google.mlkit.common.** { *; }

-dontwarn com.google_mlkit_text_recognition.**
-keep class com.google_mlkit_text_recognition.** { *; }

# Razorpay
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }

# Google Mobile Ads
-dontwarn com.google.android.gms.ads.**
-keep class com.google.android.gms.ads.** { *; }

# Flutter Wrapper & Play Core Deferred Components
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
