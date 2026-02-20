package com.dksw.app

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

/// 채팅방 목록 아이템 스타일 네이티브 광고 팩토리
class NativeAdChatItemFactory(private val context: Context) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_chat_item, null) as NativeAdView

        val iconView = nativeAdView.findViewById<ImageView>(R.id.ad_icon)
        val headlineView = nativeAdView.findViewById<TextView>(R.id.ad_headline)
        val bodyView = nativeAdView.findViewById<TextView>(R.id.ad_body)
        val ctaView = nativeAdView.findViewById<TextView>(R.id.ad_call_to_action)

        // 아이콘 설정
        val icon = nativeAd.icon
        if (icon?.drawable != null) {
            iconView.setImageDrawable(icon.drawable)
        } else {
            // 아이콘 없을 때 기본 배경색(파란색 원)만 표시
            iconView.setImageDrawable(null)
        }
        nativeAdView.iconView = iconView

        // 헤드라인 (방 이름처럼)
        headlineView.text = nativeAd.headline ?: ""
        nativeAdView.headlineView = headlineView

        // 본문 (마지막 메시지처럼)
        val body = nativeAd.body
        if (body.isNullOrEmpty()) {
            bodyView.visibility = View.GONE
        } else {
            bodyView.text = body
            bodyView.visibility = View.VISIBLE
        }
        nativeAdView.bodyView = bodyView

        // CTA 버튼 (알아보기 등)
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
