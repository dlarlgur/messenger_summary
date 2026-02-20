package com.dksw.app

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

/// 상단 고정 네이티브 광고 팩토리 (연한 회색 배경)
class NativeAdTopFactory(private val context: Context) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_top, null) as NativeAdView

        val iconView = nativeAdView.findViewById<ImageView>(R.id.ad_icon)
        val headlineView = nativeAdView.findViewById<TextView>(R.id.ad_headline)
        val bodyView = nativeAdView.findViewById<TextView>(R.id.ad_body)
        val ctaView = nativeAdView.findViewById<TextView>(R.id.ad_call_to_action)

        val icon = nativeAd.icon
        if (icon?.drawable != null) {
            iconView.setImageDrawable(icon.drawable)
        } else {
            iconView.setImageDrawable(null)
        }
        nativeAdView.iconView = iconView

        headlineView.text = nativeAd.headline ?: ""
        nativeAdView.headlineView = headlineView

        val body = nativeAd.body
        if (body.isNullOrEmpty()) {
            bodyView.visibility = View.GONE
        } else {
            bodyView.text = body
            bodyView.visibility = View.VISIBLE
        }
        nativeAdView.bodyView = bodyView

        val cta = nativeAd.callToAction
        if (cta.isNullOrEmpty()) {
            ctaView.visibility = View.INVISIBLE
        } else {
            ctaView.text = cta
            ctaView.visibility = View.VISIBLE
        }
        nativeAdView.callToActionView = ctaView

        nativeAdView.setNativeAd(nativeAd)
        return nativeAdView
    }
}
