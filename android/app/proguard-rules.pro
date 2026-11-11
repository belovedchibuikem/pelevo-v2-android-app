# Flutter / Play / App Check / IAP
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Audio service / media session
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# just_audio loads this by name when building ExoPlayer's HTTP data source.
-keep class com.podemeraldltd.pelevo.PelevoExoUserAgent {
    public static java.lang.String get();
    public static void set(java.lang.String);
    public static void install(android.content.Context);
}

# Firebase / GMS — keep reflection entry points without freezing all of Play Services.
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Mobile Ads + UMP — R8 full mode otherwise strips reflection/JNI entry
# points and the Ads ContentProvider crashes before Dart main() runs (Play
# “crashes after opening”). google_mobile_ads 7.x ships no consumer rules.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.gms.internal.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.ump.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.ads.**
-dontwarn com.google.android.gms.internal.ads.**
-dontwarn com.google.android.ump.**

# Sentry (native + JNI); consumer rules exist but keep explicitly under fullMode.
-keep class io.sentry.** { *; }
-keepattributes LineNumberTable,SourceFile

# WorkManager + Room + App Startup — R8 full mode was stripping these and
# crashing before Flutter: InitializationProvider → WorkManagerInitializer →
# "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class androidx.startup.** { *; }
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase
-keep class * extends androidx.work.Worker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context,androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.InputMerger
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# Google Play Billing
-keep class com.android.vending.billing.** { *; }

# Google Cast / Chromecast
-keep class com.google.android.gms.cast.** { *; }
-keep class com.google.android.gms.cast.framework.** { *; }
-keep class com.felnanuke.google_cast.** { *; }
-keep class androidx.mediarouter.** { *; }
-dontwarn com.google.android.gms.cast.**
-dontwarn com.felnanuke.google_cast.**

# Flutter deferred components reference Play Core APIs that are not on the
# classpath unless you ship Play Feature Delivery. Safe to ignore for a
# single-APK / App Bundle without on-demand modules.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
