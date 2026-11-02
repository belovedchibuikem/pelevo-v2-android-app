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
