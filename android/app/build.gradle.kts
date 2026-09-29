plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.urheart.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // SEC-MED-03: Externalized Production Signing Architecture
    val keystorePropertiesFile = rootProject.file("key.properties")
    val localKeystoreFile = project.file("key.properties")
    val targetKeystoreFile = if (keystorePropertiesFile.exists()) keystorePropertiesFile else localKeystoreFile
    val keystoreProperties = java.util.Properties()
    val hasReleaseSigning = targetKeystoreFile.exists().also { exists ->
        if (exists) {
            java.io.FileInputStream(targetKeystoreFile).use { stream ->
                keystoreProperties.load(stream)
            }
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                if (!storeFilePath.isNullOrBlank()) {
                    storeFile = file(storeFilePath)
                    storePassword = keystoreProperties.getProperty("storePassword")
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                    enableV1Signing = true
                    enableV2Signing = true
                }
            }
        }
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            enableV1Signing = true
            enableV2Signing = true
        }
    }

    defaultConfig {
        applicationId = "com.urheart.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // SEC-MED-03: Production Keystore Isolation. Debug signing is strictly detached.
            signingConfig = if (hasReleaseSigning && !keystoreProperties.getProperty("storeFile").isNullOrBlank()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
            // SEC-MED-04: R8 Code Shrinking, Resource Optimization & Obfuscation
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("androidx.multidex:multidex:2.0.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
