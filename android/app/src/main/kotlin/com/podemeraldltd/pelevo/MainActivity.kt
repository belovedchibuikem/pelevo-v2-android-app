package com.podemeraldltd.pelevo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : AudioServiceActivity() {
    private val reelsNativeFactoryId = "pelevoReelsNative"
    private val homeNativeFactoryId = "pelevoHomeNative"
    private val searchNativeFactoryId = "pelevoSearchNative"

    override fun onCreate(savedInstanceState: Bundle?) {
        PelevoExoUserAgent.install(this)
        ensureAlertChannel()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pelevo/exo_user_agent")
            .setMethodCallHandler { call, result ->
                if (call.method != "setUserAgent") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val agent = call.argument<String>("userAgent")
                if (agent.isNullOrBlank()) {
                    result.error("bad_args", "userAgent is required", null)
                    return@setMethodCallHandler
                }
                PelevoExoUserAgent.set(agent)
                result.success(null)
            }
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            reelsNativeFactoryId,
            ReelsNativeAdFactory(this),
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            homeNativeFactoryId,
            HomeFeedNativeAdFactory(this),
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            searchNativeFactoryId,
            SearchNativeAdFactory(this),
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, reelsNativeFactoryId)
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, homeNativeFactoryId)
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, searchNativeFactoryId)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun ensureAlertChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel =
            NotificationChannel(
                "pelevo_alerts",
                "Pelevo Alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Episode, download and live alerts"
                enableVibration(true)
                setShowBadge(true)
            }
        manager.createNotificationChannel(channel)
    }
}
