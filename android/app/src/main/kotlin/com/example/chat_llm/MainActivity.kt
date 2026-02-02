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
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val TAG = "MainActivity"
        const val METHOD_CHANNEL = "com.example.chat_llm/notification"
        const val MAIN_METHOD_CHANNEL = "com.example.chat_llm/main"
        const val EVENT_CHANNEL = "com.example.chat_llm/notification_stream"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var notificationReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Main MethodChannel 설정 (파일 경로 등)
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
                            Log.d(TAG, "채팅방 업데이트 브로드캐스트 수신: $data")
                            eventSink?.success(data)
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

    @Suppress("BatteryLife")
    private fun openBatteryOptimizationSettings() {
        try {
            // 직접 배터리 최적화 제외 요청 (앱별)
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "배터리 최적화 설정 열기 실패: ${e.message}")
            // 실패 시 일반 배터리 최적화 설정 화면으로 이동
            try {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                startActivity(intent)
            } catch (e2: Exception) {
                Log.e(TAG, "배터리 설정 열기 실패: ${e2.message}")
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

    override fun onDestroy() {
        super.onDestroy()
        unregisterNotificationReceiver()
    }
}
