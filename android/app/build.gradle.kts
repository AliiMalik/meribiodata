import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload key details, kept out of git. See android/key.properties.example.
//
// The keystore is the single most unrecoverable thing in this project: lose it
// and the app can never be updated on Play under this applicationId again, by
// anyone, ever. It is deliberately not in the repository, not in CI, and not
// derivable from anything that is.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null &&
    rootProject.file(keystoreProperties.getProperty("storeFile", "")).exists()

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

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Signed with the upload key when key.properties is present, and
            // with the debug key when it is not.
            //
            // Falling back rather than failing is deliberate: `flutter build
            // apk --release` has to keep working for anyone checking out the
            // repository, and a build that dies on a missing keystore is a
            // poor first experience. The safeguard is that a debug-signed
            // build is *rejected by Play*, so the fallback cannot be shipped
            // by accident — the failure lands at upload, loudly, rather than
            // silently producing an artifact nobody can install over.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Shrinking is on because the app bundles three fonts and the ads
            // SDK; the Flutter plugin supplies the ProGuard rules Flutter
            // itself needs.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Prints which key a release build used. Without this the difference between a
// correctly signed bundle and a debug-signed one is invisible until Play
// rejects it.
tasks.register("reportSigning") {
    doLast {
        println(
            if (hasReleaseKey) {
                "Release signing: upload key from key.properties"
            } else {
                "Release signing: DEBUG KEY - this build cannot be uploaded to Play"
            }
        )
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
