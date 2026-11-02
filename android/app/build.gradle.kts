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
        // Play Automatic Protection requires minSdk 24+.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
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
            val playUploadRequested =
                gradle.startParameter.taskNames.any { task ->
                    val name = task.lowercase()
                    name.contains("bundlerelease") ||
                        name.contains("assemblerelease") ||
                        (name.contains("bundle") && name.contains("release"))
                }
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
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
