import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // Flutter 3.47 template omits kotlin-android here; AGP 9 + android.builtInKotlin=false
    // keeps plugin KGP working. App Kotlin uses the kotlin { compilerOptions } block below.
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Ads SDK requires a valid APPLICATION_ID in the manifest or the process crashes
 // before Flutter starts. Builds without AdMob use Google's official sample id;
 // omit ADMOB_* dart-defines so no production ad units are requested.
val googleSampleAdmobAppId = "ca-app-pub-3940256099942544~3347511713"
val admobAppIdPattern = Regex("""^ca-app-pub-\d{16}~\d{10}$""")
val admobEnvRaw = System.getenv("ADMOB_ANDROID_APP_ID").orEmpty().trim()
val admobDisabled =
    System.getenv("PELEVO_DISABLE_ADMOB").orEmpty().equals("1", ignoreCase = true) ||
        System.getenv("PELEVO_DISABLE_ADMOB").orEmpty().equals("true", ignoreCase = true) ||
        admobEnvRaw.equals("disabled", ignoreCase = true) ||
        admobEnvRaw.equals("none", ignoreCase = true) ||
        admobEnvRaw.equals("off", ignoreCase = true)
val admobAndroidAppId =
    when {
        admobDisabled || admobEnvRaw.isBlank() -> googleSampleAdmobAppId
        admobAppIdPattern.matches(admobEnvRaw) -> admobEnvRaw
        else ->
            throw GradleException(
                "ADMOB_ANDROID_APP_ID must look like ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY, " +
                    "or be unset/disabled to build without AdMob (sample id is used in the manifest only).",
            )
    }
val playUploadRequested =
    gradle.startParameter.taskNames.any { task ->
        val name = task.lowercase()
        name.contains("bundlerelease") ||
            name.contains("assemblerelease") ||
            (name.contains("bundle") && name.contains("release"))
    }

android {
    namespace = "com.podemeraldltd.pelevo"
    // permission_handler 13 compiles against API 37.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.Podemeraldltd.pelevo"
        // sentry_flutter 10.x requires minSdk 26 (Play Automatic Protection is 24+).
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Resolved above: real id, or Google sample when AdMob is disabled/unset.
        manifestPlaceholders["admobAppId"] = admobAndroidAppId
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // AGP 8.5.1+ / 9: keep native libs uncompressed so Play can 16 KB-zip-align
    // them in generated APKs (required for 16 KB page-size devices).
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    buildTypes {
        debug {
            manifestPlaceholders["admobAppId"] =
                "ca-app-pub-3940256099942544~3347511713"
        }
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else if (playUploadRequested) {
                    throw GradleException(
                        "android/key.properties is required for Play Store release builds. " +
                            "Copy android/key.properties.example and point storeFile at your upload keystore.",
                    )
                } else {
                    // Local `flutter run --release` only — never upload a debug-signed AAB/APK.
                    signingConfigs.getByName("debug")
                }
            // Opt out only for local triage: PELEVO_DISABLE_MINIFY=1
            val minifyRelease =
                !System.getenv("PELEVO_DISABLE_MINIFY").orEmpty().equals("1", ignoreCase = true) &&
                    !System.getenv("PELEVO_DISABLE_MINIFY").orEmpty().equals("true", ignoreCase = true)
            isMinifyEnabled = minifyRelease
            isShrinkResources = minifyRelease
            if (minifyRelease) {
                proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro",
                )
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Billing Library version comes from in_app_purchase_android (0.5.5 → Billing 9.1.0).
// Do not force a different com.android.billingclient version here — a mismatch
// can make queryProductDetails return empty with no error.

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.core:core-ktx:1.15.0")
}

flutter {
    source = "../.."
}
