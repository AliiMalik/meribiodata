plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "safarnamastudios.meribiodata.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Settled in docs/decisions.md D9. Immutable once published to Play,
        // so it must not change after the M6 upload.
        applicationId = "safarnamastudios.meribiodata.app"
        // Android 8.0. Fixed by the build prompt (§0.8), not inherited from
        // Flutter's default, so a Flutter upgrade cannot silently raise it.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AdMob App ID. Defaults to Google's official test App ID so nothing
        // real is ever committed (§8). Release builds pass the production one:
        //   flutter build appbundle -PadmobAppId=ca-app-pub-XXXX~YYYY
        manifestPlaceholders["admobAppId"] =
            (project.findProperty("admobAppId") as String?)
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    buildTypes {
        release {
            // Debug signing until the Play Console account exists (M4/M6).
            signingConfig = signingConfigs.getByName("debug")
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
