import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// The upload key lives outside the repo: android/key.properties (local) or
// written by CI from a secret. When it isn't there — a contributor's clone,
// a plain `flutter run` — release still builds, just debug-signed, which is
// fine for everything except uploading to Play.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.veryfew.kistify"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent once the app is published: Play keys a listing to its
        // application ID and it can never be changed afterwards.
        applicationId = "com.veryfew.kistify"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Auth (phone verification) requires API 23+.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // A stable, committed debug keystore (instead of Gradle's default
        // per-machine ~/.android/debug.keystore) so every build — local or
        // CI — is signed with the same key and has the same SHA-1. Google
        // Sign-In needs that fingerprint registered once in Firebase Console
        // and it then keeps working across rebuilds.
        getByName("debug") {
            storeFile = file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }

        // Play refuses anything signed with a debug key. This is the *upload*
        // key: Play re-signs the app with its own key before distributing it
        // (Play App Signing), which is why the release SHA-1 registered in
        // Firebase has to be Play's, not this one's — otherwise Google
        // Sign-In fails for everyone who installs from the store.
        if (hasUploadKey) {
            create("upload") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
            // R8 minification was tried here for app size, but it broke the
            // app on a real Android 10 device (wouldn't open at all) — with
            // no local Android SDK to test against before shipping, R8
            // stripped something Firebase needed at runtime that the
            // proguard-rules.pro keep-rules didn't cover. Reverted; the
            // split-per-ABI build below is the safe part of that size win
            // and stays. Re-enabling this needs verifying an actual release
            // build launches on a real device first, not just CI compiling.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
