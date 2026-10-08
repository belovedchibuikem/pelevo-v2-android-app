package com.podemeraldltd.pelevo

import android.content.Context
import android.graphics.Color
import android.graphics.Outline
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
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

private fun roundedOutline(radiusPx: Float) =
    object : ViewOutlineProvider() {
        override fun getOutline(view: View, outline: Outline) {
            outline.setRoundRect(0, 0, view.width, view.height, radiusPx)
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
            }
        val adChoices = AdChoicesView(context)
        val mediaFrame = FrameLayout(context)
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
                0,
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
        val density = context.resources.displayMetrics.density
        fun dp(value: Int) = context.feedDp(value)

        val adView =
            NativeAdView(context).apply {
                setBackgroundColor(Color.TRANSPARENT)
                contentDescription = "Sponsored advertisement"
            }
        val row =
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
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
        val adChoices = AdChoicesView(context)
        val iconFrame = FrameLayout(context)
        iconFrame.addView(icon, FrameLayout.LayoutParams(dp(56), dp(56)))
        iconFrame.addView(
            adChoices,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP or Gravity.END,
            ),
        )

        val headline =
            TextView(context).apply {
                text = nativeAd.headline
                setTextColor(Color.WHITE)
                textSize = 14f
                setTypeface(typeface, Typeface.BOLD)
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
            }
        val advertiser =
            TextView(context).apply {
                text = nativeAd.advertiser.orEmpty()
                setTextColor(feedMuted)
                textSize = 12f
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                maxWidth = dp(180)
                visibility = if (nativeAd.advertiser.isNullOrBlank()) View.GONE else View.VISIBLE
            }
        val badge =
            TextView(context).apply {
                text = if (nativeAd.advertiser.isNullOrBlank()) "Ad" else "· Ad"
                setTextColor(feedMuted)
                textSize = 12f
                maxLines = 1
            }
        val subtitle =
            LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(
                    advertiser,
                    LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ),
                )
                addView(
                    badge,
                    LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT,
                    ).apply {
                        marginStart = if (nativeAd.advertiser.isNullOrBlank()) 0 else dp(4)
                    },
                )
            }
        val textColumn =
            LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                addView(headline)
                addView(subtitle)
            }

        val callToAction =
            TextView(context).apply {
                text = nativeAd.callToAction ?: "Open"
                setTextColor(Color.BLACK)
                textSize = 12f
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.CENTER
                background =
                    GradientDrawable().apply {
                        setColor(feedGreen)
                        cornerRadius = dp(8).toFloat()
                    }
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                maxWidth = dp(96)
                setPadding(dp(12), dp(6), dp(12), dp(6))
            }

        row.addView(iconFrame, LinearLayout.LayoutParams(dp(56), dp(56)))
        row.addView(
            textColumn,
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(12)
                marginEnd = dp(12)
            },
        )
        row.addView(
            callToAction,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                dp(32),
            ),
        )
        adView.addView(
            row,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER_VERTICAL,
            ),
        )

        adView.iconView = icon
        adView.headlineView = headline
        adView.advertiserView = advertiser
        adView.callToActionView = callToAction
        adView.adChoicesView = adChoices
        adView.setNativeAd(nativeAd)
        advertiser.visibility = if (nativeAd.advertiser.isNullOrBlank()) View.GONE else View.VISIBLE
        badge.text = if (nativeAd.advertiser.isNullOrBlank()) "Ad" else "· Ad"
        return adView
    }
}
