package com.podemeraldltd.pelevo

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.AdChoicesView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class ReelsNativeAdFactory(
    private val context: Context,
) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val density = context.resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val adView = NativeAdView(context).apply {
            setBackgroundColor(Color.BLACK)
            contentDescription = "Sponsored advertisement"
        }
        val root = FrameLayout(context)
        val media = MediaView(context).apply {
            setBackgroundColor(Color.BLACK)
        }
        root.addView(
            media,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        val gradient = View(context).apply {
            background =
                GradientDrawable(
                    GradientDrawable.Orientation.TOP_BOTTOM,
                    intArrayOf(Color.TRANSPARENT, 0xCC000000.toInt()),
                )
        }
        root.addView(
            gradient,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                dp(300),
                Gravity.BOTTOM,
            ),
        )

        val details =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(20), dp(16), dp(20), dp(28))
                gravity = Gravity.START
            }
        val sponsored =
            TextView(context).apply {
                text = "Sponsored"
                setTextColor(Color.WHITE)
                textSize = 12f
                setTypeface(typeface, Typeface.BOLD)
                setBackgroundColor(0x99000000.toInt())
                setPadding(dp(8), dp(4), dp(8), dp(4))
            }
        val headline =
            TextView(context).apply {
                text = nativeAd.headline
                setTextColor(Color.WHITE)
                textSize = 22f
                setTypeface(typeface, Typeface.BOLD)
                maxLines = 2
                setPadding(0, dp(10), 0, 0)
            }
        val advertiser =
            TextView(context).apply {
                text = nativeAd.advertiser ?: ""
                setTextColor(0xFFE0E0E0.toInt())
                textSize = 14f
                maxLines = 1
            }
        val body =
            TextView(context).apply {
                text = nativeAd.body ?: ""
                setTextColor(0xFFE0E0E0.toInt())
                textSize = 15f
                maxLines = 3
                setPadding(0, dp(8), 0, dp(12))
            }
        val callToAction =
            Button(context).apply {
                text = nativeAd.callToAction ?: "Learn more"
                isAllCaps = false
                setTextColor(Color.WHITE)
                setTypeface(typeface, Typeface.BOLD)
                background =
                    GradientDrawable().apply {
                        setColor(0xFF7C3AED.toInt())
                        cornerRadius = dp(24).toFloat()
                    }
            }
        val icon =
            ImageView(context).apply {
                nativeAd.icon?.drawable?.let(::setImageDrawable)
                adjustViewBounds = true
                visibility = if (nativeAd.icon == null) View.GONE else View.VISIBLE
            }

        details.addView(sponsored)
        details.addView(icon, LinearLayout.LayoutParams(dp(44), dp(44)).apply { topMargin = dp(10) })
        details.addView(headline)
        details.addView(advertiser)
        details.addView(body)
        details.addView(
            callToAction,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(50),
            ),
        )
        root.addView(
            details,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ),
        )

        val adChoices = AdChoicesView(context)
        root.addView(
            adChoices,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.END,
            ),
        )
        adView.addView(
            root,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        adView.mediaView = media
        adView.headlineView = headline
        adView.advertiserView = advertiser
        adView.bodyView = body
        adView.callToActionView = callToAction
        adView.iconView = icon
        adView.adChoicesView = adChoices
        adView.setNativeAd(nativeAd)
        return adView
    }
}
