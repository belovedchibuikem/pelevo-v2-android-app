package com.podemeraldltd.pelevo;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;

/**
 * IAB podcast User-Agent installed on Media3 {@code DefaultHttpDataSource}.
 *
 * <p>Matches {@code PelevoUserAgent.format}: {@code Pelevo/1.0.0 (Linux; Android
 * 14; SM-S911U)}. just_audio reads this via reflection when it builds the
 * ExoPlayer HTTP data source, so the .mp3 request does not use the {@code
 * just_audio} fallback.
 */
public final class PelevoExoUserAgent {
    private static volatile String value;

    private PelevoExoUserAgent() {}

    public static void install(Context context) {
        if (value != null && !value.isEmpty()) {
            return;
        }
        set(build(context));
    }

    public static void set(String userAgent) {
        if (userAgent == null) {
            return;
        }
        String trimmed = userAgent.trim();
        if (trimmed.isEmpty()) {
            return;
        }
        value = trimmed;
    }

    public static String get() {
        return value;
    }

    private static String build(Context context) {
        String version = "1.0.0";
        try {
            PackageInfo info = context.getPackageManager().getPackageInfo(context.getPackageName(), 0);
            if (info.versionName != null && !info.versionName.trim().isEmpty()) {
                version = info.versionName.trim();
            }
        } catch (PackageManager.NameNotFoundException ignored) {
            // Keep the fallback version.
        }
        String release = Build.VERSION.RELEASE == null ? "" : Build.VERSION.RELEASE.trim();
        String os = release.isEmpty() ? "Android" : "Android " + release;
        String model = Build.MODEL == null ? "" : Build.MODEL.trim();
        if (model.isEmpty()) {
            model = "Android";
        }
        model = model.replace(';', ' ').replace('\n', ' ').replace('\r', ' ');
        return "Pelevo/" + version + " (Linux; " + os + "; " + model + ")";
    }
}
