package com.dksw.app

import android.Manifest
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import com.google.android.play.core.integrity.IntegrityManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import com.google.android.play.core.integrity.IntegrityTokenResponse
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val TAG = "MainActivity"
        const val METHOD_CHANNEL = "com.dksw.app/notification"
        const val MAIN_METHOD_CHANNEL = "com.dksw.app/main"
        const val EVENT_CHANNEL = "com.dksw.app/notification_stream"
        const val PLAY_INTEGRITY_CHANNEL = "com.dksw.app/play_integrity"
        const val ADFIT_CHANNEL = "com.dksw.app/adfit"
        const val ADFIT_BANNER_VIEW_TYPE = "com.dksw.app/adfit_banner"
        const val ADFIT_NATIVE_LIST_VIEW_TYPE = "com.dksw.app/adfit_native_chat_list"
        const val ADFIT_NATIVE_TOP_VIEW_TYPE = "com.dksw.app/adfit_native_top"
        private const val REQUEST_CODE_POST_NOTIFICATIONS = 2001
    }

    private var adFitPopupBridge: AdFitPopupBridge? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    /**
     * TextureView 렌더링 모드 사용
     * SurfaceView(기본값)는 AdMob 전면광고 표시 중 앱 킬 후 재시작 시
     * Surface 재생성 타이밍 문제로 블랙화면이 발생할 수 있음.
     * TextureView는 뷰 계층에 통합되어 이 문제를 방지함.
     */
    override fun getRenderMode(): RenderMode = RenderMode.texture

    /**
     * 예열된 Flutter 엔진을 사용하도록 설정
     * MyApplication에서 미리 예열한 엔진을 재사용하여 즉시 화면 표시
     * 엔진이 없을 경우 null을 반환하여 새 엔진을 생성하도록 함
     */
    override fun getCachedEngineId(): String? {
        val cachedEngine = FlutterEngineCache.getInstance().get(MyApplication.FLUTTER_ENGINE_ID)
        return if (cachedEngine != null) {
            Log.d(TAG, "✅ 캐시된 Flutter 엔진 사용")
            MyApplication.FLUTTER_ENGINE_ID
        } else {
            Log.w(TAG, "⚠️ 캐시된 Flutter 엔진 없음 - 새 엔진 생성")
            null // null을 반환하면 FlutterActivity가 새 엔진을 생성함
        }
    }

    private var eventSink: EventChannel.EventSink? = null
    private var notificationReceiver: BroadcastReceiver? = null
    private var mainMethodChannel: MethodChannel? = null
    private var pendingSummaryId: Int = -1
    // MainActivity가 새로 생성된 경우(종료/스와이프 후 재실행) 인메모리 플래그로 표시
    // HOME 버튼 복귀는 onCreate가 호출되지 않으므로 플래그 미설정
    // SharedPreferences 대신 인메모리 플래그를 사용해 Dart 캐시 문제 회피
    private var isFreshLaunch: Boolean = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        isFreshLaunch = true // super.onCreate() 전에 설정해야 Flutter 질의 시점에 준비됨
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val summaryId = intent?.getIntExtra("summaryId", -1) ?: -1
        if (summaryId > 0) {
            Log.d(TAG, "summaryId 받음: $summaryId")
            pendingSummaryId = summaryId
            // SharedPreferences에도 저장 (백업용)
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putInt("flutter.pending_summary_id", summaryId).apply()
            // MethodChannel이 준비되어 있으면 즉시 전달
            mainMethodChannel?.invokeMethod("openSummary", summaryId)
        }

        // 페이월 알림 클릭 시 구독 화면 열기
        val openSubscription = intent?.getBooleanExtra("openSubscription", false) ?: false
        if (openSubscription) {
            Log.d(TAG, "openSubscription 받음 - 구독 화면 열기")
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.pending_open_subscription", true).apply()
            mainMethodChannel?.invokeMethod("openSubscription", null)
        }
        
        // OnboardingActivity에서 넘어왔는지 확인
        val fromOnboarding = intent?.getBooleanExtra("fromOnboarding", false) ?: false
        if (fromOnboarding) {
            Log.d(TAG, "OnboardingActivity에서 넘어옴 - 권한 확인 필요")
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.from_onboarding", true).apply()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Kakao AdFit 배너 (PlatformView)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            ADFIT_BANNER_VIEW_TYPE,
            AdFitBannerPlatformViewFactory(this),
        )
        flutterEngine.platformViewsController.registry.registerViewFactory(
            ADFIT_NATIVE_LIST_VIEW_TYPE,
            AdFitNativeListPlatformViewFactory(this),
        )
        flutterEngine.platformViewsController.registry.registerViewFactory(
            ADFIT_NATIVE_TOP_VIEW_TYPE,
            AdFitNativeTopPlatformViewFactory(this),
        )

        adFitPopupBridge = AdFitPopupBridge(this).also { it.registerFragmentListener() }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADFIT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showExitPopupAd" -> {
                    val clientId = call.argument<String>("clientId") ?: ""
                    adFitPopupBridge?.showExitPopup(clientId, result) ?: result.error("NO_BRIDGE", null, null)
                }
                "showTransitionPopupAd" -> {
                    val clientId = call.argument<String>("clientId") ?: ""
                    adFitPopupBridge?.showTransitionPopup(clientId, result) ?: result.error("NO_BRIDGE", null, null)
                }
                else -> result.notImplemented()
            }
        }

        // AdMob NativeAd 팩토리 (Flutter google_mobile_ads). iOS·폴백용.
        // Android 무료 플랜은 Dart에서 AdFit 배너 위주라 NativeAd를 만들지 않을 수 있으나, 플러그인 등록은 유지.
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "chatListNativeAd",
            NativeAdChatItemFactory(applicationContext)
        )
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "topNativeAd",
            NativeAdTopFactory(applicationContext)
        )

        // Main MethodChannel 설정 (파일 경로, 권한 확인 등)
        mainMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAIN_METHOD_CHANNEL)
        mainMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCacheDir" -> {
                    // Android의 cacheDir 경로를 Flutter에 전달
                    result.success(cacheDir?.absolutePath)
                }
                "getFilesDir" -> {
                    // Android의 filesDir 경로를 Flutter에 전달 (캐시 삭제해도 유지)
                    result.success(filesDir?.absolutePath)
                }
                "canDrawOverlays" -> {
                    result.success(canDrawOverlays())
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                "areNotificationsEnabled" -> {
                    result.success(areNotificationsEnabled())
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission(result)
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(true)
                }
                "getJwtToken" -> {
                    // Flutter에서 JWT 토큰 요청 시 SecureStorage에서 읽어서 반환
                    getJwtTokenFromSecureStorage(result)
                }
                "getPendingSummaryId" -> {
                    // 대기 중인 summaryId 반환
                    val summaryId = if (pendingSummaryId > 0) pendingSummaryId else {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.getInt("flutter.pending_summary_id", -1)
                    }
                    if (summaryId > 0) {
                        // 반환 후 초기화
                        pendingSummaryId = -1
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit().remove("flutter.pending_summary_id").apply()
                    }
                    result.success(if (summaryId > 0) summaryId else null)
                }
                "checkFreshLaunch" -> {
                    // 종료/스와이프 후 재실행 여부 반환 (읽은 후 즉시 초기화)
                    val wasFreshLaunch = isFreshLaunch
                    isFreshLaunch = false
                    result.success(wasFreshLaunch)
                }
                else -> result.notImplemented()
            }
        }
        
        // Flutter 엔진이 준비되면 대기 중인 summaryId 전달
        if (pendingSummaryId > 0) {
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                mainMethodChannel?.invokeMethod("openSummary", pendingSummaryId)
            }, 500) // Flutter가 완전히 초기화될 때까지 약간의 딜레이
        }

        // Play Integrity MethodChannel 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLAY_INTEGRITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestIntegrityToken" -> {
                    val cloudProjectNumber = call.argument<String>("cloudProjectNumber")
                    if (cloudProjectNumber != null) {
                        requestPlayIntegrityToken(cloudProjectNumber, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "cloudProjectNumber is required", null)
                    }
                }
                "getDeviceId" -> {
                    val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    Log.d(TAG, "Android ID 조회: ${androidId?.take(8)}...")
                    result.success(androidId)
                }
                else -> result.notImplemented()
            }
        }

        // Notification MethodChannel 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerEnabled" -> {
                    result.success(isNotificationServiceEnabled())
                }
                "openNotificationSettings" -> {
                    openNotificationListenerSettings()
                    result.success(true)
                }
                "isBatteryOptimizationDisabled" -> {
                    result.success(isBatteryOptimizationDisabled())
                }
                "openBatteryOptimizationSettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(true)
                }
                "canDrawOverlays" -> {
                    result.success(canDrawOverlays())
                }
                "openOverlaySettings" -> {
                    openOverlaySettings()
                    result.success(true)
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(true)
                }
                "areNotificationsEnabled" -> {
                    result.success(areNotificationsEnabled())
                }
                "cancelNotification" -> {
                    val key = call.argument<String>("key")
                    if (key != null) {
                        cancelNotification(key)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "key is required", null)
                    }
                }
                "cancelAllNotificationsForRoom" -> {
                    val roomName = call.argument<String>("roomName")
                    if (roomName != null) {
                        cancelAllNotificationsForRoom(roomName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "roomName is required", null)
                    }
                }
                "sendMessage" -> {
                    val roomIdValue = call.argument<Any>("roomId")
                    val roomId = when (roomIdValue) {
                        is Long -> roomIdValue
                        is Int -> roomIdValue.toLong()
                        is Number -> roomIdValue.toLong()
                        else -> null
                    }
                    val message = call.argument<String>("message")
                    if (roomId != null && roomId > 0 && message != null && message.isNotEmpty()) {
                        val success = sendMessage(roomId, message)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "roomId and message are required", null)
                    }
                }
                "getCacheDir" -> {
                    // Android의 cacheDir 경로를 Flutter에 전달 (하위 호환)
                    result.success(cacheDir?.absolutePath)
                }
                "updateNotificationBadge" -> {
                    val count = call.argument<Int>("count") ?: 0
                    updateNotificationBadge(count)
                    result.success(true)
                }
                "openApp" -> {
                    val packageName = call.argument<String>("packageName")
                    val scheme = call.argument<String?>("scheme")
                    val httpsUrl = call.argument<String?>("httpsUrl")
                    if (packageName != null) {
                        val success = openApp(packageName, scheme, httpsUrl)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "packageName is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel 설정
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerNotificationReceiver()
                    Log.d(TAG, "EventChannel 리스닝 시작")
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterNotificationReceiver()
                    Log.d(TAG, "EventChannel 리스닝 취소")
                }
            }
        )
    }

    private fun registerNotificationReceiver() {
        notificationReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                intent?.let {
                    when (it.action) {
                        NotificationListener.ACTION_NOTIFICATION_RECEIVED -> {
                            // 알림 타입 확인 (자동요약 알림인지 일반 알림인지)
                            val notificationType = it.getStringExtra("type") ?: "notification"
                            
                            if (notificationType == "auto_summary") {
                                // 자동요약 알림 처리
                                val data = mutableMapOf<String, Any>(
                                    "type" to "auto_summary",
                                    "packageName" to (it.getStringExtra("packageName") ?: ""),
                                    "sender" to (it.getStringExtra("sender") ?: ""),
                                    "message" to (it.getStringExtra("message") ?: ""),
                                    "roomName" to (it.getStringExtra("roomName") ?: ""),
                                    "postTime" to it.getLongExtra("postTime", 0),
                                    "isAutoSummary" to it.getBooleanExtra("isAutoSummary", false)
                                )
                                
                                // summaryId가 있으면 추가
                                val summaryId = it.getIntExtra("summaryId", -1)
                                if (summaryId != -1) {
                                    data["summaryId"] = summaryId
                                }
                                
                                Log.d(TAG, "🤖 자동요약 알림 브로드캐스트 수신: $data")
                                eventSink?.success(data)
                            } else {
                                // 일반 알림 수신 처리
                                val data = mapOf(
                                    "type" to "notification",
                                    "packageName" to (it.getStringExtra("packageName") ?: ""),
                                    "title" to (it.getStringExtra("title") ?: ""),
                                    "text" to (it.getStringExtra("text") ?: ""),
                                    "subText" to (it.getStringExtra("subText") ?: ""),
                                    "bigText" to (it.getStringExtra("bigText") ?: ""),
                                    "postTime" to it.getLongExtra("postTime", 0),
                                    "id" to it.getIntExtra("id", 0),
                                    "tag" to (it.getStringExtra("tag") ?: ""),
                                    "key" to (it.getStringExtra("key") ?: ""),
                                    "groupKey" to (it.getStringExtra("groupKey") ?: ""),
                                    "category" to (it.getStringExtra("category") ?: ""),
                                    "channelId" to (it.getStringExtra("channelId") ?: ""),
                                    "group" to (it.getStringExtra("group") ?: ""),
                                    "sortKey" to (it.getStringExtra("sortKey") ?: ""),
                                    "tickerText" to (it.getStringExtra("tickerText") ?: ""),
                                    "conversationTitle" to (it.getStringExtra("conversationTitle") ?: ""),
                                    "isGroupConversation" to it.getBooleanExtra("isGroupConversation", false),
                                    "allExtras" to (it.getStringExtra("allExtras") ?: "")
                                )
                                Log.d(TAG, "알림 브로드캐스트 수신: $data")
                                eventSink?.success(data)
                            }
                        }
                        NotificationListener.ACTION_ROOM_UPDATED -> {
                            // 채팅방 업데이트 (서버 응답) 처리
                            val data = mapOf(
                                "type" to "room_updated",
                                "roomId" to it.getLongExtra("roomId", 0),
                                "roomName" to (it.getStringExtra("roomName") ?: ""),
                                "unreadCount" to it.getIntExtra("unreadCount", 0),
                                "lastMessage" to (it.getStringExtra("lastMessage") ?: ""),
                                "lastMessageTime" to (it.getStringExtra("lastMessageTime") ?: ""),
                                "pinned" to it.getBooleanExtra("pinned", false),
                                "category" to (it.getStringExtra("category") ?: "DAILY")
                            )
                            Log.d(TAG, "✅ 채팅방 업데이트 브로드캐스트 수신: $data")
                            if (eventSink != null) {
                                eventSink?.success(data)
                                Log.d(TAG, "✅ Flutter로 채팅방 업데이트 이벤트 전송 완료")
                            } else {
                                Log.w(TAG, "⚠️ eventSink가 null - Flutter로 이벤트 전송 실패")
                            }
                        }
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(NotificationListener.ACTION_NOTIFICATION_RECEIVED)
            addAction(NotificationListener.ACTION_ROOM_UPDATED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notificationReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12-12L (API 31-32): targetSdk >= 31이면 반드시 exported 플래그 지정 필요
            // Context.RECEIVER_NOT_EXPORTED = 0x4 (API 33에서 정의되나 값은 동일)
            registerReceiver(notificationReceiver, filter, 0x4)
        } else {
            registerReceiver(notificationReceiver, filter)
        }
        Log.d(TAG, "BroadcastReceiver 등록됨 (알림 + 채팅방 업데이트)")
    }

    private fun unregisterNotificationReceiver() {
        notificationReceiver?.let {
            unregisterReceiver(it)
            notificationReceiver = null
            Log.d(TAG, "BroadcastReceiver 해제됨")
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val packageName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (!TextUtils.isEmpty(flat)) {
            val names = flat.split(":".toRegex())
            for (name in names) {
                val componentName = ComponentName.unflattenFromString(name)
                if (componentName != null && TextUtils.equals(packageName, componentName.packageName)) {
                    return true
                }
            }
        }
        return false
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        startActivity(intent)
    }

    /**
     * 메시지 전송 (NotificationListener의 sendMessage 호출)
     */
    private fun sendMessage(roomId: Long, message: String): Boolean {
        try {
            val intent = Intent(NotificationListener.ACTION_SEND_MESSAGE).apply {
                putExtra("roomId", roomId)
                putExtra("message", message)
                setPackage(packageName)
            }
            sendBroadcast(intent)
            Log.d(TAG, "메시지 전송 브로드캐스트 전송: roomId=$roomId, message=$message")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "메시지 전송 실패: ${e.message}", e)
            return false
        }
    }
    
    private fun isBatteryOptimizationDisabled(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true // Android 6.0 미만에서는 권한 필요 없음
        }
    }

    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                // 오버레이 권한 설정 화면으로 직접 이동
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                Log.d(TAG, "오버레이 권한 설정 화면으로 이동: package=$packageName")
            } catch (e: Exception) {
                Log.e(TAG, "오버레이 설정 화면 열기 실패: ${e.message}")
            }
        }
    }

    /**
     * FlutterSecureStorage에서 JWT 토큰 가져오기
     * FlutterSecureStorage는 복잡한 암호화를 사용하므로 직접 접근이 어려움
     * 대신 Flutter에서 토큰을 받아오는 방식 사용 (MethodChannel을 통해)
     */
    private fun getJwtTokenFromSecureStorage(result: MethodChannel.Result) {
        // FlutterSecureStorage는 복잡한 암호화를 사용하므로 직접 접근이 어려움
        // 대신 SharedPreferences에 별도로 저장된 토큰을 확인하거나
        // Flutter에서 토큰을 받아오는 방식 사용
        // 현재는 null 반환 (Flutter에서 토큰을 제공하도록 수정 필요)
        result.success(null)
    }

    private fun openAppSettings() {
        try {
            // 앱 설정 화면(애플리케이션 정보)으로 이동
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            Log.d(TAG, "앱 설정 화면으로 이동: package=$packageName")
        } catch (e: Exception) {
            Log.e(TAG, "앱 설정 화면 열기 실패: ${e.message}")
        }
    }

    private fun areNotificationsEnabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            NotificationManagerCompat.from(this).areNotificationsEnabled()
        } else {
            true // Android 12 이하는 항상 true
        }
    }

    /**
     * 알림 전송 권한(POST_NOTIFICATIONS) 요청.
     * - Android 13+: 네이티브 시스템 권한 다이얼로그 표시 (인앱 확인 팝업 없이 바로)
     * - Android 12 이하: POST_NOTIFICATIONS 런타임 권한 없음 → 앱 설정 화면 오픈
     * 결과: { granted: Boolean, fallbackToSettings: Boolean }
     */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (areNotificationsEnabled()) {
            result.success(mapOf("granted" to true, "fallbackToSettings" to false))
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (pendingNotificationPermissionResult != null) {
                result.error("BUSY", "notification permission already requesting", null)
                return
            }
            pendingNotificationPermissionResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_CODE_POST_NOTIFICATIONS,
            )
        } else {
            openAppSettings()
            result.success(mapOf("granted" to false, "fallbackToSettings" to true))
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE_POST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationPermissionResult?.success(
                mapOf("granted" to granted, "fallbackToSettings" to false),
            )
            pendingNotificationPermissionResult = null
        }
    }

    @Suppress("BatteryLife")
    private fun openBatteryOptimizationSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                // 배터리 최적화 제외 요청 다이얼로그 표시
                // "AI톡비서는 백그라운드에서 실행될 수 있으며, 배터리를 제한 없이 사용할 수 있습니다. 거부/허용" 다이얼로그가 표시됨
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                Log.d(TAG, "배터리 최적화 제외 요청 다이얼로그 표시: package=$packageName")
            } catch (e: Exception) {
                Log.e(TAG, "배터리 최적화 제외 요청 실패: ${e.message}")
                // 실패 시 일반 배터리 최적화 설정 화면으로 이동
                try {
                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(intent)
                    Log.d(TAG, "배터리 최적화 설정 화면으로 이동")
                } catch (e2: Exception) {
                    Log.e(TAG, "배터리 설정 열기 실패: ${e2.message}")
                }
            }
        }
    }

    private fun cancelNotification(key: String) {
        val intent = Intent(NotificationListener.ACTION_CANCEL_NOTIFICATION).apply {
            putExtra("key", key)
            setPackage(packageName)
        }
        sendBroadcast(intent)
        Log.d(TAG, "알림 취소 요청: $key")
    }

    private fun cancelAllNotificationsForRoom(roomName: String) {
        val intent = Intent(NotificationListener.ACTION_CANCEL_ROOM_NOTIFICATIONS).apply {
            putExtra("roomName", roomName)
            setPackage(packageName)
        }
        sendBroadcast(intent)
        Log.d(TAG, "채팅방 알림 취소 요청: $roomName")
    }

    /**
     * Play Integrity 토큰 요청
     */
    private fun requestPlayIntegrityToken(cloudProjectNumber: String, result: MethodChannel.Result) {
        try {
            // Play Integrity API는 Android 8.0 (API 26) 이상에서만 사용 가능
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                result.error("UNSUPPORTED", "Play Integrity requires Android 8.0 or higher", null)
                return
            }

            // Nonce 생성 (UUID를 Base64로 인코딩)
            val nonce = UUID.randomUUID().toString()
            Log.d(TAG, "Play Integrity 토큰 요청: cloudProjectNumber=$cloudProjectNumber, packageName=$packageName, nonce=$nonce")

            val integrityManager: IntegrityManager = IntegrityManagerFactory.create(applicationContext)
            val request = IntegrityTokenRequest.builder()
                .setCloudProjectNumber(cloudProjectNumber.toLong())
                .setNonce(nonce)  // Nonce 필수
                .build()
            
            integrityManager.requestIntegrityToken(request)
                .addOnSuccessListener { response: IntegrityTokenResponse ->
                    val token = response.token()
                    Log.d(TAG, "Play Integrity 토큰 요청 성공")
                    result.success(token)
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "Play Integrity 토큰 요청 실패: ${e.message}", e)
                    result.error("INTEGRITY_ERROR", e.message, null)
                }
        } catch (e: Exception) {
            Log.e(TAG, "Play Integrity 토큰 요청 실패: ${e.message}", e)
            result.error("ERROR", e.message, null)
        }
    }

    /**
     * 앱 열기 (100% 작동하는 fallback 체인)
     * 1. 앱 설치 여부 체크
     * 2. 딥링크 스킴 시도
     * 3. 실패 시 앱 실행 Intent 사용
     * 4. 실패 시 https fallback
     * 5. 실패 시 Play Store fallback
     */
    private fun openApp(packageName: String, scheme: String?, httpsUrl: String?): Boolean {
        // 1. 앱 설치 여부 체크
        val isAppInstalled = try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
        
        // 2. 딥링크 스킴 시도 (setPackage 포함)
        if (!scheme.isNullOrEmpty()) {
            try {
                val uri = Uri.parse(scheme)
                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    setPackage(packageName)
                }

                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}

            // 2-1. setPackage 없이 딥링크 재시도
            try {
                val uri = Uri.parse(scheme)
                val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}
        }
        
        // 3. 앱 실행 Intent 사용 (앱이 설치되어 있는 경우)
        if (isAppInstalled) {
            try {
                val intent = packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}
        }
        
        // 4. https fallback (웹으로 열기)
        if (!httpsUrl.isNullOrEmpty()) {
            try {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(httpsUrl)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}
        }
        
        // 5. Play Store fallback
        try {
            _openPlayStore(packageName)
            return false
        } catch (e: Exception) {
            Log.e(TAG, "앱 열기 실패: $packageName, ${e.message}")
            return false
        }
    }
    
    /**
     * 플레이스토어 열기
     */
    private fun _openPlayStore(packageName: String) {
        try {
            val playStoreUrl = "https://play.google.com/store/apps/details?id=$packageName"
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(playStoreUrl)).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            Log.d(TAG, "플레이스토어로 이동: $packageName")
        } catch (e: Exception) {
            Log.e(TAG, "플레이스토어 열기 실패: ${e.message}", e)
        }
    }

    /**
     * 알림 배지 업데이트 (Android 8.0 이상)
     * 참고: Android의 배지 API는 제조사별로 다를 수 있습니다.
     * 일부 기기에서는 작동하지 않을 수 있습니다.
     */
    private fun updateNotificationBadge(count: Int) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = NotificationManagerCompat.from(this)
                
                // Android 8.0 이상에서 배지 표시/숨김
                // 참고: setNotificationBadge()는 실제로는 존재하지 않을 수 있습니다.
                // 대신 Notification.Builder.setNumber()를 사용하여 알림에 숫자를 표시할 수 있습니다.
                // 하지만 앱 아이콘 배지는 제조사별로 다를 수 있습니다.
                
                // 대안: ShortcutManager를 사용하거나, 라이브러리(예: flutter_app_badger)를 사용할 수 있습니다.
                // 여기서는 로그만 출력하고, 실제 배지는 시스템이 자동으로 관리합니다.
                
                if (count > 0) {
                    Log.d(TAG, "✅ 알림 배지 업데이트 요청: $count (시스템이 자동으로 관리)")
                } else {
                    Log.d(TAG, "✅ 알림 배지 제거 요청 (시스템이 자동으로 관리)")
                }
                
                // 참고: 실제 앱 아이콘 배지를 설정하려면 flutter_app_badger 같은 패키지를 사용하는 것이 좋습니다.
                // 또는 Notification.Builder.setNumber()를 사용하여 알림 자체에 숫자를 표시할 수 있습니다.
            } else {
                Log.d(TAG, "⚠️ 알림 배지는 Android 8.0 이상에서만 지원됩니다")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 알림 배지 업데이트 실패: ${e.message}", e)
        }
    }

    /**
     * 포커스 복귀 시 Flutter View 강제 재드로우
     * AdActivity가 전면광고를 부분 로딩 상태로 표시하다 종료될 경우,
     * AdActivity가 설정한 Window 플래그(FLAG_FULLSCREEN 등)가 복원되지 않아
     * Flutter TextureView가 검은 화면으로 남을 수 있음.
     * onWindowFocusChanged(true) 시점에 decorView.invalidate()를 호출해 강제 재드로우.
     */
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            window.decorView.post {
                window.decorView.invalidate()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "chatListNativeAd")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "topNativeAd")
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        adFitPopupBridge?.destroy()
        adFitPopupBridge = null
        super.onDestroy()
        unregisterNotificationReceiver()
    }
}
