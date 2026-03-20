package com.dksw.app

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.widget.FrameLayout
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.kakao.adfit.ads.AdError
import com.kakao.adfit.ads.AdListener
import com.kakao.adfit.ads.ba.BannerAdView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Flutter [AndroidView]용 Kakao AdFit 배너 (공식 SDK BannerAdView)
 */
class AdFitBannerPlatformViewFactory(
    private val activity: Activity,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val clientId = params?.get("clientId") as? String ?: ""
        val heightDp = (params?.get("heightDp") as? Number)?.toFloat() ?: 100f
        val heightPx = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            heightDp,
            context.resources.displayMetrics,
        ).toInt()

        return AdFitBannerPlatformView(activity, clientId, heightPx)
    }
}

private class AdFitBannerPlatformView(
    private val activity: Activity,
    private val clientId: String,
    heightPx: Int,
) : PlatformView {

    private var bannerRetryDone = false
    private val mainHandler = Handler(Looper.getMainLooper())

    private val bannerView: BannerAdView = BannerAdView(activity).apply {
        layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            heightPx,
        )
        if (clientId.isNotEmpty()) {
            setClientId(clientId)
            setAdListener(object : AdListener {
                override fun onAdLoaded() {
                    Log.d("AdFitBanner", "onAdLoaded clientId=$clientId")
                }

                override fun onAdFailed(errorCode: Int) {
                    Log.w("AdFitBanner", "onAdFailed errorCode=$errorCode clientId=$clientId")
                    if (!bannerRetryDone && errorCode == AdError.HTTP_FAILED.errorCode) {
                        bannerRetryDone = true
                        mainHandler.postDelayed({
                            if (activity.isDestroyed) return@postDelayed
                            Log.i("AdFitBanner", "retry loadAd after HTTP_FAILED")
                            loadAd()
                        }, 900)
                    }
                }

                override fun onAdClicked() {}
            })
            loadAd()
        }
    }

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onResume(owner: LifecycleOwner) {
            bannerView.resume()
        }

        override fun onPause(owner: LifecycleOwner) {
            bannerView.pause()
        }

        override fun onDestroy(owner: LifecycleOwner) {
            bannerView.destroy()
        }
    }

    init {
        if (activity is LifecycleOwner) {
            activity.lifecycle.addObserver(lifecycleObserver)
        }
    }

    override fun getView(): View = bannerView

    override fun dispose() {
        if (activity is LifecycleOwner) {
            activity.lifecycle.removeObserver(lifecycleObserver)
        }
        bannerView.destroy()
    }
}
