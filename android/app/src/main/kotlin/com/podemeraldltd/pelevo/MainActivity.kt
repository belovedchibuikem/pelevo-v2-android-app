package com.podemeraldltd.pelevo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : AudioServiceActivity() {
    private val reelsNativeFactoryId = "pelevoReelsNative"
    private val homeNativeFactoryId = "pelevoHomeNative"
    private val searchNativeFactoryId = "pelevoSearchNative"

    override fun onCreate(savedInstanceState: Bundle?) {
        ensureAlertChannel()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
