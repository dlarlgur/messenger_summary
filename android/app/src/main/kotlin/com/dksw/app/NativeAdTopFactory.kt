package com.dksw.app

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

/// 상단 고정 네이티브 광고 팩토리 (배너 스타일: 왼쪽 텍스트 + 오른쪽 큰 이미지)
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
        val mediaView = nativeAdView.findViewById<MediaView>(R.id.ad_media)

        // 아이콘
        val icon = nativeAd.icon
        if (icon?.drawable != null) {
            iconView.setImageDrawable(icon.drawable)
            iconView.visibility = View.VISIBLE
        } else {
            iconView.visibility = View.GONE
        }
        nativeAdView.iconView = iconView

        // 헤드라인
        headlineView.text = nativeAd.headline ?: ""
        nativeAdView.headlineView = headlineView

        // 본문
        val body = nativeAd.body
        if (body.isNullOrEmpty()) {
            bodyView.visibility = View.GONE
        } else {
            bodyView.text = body
            bodyView.visibility = View.VISIBLE
        }
        nativeAdView.bodyView = bodyView

        // CTA
        val cta = nativeAd.callToAction
        if (cta.isNullOrEmpty()) {
            ctaView.visibility = View.INVISIBLE
        } else {
            ctaView.text = cta
            ctaView.visibility = View.VISIBLE
        }
        nativeAdView.callToActionView = ctaView

        // 미디어 이미지 (오른쪽 큰 이미지)
        nativeAdView.mediaView = mediaView

        nativeAdView.setNativeAd(nativeAd)
        return nativeAdView
    }
}
