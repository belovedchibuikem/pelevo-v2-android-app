import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val admobAndroidAppId = System.getenv("ADMOB_ANDROID_APP_ID").orEmpty()
val releaseRequested =
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (releaseRequested && admobAndroidAppId.isBlank()) {
    throw GradleException(
        "ADMOB_ANDROID_APP_ID is required for release builds; test IDs are never used in production.",
    )
}

android {
    namespace = "com.podemeraldltd.pelevo"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.Podemeraldltd.pelevo"
        // Play Automatic Protection requires minSdk 24+.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        // Play Console requires target API 36+ for updates (Flutter template still defaults to 35).
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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

    buildTypes {
        debug {
            manifestPlaceholders["admobAppId"] =
                "ca-app-pub-3940256099942544~3347511713"
        }
        release {
            val playUploadRequested =
                gradle.startParameter.taskNames.any { task ->
                    val name = task.lowercase()
                    name.contains("bundlerelease") ||
                        name.contains("assemblerelease") ||
                        (name.contains("bundle") && name.contains("release"))
                }
            signingConfig = if (keystorePropertiesFile.exists()) {
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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

configurations.configureEach {
    resolutionStrategy.eachDependency {
        if (requested.group == "com.android.billingclient") {
            useVersion("8.0.0")
            because("Google Play requires Billing Library 8.0.0+")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.6.1")
    // Explicit pin so Play Console detects Billing Library 8+.
    implementation("com.android.billingclient:billing:8.0.0")
}

flutter {
    source = "../.."
}
