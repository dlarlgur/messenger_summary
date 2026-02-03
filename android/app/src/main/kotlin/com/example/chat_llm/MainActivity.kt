package com.example.chat_llm

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import com.google.android.play.core.integrity.IntegrityManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import com.google.android.play.core.integrity.IntegrityTokenResponse
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        const val TAG = "MainActivity"
        const val METHOD_CHANNEL = "com.example.chat_llm/notification"
        const val MAIN_METHOD_CHANNEL = "com.example.chat_llm/main"
        const val EVENT_CHANNEL = "com.example.chat_llm/notification_stream"
        const val PLAY_INTEGRITY_CHANNEL = "com.dksw.chat_llm/play_integrity"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var notificationReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
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
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit().putInt("flutter.pending_summary_id", summaryId).apply()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Main MethodChannel 설정 (파일 경로, 권한 확인 등)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MAIN_METHOD_CHANNEL).setMethodCallHandler { call, result ->
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
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(true)
                }
                "getJwtToken" -> {
                    // Flutter에서 JWT 토큰 요청 시 SecureStorage에서 읽어서 반환
                    getJwtTokenFromSecureStorage(result)
                }
                else -> result.notImplemented()
            }
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
                            // 기존 알림 수신 처리
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
            Log.d(TAG, "Play Integrity 토큰 요청: cloudProjectNumber=$cloudProjectNumber, nonce=$nonce")

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

    override fun onDestroy() {
        super.onDestroy()
        unregisterNotificationReceiver()
    }
}
