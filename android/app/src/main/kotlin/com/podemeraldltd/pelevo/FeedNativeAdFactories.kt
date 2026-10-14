package com.podemeraldltd.pelevo

import android.content.Context
import android.graphics.Color
import android.os.Build
import android.graphics.Outline
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.AdChoicesView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

private val feedCard = 0xFF121212.toInt()
private val feedMuted = 0xFFA0A0A0.toInt()
private val feedGreen = 0xFF2FA44F.toInt()
private val feedWell = 0xFF1E1E1E.toInt()

private fun Context.feedDp(value: Int): Int =
    (value * resources.displayMetrics.density).toInt()

private const val searchAdTag = "Ads"
private const val searchAdHeightDp = 76

private fun roundedOutline(radiusPx: Float) =
    object : ViewOutlineProvider() {
        override fun getOutline(view: View, outline: Outline) {
            val width = view.width
            val height = view.height
            if (width <= 0 || height <= 0) {
                outline.setEmpty()
                return
            }
            outline.setRoundRect(0, 0, width, height, radiusPx)
        }
    }

private fun destroyNativeAd(nativeAd: NativeAd?) {
    if (nativeAd == null) return
    try {
        nativeAd.destroy()
    } catch (error: RuntimeException) {
        Log.w(searchAdTag, "AdMob nativeAd.destroy failed", error)
    }
}

class HomeFeedNativeAdFactory(
    private val context: Context,
) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val density = context.resources.displayMetrics.density
        fun dp(value: Int) = context.feedDp(value)

        val adView =
            NativeAdView(context).apply {
                setBackgroundColor(feedCard)
                contentDescription = "Sponsored advertisement"
                clipToOutline = true
                outlineProvider = roundedOutline(12f * density)
            }
        val root =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(12), dp(12), dp(12), dp(12))
            }

        val icon =
            ImageView(context).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
                background =
                    GradientDrawable().apply {
                        cornerRadius = dp(8).toFloat()
                        setColor(feedWell)
                    }
                clipToOutline = true
                outlineProvider = roundedOutline(8f * density)
                nativeAd.icon?.drawable?.let(::setImageDrawable)
            }
        val headline =
            TextView(context).apply {
                text = nativeAd.headline
                setTextColor(Color.WHITE)
                textSize = 14f
                setTypeface(typeface, Typeface.BOLD)
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
            }
        val body =
            TextView(context).apply {
                text = nativeAd.body.orEmpty()
                setTextColor(feedMuted)
                textSize = 12f
                maxLines = 2
                ellipsize = TextUtils.TruncateAt.END
                visibility = if (nativeAd.body.isNullOrBlank()) View.GONE else View.VISIBLE
            }
        val sponsored =
            TextView(context).apply {
                text = "Sponsored"
                setTextColor(feedMuted)
                textSize = 10f
                gravity = Gravity.END
            }
        val textColumn =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                addView(headline)
                addView(body)
            }
        val header =
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(icon, LinearLayout.LayoutParams(dp(36), dp(36)))
                addView(
                    textColumn,
                    LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                        marginStart = dp(8)
                        marginEnd = dp(8)
                    },
                )
                addView(
                    sponsored,
                    LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ),
                )
            }

        val media =
            MediaView(context).apply {
                setImageScaleType(ImageView.ScaleType.CENTER_CROP)
                setBackgroundColor(feedWell)
                minimumHeight = dp(120)
            }
        val adChoices = AdChoicesView(context)
        val mediaFrame =
            FrameLayout(context).apply {
                minimumHeight = dp(120)
            }
        mediaFrame.addView(
            media,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        mediaFrame.addView(
            adChoices,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.END,
            ).apply {
                topMargin = dp(4)
                marginEnd = dp(4)
            },
        )

        val callToAction =
            TextView(context).apply {
                text = nativeAd.callToAction ?: "Learn more"
                setTextColor(Color.BLACK)
                textSize = 13f
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.CENTER
                background =
                    GradientDrawable().apply {
                        setColor(feedGreen)
                        cornerRadius = dp(8).toFloat()
                    }
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
            }

        root.addView(header)
        root.addView(
            mediaFrame,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(120),
                1f,
            ).apply {
                topMargin = dp(8)
                bottomMargin = dp(8)
            },
        )
        root.addView(
            callToAction,
            LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(36)),
        )
        adView.addView(
            root,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )

        adView.iconView = icon
        adView.headlineView = headline
        adView.bodyView = body
        adView.mediaView = media
        adView.callToActionView = callToAction
        adView.adChoicesView = adChoices
        adView.setNativeAd(nativeAd)
        body.visibility = if (nativeAd.body.isNullOrBlank()) View.GONE else View.VISIBLE
        return adView
    }
}

