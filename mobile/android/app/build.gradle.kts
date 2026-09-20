import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Real release signing — key.properties is gitignored and points at a
// keystore stored outside the repo entirely (see mobile/android/key.properties.example
// for the shape). Missing on a machine that hasn't been set up for release
// builds yet; only release builds need it, so debug/profile builds still
// work with nothing configured.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.barbershopapp.mobile"
    compileSdk = flutter.compileSdkVersion
    // Pinned above Flutter's default (flutter.ndkVersion) — several plugins
    // (webview_flutter_android among them) require this newer NDK; it's
    // backward compatible with the rest of the toolchain.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.barbershopapp.mobile"
        // flutter_secure_storage requires 23+ — Flutter's own template default (21)
        // fails the manifest merge outright, so this can't stay at the default.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug key only when key.properties genuinely
            // doesn't exist (a fresh checkout that hasn't been set up for
            // release builds) — never silently on a machine that has one,
            // so a real release build can't accidentally ship debug-signed.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
