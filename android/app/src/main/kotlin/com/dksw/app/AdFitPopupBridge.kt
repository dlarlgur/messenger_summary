package com.dksw.app

import android.content.res.Configuration
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.UiThread
import androidx.fragment.app.FragmentActivity
import com.kakao.adfit.ads.AdError
import com.kakao.adfit.ads.popup.AdFitPopupAd
import com.kakao.adfit.ads.popup.AdFitPopupAdDialogFragment
import com.kakao.adfit.ads.popup.AdFitPopupAdLoader
import com.kakao.adfit.ads.popup.AdFitPopupAdRequest
import io.flutter.plugin.common.MethodChannel

/**
 * AdFit 앱 종료 / 앱 전환 팝업 광고 (공식 AdFitPopupAdLoader)
 */
class AdFitPopupBridge(
    private val activity: FragmentActivity,
) : AdFitPopupAdLoader.OnAdLoadListener {

    companion object {
        const val TAG = "AdFitPopupBridge"
    }

    private var exitLoader: AdFitPopupAdLoader? = null
    private var transitionLoader: AdFitPopupAdLoader? = null

    private var exitClientId: String? = null
    private var transitionClientId: String? = null

    private var pendingExitResult: MethodChannel.Result? = null
    private var pendingTransitionResult: MethodChannel.Result? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    /** HTTP_FAILED(일부 단말/망) 1회 자동 재시도 */
    private var exitHttpRetryScheduled = false
    private var transitionHttpRetryScheduled = false

    fun registerFragmentListener() {
        activity.supportFragmentManager.setFragmentResultListener(
            AdFitPopupAdDialogFragment.REQUEST_KEY_POPUP_AD,
            activity,
        ) { _, bundle ->
            val event = bundle.getString(AdFitPopupAdDialogFragment.BUNDLE_KEY_EVENT_TYPE) ?: return@setFragmentResultListener
            Log.d(TAG, "AdFit popup event: $event")

            when {
                pendingExitResult != null -> {
                    when (event) {
                        AdFitPopupAdDialogFragment.EVENT_POPUP_CANCELED -> {
                            // 샘플: 취소 시 앱 유지
                            finishPendingExit(false, mapOf("reason" to "cancelled"))
                        }
                        AdFitPopupAdDialogFragment.EVENT_EXIT_CONFIRMED,
                        AdFitPopupAdDialogFragment.EVENT_BACK_PRESSED,
                        AdFitPopupAdDialogFragment.EVENT_AD_CLICKED,
                        -> finishPendingExit(true)
                        else -> finishPendingExit(true)
                    }
                }
                pendingTransitionResult != null -> {
                    // 전환 광고: 닫히면 채팅 화면 pop
                    finishPendingTransition(true)
                }
            }
        }
    }

    fun destroy() {
        exitLoader?.destroy()
        exitLoader = null
        transitionLoader?.destroy()
        transitionLoader = null
        pendingExitResult?.error("DISPOSED", "activity destroyed", null)
        pendingExitResult = null
        pendingTransitionResult?.error("DISPOSED", "activity destroyed", null)
        pendingTransitionResult = null
    }

    fun showExitPopup(clientId: String, result: MethodChannel.Result) {
        if (clientId.isBlank()) {
            result.success(mapOf("ok" to false, "reason" to "empty_client_id", "type" to "exit"))
            return
        }
        if (pendingExitResult != null) {
            result.error("BUSY", "exit ad already pending", null)
            return
        }
        pendingExitResult = result
        exitHttpRetryScheduled = false

        val loader = getExitLoader(clientId)
        if (activity.isFinishing || activity.isDestroyed || loader.isDestroyed) {
            finishPendingExit(false, mapOf("reason" to "activity_invalid"))
            return
        }
        if (loader.isLoading) {
            finishPendingExit(false, mapOf("reason" to "loading"))
            return
        }
        if (loader.isBlockedByRequestPolicy) {
            finishPendingExit(false, mapOf("reason" to "blocked_by_policy"))
            return
        }
        if (activity.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE) {
            finishPendingExit(false, mapOf("reason" to "landscape"))
            return
        }
        if (activity.supportFragmentManager.findFragmentByTag(AdFitPopupAdDialogFragment.TAG) != null) {
            finishPendingExit(false, mapOf("reason" to "popup_already_showing"))
            return
        }

        val started = loader.loadAd(
            AdFitPopupAdRequest.build(AdFitPopupAd.Type.Exit),
            this,
        )
        if (!started) {
            finishPendingExit(false, mapOf("reason" to "load_not_started"))
        }
    }

    fun showTransitionPopup(clientId: String, result: MethodChannel.Result) {
        if (clientId.isBlank()) {
            result.success(mapOf("ok" to false, "reason" to "empty_client_id", "type" to "transition"))
            return
        }
        if (pendingTransitionResult != null) {
            result.error("BUSY", "transition ad already pending", null)
            return
        }
        pendingTransitionResult = result
        transitionHttpRetryScheduled = false

        val loader = getTransitionLoader(clientId)
        if (activity.isFinishing || activity.isDestroyed || loader.isDestroyed) {
            finishPendingTransition(false, mapOf("reason" to "activity_invalid"))
            return
        }
        if (loader.isLoading) {
            finishPendingTransition(false, mapOf("reason" to "loading"))
            return
        }
        if (loader.isBlockedByRequestPolicy) {
            finishPendingTransition(false, mapOf("reason" to "blocked_by_policy"))
            return
        }
        if (activity.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE) {
            finishPendingTransition(false, mapOf("reason" to "landscape"))
            return
        }
        if (activity.supportFragmentManager.findFragmentByTag(AdFitPopupAdDialogFragment.TAG) != null) {
            finishPendingTransition(false, mapOf("reason" to "popup_already_showing"))
            return
        }

        val started = loader.loadAd(
            AdFitPopupAdRequest.build(AdFitPopupAd.Type.Transition),
            this,
        )
        if (!started) {
            finishPendingTransition(false, mapOf("reason" to "load_not_started"))
        }
    }

    private fun getExitLoader(clientId: String): AdFitPopupAdLoader {
        if (exitLoader != null && exitClientId == clientId) {
            return exitLoader!!
        }
        exitLoader?.destroy()
        exitClientId = clientId
        exitLoader = AdFitPopupAdLoader.create(activity, clientId)
        return exitLoader!!
    }

    private fun getTransitionLoader(clientId: String): AdFitPopupAdLoader {
        if (transitionLoader != null && transitionClientId == clientId) {
            return transitionLoader!!
        }
        transitionLoader?.destroy()
        transitionClientId = clientId
        transitionLoader = AdFitPopupAdLoader.create(activity, clientId)
        return transitionLoader!!
    }

    @UiThread
    override fun onAdLoaded(ad: AdFitPopupAd) {
        if (activity.isFinishing || activity.isDestroyed) return
        exitHttpRetryScheduled = false
        transitionHttpRetryScheduled = false

        try {
            AdFitPopupAdDialogFragment.Builder(ad)
                .setNavigationBarColor(color = Color.BLACK, isLight = false)
                .build()
                .show(activity.supportFragmentManager, AdFitPopupAdDialogFragment.TAG)
        } catch (e: Exception) {
            Log.e(TAG, "show AdFit popup failed", e)
            if (pendingExitResult != null) {
                finishPendingExit(false, mapOf("reason" to "show_failed"))
            } else if (pendingTransitionResult != null) {
                finishPendingTransition(false, mapOf("reason" to "show_failed"))
            }
        }
    }

    @UiThread
    override fun onAdLoadError(errorCode: Int) {
        if (activity.isFinishing || activity.isDestroyed) return

        val clientHint = when {
            pendingExitResult != null -> exitClientId ?: "exit?"
            pendingTransitionResult != null -> transitionClientId ?: "transition?"
            else -> "?"
        }
        Log.w(TAG, "AdFit popup load error: errorCode=$errorCode clientId=$clientHint")
        val payload = mutableMapOf<String, Any>(
            "errorCode" to errorCode,
        )
        when (errorCode) {
            AdError.NO_AD.errorCode -> payload["reason"] = "no_ad"
            AdError.HTTP_FAILED.errorCode -> payload["reason"] = "http_failed"
            else -> payload["reason"] = "unknown"
        }

        if (pendingExitResult != null &&
            errorCode == AdError.HTTP_FAILED.errorCode &&
            !exitHttpRetryScheduled
        ) {
            exitHttpRetryScheduled = true
            val loader = exitLoader
            Log.i(TAG, "HTTP_FAILED — 1회 재요청 예약 (exit)")
            mainHandler.postDelayed({
                if (activity.isFinishing || activity.isDestroyed) return@postDelayed
                if (pendingExitResult == null) return@postDelayed
                val ld = loader ?: exitLoader
                if (ld == null || ld.isDestroyed || ld.isLoading || ld.isBlockedByRequestPolicy) {
                    exitHttpRetryScheduled = false
                    finishPendingExit(false, payload)
                    return@postDelayed
                }
                val started = ld.loadAd(
                    AdFitPopupAdRequest.build(AdFitPopupAd.Type.Exit),
                    this@AdFitPopupBridge,
                )
                if (!started) {
                    exitHttpRetryScheduled = false
                    payload["retry"] = "load_not_started"
                    finishPendingExit(false, payload)
                }
            }, 1000)
            return
        }

        if (pendingTransitionResult != null &&
            errorCode == AdError.HTTP_FAILED.errorCode &&
            !transitionHttpRetryScheduled
        ) {
            transitionHttpRetryScheduled = true
            val loader = transitionLoader
            Log.i(TAG, "HTTP_FAILED — 1회 재요청 예약 (transition)")
            mainHandler.postDelayed({
                if (activity.isFinishing || activity.isDestroyed) return@postDelayed
                if (pendingTransitionResult == null) return@postDelayed
                val ld = loader ?: transitionLoader
                if (ld == null || ld.isDestroyed || ld.isLoading || ld.isBlockedByRequestPolicy) {
                    transitionHttpRetryScheduled = false
                    finishPendingTransition(false, payload)
                    return@postDelayed
                }
                val started = ld.loadAd(
                    AdFitPopupAdRequest.build(AdFitPopupAd.Type.Transition),
                    this@AdFitPopupBridge,
                )
                if (!started) {
                    transitionHttpRetryScheduled = false
                    payload["retry"] = "load_not_started"
                    finishPendingTransition(false, payload)
                }
            }, 1000)
            return
        }

        exitHttpRetryScheduled = false
        transitionHttpRetryScheduled = false

        if (pendingExitResult != null) {
            finishPendingExit(false, payload)
        } else if (pendingTransitionResult != null) {
            finishPendingTransition(false, payload)
        }
    }

    private fun finishPendingExit(adShown: Boolean, extra: Map<String, Any>? = null) {
        val r = pendingExitResult ?: return
        pendingExitResult = null
        val map = mutableMapOf<String, Any>(
            "ok" to adShown,
            "type" to "exit",
        )
        extra?.let { map.putAll(it) }
        r.success(map)
    }

    private fun finishPendingTransition(adShown: Boolean, extra: Map<String, Any>? = null) {
        val r = pendingTransitionResult ?: return
        pendingTransitionResult = null
        val map = mutableMapOf<String, Any>(
            "ok" to adShown,
            "type" to "transition",
        )
        extra?.let { map.putAll(it) }
        r.success(map)
    }
}