class SearchNativeAdFactory(
    private val context: Context,
) : GoogleMobileAdsPlugin.NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        // Android 10 and older must not bind a search native ad. AdLoader has
        // already been refused from Dart; this is the native entry if one arrives.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            Log.w(searchAdTag, "AdMob search ad skipped below Android 11")
            return NativeAdView(context).apply {
                minimumHeight = context.feedDp(searchAdHeightDp)
            }
        }
        return try {
            buildSearchAd(nativeAd)
        } catch (error: RuntimeException) {
            Log.e(searchAdTag, "AdMob search native ad view failed", error)
            NativeAdView(context).apply {
                minimumHeight = context.feedDp(searchAdHeightDp)
                safeSetNativeAd(this, nativeAd)
            }
        }
    }

    private fun buildSearchAd(nativeAd: NativeAd): NativeAdView {
        fun dp(value: Int) = context.feedDp(value)
        // Inset every registered asset. Exact child sizes that exceed the
        // platform-view height, or a wrap-content AdChoices icon on the edge,
        // sit outside NativeAdView and fail the AdMob validator.
        val adView =
            NativeAdView(context).apply {
                setBackgroundColor(Color.TRANSPARENT)
                contentDescription = "Sponsored advertisement"
                clipChildren = true
                clipToPadding = true
                minimumHeight = dp(searchAdHeightDp)
                setPadding(dp(4), dp(6), dp(4), dp(6))
            }
        val row =
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                clipChildren = true
                setPadding(0, 0, dp(20), 0)
            }

        val iconDrawable = nativeAd.icon?.drawable
        val iconSize = dp(40)
        val icon =
            ImageView(context).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
                adjustViewBounds = false
                background =
                    GradientDrawable().apply {
                        cornerRadius = dp(8).toFloat()
                        setColor(feedWell)
                    }
                if (iconDrawable != null) setImageDrawable(iconDrawable)
            }

        val headline =
            TextView(context).apply {
                text = nativeAd.headline?.takeIf { it.isNotBlank() } ?: "Sponsored"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14f)
                setTypeface(typeface, Typeface.BOLD)
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                includeFontPadding = false
                gravity = Gravity.CENTER_VERTICAL
            }
        val advertiserText = nativeAd.advertiser?.takeIf { it.isNotBlank() }
        val advertiser =
            TextView(context).apply {
                text = advertiserText.orEmpty()
                setTextColor(feedMuted)
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12f)
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                includeFontPadding = false
                gravity = Gravity.CENTER_VERTICAL
                visibility = if (advertiserText == null) View.GONE else View.VISIBLE
            }
        val badge =
            TextView(context).apply {
                text = "Ad"
                setTextColor(feedMuted)
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12f)
                maxLines = 1
                includeFontPadding = false
                gravity = Gravity.CENTER_VERTICAL
            }
        val subtitle =
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                clipChildren = true
            }
        if (advertiserText != null) {
            subtitle.addView(
                advertiser,
                LinearLayout.LayoutParams(0, dp(16), 1f).apply {
                    marginEnd = dp(4)
                },
            )
        }
        subtitle.addView(
            badge,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                dp(16),
            ),
        )
        val textColumn =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_VERTICAL
                clipChildren = true
                addView(
                    headline,
                    LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        dp(18),
                    ),
                )
                addView(
                    subtitle,
                    LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        dp(16),
                    ).apply {
                        topMargin = dp(2)
                    },
                )
            }

        val callToActionText = nativeAd.callToAction?.takeIf { it.isNotBlank() }
        val callToAction =
            TextView(context).apply {
                text = callToActionText ?: "Open"
                setTextColor(Color.BLACK)
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12f)
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.CENTER
                includeFontPadding = false
                background =
                    GradientDrawable().apply {
                        setColor(feedGreen)
                        cornerRadius = dp(8).toFloat()
                    }
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                visibility = if (callToActionText == null) View.GONE else View.VISIBLE
            }

        row.addView(icon, LinearLayout.LayoutParams(iconSize, iconSize))
        row.addView(
            textColumn,
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(10)
                marginEnd = dp(8)
            },
        )
        row.addView(callToAction, LinearLayout.LayoutParams(dp(76), dp(28)))
        adView.addView(
            row,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        val adChoices = AdChoicesView(context)
        val adChoicesSize = dp(20)
        adView.addView(
            adChoices,
            FrameLayout.LayoutParams(
                adChoicesSize,
                adChoicesSize,
                Gravity.TOP or Gravity.END,
            ).apply {
                topMargin = dp(2)
                marginEnd = dp(2)
            },
        )

        adView.headlineView = headline
        adView.adChoicesView = adChoices
        if (iconDrawable != null) adView.iconView = icon
        if (advertiserText != null) adView.advertiserView = advertiser
        if (callToActionText != null) adView.callToActionView = callToAction
        safeSetNativeAd(adView, nativeAd)
        lockExact(icon, iconSize, iconSize)
        lockExact(headline, LinearLayout.LayoutParams.MATCH_PARENT, dp(18))
        if (advertiserText != null) {
            val params = advertiser.layoutParams
            if (params is LinearLayout.LayoutParams) {
                params.width = 0
                params.height = dp(16)
                params.weight = 1f
                advertiser.layoutParams = params
            }
        }
        lockExact(callToAction, dp(76), dp(28))
        lockExact(adChoices, adChoicesSize, adChoicesSize)
        return adView
    }
}

private fun lockExact(view: View, width: Int, height: Int) {
    val params = view.layoutParams ?: return
    params.width = width
    params.height = height
    view.layoutParams = params
}

private fun safeSetNativeAd(adView: NativeAdView, nativeAd: NativeAd) {
    try {
        adView.setNativeAd(nativeAd)
    } catch (error: RuntimeException) {
        Log.e(searchAdTag, "AdMob setNativeAd failed", error)
        destroyNativeAd(nativeAd)
    }
}
