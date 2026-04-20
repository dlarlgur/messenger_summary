package com.dksw.app

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import com.kakao.adfit.ads.AdError
import com.kakao.adfit.ads.na.AdFitAdInfoIconPosition
import com.kakao.adfit.ads.na.AdFitMediaView
import com.kakao.adfit.ads.na.AdFitNativeAdBinder
import com.kakao.adfit.ads.na.AdFitNativeAdLayout
import com.kakao.adfit.ads.na.AdFitNativeAdLoader
import com.kakao.adfit.ads.na.AdFitNativeAdRequest
import com.kakao.adfit.ads.na.AdFitNativeAdView
import com.kakao.adfit.ads.na.AdFitVideoAutoPlayPolicy
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

private const val TAG_NATIVE_TOP = "AdFitNativeTop"

/**
 * 채팅 목록 **상단** 슬롯 — Kakao AdFit 네이티브 (카드 레이아웃).
 *
 * 요청: [AdFitNativeAdLoader.create] + [AdFitNativeAdRequest.Builder]
 * (광고 정보 아이콘 위치, WiFi 전용 동영상 자동재생 등).
 * 바인딩: [AdFitNativeAdLayout.Builder] — 가이드의 필수/선택 요소에 맞게 구성.
 */
class AdFitNativeTopPlatformViewFactory(
    private val activity: Activity,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val clientId = params?.get("clientId") as? String ?: ""
        return AdFitNativeTopPlatformView(activity, clientId)
    }
}

private class AdFitNativeTopPlatformView(
    private val activity: Activity,
    private val clientId: String,
) : PlatformView, AdFitNativeAdLoader.AdLoadListener {

    private val root: View =
        LayoutInflater.from(activity).inflate(R.layout.adfit_native_top_card, null, false)

    private val placeholder: View = root.findViewById(R.id.adfit_placeholder)
    private val containerView: AdFitNativeAdView = root.findViewById(R.id.containerView)

    private var nativeAdLoader: AdFitNativeAdLoader? = null
    private var nativeAdBinder: AdFitNativeAdBinder? = null
    private var nativeAdLayout: AdFitNativeAdLayout? = null
    private var disposed = false
    private var nativeHttpRetryDone = false
    private val mainHandler = Handler(Looper.getMainLooper())

    private val nativeRequest: AdFitNativeAdRequest = AdFitNativeAdRequest.Builder()
        .setAdInfoIconPosition(AdFitAdInfoIconPosition.LEFT_BOTTOM)
        .setVideoAutoPlayPolicy(AdFitVideoAutoPlayPolicy.WIFI_ONLY)
        .build()

    init {
        if (clientId.isNotEmpty()) {
            nativeAdLoader = AdFitNativeAdLoader.create(activity, clientId)
            nativeAdLoader?.loadAd(nativeRequest, this)
        } else {
            placeholder.visibility = View.VISIBLE
            containerView.visibility = View.INVISIBLE
        }
    }

    override fun getView(): View {
        root.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
        )
        return root
    }

    override fun onAdLoaded(binder: AdFitNativeAdBinder) {
        if (disposed) {
            binder.unbind()
            return
        }
        if (activity is LifecycleOwner) {
            val state = activity.lifecycle.currentState
            if (state == Lifecycle.State.DESTROYED) {
                binder.unbind()
                return
            }
        }

        nativeAdBinder?.unbind()
        nativeAdBinder = binder

        if (nativeAdLayout == null) {
            val title = root.findViewById<TextView>(R.id.titleTextView)
            val body = root.findViewById<TextView>(R.id.bodyTextView)
            val profileIcon = root.findViewById<ImageView>(R.id.profileIconView)
            val profileName = root.findViewById<TextView>(R.id.profileNameTextView)
            val media = root.findViewById<AdFitMediaView>(R.id.mediaView)
            val cta = root.findViewById<Button>(R.id.callToActionButton)

            nativeAdLayout = AdFitNativeAdLayout.Builder(containerView)
                .setContainerViewClickable(true)
                .setTitleView(title)
                .setBodyView(body)
                .setProfileIconView(profileIcon)
                .setProfileNameView(profileName)
                .setMediaView(media)
                .setCallToActionButton(cta)
                .build()
        }

        binder.bind(nativeAdLayout!!)
        placeholder.visibility = View.GONE
        containerView.visibility = View.VISIBLE
        nativeHttpRetryDone = false
    }

    override fun onAdLoadError(errorCode: Int) {
        if (disposed) return
        Log.w(TAG_NATIVE_TOP, "onAdLoadError errorCode=$errorCode clientId=$clientId")
        if (!nativeHttpRetryDone && errorCode == AdError.HTTP_FAILED.errorCode && nativeAdLoader != null) {
            nativeHttpRetryDone = true
            Log.i(TAG_NATIVE_TOP, "HTTP_FAILED — native top 1회 재요청")
            mainHandler.postDelayed({
                if (disposed) return@postDelayed
                nativeAdLoader?.loadAd(nativeRequest, this)
            }, 900)
            return
        }
        if (nativeAdBinder == null) {
            placeholder.visibility = View.VISIBLE
            containerView.visibility = View.INVISIBLE
        }
    }

    override fun dispose() {
        disposed = true
        nativeAdBinder?.unbind()
        nativeAdBinder = null
        nativeAdLayout = null
        nativeAdLoader = null
    }
}
