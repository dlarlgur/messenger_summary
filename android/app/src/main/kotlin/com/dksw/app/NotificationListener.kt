package com.dksw.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.io.File
import java.io.FileOutputStream
import org.json.JSONArray
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.net.URLDecoder
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import kotlinx.coroutines.*
import java.util.concurrent.TimeUnit

class NotificationListener : NotificationListenerService() {
    companion object {
        const val TAG = "NotificationListener"
        const val ACTION_NOTIFICATION_RECEIVED = "com.dksw.app.NOTIFICATION_RECEIVED"
        const val ACTION_CANCEL_NOTIFICATION = "com.dksw.app.CANCEL_NOTIFICATION"
        const val ACTION_CANCEL_ROOM_NOTIFICATIONS = "com.dksw.app.CANCEL_ROOM_NOTIFICATIONS"
        const val ACTION_ROOM_UPDATED = "com.dksw.app.ROOM_UPDATED"
        const val ACTION_SEND_MESSAGE = "com.dksw.app.SEND_MESSAGE"

        // 알림 수신 대상 메신저 (전체 등록 목록)
        val ALL_MESSENGERS = mapOf(
            "com.kakao.talk" to "카카오톡",
            "jp.naver.line.android" to "LINE",
            "org.telegram.messenger" to "Telegram",
            "com.instagram.android" to "Instagram",
            "com.Slack" to "Slack",
            "com.microsoft.teams" to "Teams",
            "com.facebook.orca" to "Messenger"
        )

        // SharedPreferences 키 (활성 메신저 목록)
        const val ENABLED_MESSENGERS_KEY = "flutter.enabled_messengers"

        // Flutter SharedPreferences 키 (음소거 설정용)
        const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
        const val MUTED_ROOMS_KEY = "flutter.muted_rooms"
        const val AUTO_SUMMARY_NOTIFICATION_ENABLED_KEY = "flutter.auto_summary_notification_enabled"
        const val VIBRATION_ENABLED_KEY = "flutter.notification_vibration_enabled"
        const val SOUND_ENABLED_KEY = "flutter.notification_sound_enabled"
        
        // Onboarding SharedPreferences 키 (동의 여부 확인용)
        const val ONBOARDING_PREFS_NAME = "onboarding_prefs"
        const val KEY_AGREEMENT = "agreement_accepted"
        
        // 자동 요약 API 설정
        const val SUMMARY_API_BASE_URL = "https://api.dksw4.com"
        const val SUMMARY_API_ENDPOINT = "/api/v1/llm/summary"
        const val USAGE_API_ENDPOINT = "/api/v1/llm/usage"

        // 자동 요약 알림 채널
        const val AUTO_SUMMARY_CHANNEL_ID = "auto_summary_channel"
        const val AUTO_SUMMARY_CHANNEL_NAME = "자동 요약 알림"

        // FREE 유저 페이월 알림 설정
        const val FREE_UNREAD_THRESHOLD = 50  // FREE 유저 메시지 제한 임계값
        const val PAYWALL_NOTIF_COOLDOWN_MS = 24 * 60 * 60 * 1000L  // 24시간 쿨다운
        const val PLAN_TYPE_KEY = "flutter.plan_type"  // SharedPreferences 플랜 캐시 키
    }

    private var cancelReceiver: BroadcastReceiver? = null
    private var sendMessageReceiver: BroadcastReceiver? = null
    
    // OkHttp 클라이언트 (자동 요약 API 호출용)
    private val okHttpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()
    
    // 코루틴 스코프
    private val autoSummaryScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    // ✅ 메시지 저장용 코루틴 스코프 (알림 삭제는 즉시, 저장은 백그라운드)
    private val messageSaveScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // 자동 요약 진행 중인 채팅방 ID (중복 실행 방지)
    private val autoSummaryInProgress = mutableSetOf<Long>()

    // 로그 샘플링 카운터 (성능 최적화 - 배터리/성능 영향 최소화)
    // Long으로 선언하여 overflow 방지, 주기적 reset으로 메모리 최적화
    private var logCounter = 0L
    private val logSampleRate = 50L // 50개 중 1개만 로그 출력
    private val logResetThreshold = 10000L // 10000개마다 리셋하여 overflow 방지

    // ★★★ 디버그 모드: true로 설정하면 모든 알림 데이터를 상세히 로그 출력 ★★★
    private val DEBUG_NOTIFICATION_DATA = false
    
    // roomId -> 최신 PendingIntent 및 RemoteInput 캐시 (메모리)
    private data class ReplyIntentData(
        val pendingIntent: PendingIntent,
        val remoteInput: RemoteInput?,
        val actionTitle: String?
    )
    private val replyIntentCache = mutableMapOf<Long, ReplyIntentData>()

    /**
     * ★★★ 디버그용: 알림 데이터 전체 덤프 ★★★
     * 채팅 유형(단톡/오픈/개인)과 메시지 유형(텍스트/이모티콘/사진/링크) 분석
     */
    @Suppress("DEPRECATION")
    private fun dumpNotificationData(sbn: StatusBarNotification, extras: Bundle) {
        val TAG_DEBUG = "📋DUMP"

        // 기본 정보
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
        val isGroupConversation = extras.getBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION, false)

        // 빈 알림이나 요약 알림은 스킵
        if (title.isEmpty() && text.isEmpty()) {
            Log.d(TAG_DEBUG, "⏭️ 빈 알림 스킵 (subText: $subText)")
            return
        }

        // 채팅 유형 판단
        val chatType = when {
            subText.isEmpty() && !isGroupConversation -> "개인톡"
            isGroupConversation -> if (subText.contains("오픈채팅") || subText.contains("Open")) "오픈채팅" else "단톡"
            else -> "단톡"
        }
        val roomName = if (subText.isEmpty()) title else subText
        val sender = if (subText.isEmpty()) title else title

        Log.i(TAG_DEBUG, "")
        Log.i(TAG_DEBUG, "╔══════════════════════════════════════════════════════════════")
        Log.i(TAG_DEBUG, "║ 📱 채팅 유형: $chatType")
        Log.i(TAG_DEBUG, "║ 🏠 대화방: $roomName")
        Log.i(TAG_DEBUG, "║ 👤 발신자: $sender")
        Log.i(TAG_DEBUG, "║ 💬 메시지: $text")
        Log.i(TAG_DEBUG, "╠══════════════════════════════════════════════════════════════")

        // 메시지 유형 판단
        val msgType = when {
            text.contains("이모티콘") -> "이모티콘"
            text.contains("사진") || text == "사진을 보냈습니다." -> "사진"
            text.contains("http://") || text.contains("https://") -> "링크"
            text.contains("동영상") -> "동영상"
            text.contains("파일") -> "파일"
            else -> "텍스트"
        }
        Log.i(TAG_DEBUG, "║ 📝 메시지 유형: $msgType")
        Log.i(TAG_DEBUG, "╠══════════════════════════════════════════════════════════════")

        // 핵심 extras 정보
        Log.i(TAG_DEBUG, "║ [기본 extras]")
        Log.i(TAG_DEBUG, "║   title: '$title'")
        Log.i(TAG_DEBUG, "║   text: '$text'")
        Log.i(TAG_DEBUG, "║   subText: '$subText'")
        Log.i(TAG_DEBUG, "║   isGroupConversation: $isGroupConversation")

        // EXTRA_MESSAGES 분석 (가장 중요)
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        Log.i(TAG_DEBUG, "╠══════════════════════════════════════════════════════════════")
        Log.i(TAG_DEBUG, "║ [EXTRA_MESSAGES] 개수: ${messages?.size ?: 0}")

        if (messages != null && messages.isNotEmpty()) {
            messages.forEachIndexed { index, msg ->
                if (msg is Bundle) {
                    Log.i(TAG_DEBUG, "║   ── messages[$index] ──")
                    for (key in msg.keySet()) {
                        val value = msg.get(key)
                        val valueStr = when (value) {
                            is Bundle -> "Bundle(${value.keySet().joinToString(", ")})"
                            is android.net.Uri -> "Uri: $value"
                            is android.app.Person -> "Person(name=${value.name}, key=${value.key})"
                            is Bitmap -> "Bitmap(${value.width}x${value.height})"
                            else -> value?.toString()?.take(100) ?: "null"
                        }
                        Log.i(TAG_DEBUG, "║     $key: $valueStr")
                    }
                }
            }
        }

        // 이미지 관련 키 확인
        Log.i(TAG_DEBUG, "╠══════════════════════════════════════════════════════════════")
        Log.i(TAG_DEBUG, "║ [이미지 관련]")
        val hasReducedImages = extras.getBoolean("android.reduced.images", false)
        Log.i(TAG_DEBUG, "║   reduced.images: $hasReducedImages")

        // EXTRA_PICTURE 확인
        val picture = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            extras.getParcelable(Notification.EXTRA_PICTURE, Bitmap::class.java)
        } else {
            extras.getParcelable(Notification.EXTRA_PICTURE) as? Bitmap
        }
        Log.i(TAG_DEBUG, "║   EXTRA_PICTURE: ${if (picture != null) "${picture.width}x${picture.height}" else "null"}")

        // LargeIcon 확인
        val largeIcon = sbn.notification.getLargeIcon()
        if (largeIcon != null) {
            try {
                val drawable = largeIcon.loadDrawable(applicationContext)
                Log.i(TAG_DEBUG, "║   largeIcon: ${drawable?.intrinsicWidth}x${drawable?.intrinsicHeight}")
            } catch (e: Exception) {
                Log.i(TAG_DEBUG, "║   largeIcon: 로드 실패")
            }
        } else {
            Log.i(TAG_DEBUG, "║   largeIcon: null")
        }

        // 모든 extras 키 출력
        Log.i(TAG_DEBUG, "╠══════════════════════════════════════════════════════════════")
        Log.i(TAG_DEBUG, "║ [모든 extras 키]")
        for (key in extras.keySet()) {
            if (key.startsWith("android.") && !key.contains("messages") && !key.contains("title") && !key.contains("text")) {
                val value = extras.get(key)
                val valueType = value?.javaClass?.simpleName ?: "null"
                val valueStr = when (value) {
                    is Bundle -> "Bundle(${value.keySet().size} keys)"
                    is Array<*> -> "Array(${value.size})"
                    is Bitmap -> "Bitmap(${value.width}x${value.height})"
                    is Boolean, is Int, is Long -> value.toString()
                    is String -> if (value.length > 50) "${value.take(50)}..." else value
                    else -> valueType
                }
                Log.i(TAG_DEBUG, "║   $key: $valueStr")
            }
        }

        // StatusBarNotification 레벨 식별자
        Log.i(TAG_DEBUG, "╠══════════════════════════════════════════════════════════════")
        Log.i(TAG_DEBUG, "║ [SBN 식별자]")
        Log.i(TAG_DEBUG, "║   key: ${sbn.key}")
        Log.i(TAG_DEBUG, "║   tag: ${sbn.tag ?: "null"}")
        Log.i(TAG_DEBUG, "║   groupKey: ${sbn.groupKey ?: "null"}")
        Log.i(TAG_DEBUG, "║   notification.group: ${sbn.notification.group ?: "null"}")
        Log.i(TAG_DEBUG, "║   id: ${sbn.id}")
        Log.i(TAG_DEBUG, "║   notification.channelId: ${sbn.notification.channelId ?: "null"}")
        Log.i(TAG_DEBUG, "║   notification.shortcutId: ${sbn.notification.shortcutId ?: "null"}")

        Log.i(TAG_DEBUG, "╚══════════════════════════════════════════════════════════════")
        Log.i(TAG_DEBUG, "")
    }

    /**
     * 문자열을 SHA-256 해시로 변환
     * 파일명 충돌 방지 및 안전한 파일명 생성용
     */
    private fun sha256(input: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }.substring(0, 16) // 16자만 사용
    }

    /**
     * 안전한 sender 프로필 파일명 생성
     * packageName + roomName + senderName 조합으로 고유 키 생성
     */
    private fun getSenderProfileKey(packageName: String, roomName: String, senderName: String): String {
        val uniqueKey = "$packageName|$roomName|$senderName"
        return sha256(uniqueKey)
    }

    /**
     * 채널인지 확인 (Slack의 경우 roomName이 "#"으로 시작하거나 "xxx / #yyy" 형식)
     */
    private fun isChannel(roomName: String, packageName: String): Boolean {
        return packageName == "com.Slack" && (roomName.startsWith("#") || roomName.contains(" / #"))
    }

    /**
     * 대화방 프로필 사진을 앱 filesDir에 저장 (캐시 삭제해도 유지)
     * 저장 경로: /data/data/com.dksw.app/files/profile/room/{roomName}.jpg
     * 채널인 경우 저장하지 않음
     */
    private fun saveRoomProfileImage(roomName: String, bitmap: Bitmap?, packageName: String = "com.kakao.talk") {
        if (bitmap == null) {
            Log.w(TAG, "⚠️ 대화방 프로필 이미지 저장 스킵: bitmap이 null, roomName='$roomName'")
            return
        }
        
        if (isChannel(roomName, packageName)) {
            Log.d(TAG, "⏭️ 채널 대화방 - 프로필 이미지 저장 스킵: roomName='$roomName'")
            return
        }

        try {
            val safeRoomName = roomName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
            val safePackageName = packageName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
            
            // 메신저별 폴더에 저장
            val profileDir = File(applicationContext.filesDir, "profile/room/$safePackageName")
            if (!profileDir.exists()) {
                val created = profileDir.mkdirs()
                Log.d(TAG, "📁 프로필 디렉토리 생성: ${profileDir.absolutePath} (성공: $created)")
            }

            val profileFile = File(profileDir, "$safeRoomName.jpg")
            FileOutputStream(profileFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                out.flush()
            }
            
            // 하위 호환성: 기존 경로에도 복사 (Flutter가 아직 기존 경로를 확인할 수 있도록)
            val legacyProfileDir = File(applicationContext.filesDir, "profile/room")
            if (!legacyProfileDir.exists()) {
                legacyProfileDir.mkdirs()
            }
            val legacyProfileFile = File(legacyProfileDir, "$safeRoomName.jpg")
            try {
                profileFile.copyTo(legacyProfileFile, overwrite = true)
                Log.d(TAG, "📋 하위 호환성: 기존 경로에도 복사: ${legacyProfileFile.absolutePath}")
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ 기존 경로 복사 실패 (무시): ${e.message}")
            }
            
            val fileSize = profileFile.length()
            Log.i(TAG, "✅ 대화방 프로필 이미지 저장 성공: roomName='$roomName', packageName='$packageName', 경로=${profileFile.absolutePath}, 크기=$fileSize bytes")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 대화방 프로필 사진 저장 실패: roomName='$roomName', packageName='$packageName', ${e.message}", e)
        }
    }

    /**
     * 보낸사람 프로필 사진을 앱 filesDir에 저장 (캐시 삭제해도 유지)
     * 저장 경로: /data/data/com.dksw.app/files/profile/sender/{hash}.jpg
     * 해시 기반 파일명으로 충돌 방지 (packageName + roomName + senderName)
     * 채널인 경우 저장하지 않음
     */
    private fun saveSenderProfileImage(
        packageName: String,
        roomName: String,
        senderName: String,
        bitmap: Bitmap?
    ) {
        if (bitmap == null || senderName.isEmpty() || roomName.isEmpty()) {
            Log.d(TAG, "보낸사람 프로필 사진 저장 스킵: senderName='$senderName', roomName='$roomName', bitmap=${bitmap != null}")
            return
        }
        
        if (isChannel(roomName, packageName)) return

        try {
            val profileDir = File(applicationContext.filesDir, "profile/sender")
            if (!profileDir.exists()) {
                val created = profileDir.mkdirs()
                Log.d(TAG, "프로필 디렉토리 생성: ${profileDir.absolutePath} (성공: $created)")
            }

            // 해시 기반 파일명 생성 (충돌 방지)
            val fileKey = getSenderProfileKey(packageName, roomName, senderName)
            val profileFile = File(profileDir, "$fileKey.jpg")
            
            FileOutputStream(profileFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                out.flush()
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 보낸사람 프로필 사진 저장 실패: senderName='$senderName', ${e.message}", e)
        }
    }

    /**
     * 카카오톡 알림에서 이미지를 추출하여 대화방별 폴더에 저장
     * @return 저장된 이미지 파일 경로 (실패 시 null)
     */
    /**
     * 알림에서 받은 이미지를 앱 내부 저장소에 저장 (갤러리에 보이지 않음)
     * @param roomName 대화방 이름
     * @param bitmap 저장할 이미지 Bitmap
     * @param postTime 알림 시간 (파일명 생성용)
     * @return 저장된 이미지의 절대 경로, 실패 시 null
     */
    private fun saveNotificationImage(roomName: String, bitmap: Bitmap?, postTime: Long, packageName: String = "com.kakao.talk"): String? {
        if (bitmap == null) {
            Log.w(TAG, "이미지 저장 실패: bitmap이 null")
            return null
        }

        val safeRoomName = roomName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val safePackageName = packageName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val fileName = "img_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date(postTime))}.jpg"

        try {
            // 앱 내부 저장소 사용 (갤러리에 보이지 않음) - 메신저별 분리
            val imagesDir = File(applicationContext.filesDir, "images/$safePackageName/$safeRoomName")
            if (!imagesDir.exists()) {
                val created = imagesDir.mkdirs()
                if (!created) {
                    Log.e(TAG, "이미지 디렉토리 생성 실패: ${imagesDir.absolutePath}")
                    return null
                }
                Log.d(TAG, "이미지 디렉토리 생성: ${imagesDir.absolutePath}")
            }

            val imageFile = File(imagesDir, fileName)
            FileOutputStream(imageFile).use { out ->
                val compressed = bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                if (!compressed) {
                    Log.e(TAG, "이미지 압축 실패")
                    return null
                }
                out.flush()
            }
            
            // 파일 저장 확인
            if (!imageFile.exists() || imageFile.length() == 0L) {
                Log.e(TAG, "이미지 파일 저장 실패: 파일이 존재하지 않거나 크기가 0")
                return null
            }
            
            val absolutePath = imageFile.absolutePath
            Log.i(TAG, "✅ 이미지 저장 완료 (앱 내부 저장소): $absolutePath (크기: ${imageFile.length()} bytes)")
            return absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "❌ 이미지 저장 실패: ${e.message}", e)
            e.printStackTrace()
        }
        return null
    }

    /**
     * Notification에서 답장용 PendingIntent 및 RemoteInput 추출
     * reply action을 우선적으로 찾고, 없으면 contentIntent 사용
     */
    private fun extractReplyIntentData(notification: Notification): ReplyIntentData? {
        try {
            // 1. reply action의 PendingIntent 우선 시도 (RemoteInput 사용 가능)
            val actions = notification.actions
            if (actions != null) {
                for (action in actions) {
                    val remoteInputs = action.remoteInputs
                    if (remoteInputs != null && remoteInputs.isNotEmpty()) {
                        // RemoteInput이 있으면 reply action
                        val replyIntent = action.actionIntent
                        if (replyIntent != null) {
                            val actionTitle = action.title?.toString() ?: ""
                            val remoteInput = remoteInputs[0]  // 첫 번째 RemoteInput 사용
                            Log.d(TAG, "✅ reply action 발견: $actionTitle, RemoteInput key: ${remoteInput.resultKey}")
                            return ReplyIntentData(replyIntent, remoteInput, actionTitle)
                        }
                    }
                }
            }
            
            // 2. contentIntent 시도 (알림 클릭 시 실행되는 Intent)
            val contentIntent = notification.contentIntent
            if (contentIntent != null) {
                Log.d(TAG, "✅ contentIntent 발견 (RemoteInput 없음)")
                return ReplyIntentData(contentIntent, null, null)
            }
            
            Log.d(TAG, "⚠️ 답장용 PendingIntent를 찾을 수 없음")
            return null
        } catch (e: Exception) {
            Log.e(TAG, "❌ PendingIntent 추출 실패: ${e.message}", e)
            return null
        }
    }
    
    /**
     * Notification에서 답장용 PendingIntent 추출 (하위 호환용)
     */
    private fun extractReplyIntent(notification: Notification): String? {
        val replyData = extractReplyIntentData(notification)
        return if (replyData != null) {
            if (replyData.remoteInput != null) "reply" else "content"
        } else null
    }
    
    /**
     * Notification에서 공유된 사진/이모티콘 Bitmap 추출 (BigPictureStyle + MessagingStyle)
     * 이모티콘과 사진은 알림 형식이 다르므로 분기 처리
     * @param notification Notification 객체 (largeIcon 접근용)
     * @param extras Notification extras Bundle
     * @param messageText 메시지 텍스트 (이모티콘/사진 구분용)
     */
    @Suppress("DEPRECATION")
    private fun extractSharedImage(notification: Notification, extras: Bundle, messageText: String = ""): Bitmap? {
        // 이모티콘/스티커 여부 확인
        val isEmojiOrSticker = messageText.contains("이모티콘", ignoreCase = true) ||
                               messageText.contains("스티커", ignoreCase = true)

        if (isEmojiOrSticker) {
            return extractEmojiOrStickerImage(extras)
        }

        return extractPhotoImage(notification, extras)
    }
    
    /**
     * 이모티콘/스티커 이미지 추출 (Message Bundle의 URI에서)
     */
    @Suppress("DEPRECATION")
    private fun extractEmojiOrStickerImage(extras: Bundle): Bitmap? {
        Log.i(TAG, "🎨 ========== 이모티콘/스티커 이미지 추출 시작 ==========")
        
        try {
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (messages != null && messages.isNotEmpty()) {
                val latestMessage = messages[messages.size - 1] as? Bundle
                if (latestMessage != null) {
                    // 1. Bundle에서 직접 Bitmap 찾기
                    for (key in latestMessage.keySet()) {
                        val value = latestMessage.get(key)
                        if (value is Bitmap) return value
                    }

                    // 2. URI 확인
                    var uri: android.net.Uri? = null
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        uri = latestMessage.getParcelable("uri", android.net.Uri::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        uri = latestMessage.getParcelable("uri") as? android.net.Uri
                    }
                    if (uri == null) {
                        val uriStr = latestMessage.getString("uri")
                        if (!uriStr.isNullOrEmpty()) {
                            try { uri = android.net.Uri.parse(uriStr) } catch (_: Exception) {}
                        }
                    }

                    val mimeType = latestMessage.getString("type") ?: ""
                    if (uri != null) {
                        val uriString = uri.toString()
                        val isEmoticonPath = uriString.contains("emoticon_dir", ignoreCase = true) ||
                                            uriString.contains("sticker", ignoreCase = true)
                        if (mimeType.startsWith("image/") || isEmoticonPath || mimeType.isEmpty()) {
                            val bitmap = loadBitmapFromUri(uri)
                            if (bitmap != null) return bitmap
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "이모티콘 이미지 추출 실패: ${e.message}")
        }

        return null
    }
    
    /**
     * 일반 사진 이미지 추출 (EXTRA_PICTURE, largeIcon 등에서)
     * ⚠️ 복구: LargeIcon에서 사진 추출 로직 활성화 (크기 조건 200x200 이상)
     */
    @Suppress("DEPRECATION")
    private fun extractPhotoImage(notification: Notification, extras: Bundle): Bitmap? {
        val hasReducedImages = extras.getBoolean("android.reduced.images", false)

        // 0.5. extras의 모든 Bundle을 재귀적으로 탐색
        val recursiveBitmap = findBitmapRecursively(extras, maxDepth = 5)
        if (recursiveBitmap != null) {
            Log.i(TAG, "✅ 재귀적 검색으로 Bitmap 발견 (크기: ${recursiveBitmap.width}x${recursiveBitmap.height})")
            return recursiveBitmap
        }
        
        // android.reduced.images가 true일 때 추가 확인
        if (hasReducedImages) {
            for (key in extras.keySet()) {
                val value = extras.get(key)
                if (value is Bundle) {
                    for (bundleKey in value.keySet()) {
                        val bundleValue = value.get(bundleKey)
                        if (bundleValue is Bitmap) return bundleValue
                        else if (bundleValue is android.net.Uri) {
                            val bitmap = loadBitmapFromUri(bundleValue)
                            if (bitmap != null) return bitmap
                        }
                    }
                }
            }
        }
        
        // 1. EXTRA_PICTURE (BigPictureStyle에서 사용하는 큰 이미지 - 공유된 사진)
        val picture = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            extras.getParcelable(Notification.EXTRA_PICTURE, Bitmap::class.java)
        } else {
            extras.getParcelable(Notification.EXTRA_PICTURE) as? Bitmap
        }
        if (picture != null) return picture
        
        // 2. 다른 가능한 이미지 키들 확인
        val imageKeys = listOf(
            "android.picture", "android.bigPicture",
            "picture", "big_picture"
        )
        for (key in imageKeys) {
            if (extras.containsKey(key)) {
                val image = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    extras.getParcelable(key, Bitmap::class.java)
                } else {
                    extras.getParcelable(key) as? Bitmap
                }
                if (image != null) return image
            }
        }

        // 3. MessagingStyle 메시지에서 이미지 URI 추출 시도 (사진용)
        try {
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (messages != null && messages.isNotEmpty()) {
                // 모든 메시지에서 Bitmap 직접 확인
                for (i in messages.size - 1 downTo 0) {
                    val msg = messages[i] as? Bundle
                    if (msg != null) {
                        for (key in msg.keySet()) {
                            val value = msg.get(key)
                            if (value is Bitmap && (value.width > 200 || value.height > 200)) return value
                        }
                        val bitmap = findBitmapRecursively(msg, maxDepth = 3)
                        if (bitmap != null) return bitmap
                    }
                }

                // 가장 최신 메시지에서 이미지 URI 확인
                val latestMessage = messages[messages.size - 1] as? Bundle
                if (latestMessage != null) {
                    var uri: android.net.Uri? = null
                    
                    // 가능한 모든 URI 키 이름 시도
                    val uriKeys = listOf(
                        "uri", "data_uri", "android.remoteInputDataUri",
                        "android.messages.uri", "android.messages.data_uri",
                        "remote_input_data_uri", "shared_image_uri"
                    )
                    
                    // 방법 1: Uri 객체로 직접 가져오기
                    for (key in uriKeys) {
                        if (uri != null) break
                        
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            uri = latestMessage.getParcelable(key, android.net.Uri::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            uri = latestMessage.getParcelable(key) as? android.net.Uri
                        }
                        
                        if (uri != null) break
                    }
                    
                    // 방법 2: String으로 가져오기 (Uri 객체가 아닌 경우)
                    if (uri == null) {
                        for (key in uriKeys) {
                            val uriStr = latestMessage.getString(key)
                            if (uriStr != null && uriStr.isNotEmpty()) {
                                try {
                                    uri = android.net.Uri.parse(uriStr)
                                    break
                                } catch (_: Exception) {}
                            }
                        }
                    }
                    
                    // 방법 3: extras Bundle 내부에서 URI 찾기 (모든 키 확인)
                    if (uri == null) {
                        val extrasBundle = latestMessage.getBundle("extras")
                        if (extrasBundle != null) {
                            // 먼저 uriKeys로 시도
                            for (key in uriKeys) {
                                // Uri 객체로 시도
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    uri = extrasBundle.getParcelable(key, android.net.Uri::class.java)
                                } else {
                                    @Suppress("DEPRECATION")
                                    uri = extrasBundle.getParcelable(key) as? android.net.Uri
                                }
                                
                                if (uri != null) break
                                
                                // String으로 시도
                                val uriStr = extrasBundle.getString(key)
                                if (uriStr != null && uriStr.isNotEmpty()) {
                                    try {
                                        uri = android.net.Uri.parse(uriStr)
                                        break
                                    } catch (_: Exception) {}
                                }
                            }
                            
                            // uriKeys로 찾지 못했으면 모든 키를 확인 (오픈채팅 대응)
                            if (uri == null) {
                                for (key in extrasBundle.keySet()) {
                                    val value = extrasBundle.get(key)
                                    if (value is android.net.Uri) {
                                        uri = value
                                        break
                                    } else if (value is String && value.startsWith("content://")) {
                                        try {
                                            uri = android.net.Uri.parse(value)
                                            break
                                        } catch (_: Exception) {}
                                    }
                                }
                            }
                        }
                    }
                    
                    // 방법 4: 모든 메시지에서 이미지 URI 찾기 (오픈채팅 대응 - 최신 메시지에서 못 찾았을 때)
                    if (uri == null && messages != null && messages.size > 1) {
                        for (i in messages.size - 2 downTo 0) {
                            val msg = messages[i] as? Bundle
                            if (msg != null) {
                                // 각 메시지의 모든 키 확인
                                for (key in msg.keySet()) {
                                    val value = msg.get(key)
                                    if (value is android.net.Uri) {
                                        uri = value
                                        break
                                    } else if (value is String && value.startsWith("content://")) {
                                        try {
                                            uri = android.net.Uri.parse(value)
                                            break
                                        } catch (e: Exception) {
                                            // 무시
                                        }
                                    }
                                }
                                if (uri != null) break
                            }
                        }
                    }
                    
                    // MIME 타입 확인 (가능한 모든 키 시도)
                    val mimeTypeKeys = listOf(
                        "type", "data_mime_type", "mime_type",
                        "android.messages.type", "android.messages.data_mime_type"
                    )
                    
                    var mimeType = ""
                    for (key in mimeTypeKeys) {
                        val type = latestMessage.getString(key)
                        if (type != null && type.isNotEmpty()) {
                            mimeType = type
                            break
                        }
                    }

                    // 사진용 URI 추출: 이모티콘/스티커 경로는 제외
                    if (uri != null) {
                        val uriString = uri.toString()
                        val isEmoticonPath = uriString.contains("emoticon_dir", ignoreCase = true) ||
                                            uriString.contains("sticker", ignoreCase = true)

                        if (!isEmoticonPath && (mimeType.startsWith("image/") || mimeType.isEmpty())) {
                            val bitmap = loadBitmapFromUri(uri)
                            if (bitmap != null && (bitmap.width >= 200 || bitmap.height >= 200)) {
                                return bitmap
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "MessagingStyle 사진 추출 실패: ${e.message}")
        }

        // ⚠️ 복구: 마지막 수단으로 LargeIcon에서 이미지 추출 시도
        // 다른 방법이 모두 실패한 경우에만 LargeIcon 확인
        // 카카오톡에서 사진/이모티콘 알림 시 LargeIcon에 썸네일이 있을 수 있음
        val largeIcon = notification.getLargeIcon()
        if (largeIcon != null) {
            try {
                val drawable = largeIcon.loadDrawable(applicationContext)
                if (drawable != null && drawable.intrinsicWidth > 0 && drawable.intrinsicHeight > 0) {
                    val bitmap = Bitmap.createBitmap(
                        drawable.intrinsicWidth,
                        drawable.intrinsicHeight,
                        Bitmap.Config.ARGB_8888
                    )
                    val canvas = Canvas(bitmap)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)

                    // 200x200 이상인 경우에만 사진으로 간주 (프로필은 보통 168x168 정도)
                    if (bitmap.width >= 200 || bitmap.height >= 200) return bitmap
                }
            } catch (e: Exception) {
                Log.w(TAG, "LargeIcon에서 이미지 추출 실패: ${e.message}")
            }
        }

        return null
    }

    /**
     * Bundle을 재귀적으로 탐색하여 Bitmap 또는 Uri 찾기
     * @param bundle 탐색할 Bundle
     * @param maxDepth 최대 탐색 깊이 (무한 루프 방지)
     * @return 찾은 Bitmap 또는 null
     */
    @Suppress("DEPRECATION")
    private fun findBitmapRecursively(bundle: Bundle, maxDepth: Int = 5, currentDepth: Int = 0): Bitmap? {
        if (currentDepth >= maxDepth) {
            return null
        }
        
        try {
            for (key in bundle.keySet()) {
                val value = bundle.get(key)
                
                // Bitmap 직접 발견
                if (value is Bitmap) {
                    if (value.width > 200 || value.height > 200) return value
                }
                
                // Uri 발견
                if (value is android.net.Uri) {
                    val uriString = value.toString()
                    // 이모티콘/스티커 경로는 제외
                    if (!uriString.contains("emoticon_dir", ignoreCase = true) && 
                        !uriString.contains("sticker", ignoreCase = true)) {
                        val bitmap = loadBitmapFromUri(value)
                        if (bitmap != null && (bitmap.width > 200 || bitmap.height > 200)) return bitmap
                    }
                }
                
                // String이 content://로 시작하는 경우
                if (value is String && value.startsWith("content://")) {
                    try {
                        val uri = android.net.Uri.parse(value)
                        val uriString = uri.toString()
                        if (!uriString.contains("emoticon_dir", ignoreCase = true) && 
                            !uriString.contains("sticker", ignoreCase = true)) {
                            val bitmap = loadBitmapFromUri(uri)
                            if (bitmap != null && (bitmap.width > 200 || bitmap.height > 200)) return bitmap
                        }
                    } catch (e: Exception) {
                        // 무시
                    }
                }
                
                // Bundle인 경우 재귀적으로 탐색
                if (value is Bundle) {
                    val nestedBitmap = findBitmapRecursively(value, maxDepth, currentDepth + 1)
                    if (nestedBitmap != null) {
                        return nestedBitmap
                    }
                }
                
                // ParcelableArray인 경우 각 요소 확인
                if (value is Array<*>) {
                    for (item in value) {
                        if (item is Bundle) {
                            val nestedBitmap = findBitmapRecursively(item, maxDepth, currentDepth + 1)
                            if (nestedBitmap != null) {
                                return nestedBitmap
                            }
                        } else if (item is Bitmap && (item.width > 200 || item.height > 200)) {
                            return item
                        }
                    }
                }
            }
        } catch (e: Exception) {
            // 재귀 검색 중 오류 무시
        }
        
        return null
    }
    
    /**
     * FileProvider URI에서 실제 파일 경로 추출
     * 카카오톡 FileProvider URI: 
     *   - content://com.kakao.talk.FileProvider/external_files/emulated/0/...
     *   - content://com.kakao.talk.FileProvider/external_cache/emoticon_dir/...
     * 실제 경로: /storage/emulated/0/... 또는 /storage/emulated/0/Android/data/com.kakao.talk/cache/...
     */
    private fun extractFilePathFromFileProviderUri(uri: android.net.Uri): String? {
        val uriString = uri.toString()
        
        // FileProvider URI 패턴 확인
        if (uriString.contains("FileProvider")) {
            try {
                // external_cache/emoticon_dir/... 형식 처리
                val cachePattern = Regex("content://[^/]+/FileProvider/external_cache/(.+)")
                val cacheMatch = cachePattern.find(uriString)
                if (cacheMatch != null && cacheMatch.groupValues.size >= 2) {
                    val cachePath = cacheMatch.groupValues[1]
                    // 여러 가능한 경로 시도
                    val possiblePaths = listOf(
                        "/storage/emulated/0/Android/data/com.kakao.talk/cache/$cachePath",
                        "/data/data/com.kakao.talk/cache/$cachePath"
                    )
                    
                    for (filePath in possiblePaths) {
                        val file = java.io.File(filePath)
                        if (file.exists() && file.canRead()) {
                            Log.d(TAG, "FileProvider URI에서 경로 추출 (external_cache): $uriString -> $filePath")
                            return filePath
                        }
                    }
                    
                    // 경로가 존재하지 않아도 첫 번째 경로 반환 (시도해볼 수 있도록)
                    val defaultPath = "/storage/emulated/0/Android/data/com.kakao.talk/cache/$cachePath"
                    Log.d(TAG, "FileProvider URI에서 경로 추출 시도 (external_cache, 기본 경로): $uriString -> $defaultPath")
                    return defaultPath
                }
                
                // ⚠️ 보수적 수정: content://com.kakao.talk.FileProvider/external_files/emulated/0/... 형식
                // 또는 content://com.kakao.talk.FileProvider/external_files/0/... 형식
                // URL 디코딩을 먼저 수행하여 %3D%3D 같은 인코딩 처리
                val decodedUriString = try {
                    URLDecoder.decode(uriString, java.nio.charset.StandardCharsets.UTF_8)
                } catch (e: Exception) {
                    uriString
                }
                
                val pattern = Regex("content://[^/]+/external_files/(?:emulated/)?(\\d+)/(.+)")
                val match = pattern.find(decodedUriString)
                if (match != null && match.groupValues.size >= 3) {
                    val storageNumber = match.groupValues[1] // "0"
                    val path = match.groupValues[2] // 나머지 경로
                    if (path.isNotEmpty()) {
                        // 이미 디코딩되었으므로 추가 디코딩 불필요
                        val decodedPath = if (path.contains("%")) {
                            URLDecoder.decode(path, java.nio.charset.StandardCharsets.UTF_8)
                        } else {
                            path
                        }
                        // /storage/emulated/0/... 형식으로 변환
                        val filePath = "/storage/emulated/$storageNumber/$decodedPath"
                        Log.d(TAG, "FileProvider URI에서 경로 추출: $uriString -> $filePath")
                        return filePath
                    }
                } else {
                    // 다른 패턴 시도: external_files/ 다음 부분만 추출
                    val altPattern = Regex("content://[^/]+/external_files/(.+)")
                    val altMatch = altPattern.find(decodedUriString)
                    if (altMatch != null && altMatch.groupValues.size >= 2) {
                        val path = altMatch.groupValues[1]
                        if (path.isNotEmpty() && !path.startsWith("emulated/")) {
                            // emulated/0이 이미 포함되어 있지 않은 경우
                            val decodedPath = URLDecoder.decode(path, java.nio.charset.StandardCharsets.UTF_8)
                            val filePath = "/storage/emulated/0/$decodedPath"
                            Log.d(TAG, "FileProvider URI에서 경로 추출 (대체 패턴): $uriString -> $filePath")
                            return filePath
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "FileProvider URI 경로 추출 실패: $uriString, ${e.message}")
            }
        }
        
        return null
    }
    
    /**
     * content:// URI에서 Bitmap 로드
     * ⚠️ 복구: FileProvider URI인 경우 먼저 파일 경로로 직접 접근 시도
     * ContentResolver보다 파일 경로 직접 접근이 더 성공 확률이 높음
     */
    private fun loadBitmapFromUri(uri: android.net.Uri): Bitmap? {
        // ⚠️ 복구: FileProvider URI인 경우 먼저 파일 경로로 직접 접근 시도
        // ContentResolver보다 파일 경로 직접 접근이 더 성공 확률이 높음
        val uriString = uri.toString()
        if (uriString.contains("FileProvider")) {
            val filePath = extractFilePathFromFileProviderUri(uri)
            if (filePath != null) {
                try {
                    val file = File(filePath)
                    if (file.exists() && file.canRead()) {
                        Log.d(TAG, "FileProvider URI를 파일 경로로 변환하여 먼저 로드 시도: $filePath")
                        val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            try {
                                val source = android.graphics.ImageDecoder.createSource(file)
                                android.graphics.ImageDecoder.decodeBitmap(source)
                            } catch (e: Exception) {
                                android.graphics.BitmapFactory.decodeFile(filePath)
                            }
                        } else {
                            android.graphics.BitmapFactory.decodeFile(filePath)
                        }

                        if (bitmap != null) {
                            Log.i(TAG, "✅ 파일 경로에서 Bitmap 로드 성공: $filePath (크기: ${bitmap.width}x${bitmap.height})")
                            return bitmap
                        }
                    } else {
                        Log.d(TAG, "⚠️ 파일이 존재하지 않거나 읽을 수 없음 (먼저 시도): $filePath")
                    }
                } catch (e: SecurityException) {
                    Log.d(TAG, "⚠️ 파일 경로 접근 권한 없음 (SecurityException): $filePath")
                } catch (e: Exception) {
                    Log.d(TAG, "⚠️ 파일 경로에서 Bitmap 로드 실패: $filePath, ${e.message}")
                }
            }
        }

        // ContentResolver.openInputStream()을 사용하여 직접 읽기 시도
        return try {
            val resolver = applicationContext.contentResolver

            // 방법 1: ContentResolver.openInputStream() 사용
            resolver.openInputStream(uri)?.use { inputStream ->
                val bitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
                if (bitmap != null) {
                    Log.i(TAG, "✅ URI에서 Bitmap 로드 성공 (InputStream): $uri (크기: ${bitmap.width}x${bitmap.height})")
                    return bitmap
                } else {
                    Log.d(TAG, "⚠️ URI에서 Bitmap 로드 실패 (bitmap이 null): $uri")
                }
            }
            
            // 방법 2: ImageDecoder 사용 (Android P 이상)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                try {
                    val source = android.graphics.ImageDecoder.createSource(resolver, uri)
                    val bitmap = android.graphics.ImageDecoder.decodeBitmap(source)
                    if (bitmap != null) {
                        Log.i(TAG, "✅ URI에서 Bitmap 로드 성공 (ImageDecoder): $uri (크기: ${bitmap.width}x${bitmap.height})")
                        return bitmap
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "⚠️ ImageDecoder로 로드 실패: $uri, ${e.message}")
                }
            }
            
            // 방법 3: MediaStore 사용 (레거시)
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
                try {
                    @Suppress("DEPRECATION")
                    val bitmap = android.provider.MediaStore.Images.Media.getBitmap(resolver, uri)
                    if (bitmap != null) {
                        Log.i(TAG, "✅ URI에서 Bitmap 로드 성공 (MediaStore): $uri (크기: ${bitmap.width}x${bitmap.height})")
                        return bitmap
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "⚠️ MediaStore로 로드 실패: $uri, ${e.message}")
                }
            }
            
            null
        } catch (e: SecurityException) {
            // ⚠️ 파일 경로 시도는 이미 함수 시작에서 했으므로 재시도하지 않음 (성능 개선)
            Log.w(TAG, "🔒 SecurityException - URI 접근 권한 없음: $uri")
            null
        } catch (e: java.io.FileNotFoundException) {
            Log.d(TAG, "⚠️ URI에서 Bitmap 로드 실패 (파일 없음): $uri")
            null
        } catch (e: Exception) {
            Log.d(TAG, "⚠️ URI에서 Bitmap 로드 실패: $uri, ${e.message}")
            null
        }
    }

    /**
     * Notification에서 보낸사람의 개별 프로필 사진 Bitmap 추출
     * - 그룹톡/오픈톡: MessagingStyle의 Message Bundle에서 sender(Person).icon 추출
     * - 개인톡: LargeIcon이 곧 상대방 프로필이므로 사용
     * @param isPrivateChat 개인톡 여부 (true면 LargeIcon을 보낸사람 프로필로 사용)
     */
    @Suppress("DEPRECATION")
    private fun extractSenderProfileImage(notification: Notification, extras: Bundle, isPrivateChat: Boolean): Bitmap? {
        // 1. MessagingStyle의 Message Bundle에서 sender(Person).icon 추출 시도
        try {
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (messages != null && messages.isNotEmpty()) {
                val messageBundle = messages[messages.size - 1] as? Bundle
                    ?: messages[0] as? Bundle

                if (messageBundle != null) {
                    val sender: android.app.Person? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        messageBundle.getParcelable("sender_person", android.app.Person::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        messageBundle.getParcelable("sender_person") as? android.app.Person
                    }

                    if (sender?.icon != null) {
                        val drawable = sender.icon!!.loadDrawable(applicationContext)
                        if (drawable != null && drawable.intrinsicWidth > 0 && drawable.intrinsicHeight > 0) {
                            val bitmap = Bitmap.createBitmap(
                                drawable.intrinsicWidth,
                                drawable.intrinsicHeight,
                                Bitmap.Config.ARGB_8888
                            )
                            val canvas = android.graphics.Canvas(bitmap)
                            drawable.setBounds(0, 0, canvas.width, canvas.height)
                            drawable.draw(canvas)
                            return bitmap
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "sender.icon 추출 실패: ${e.message}")
        }

        // 2. extras에서 people.list 확인
        try {
            val peopleList = extras.getParcelableArrayList<android.app.Person>("android.people.list")
            peopleList?.forEach { person ->
                if (person.icon != null) {
                    val drawable = person.icon?.loadDrawable(applicationContext)
                    if (drawable != null && drawable.intrinsicWidth > 0) {
                        val bitmap = Bitmap.createBitmap(
                            drawable.intrinsicWidth,
                            drawable.intrinsicHeight,
                            Bitmap.Config.ARGB_8888
                        )
                        val canvas = android.graphics.Canvas(bitmap)
                        drawable.setBounds(0, 0, canvas.width, canvas.height)
                        drawable.draw(canvas)
                        return bitmap
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "people.list 프로필 확인 실패: ${e.message}")
        }

        // 3. 개인톡의 경우에만 LargeIcon을 보낸사람 프로필로 사용
        if (isPrivateChat) {
            val largeIconBitmap = extractRoomProfileImage(notification)
            if (largeIconBitmap != null) return largeIconBitmap
        }

        return null
    }

    /**
     * Notification에서 대화방 프로필 사진 Bitmap 추출 (LargeIcon)
     */
    private fun extractRoomProfileImage(notification: Notification): Bitmap? {
        val largeIcon = notification.getLargeIcon() ?: return null

        return try {
            val drawable = largeIcon.loadDrawable(applicationContext)
            if (drawable != null && drawable.intrinsicWidth > 0 && drawable.intrinsicHeight > 0) {
                val bitmap = Bitmap.createBitmap(
                    drawable.intrinsicWidth,
                    drawable.intrinsicHeight,
                    Bitmap.Config.ARGB_8888
                )
                val canvas = android.graphics.Canvas(bitmap)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                Log.d(TAG, "LargeIcon에서 대화방 프로필 사진 발견")
                bitmap
            } else null
        } catch (e: Exception) {
            Log.e(TAG, "LargeIcon 변환 실패: ${e.message}")
            null
        }
    }

    private fun getFlutterPrefs(): SharedPreferences {
        return applicationContext.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
    }

    /**
     * 약관 동의 여부 확인
     * OnboardingActivity에서 저장한 동의 여부를 확인
     */
    private fun isAgreementAccepted(): Boolean {
        try {
            val prefs = applicationContext.getSharedPreferences(ONBOARDING_PREFS_NAME, Context.MODE_PRIVATE)
            val accepted = prefs.getBoolean(KEY_AGREEMENT, false)
            if (!accepted) {
                Log.w(TAG, "⚠️ 약관 동의 여부: false (약관에 동의하지 않음)")
            }
            return accepted
        } catch (e: Exception) {
            Log.e(TAG, "❌ 동의 여부 확인 실패: ${e.message}", e)
            return false
        }
    }

    // ============ 메신저 파싱 ============

    /**
     * 파싱된 알림 데이터
     */
    private data class ParsedNotification(
        val roomName: String,
        val sender: String,
        val message: String,
        val isPrivateChat: Boolean
    )

    /**
     * 메신저가 활성화되어 있는지 확인 (SharedPreferences에서 동적으로)
     */
    private fun isMessengerEnabled(packageName: String): Boolean {
        if (!ALL_MESSENGERS.containsKey(packageName)) return false
        try {
            val prefs = applicationContext.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            val enabledJson = prefs.getString(ENABLED_MESSENGERS_KEY, null)
            if (enabledJson == null) return packageName == "com.kakao.talk"
            val arr = JSONArray(enabledJson)
            return (0 until arr.length()).any { arr.getString(it) == packageName }
        } catch (e: Exception) {
            Log.e(TAG, "활성 메신저 확인 실패: ${e.message}")
            return packageName == "com.kakao.talk"
        }
    }

    /**
     * 메신저별 알림 파싱
     */
    private fun parseNotification(
        packageName: String,
        title: String,
        text: String,
        subText: String,
        conversationTitle: String,
        isGroupConversation: Boolean
    ): ParsedNotification? {
        return when (packageName) {
            "com.kakao.talk" -> parseKakaoTalk(title, text, subText)
            "jp.naver.line.android" -> parseLine(title, text, subText, conversationTitle, isGroupConversation)
            "org.telegram.messenger" -> parseTelegram(title, text, subText, conversationTitle, isGroupConversation)
            "com.instagram.android" -> parseInstagram(title, text, subText, conversationTitle, isGroupConversation)
            "com.Slack" -> parseSlack(title, text, subText)
            "com.microsoft.teams" -> parseTeams(title, text, subText, conversationTitle, isGroupConversation)
            "com.facebook.orca" -> parseFacebookMessenger(title, text, subText, conversationTitle, isGroupConversation)
            else -> null
        }
    }

    private fun parseKakaoTalk(title: String, text: String, subText: String): ParsedNotification {
        val roomName = if (subText.isEmpty()) title else subText
        return ParsedNotification(roomName, title, text, subText.isEmpty())
    }

    private fun parseLine(
        title: String, text: String, subText: String,
        conversationTitle: String, isGroupConversation: Boolean
    ): ParsedNotification {
        // subText가 있고 title과 다르면 그룹톡 (BigTextStyle 알림에서 conversationTitle 없이 올 수 있음)
        val isGroup = isGroupConversation || conversationTitle.isNotEmpty() ||
            (subText.isNotEmpty() && subText != title && subText.contains(", "))
        if (isGroup) {
            // 그룹명: conversationTitle > subText > title
            val roomName = conversationTitle.ifEmpty { subText.ifEmpty { title } }
            // title에서 발신자 추출: "그룹명: 발신자" → "발신자"
            val sender = if (roomName.isNotEmpty() && title.startsWith("$roomName: ")) {
                title.removePrefix("$roomName: ")
            } else if (conversationTitle.isNotEmpty()) {
                title
            } else {
                // conversationTitle이 없는 경우 (BigTextStyle) title 자체가 발신자
                title
            }
            return ParsedNotification(roomName, sender, text, false)
        }
        // 개인톡: title=발신자=대화방이름, text=메시지
        return ParsedNotification(title, title, text, true)
    }

    private fun parseTelegram(
        title: String, text: String, subText: String,
        conversationTitle: String, isGroupConversation: Boolean
    ): ParsedNotification {
        if (isGroupConversation) {
            // 단톡: conversationTitle=그룹명, title="그룹명: 발신자", subText="발신자 @ 메시지"
            val roomName = conversationTitle.ifEmpty { title }
            val sender = if (conversationTitle.isNotEmpty() && title.startsWith("$conversationTitle: ")) {
                title.removePrefix("$conversationTitle: ")
            } else {
                // subText에서 발신자 추출: "발신자 @ 메시지"
                val atIdx = subText.indexOf(" @ ")
                if (atIdx > 0) subText.substring(0, atIdx) else title
            }
            return ParsedNotification(roomName, sender, text, false)
        }
        // 개인톡: title=발신자, text=메시지 (subText는 메시지 복사본이므로 무시)
        return ParsedNotification(title, title, text, true)
    }

    private fun parseInstagram(
        title: String, text: String, subText: String,
        conversationTitle: String, isGroupConversation: Boolean
    ): ParsedNotification {
        if (isGroupConversation || conversationTitle.isNotEmpty()) {
            val roomName = conversationTitle.ifEmpty { title }
            val sender = if (conversationTitle.isNotEmpty() && title.contains(": ")) {
                // title = "username: displayname" → sender = title 전체 (발신자 식별용)
                // 그룹 대화에서는 conversationTitle = 그룹명, title에서 발신자 추출
                if (isGroupConversation) {
                    title.substringAfter(": ", title)
                } else {
                    conversationTitle
                }
            } else {
                title
            }
            Log.d(TAG, "📸 Instagram 파싱: roomName='$roomName', sender='$sender', conversationTitle='$conversationTitle', isGroup=$isGroupConversation")
            return ParsedNotification(roomName, sender, text, !isGroupConversation)
        }
        // 개인 대화: title이 사용자명 또는 표시명일 수 있음
        val roomName = title
        Log.d(TAG, "📸 Instagram 개인 대화 파싱: roomName='$roomName', title='$title'")
        return ParsedNotification(roomName, title, text, true)
    }

    private fun parseSlack(title: String, text: String, subText: String): ParsedNotification {
        val roomName = if (subText.isNotEmpty()) "$title / $subText" else title
        val isPrivate = subText.startsWith("@") || subText.isEmpty()
        val colonIdx = text.indexOf(": ")
        val (sender, message) = if (colonIdx > 0) {
            text.substring(0, colonIdx) to text.substring(colonIdx + 2)
        } else {
            title to text
        }
        return ParsedNotification(roomName, sender, message, isPrivate)
    }

    private fun parseTeams(
        title: String, text: String, subText: String,
        conversationTitle: String, isGroupConversation: Boolean
    ): ParsedNotification {
        // 1:1 채팅: conversationTitle="임기혁 (외부)", title="임기혁 (외부): (외부) 임기혁", text=메시지
        if (conversationTitle.isNotEmpty()) {
            val roomName = conversationTitle
            // title에서 발신자 추출: "conversationTitle: displayName" → displayName 부분 사용
            val sender = if (title.startsWith("$conversationTitle: ")) {
                title.removePrefix("$conversationTitle: ").ifEmpty { conversationTitle }
            } else {
                conversationTitle
            }
            return ParsedNotification(roomName, sender, text, !isGroupConversation)
        }

        // 채널 메시지: title="XXX 님이 YYY 팀의 채널 ZZZ에서 회신했습니다.", text=메시지
        val channelPattern = Regex("""(.+?) 님이 (.+?) 팀의 채널 (.+?)에서""")
        val match = channelPattern.find(title)
        if (match != null) {
            val sender = match.groupValues[1]
            val teamName = match.groupValues[2]
            val channelName = match.groupValues[3]
            val roomName = "$teamName / $channelName"
            return ParsedNotification(roomName, sender, text, false)
        }

        // 기타 Teams 알림: title=발신자, text=메시지
        return ParsedNotification(title, title, text, true)
    }

    private fun parseFacebookMessenger(
        title: String, text: String, subText: String,
        conversationTitle: String, isGroupConversation: Boolean
    ): ParsedNotification {
        // 그룹 대화: conversationTitle=그룹명, title=발신자
        if (isGroupConversation || conversationTitle.isNotEmpty()) {
            val roomName = conversationTitle.ifEmpty { title }
            val sender = if (conversationTitle.isNotEmpty()) title else title
            return ParsedNotification(roomName, sender, text, false)
        }
        // 1:1 대화: title=발신자, text=메시지
        return ParsedNotification(title, title, text, true)
    }

    /**
     * LINE/Instagram 미디어 메시지를 한국어로 정규화
     */
    private fun normalizeMediaMessage(message: String): String {
        val lower = message.lowercase()
        // 사진/이미지
        if (lower.contains("sent a photo") || lower.contains("sent an image") ||
            lower.contains("사진을 보냈습니다") || lower.contains("이미지를 보냈습니다") ||
            lower == "photo" || lower == "사진") {
            return "사진을 보냈습니다"
        }
        // 이모티콘/스티커
        if (lower.contains("sticker") || lower.contains("스티커") ||
            lower.contains("이모티콘") || lower == "emoji") {
            return "이모티콘을 보냈습니다"
        }
        // 동영상
        if (lower.contains("sent a video") || lower.contains("동영상을 보냈습니다") ||
            lower == "video" || lower == "동영상") {
            return "동영상을 보냈습니다"
        }
        // 파일
        if (lower.contains("sent a file") || lower.contains("파일을 보냈습니다")) {
            return "파일을 보냈습니다"
        }
        // 음성메시지
        if (lower.contains("sent a voice message") || lower.contains("음성메시지를 보냈습니다") ||
            lower.contains("sent an audio")) {
            return "음성메시지를 보냈습니다"
        }
        return message
    }

    /**
     * 메신저별 이모티콘/스티커 메시지 감지
     */
    private fun isEmojiOrStickerMessage(packageName: String, messageText: String): Boolean {
        return when (packageName) {
            "com.kakao.talk" -> messageText.contains("이모티콘", ignoreCase = true) ||
                                messageText.contains("스티커", ignoreCase = true)
            "jp.naver.line.android" -> messageText.contains("Sticker", ignoreCase = true) ||
                                       messageText.contains("스티커", ignoreCase = true) ||
                                       messageText.contains("이모티콘", ignoreCase = true)
            "org.telegram.messenger" -> messageText.contains("Sticker", ignoreCase = true)
            "com.instagram.android" -> false
            "com.Slack" -> false
            "com.microsoft.teams" -> false
            "com.facebook.orca" -> messageText.contains("Sticker", ignoreCase = true) ||
                                    messageText.contains("스티커", ignoreCase = true)
            else -> false
        }
    }

    /**
     * 메신저별 시스템 메시지 패턴
     */
    private fun getSystemMessagePatterns(packageName: String): List<String> {
        return when (packageName) {
            "com.kakao.talk" -> listOf("사진을 보냈습니다", "이미지를 보냈습니다")
            "jp.naver.line.android" -> listOf("sent a photo", "사진을 보냈습니다", "sent an image", "sent a video", "동영상을 보냈습니다", "sent a file")
            "org.telegram.messenger" -> listOf("Photo", "사진")
            "com.instagram.android" -> listOf("sent a photo", "Sent a photo", "사진을 보냈습니다")
            "com.Slack" -> listOf("uploaded a file", "shared an image")
            "com.microsoft.teams" -> listOf("sent an image", "이미지를 보냈습니다", "sent a file")
            "com.facebook.orca" -> listOf("sent a photo", "sent an image", "사진을 보냈습니다", "sent a video", "sent a file", "sent a GIF")
            else -> listOf("사진을 보냈습니다")
        }
    }

    /**
     * 채팅방이 음소거 상태인지 확인
     * Flutter SharedPreferences에서 muted_rooms 목록을 읽어서 확인
     * ★ 화면 켜짐 방지를 위해 최대한 빠르게 처리 ★
     * 
     * 라인(LINE)의 경우 chatId를 우선 사용 (roomName이 랜덤으로 변할 수 있음)
     */
    private fun isRoomMuted(roomName: String, packageName: String = "com.kakao.talk", chatId: String? = null): Boolean {
        try {
            val prefs = applicationContext.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            val mutedRoomsJson = prefs.getString(MUTED_ROOMS_KEY, null)

            if (mutedRoomsJson != null && mutedRoomsJson.isNotEmpty()) {
                val mutedRooms = JSONArray(mutedRoomsJson)

                // 라인인 경우 chatId를 우선 사용
                if (packageName == "jp.naver.line.android" && !chatId.isNullOrEmpty()) {
                    val chatIdKey = "$packageName|$chatId"
                    for (i in 0 until mutedRooms.length()) {
                        if (mutedRooms.getString(i) == chatIdKey) return true
                    }
                }

                val compoundKey = "$packageName|$roomName"
                for (i in 0 until mutedRooms.length()) {
                    val mutedRoom = mutedRooms.getString(i)
                    if (mutedRoom == compoundKey || mutedRoom == roomName) return true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "음소거 확인 실패: ${e.message}")
        }
        return false
    }

    /**
     * 채팅방이 차단 상태인지 확인
     * SQLite DB에서 blocked 상태 조회
     */
    private fun isRoomBlocked(roomName: String, packageName: String): Boolean {
        return try {
            val db = ChatDatabase.getInstance(applicationContext)
            db.isRoomBlocked(roomName, packageName)
        } catch (e: Exception) {
            Log.e(TAG, "차단 상태 확인 실패: ${e.message}")
            false
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn?.let { notification ->
            val packageName = notification.packageName
            
            // 지원하는 메신저인지 확인 (가장 빠른 체크)
            val isSupportedMessenger = isMessengerEnabled(packageName)

            val extras: Bundle? = notification.notification.extras
            val noti = notification.notification
            val messengerName = ALL_MESSENGERS[packageName] ?: packageName

            // 모든 알림 로그 (디버깅용 - 샘플링으로 성능 최적화)
            logCounter++
            if (logCounter >= logResetThreshold) {
                logCounter = 0L
            }
            val shouldLog = (logCounter % logSampleRate == 0L)
            if (shouldLog) {
                Log.d(TAG, "========== 알림 수신 (샘플링: $logCounter) ==========")
                Log.d(TAG, "패키지명: $packageName, 알림 ID: ${notification.id}")
            }

            // ★★★ 디버그 모드: 카카오톡 알림 데이터 전체 덤프 ★★★
            if (DEBUG_NOTIFICATION_DATA && isSupportedMessenger && extras != null) {
                dumpNotificationData(notification, extras)
            }

            extras?.let { bundle ->
                val title = bundle.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
                val text = bundle.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
                val subText = bundle.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
                val bigText = bundle.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
                val infoText = bundle.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString() ?: ""
                val summaryText = bundle.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString() ?: ""

                // 대화 관련 추가 정보
                val conversationTitle = bundle.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString() ?: ""
                val selfDisplayName = bundle.getCharSequence(Notification.EXTRA_SELF_DISPLAY_NAME)?.toString() ?: ""
                val isGroupConversation = bundle.getBoolean(Notification.EXTRA_IS_GROUP_CONVERSATION, false)
                val messages = bundle.getParcelableArray(Notification.EXTRA_MESSAGES)
                val remotePerson = bundle.get("android.remotePerson")
                val messagingPerson = bundle.get("android.messagingUser")

                // 상세 로그는 샘플링으로 최적화 (성능 향상)
                if (shouldLog) {
                    Log.d(TAG, "제목: $title, 내용: $text, 서브텍스트: $subText")
                }

                // 지원하는 메신저 알림인 경우 API 호출
                if (isSupportedMessenger) {
                    Log.d(TAG, "📱 지원하는 메신저 알림: $messengerName")
                    
                    // ★★★ 빈 알림/선행 알림/요약 알림 필터링 ★★★
                    // 카카오톡은 실제 알림 전에 빈 알림을 먼저 보내거나, 그룹화된 요약 알림을 보냄
                    // 이런 알림들은 이미지 추출 시도도 하지 않고 바로 무시
                    
                    // 1. 빈 알림 (title, text 모두 비어있음) - 선행 알림 또는 무의미한 알림
                    if (title.isEmpty() && text.isEmpty()) {
                        // 요약 알림인 경우 (subText에 "안 읽은 메시지" 포함)
                        // 로그 샘플링
                        if (shouldLog) {
                            if (subText.contains("안 읽은 메시지") || subText.contains("unread message")) {
                                Log.d(TAG, ">>> [$messengerName] 요약 알림 무시: $subText")
                            } else {
                                Log.d(TAG, ">>> [$messengerName] 빈 알림 무시")
                            }
                        }
                        return
                    }
                    
                    // 중요 로그만 출력 (샘플링 - 10개 중 1개)
                    if (logCounter % (logSampleRate / 5) == 0L) {
                        Log.i(TAG, "[$messengerName] 알림 감지: 발신자=$title, 메시지=$text")
                    }

                    // 메신저별 알림 파싱 (개인톡/그룹톡 구분)
                    val parsed = parseNotification(packageName, title, text, subText, conversationTitle, isGroupConversation)
                    if (parsed == null) {
                        Log.w(TAG, "⚠️ 파싱 실패: packageName=$packageName")
                        return
                    }
                    val roomName = parsed.roomName
                    var sender = parsed.sender
                    var message = parsed.message
                    val isPrivateChat = parsed.isPrivateChat

                    // 메신저별 대화방 고유 식별자 추출 (LINE: shortcutId)
                    val chatId = noti.shortcutId?.takeIf { it.isNotEmpty() }

                    // LINE/Instagram: 미디어 메시지 한국어 정규화 (이미지 추출 시도하지 않음)
                    // Slack: sender_person.icon 비트맵이 재귀 검색에 걸려 프로필이 사진으로 잘못 추출되는 문제 방지
                    val skipImageExtraction = packageName == "jp.naver.line.android" || packageName == "com.instagram.android" || packageName == "com.Slack"
                    if (skipImageExtraction) {
                        message = normalizeMediaMessage(message)
                    }

                    Log.d(TAG, "📝 알림 파싱: sender='$sender', message='${message.take(50)}', roomName='$roomName', isPrivate=$isPrivateChat")

                    // ★★★ 이미지 추출을 음소거 체크 전에 수행 (알림 삭제 전에 데이터 확보) ★★★
                    // 알림에서 이미지 데이터를 먼저 추출해두고, 그 후 음소거면 알림 삭제
                    var preExtractedImage: android.graphics.Bitmap? = null
                    var preExtractedRoomProfile: android.graphics.Bitmap? = null
                    var preExtractedSenderProfile: android.graphics.Bitmap? = null

                    if (roomName.isNotEmpty()) {
                        // 이미지 데이터 선추출 (알림 삭제 전에 메모리로 복사)
                        preExtractedRoomProfile = extractRoomProfileImage(noti)
                        if (preExtractedRoomProfile != null) {
                            Log.d(TAG, "✅ 대화방 프로필 이미지 선추출 성공: roomName='$roomName', 크기=${preExtractedRoomProfile.width}x${preExtractedRoomProfile.height}")
                        } else {
                            Log.d(TAG, "❌ 대화방 프로필 이미지 선추출 실패: roomName='$roomName'")
                        }
                        
                        preExtractedSenderProfile = extractSenderProfileImage(noti, bundle, subText.isEmpty())
                        if (preExtractedSenderProfile != null) {
                            Log.d(TAG, "✅ 보낸사람 프로필 이미지 선추출 성공: sender='$sender', isPrivateChat=${subText.isEmpty()}, 크기=${preExtractedSenderProfile.width}x${preExtractedSenderProfile.height}")
                        } else {
                            Log.d(TAG, "❌ 보낸사람 프로필 이미지 선추출 실패: sender='$sender', isPrivateChat=${subText.isEmpty()}")
                        }

                        // 공유 이미지 선추출 (이모티콘/스티커 포함)
                        // LINE/Instagram은 이미지 추출 스킵, 미디어 메시지는 한국어 텍스트로 정규화됨
                        if (!skipImageExtraction) {
                            preExtractedImage = extractSharedImage(noti, bundle, message)
                        }
                    }

                    // ★★★ 음소거 및 차단 체크 ★★★
                    if (roomName.isNotEmpty()) {
                        // 1. 음소거 체크 (알림만 삭제, 저장은 계속 진행)
                        // 라인인 경우 chatId를 우선 사용 (roomName이 랜덤으로 변할 수 있음)
                        val isMuted = isRoomMuted(roomName, packageName, chatId)
                        if (isMuted) {
                            try {
                                cancelNotification(notification.key)
                            } catch (e: Exception) {
                                Log.e(TAG, "알림 삭제 실패: ${e.message}")
                            }
                        }

                        // 2. 차단 체크 (저장만 스킵, 알림은 유지)
                        val isBlocked = isRoomBlocked(roomName, packageName)
                        if (isBlocked) {
                            return
                        }
                    } else {
                        Log.w(TAG, "⚠️ roomName이 비어있음 - 메시지 저장 스킵 가능")
                    }
                    
                    // 내가 보낸 메시지인지 확인 (selfDisplayName과 비교)
                    if (sender == selfDisplayName || sender == "나") {
                        sender = "나"
                        // 로그 샘플링
                        if (shouldLog) {
                            Log.d(TAG, ">>> 내가 보낸 메시지: sender='$sender'")
                        }
                    }

                    // 필드 검증 로그는 샘플링
                    if (shouldLog) {
                        Log.d(TAG, ">>> [$messengerName] 개인톡=$isPrivateChat, sender='$sender', roomName='$roomName'")
                    }

                    // 이미지 처리 (선추출된 이미지 사용 - 알림 삭제 전에 미리 추출됨)
                    var savedImagePath: String? = null
                    var imageMessage: String? = null

                    if (roomName.isNotEmpty()) {
                        // 1. 대화방 프로필 사진 저장 (선추출된 이미지 사용)
                        if (preExtractedRoomProfile != null) {
                            Log.d(TAG, "💾 대화방 프로필 이미지 저장 시도: roomName='$roomName', packageName='$packageName'")
                            saveRoomProfileImage(roomName, preExtractedRoomProfile, packageName)
                        } else {
                            Log.w(TAG, "⚠️ 대화방 프로필 이미지 없음 - 저장 스킵: roomName='$roomName'")
                        }

                        // 2. 보낸사람 프로필 사진 저장 (선추출된 이미지 사용)
                        if (preExtractedSenderProfile != null) {
                            Log.d(TAG, "💾 보낸사람 프로필 이미지 저장 시도: sender='$sender', roomName='$roomName'")
                            saveSenderProfileImage(packageName, roomName, sender, preExtractedSenderProfile)
                        } else {
                            Log.w(TAG, "⚠️ 보낸사람 프로필 이미지 없음 - 저장 스킵: sender='$sender', roomName='$roomName'")
                        }

                        // 3. 공유된 사진 저장 (선추출된 이미지 사용)
                        val systemMessagePatterns = getSystemMessagePatterns(packageName)
                        val isSystemMessage = systemMessagePatterns.any { pattern ->
                            message.contains(pattern, ignoreCase = true)
                        }
                        val urlPattern = Regex("""(https?://|www\.)[^\s]+""", RegexOption.IGNORE_CASE)
                        val isLinkMessage = urlPattern.containsMatchIn(message)
                        val isEmojiOrSticker = isEmojiOrStickerMessage(packageName, message)

                        if (preExtractedImage != null) {
                            // 선추출된 이미지 크기 검증 후 저장
                            // 이모티콘/스티커는 크기가 작으므로 최소 크기 조건 완화
                            val minSize = if (isEmojiOrSticker) 30 else if (isSystemMessage || isLinkMessage) 200 else 300
                            val isLargeEnough = preExtractedImage.width >= minSize || preExtractedImage.height >= minSize

                            if (isLargeEnough) {
                                savedImagePath = saveNotificationImage(roomName, preExtractedImage, notification.postTime, packageName)
                            }
                        }

                        // 이미지 메시지 처리
                        if (savedImagePath != null) {
                            imageMessage = if (isLinkMessage) "[LINK:$savedImagePath]$message" else if (isEmojiOrSticker) "[IMAGE:$savedImagePath]$message" else "[IMAGE:$savedImagePath]$message"
                        } else if (isLinkMessage) {
                            imageMessage = message
                        }
                        
                        // 이미지 메시지가 있는 경우 저장
                        if (imageMessage != null) {
                            // 약관 동의 여부 확인
                            if (!isAgreementAccepted()) {
                                Log.w(TAG, "⚠️ 약관 동의 안 됨 - 이미지 메시지 저장 스킵")
                                return
                            }

                            // ✅ 비동기 처리: 메시지 저장을 백그라운드에서 처리 (알림 삭제는 이미 완료)
                            if (sender.isNotEmpty() && roomName.isNotEmpty()) {
                                Log.d(TAG, "💾 이미지 메시지 저장 시작: sender='$sender', roomName='$roomName'")
                                
                                // 필요한 데이터를 로컬 변수로 복사 (클로저 안전성)
                                val imageMsg = imageMessage
                                val savedPath = savedImagePath
                                val senderName = sender
                                val room = roomName
                                val pkgName = packageName
                                val postTime = notification.postTime
                                val isPrivate = isPrivateChat
                                
                                messageSaveScope.launch {
                                    try {
                                        val db = ChatDatabase.getInstance(applicationContext)
                                        
                                        // PendingIntent 추출 (contentIntent 또는 reply action의 intent)
                                        val replyIntentUri = extractReplyIntent(noti)
                                        val replyData = extractReplyIntentData(noti)
                                        
                                        // 채팅방 저장/업데이트 및 roomId 반환
                                        // 개인채팅은 요약 끄기, 그룹/오픈채팅은 요약 켜기
                                        Log.d(TAG, "💾 이미지 채팅방 저장/업데이트 시도: roomName='$room', packageName='$pkgName'")
                                        val roomId = db.saveOrUpdateRoom(
                                            roomName = room,
                                            packageName = pkgName,
                                            lastMessage = imageMsg,
                                            lastSender = senderName,
                                            lastMessageTime = postTime,
                                            replyIntent = replyIntentUri,
                                            isPrivateChat = isPrivate,
                                            chatId = chatId
                                        )

                                        Log.d(TAG, "💾 이미지 채팅방 저장 결과: roomId=$roomId")

                                        // PendingIntent 및 RemoteInput 캐시에 저장
                                        if (roomId > 0 && replyData != null) {
                                            replyIntentCache[roomId] = replyData
                                        }

                                        // 메시지 저장
                                        if (roomId > 0) {
                                            try {
                                                Log.d(TAG, "💾 이미지 메시지 저장 시도: roomId=$roomId, sender='$senderName'")
                                                val imgSaveResult = db.saveMessage(
                                                    roomId = roomId,
                                                    sender = senderName,
                                                    message = imageMsg,
                                                    createTime = postTime,
                                                    roomName = room
                                                )

                                                if (imgSaveResult == -2L) {
                                                    Log.d(TAG, "⏭️ 중복 이미지 메시지 - 브로드캐스트/자동요약 스킵: roomId=$roomId")
                                                } else {
                                                    val updatedUnreadCount = db.getUnreadCount(roomId)
                                                    Log.i(TAG, "✅ 이미지 메시지 저장 성공: roomId=$roomId, unreadCount=$updatedUnreadCount")

                                                    // 채팅방 업데이트 브로드캐스트
                                                    val roomUpdateIntent = Intent(ACTION_ROOM_UPDATED).apply {
                                                        putExtra("roomId", roomId)
                                                        putExtra("roomName", room)
                                                        putExtra("lastMessage", imageMsg)
                                                        putExtra("lastSender", senderName)
                                                        putExtra("lastMessageTime", postTime.toString())
                                                        putExtra("unreadCount", updatedUnreadCount)
                                                        setPackage(this@NotificationListener.packageName)
                                                        addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                                                    }
                                                    sendBroadcast(roomUpdateIntent)

                                                    checkAndTriggerAutoSummary(roomId, room, updatedUnreadCount)
                                                    checkAndSendPaywallNotification(roomId, room, updatedUnreadCount)
                                                }
                                            } catch (e: Exception) {
                                                Log.e(TAG, "❌ 이미지 메시지 저장 실패: ${e.message}", e)
                                            }
                                        } else {
                                            Log.e(TAG, "❌ 이미지 채팅방 저장 실패: roomId=$roomId (0 이하)")
                                        }
                                    } catch (e: Exception) {
                                        Log.e(TAG, "❌ 이미지 메시지 DB 오류: ${e.message}", e)
                                    }
                                }
                            } else {
                                Log.w(TAG, "⚠️ 이미지 메시지 저장 조건 불만족: sender.isEmpty=${sender.isEmpty()}, roomName.isEmpty=${roomName.isEmpty()}")
                            }
                            return
                        }
                    }

                    // 약관 동의 여부 확인
                    if (!isAgreementAccepted()) {
                        Log.w(TAG, "⚠️ 약관 동의 안 됨 - 메시지 저장 스킵")
                        return
                    }

                    // 일반 메시지 저장
                    if (sender.isNotEmpty() && message.isNotEmpty() && roomName.isNotEmpty()) {
                        Log.d(TAG, "💾 메시지 저장 시작: sender='$sender', roomName='$roomName', message='${message.take(50)}...'")
                        
                        // 필요한 데이터를 로컬 변수로 복사 (클로저 안전성)
                        val finalMessage = message
                        val senderName = sender
                        val room = roomName
                        val pkgName = packageName
                        val postTime = notification.postTime
                        val isPrivate = isPrivateChat
                        val savedPath = savedImagePath
                        
                        messageSaveScope.launch {
                            try {
                                val db = ChatDatabase.getInstance(applicationContext)

                                val replyIntentUri = extractReplyIntent(noti)
                                val replyData = extractReplyIntentData(noti)

                                Log.d(TAG, "💾 채팅방 저장/업데이트 시도: roomName='$room', packageName='$pkgName'")
                                val roomId = db.saveOrUpdateRoom(
                                    roomName = room,
                                    packageName = pkgName,
                                    lastMessage = finalMessage,
                                    lastSender = senderName,
                                    lastMessageTime = postTime,
                                    replyIntent = replyIntentUri,
                                    isPrivateChat = isPrivate,
                                    chatId = chatId
                                )

                                Log.d(TAG, "💾 채팅방 저장 결과: roomId=$roomId")

                                if (roomId > 0 && replyData != null) {
                                    replyIntentCache[roomId] = replyData
                                }

                                if (roomId > 0) {
                                    try {
                                        Log.d(TAG, "💾 메시지 저장 시도: roomId=$roomId, sender='$senderName', message='${finalMessage.take(50)}...'")
                                        val saveResult = db.saveMessage(
                                            roomId = roomId,
                                            sender = senderName,
                                            message = finalMessage,
                                            createTime = postTime,
                                            roomName = room
                                        )

                                        if (saveResult == -2L) {
                                            Log.d(TAG, "⏭️ 중복 메시지 - 브로드캐스트/자동요약 스킵: roomId=$roomId")
                                        } else {
                                            val updatedUnreadCount = db.getUnreadCount(roomId)
                                            Log.i(TAG, "✅ 메시지 저장 성공: roomId=$roomId, unreadCount=$updatedUnreadCount")

                                            val roomUpdateIntent = Intent(ACTION_ROOM_UPDATED).apply {
                                                putExtra("roomId", roomId)
                                                putExtra("roomName", room)
                                                putExtra("lastMessage", finalMessage)
                                                putExtra("lastSender", senderName)
                                                putExtra("lastMessageTime", postTime.toString())
                                                putExtra("unreadCount", updatedUnreadCount)
                                                setPackage(this@NotificationListener.packageName)
                                                addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                                            }
                                            sendBroadcast(roomUpdateIntent)
                                            checkAndTriggerAutoSummary(roomId, room, updatedUnreadCount)
                                            checkAndSendPaywallNotification(roomId, room, updatedUnreadCount)
                                        }
                                    } catch (e: Exception) {
                                        Log.e(TAG, "❌ 메시지 저장 실패: ${e.message}", e)
                                    }
                                } else {
                                    Log.e(TAG, "❌ 채팅방 저장 실패: roomId=$roomId (0 이하)")
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "❌ DB 오류: ${e.message}", e)
                            }
                        }
                    } else {
                        Log.w(TAG, "⚠️ 메시지 저장 조건 불만족: sender.isEmpty=${sender.isEmpty()}, message.isEmpty=${message.isEmpty()}, roomName.isEmpty=${roomName.isEmpty()}")
                    }
                }

                // 모든 extras를 문자열로 변환
                val allExtrasString = StringBuilder()
                for (key in bundle.keySet()) {
                    val value = bundle.get(key)
                    allExtrasString.append("$key: $value (${value?.javaClass?.simpleName})\n")
                }

                // Flutter로 브로드캐스트 전송 (앱이 포그라운드일 때)
                val intent = Intent(ACTION_NOTIFICATION_RECEIVED).apply {
                    putExtra("packageName", packageName)
                    putExtra("title", title)
                    putExtra("text", text)
                    putExtra("subText", subText)
                    putExtra("bigText", bigText)
                    putExtra("postTime", notification.postTime)
                    putExtra("id", notification.id)
                    // 추가 정보
                    putExtra("tag", notification.tag ?: "")
                    putExtra("key", notification.key ?: "")
                    putExtra("groupKey", notification.groupKey ?: "")
                    putExtra("category", noti.category ?: "")
                    putExtra("channelId", noti.channelId ?: "")
                    putExtra("group", noti.group ?: "")
                    putExtra("sortKey", noti.sortKey ?: "")
                    putExtra("tickerText", noti.tickerText?.toString() ?: "")
                    putExtra("conversationTitle", conversationTitle)
                    putExtra("isGroupConversation", isGroupConversation)
                    putExtra("allExtras", allExtrasString.toString())
                    setPackage(this@NotificationListener.packageName)
                }
                sendBroadcast(intent)
            }

            // 로그 종료 마커는 샘플링
            if (shouldLog) {
                Log.d(TAG, "================================")
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn?.let {
            Log.d(TAG, "알림 제거됨: ${it.packageName} - ID: ${it.id}")
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "NotificationListenerService 연결됨!")
        createAutoSummaryNotificationChannel()
        registerCancelReceiver()
        registerSendMessageReceiver()
    }

    /**
     * 자동 요약 알림 채널 생성
     */
    private fun createAutoSummaryNotificationChannel() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 기존 채널 삭제 후 재생성 (설정 변경 반영을 위해)
            notificationManager.deleteNotificationChannel(AUTO_SUMMARY_CHANNEL_ID)

            // SharedPreferences에서 설정 읽기
            val prefs = applicationContext.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            val soundEnabled = prefs.getBoolean(SOUND_ENABLED_KEY, true)
            val vibrationEnabled = prefs.getBoolean(VIBRATION_ENABLED_KEY, true)

            val channel = NotificationChannel(
                AUTO_SUMMARY_CHANNEL_ID,
                AUTO_SUMMARY_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "AI 톡비서 자동 요약 완료 알림"

                // 소리 설정
                if (soundEnabled) {
                    // 커스텀 사운드 설정 (톡비서)
                    // res/raw/tokbiseo.mp3 파일이 필요
                    try {
                        val soundUri = android.net.Uri.parse(
                            "android.resource://${packageName}/raw/tokbiseo"
                        )
                        setSound(soundUri, android.media.AudioAttributes.Builder()
                            .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build())
                        Log.i(TAG, "✅ 커스텀 알림 사운드 설정 완료: tokbiseo")
                    } catch (e: Exception) {
                        Log.w(TAG, "⚠️ 커스텀 사운드 설정 실패, 기본 사운드 사용: ${e.message}")
                        // 기본 사운드 사용
                        setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, null)
                    }
                } else {
                    // 소리 끄기
                    setSound(null, null)
                    Log.i(TAG, "🔇 알림 소리 꺼짐")
                }

                // 진동 패턴 설정
                if (vibrationEnabled) {
                    vibrationPattern = longArrayOf(0, 300, 200, 300)
                    enableVibration(true)
                } else {
                    enableVibration(false)
                }

                // LED 설정
                enableLights(true)
                lightColor = android.graphics.Color.BLUE
            }

            notificationManager.createNotificationChannel(channel)
            Log.i(TAG, "✅ 자동 요약 알림 채널 생성 완료: sound=$soundEnabled, vibration=$vibrationEnabled")
        }
    }


    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.i(TAG, "NotificationListenerService 연결 해제됨!")
        unregisterCancelReceiver()
        unregisterSendMessageReceiver()
    }

    private fun registerCancelReceiver() {
        cancelReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                intent?.let {
                    when (it.action) {
                        ACTION_CANCEL_NOTIFICATION -> {
                            val key = it.getStringExtra("key")
                            if (key != null) {
                                cancelNotificationByKey(key)
                            }
                        }
                        ACTION_CANCEL_ROOM_NOTIFICATIONS -> {
                            val roomName = it.getStringExtra("roomName")
                            if (roomName != null) {
                                cancelNotificationsForRoom(roomName)
                            }
                        }
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(ACTION_CANCEL_NOTIFICATION)
            addAction(ACTION_CANCEL_ROOM_NOTIFICATIONS)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(cancelReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(cancelReceiver, filter)
        }
        Log.d(TAG, "취소 리시버 등록됨")
    }

    /**
     * 메시지 전송 (PendingIntent 실행)
     * RemoteInput이 있으면 RemoteInput 사용, 없으면 일반 Intent 사용
     */
    fun sendMessage(roomId: Long, message: String): Boolean {
        try {
            Log.d(TAG, "📤 메시지 전송 시도: roomId=$roomId, message='$message', 캐시 크기: ${replyIntentCache.size}")
            val replyData = replyIntentCache[roomId]
            if (replyData != null) {
                Log.d(TAG, "  - PendingIntent 발견: hasRemoteInput=${replyData.remoteInput != null}, actionTitle=${replyData.actionTitle}")
                
                if (replyData.remoteInput != null) {
                    // RemoteInput 사용 (카카오톡 reply action)
                    val remoteInput = replyData.remoteInput
                    Log.d(TAG, "  - RemoteInput 사용: resultKey=${remoteInput.resultKey}")
                    
                    val results = Bundle().apply {
                        putCharSequence(remoteInput.resultKey, message)
                    }
                    
                    val intent = Intent().apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    
                    // RemoteInput.addResultsToIntent 사용
                    RemoteInput.addResultsToIntent(arrayOf(remoteInput), intent, results)
                    
                    try {
                        replyData.pendingIntent.send(applicationContext, 0, intent)
                        Log.i(TAG, "✅ 메시지 전송 성공 (RemoteInput 사용): roomId=$roomId, message='$message'")
                        return true
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ RemoteInput 메시지 전송 실패: ${e.message}", e)
                        e.printStackTrace()
                        // RemoteInput 실패 시 일반 Intent로 재시도
                    }
                }
                
                // RemoteInput이 없거나 실패한 경우 일반 Intent 사용
                Log.d(TAG, "  - 일반 Intent 사용 (RemoteInput 없음 또는 실패)")
                val intent = Intent().apply {
                    putExtra("message", message)
                    putExtra("text", message)
                    // 카카오톡의 경우 추가 extras가 필요할 수 있음
                }
                replyData.pendingIntent.send(applicationContext, 0, intent)
                Log.i(TAG, "✅ 메시지 전송 성공 (일반 Intent): roomId=$roomId, message='$message'")
                return true
            } else {
                Log.w(TAG, "⚠️ PendingIntent를 찾을 수 없음: roomId=$roomId, 캐시 크기: ${replyIntentCache.size}")
                Log.w(TAG, "  - 캐시된 roomId 목록: ${replyIntentCache.keys.joinToString()}")
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 메시지 전송 실패: ${e.message}", e)
            e.printStackTrace()
            return false
        }
    }
    
    private fun registerSendMessageReceiver() {
        sendMessageReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                Log.d(TAG, "📨 메시지 전송 브로드캐스트 수신: action=${intent?.action}")
                intent?.let {
                    if (it.action == ACTION_SEND_MESSAGE) {
                        val roomId = it.getLongExtra("roomId", -1)
                        val message = it.getStringExtra("message") ?: ""
                        Log.d(TAG, "📨 메시지 전송 요청: roomId=$roomId, message='$message'")
                        if (roomId > 0 && message.isNotEmpty()) {
                            val result = sendMessage(roomId, message)
                            Log.d(TAG, "📨 메시지 전송 결과: $result")
                        } else {
                            Log.w(TAG, "⚠️ 메시지 전송 요청 무효: roomId=$roomId, message='$message'")
                        }
                    } else {
                        Log.d(TAG, "📨 다른 액션 브로드캐스트: ${it.action}")
                    }
                } ?: Log.w(TAG, "⚠️ 브로드캐스트 intent가 null")
            }
        }
        
        val filter = IntentFilter(ACTION_SEND_MESSAGE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(sendMessageReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(sendMessageReceiver, filter)
        }
        Log.d(TAG, "✅ 메시지 전송 리시버 등록됨: ACTION=$ACTION_SEND_MESSAGE")
    }
    
    private fun unregisterSendMessageReceiver() {
        sendMessageReceiver?.let {
            try {
                unregisterReceiver(it)
                sendMessageReceiver = null
            } catch (e: Exception) {
                Log.e(TAG, "메시지 전송 리시버 해제 실패: ${e.message}")
            }
        }
    }
    
    private fun unregisterCancelReceiver() {
        cancelReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(TAG, "취소 리시버 해제 실패: ${e.message}")
            }
            cancelReceiver = null
        }
    }

    private fun cancelNotificationByKey(key: String) {
        try {
            cancelNotification(key)
            Log.d(TAG, "알림 취소됨: $key")
        } catch (e: Exception) {
            Log.e(TAG, "알림 취소 실패: ${e.message}")
        }
    }

    private fun cancelNotificationsForRoom(roomName: String) {
        try {
            val activeNotifications = activeNotifications
            for (sbn in activeNotifications) {
                // 지원하는 모든 메신저에서 해당 채팅방 알림 취소
                if (ALL_MESSENGERS.containsKey(sbn.packageName)) {
                    val extras = sbn.notification.extras
                    val subText = extras?.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
                    val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
                    // 개인톡은 subText가 비어있고 title이 채팅방 이름
                    val notificationRoomName = if (subText.isEmpty()) title else subText
                    if (notificationRoomName == roomName) {
                        cancelNotification(sbn.key)
                        val messengerName = ALL_MESSENGERS[sbn.packageName] ?: sbn.packageName
                        Log.d(TAG, "[$messengerName] 채팅방 알림 취소됨: $roomName, key: ${sbn.key}")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "채팅방 알림 취소 실패: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterCancelReceiver()
        autoSummaryScope.cancel()
    }
    
    /**
     * 자동 요약 체크 및 실행
     */
    private fun checkAndTriggerAutoSummary(roomId: Long, roomName: String, unreadCount: Int) {
        // 이미 진행 중인 자동 요약이 있으면 스킵
        synchronized(autoSummaryInProgress) {
            if (autoSummaryInProgress.contains(roomId)) {
                Log.d(TAG, "🤖 자동 요약 이미 진행 중 - 스킵: roomName='$roomName', roomId=$roomId")
                return
            }
        }

        autoSummaryScope.launch {
            try {
                val db = ChatDatabase.getInstance(applicationContext)

                // 자동 요약 설정 확인 (요약 기능이 켜져 있어야 자동 요약 가능)
                val (summaryEnabled, autoSummaryEnabled, autoSummaryMessageCount) = db.getAutoSummarySettings(roomId)

                // 요약 기능이 꺼져 있으면 자동 요약도 실행하지 않음
                if (!summaryEnabled) {
                    Log.d(TAG, "🤖 요약 기능 비활성화로 인해 자동 요약 스킵: roomName='$roomName', roomId=$roomId")
                    return@launch
                }

                if (!autoSummaryEnabled) {
                    Log.d(TAG, "🤖 자동 요약 비활성화: roomName='$roomName', roomId=$roomId")
                    return@launch
                }

                // 안 읽은 메시지 개수가 설정값에 도달했는지 확인
                if (unreadCount < autoSummaryMessageCount) {
                    Log.d(TAG, "🤖 자동 요약 조건 미충족: roomName='$roomName', unreadCount=$unreadCount, required=$autoSummaryMessageCount")
                    return@launch
                }

                // 중복 실행 방지: 진행 중 표시
                synchronized(autoSummaryInProgress) {
                    autoSummaryInProgress.add(roomId)
                }

                try {
                    Log.i(TAG, "🤖 자동 요약 조건 충족: roomName='$roomName', unreadCount=$unreadCount, required=$autoSummaryMessageCount")

                    // 베이직 플랜 확인 (API 호출로 플랜 정보 확인)
                    val planType = getPlanType()
                    if (planType != "basic") {
                        Log.w(TAG, "🤖 ⚠️ 베이직 플랜이 아님: planType=$planType, 자동 요약 실행 불가")
                        return@launch
                    }

                    // 안 읽은 메시지 목록 조회 (최근 N개, 시간순 정렬)
                    val recentMessages = db.getUnreadMessages(roomId, autoSummaryMessageCount)

                    if (recentMessages.size < 5) {
                        Log.w(TAG, "🤖 ⚠️ 메시지 개수 부족: ${recentMessages.size}개 (최소 5개 필요)")
                        return@launch
                    }

                    // 자동 요약 실행
                    executeAutoSummary(roomId, roomName, recentMessages)

                } finally {
                    // 자동 요약 완료/실패 후 진행 중 표시 제거
                    synchronized(autoSummaryInProgress) {
                        autoSummaryInProgress.remove(roomId)
                        Log.d(TAG, "🤖 자동 요약 진행 중 플래그 제거: roomId=$roomId")
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "🤖 ❌ 자동 요약 체크 실패: ${e.message}", e)
            }
        }
    }
    
    /**
     * 플랜 타입 조회 (API 호출)
     * /api/v1/llm/usage 엔드포인트를 호출하여 플랜 타입 확인
     */
    private suspend fun getPlanType(): String {
        return withContext(Dispatchers.IO) {
            try {
                // JWT 토큰 가져오기
                val jwtToken = getJwtToken()
                if (jwtToken == null) {
                    Log.w(TAG, "🤖 ⚠️ JWT 토큰 없음 - 기본값 'free' 반환")
                    return@withContext "free"
                }
                
                // API 호출
                val request = Request.Builder()
                    .url("$SUMMARY_API_BASE_URL$USAGE_API_ENDPOINT")
                    .get()
                    .addHeader("Authorization", "Bearer $jwtToken")
                    .addHeader("Content-Type", "application/json")
                    .build()
                
                val response = okHttpClient.newCall(request).execute()
                
                if (response.isSuccessful) {
                    val responseBody = response.body?.string()
                    if (responseBody != null) {
                        val result = JSONObject(responseBody)
                        val planType = result.optString("planType", "free")
                        Log.d(TAG, "🤖 ✅ 플랜 타입 조회 성공: planType=$planType")
                        return@withContext planType
                    }
                } else {
                    Log.w(TAG, "🤖 ⚠️ 플랜 타입 조회 실패: HTTP ${response.code}")
                }
                
                // 기본값 반환
                return@withContext "free"
            } catch (e: Exception) {
                Log.e(TAG, "🤖 ❌ 플랜 타입 조회 실패: ${e.message}", e)
                return@withContext "free" // 기본값
            }
        }
    }
    
    /**
     * 자동 요약 실행
     */
    private suspend fun executeAutoSummary(roomId: Long, roomName: String, messages: List<Map<String, Any>>) {
        try {
            Log.i(TAG, "🤖 자동 요약 시작: roomName='$roomName', messageCount=${messages.size}")
            
            // JWT 토큰 가져오기 (Flutter SecureStorage에서)
            val jwtToken = getJwtToken()
            if (jwtToken == null) {
                Log.e(TAG, "🤖 ❌ JWT 토큰 없음 - 자동 요약 실패")
                return
            }
            
            // API 요청 데이터 구성
            val messagesJson = JSONArray()
            val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
            sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
            
            for (msg in messages) {
                // ISO 8601 형식으로 변환 (예: "2026-01-27T10:30:00.000Z")
                val createTimeMillis = msg["createTime"] as Long
                val date = Date(createTimeMillis)
                val createTimeIso = sdf.format(date)
                
                val msgObj = JSONObject().apply {
                    put("sender", msg["sender"])
                    put("message", msg["message"])
                    put("createTime", createTimeIso)
                }
                messagesJson.put(msgObj)
            }
            
            val requestBody = JSONObject().apply {
                put("roomName", roomName)
                put("messages", messagesJson)
                put("messageCount", messages.size)
            }
            
            // API 호출
            val request = Request.Builder()
                .url("$SUMMARY_API_BASE_URL$SUMMARY_API_ENDPOINT")
                .post(requestBody.toString().toRequestBody("application/json".toMediaType()))
                .addHeader("Authorization", "Bearer $jwtToken")
                .addHeader("Content-Type", "application/json")
                .build()
            
            val response = okHttpClient.newCall(request).execute()
            
            if (response.isSuccessful) {
                val responseBody = response.body?.string()
                if (responseBody != null) {
                    val result = JSONObject(responseBody)
                    val summaryMessage = result.optString("summaryMessage", result.optString("summary", ""))
                    val summarySubject = result.optString("summarySubject", "${messages.size}개 메시지 요약")
                    val summaryDetailMessage = result.optString("summaryDetailMessage", null).takeIf { !it.isNullOrEmpty() }
                    
                    if (summaryMessage.isNotEmpty()) {
                        // 요약 결과 저장
                        val firstMessageTime = messages.first()["createTime"] as Long
                        val lastMessageTime = messages.last()["createTime"] as Long
                        
                        val db = ChatDatabase.getInstance(applicationContext)
                        val summaryId = db.saveSummary(
                            roomId = roomId,
                            summaryName = summarySubject,
                            summaryMessage = summaryMessage,
                            summaryFrom = firstMessageTime,
                            summaryTo = lastMessageTime,
                            summaryDetailMessage = summaryDetailMessage
                        )
                        
                        Log.i(TAG, "🤖 ✅ 자동 요약 완료: roomName='$roomName', summaryId=$summaryId")

                        // 자동요약 완료 후 읽음 처리 (unread_count를 0으로 초기화)
                        db.resetUnreadCount(roomId)
                        Log.i(TAG, "🤖 📖 자동 요약 완료로 인한 읽음 처리 완료: roomId=$roomId")

                        // Flutter에 대화방 업데이트 브로드캐스트 전송 (읽음 처리 반영)
                        // 메인 스레드에서 브로드캐스트 전송 (코루틴 내에서 실행 중이므로)
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            val roomUpdateIntent = Intent(ACTION_ROOM_UPDATED).apply {
                                putExtra("roomName", roomName)
                                putExtra("roomId", roomId)
                                putExtra("unreadCount", 0) // 읽음 처리됨
                                putExtra("isAutoSummary", true)
                                putExtra("summaryId", summaryId)
                                setPackage(packageName)
                                addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                            }
                            sendBroadcast(roomUpdateIntent)
                            // 약간의 딜레이 후 한 번 더 전송 (확실하게 전달)
                            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                sendBroadcast(roomUpdateIntent)
                            }, 100)
                            Log.i(TAG, "🤖 📡 자동 요약 완료 브로드캐스트 전송 (2회): roomName=$roomName, unreadCount=0")
                        }

                        // 푸시 알림 생성
                        showAutoSummaryNotification(roomName, messages.size, summaryId.toInt())
                    } else {
                        Log.w(TAG, "🤖 ⚠️ 요약 결과가 비어있음 - 카운트 롤백")
                        // 요약 결과가 비어있으면 실패로 간주하고 카운트 롤백
                        rollbackUsageCount(jwtToken)
                    }
                } else {
                    Log.w(TAG, "🤖 ⚠️ 응답 본문이 null - 카운트 롤백")
                    rollbackUsageCount(jwtToken)
                }
            } else {
                Log.e(TAG, "🤖 ❌ 자동 요약 API 실패: ${response.code}, ${response.body?.string()} - 카운트 롤백")
                // API 호출 실패 시 카운트 롤백
                rollbackUsageCount(jwtToken)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "🤖 ❌ 자동 요약 실행 실패: ${e.message} - 카운트 롤백", e)
            // 예외 발생 시에도 카운트 롤백 시도
            try {
                val jwtToken = getJwtToken()
                if (jwtToken != null) {
                    rollbackUsageCount(jwtToken)
                }
            } catch (rollbackError: Exception) {
                Log.e(TAG, "🤖 ❌ 카운트 롤백 실패: ${rollbackError.message}", rollbackError)
            }
        }
    }
    
    /**
     * 사용량 카운트 롤백 (자동 요약 실패 시)
     * 서버에서 자동으로 롤백을 처리하지만, 클라이언트에서도 명시적으로 롤백 요청
     */
    private suspend fun rollbackUsageCount(jwtToken: String?) {
        if (jwtToken == null) {
            Log.w(TAG, "🤖 ⚠️ JWT 토큰 없음 - 카운트 롤백 스킵")
            return
        }
        
        try {
            // 서버에서 자동으로 롤백을 처리하므로, 여기서는 로그만 남김
            // 필요시 서버에 롤백 API가 있다면 호출 가능
            Log.i(TAG, "🤖 🔄 자동 요약 실패로 인한 카운트 롤백 요청 (서버에서 자동 처리됨)")
            
            // 참고: 서버의 LlmController에서 이미 onErrorResume으로 decrement를 호출하므로
            // 클라이언트에서 추가 API 호출은 불필요할 수 있음
            // 하지만 명시적으로 롤백을 요청하려면 아래 주석을 해제하고 API 호출 가능
            /*
            val request = Request.Builder()
                .url("$SUMMARY_API_BASE_URL/api/v1/llm/decrement") // 롤백 API 엔드포인트 (존재한다면)
                .post("".toRequestBody("application/json".toMediaType()))
                .addHeader("Authorization", "Bearer $jwtToken")
                .addHeader("Content-Type", "application/json")
                .build()
            
            val response = okHttpClient.newCall(request).execute()
            if (response.isSuccessful) {
                Log.i(TAG, "🤖 ✅ 카운트 롤백 성공")
            } else {
                Log.w(TAG, "🤖 ⚠️ 카운트 롤백 API 실패: ${response.code}")
            }
            */
        } catch (e: Exception) {
            Log.e(TAG, "🤖 ❌ 카운트 롤백 처리 중 오류: ${e.message}", e)
        }
    }
    
    /**
     * JWT 토큰 가져오기 (Flutter SharedPreferences에서)
     * Flutter에서 JWT 토큰을 발급받으면 SharedPreferences에 저장하므로 여기서 읽어옴
     * Flutter SharedPreferences는 "FlutterSharedPreferences" 파일에 "flutter." 접두사로 저장됨
     */
    private suspend fun getJwtToken(): String? {
        return withContext(Dispatchers.IO) {
            try {
                // Flutter SharedPreferences에서 JWT 토큰 읽기
                // Flutter는 "FlutterSharedPreferences" 파일에 "flutter." 접두사로 저장
                val prefs = getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
                val token = prefs.getString("flutter.jwt_token", null)
                if (token != null && token.isNotEmpty()) {
                    Log.d(TAG, "🤖 JWT 토큰 가져오기 성공 (FlutterSharedPreferences)")
                    return@withContext token
                }

                // SharedPreferences에 없으면 null 반환
                Log.w(TAG, "🤖 ⚠️ JWT 토큰 없음 (FlutterSharedPreferences에 flutter.jwt_token 키 없음)")
                return@withContext null
            } catch (e: Exception) {
                Log.e(TAG, "🤖 ❌ JWT 토큰 가져오기 실패: ${e.message}", e)
                return@withContext null
            }
        }
    }
    
    /**
     * 자동 요약 완료 푸시 알림 생성
     */
    private fun showAutoSummaryNotification(roomName: String, messageCount: Int, summaryId: Int) {
        try {
            // 시스템 알림 권한 확인
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val systemNotificationEnabled = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                notificationManager.areNotificationsEnabled()
            } else {
                true // API 24 미만에서는 항상 true로 간주
            }

            if (!systemNotificationEnabled) {
                Log.d(TAG, "🤖 시스템 알림 권한 없음 - 알림 생성 안 함")
                return
            }

            // 자동 요약 알림 활성화 여부 확인
            val prefs = getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            val notificationEnabled = prefs.getBoolean(AUTO_SUMMARY_NOTIFICATION_ENABLED_KEY, false)

            if (!notificationEnabled) {
                Log.d(TAG, "🤖 자동 요약 알림 비활성화 - 알림 생성 안 함")
                return
            }

            // 진동 및 소리 설정 확인
            val vibrationEnabled = prefs.getBoolean(VIBRATION_ENABLED_KEY, true)
            val soundEnabled = prefs.getBoolean(SOUND_ENABLED_KEY, true)

            // 알림 채널 재생성 (진동 및 소리 설정 반영)
            updateNotificationChannelVibration(vibrationEnabled)
            
            // 알림 채널이 존재하는지 확인 (없으면 생성)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                val channel = notificationManager.getNotificationChannel(AUTO_SUMMARY_CHANNEL_ID)
                if (channel == null) {
                    Log.w(TAG, "🤖 알림 채널이 없음 - 재생성")
                    createAutoSummaryNotificationChannel()
                }
            }

            // MainActivity로 이동하는 Intent 생성
            val intent = Intent(applicationContext, Class.forName("com.dksw.app.MainActivity")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("summaryId", summaryId)
            }
            val pendingIntent = PendingIntent.getActivity(
                applicationContext,
                summaryId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 알림 생성
            val notificationBuilder = NotificationCompat.Builder(applicationContext, AUTO_SUMMARY_CHANNEL_ID)
                .setContentTitle("자동 요약 완료")
                .setContentText("${roomName}의 메시지 ${messageCount}개가 요약되었습니다")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setSmallIcon(android.R.drawable.ic_dialog_info)

            // Android 8.0 미만에서는 직접 설정
            if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.O) {
                if (soundEnabled) {
                    notificationBuilder.setDefaults(Notification.DEFAULT_SOUND)
                }
                if (vibrationEnabled) {
                    notificationBuilder.setVibrate(longArrayOf(0, 300, 200, 300))
                }
            }

            notificationManager.notify(summaryId, notificationBuilder.build())

            Log.i(TAG, "🤖 ✅ 자동 요약 알림 생성 완료: roomName=$roomName, messageCount=$messageCount, vibration=$vibrationEnabled")

            // Flutter로 자동요약 알림 저장 요청 전송
            try {
                val saveNotificationIntent = Intent(ACTION_NOTIFICATION_RECEIVED).apply {
                    putExtra("type", "auto_summary")
                    putExtra("packageName", "com.dksw.app")
                    putExtra("sender", "AI 톡비서")
                    putExtra("message", "${roomName}의 메시지 ${messageCount}개가 요약되었습니다")
                    putExtra("roomName", roomName)
                    putExtra("postTime", System.currentTimeMillis())
                    putExtra("isAutoSummary", true)
                    putExtra("summaryId", summaryId) // Int 타입이므로 자동으로 Int로 저장됨
                    setPackage(packageName)
                    addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                }
                sendBroadcast(saveNotificationIntent)
                Log.d(TAG, "🤖 자동요약 알림 저장 요청 전송: summaryId=$summaryId")
            } catch (e: Exception) {
                Log.e(TAG, "🤖 자동요약 알림 저장 요청 실패: ${e.message}")
            }

        } catch (e: Exception) {
            Log.e(TAG, "🤖 ❌ 자동 요약 알림 생성 실패: ${e.message}", e)
        }
    }

    /**
     * 알림 채널 설정 업데이트 (진동 및 소리)
     */
    private fun updateNotificationChannelVibration(vibrationEnabled: Boolean) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 기존 채널 삭제
            notificationManager.deleteNotificationChannel(AUTO_SUMMARY_CHANNEL_ID)

            // SharedPreferences에서 소리 설정 읽기
            val prefs = applicationContext.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            val soundEnabled = prefs.getBoolean(SOUND_ENABLED_KEY, true)

            // 새 채널 생성 (진동 및 소리 설정 반영)
            val channel = NotificationChannel(
                AUTO_SUMMARY_CHANNEL_ID,
                AUTO_SUMMARY_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "AI 톡비서 자동 요약 완료 알림"

                // 소리 설정
                if (soundEnabled) {
                    // 커스텀 사운드 설정 (톡비서)
                    try {
                        val soundUri = android.net.Uri.parse(
                            "android.resource://${packageName}/raw/tokbiseo"
                        )
                        setSound(soundUri, android.media.AudioAttributes.Builder()
                            .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build())
                    } catch (e: Exception) {
                        setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, null)
                    }
                } else {
                    // 소리 끄기
                    setSound(null, null)
                }

                // 진동 설정
                if (vibrationEnabled) {
                    vibrationPattern = longArrayOf(0, 300, 200, 300)
                    enableVibration(true)
                } else {
                    enableVibration(false)
                }

                // LED 설정
                enableLights(true)
                lightColor = android.graphics.Color.BLUE
            }

            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "🔔 알림 채널 업데이트: sound=$soundEnabled, vibration=$vibrationEnabled")
        }
    }

    /**
     * FREE 유저 페이월 알림 체크
     * 안읽은 메시지가 FREE 제한(50개)을 처음 넘었을 때 구독 유도 알림 발송
     */
    private fun checkAndSendPaywallNotification(roomId: Long, roomName: String, unreadCount: Int) {
        // FREE 제한을 딱 넘은 시점(51개)에만 발송
        if (unreadCount != FREE_UNREAD_THRESHOLD + 1) return

        autoSummaryScope.launch {
            try {
                // SharedPreferences에서 캐시된 플랜 타입 확인 (API 호출 불필요)
                val prefs = applicationContext.getSharedPreferences(FLUTTER_PREFS_NAME, android.content.Context.MODE_PRIVATE)
                val planType = prefs.getString(PLAN_TYPE_KEY, "free") ?: "free"

                // BASIC 유저는 스킵
                if (planType == "basic") return@launch

                // 24시간 쿨다운 체크 (같은 방에 하루 1번만 발송)
                val lastNotifKey = "paywall_notif_$roomId"
                val lastNotifTime = prefs.getLong(lastNotifKey, 0L)
                if (System.currentTimeMillis() - lastNotifTime < PAYWALL_NOTIF_COOLDOWN_MS) {
                    Log.d(TAG, "💰 페이월 알림 쿨다운 중: roomName='$roomName'")
                    return@launch
                }

                // 쿨다운 시간 저장
                prefs.edit().putLong(lastNotifKey, System.currentTimeMillis()).apply()

                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    sendPaywallNotification(roomId, roomName, unreadCount)
                }
            } catch (e: Exception) {
                Log.e(TAG, "💰 페이월 알림 체크 실패: ${e.message}", e)
            }
        }
    }

    /**
     * FREE 유저 구독 유도 로컬 알림 발송
     * 클릭 시 앱의 구독 화면으로 이동
     */
    private fun sendPaywallNotification(roomId: Long, roomName: String, unreadCount: Int) {
        try {
            val notificationManager = getSystemService(android.content.Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

            // 알림 채널 확인/생성
            createAutoSummaryNotificationChannel()

            // 구독 화면으로 이동하는 Intent
            val intent = Intent(applicationContext, Class.forName("com.dksw.app.MainActivity")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("openSubscription", true)
            }
            val pendingIntent = android.app.PendingIntent.getActivity(
                applicationContext,
                ("paywall_$roomId").hashCode(),
                intent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(applicationContext, AUTO_SUMMARY_CHANNEL_ID)
                .setContentTitle(roomName)
                .setContentText("메시지 ${unreadCount}개 쌓임 · 자동 분석은 BASIC에서 제공됩니다")
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText("${unreadCount}개의 메시지가 쌓였습니다.\n자동 분석 및 최대 200개 요약은 BASIC 플랜(월 2,900원)에서 이용 가능합니다.")
                        .setSummaryText("BASIC으로 업그레이드")
                )
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .build()

            notificationManager.notify(("paywall_$roomId").hashCode(), notification)
            Log.i(TAG, "💰 FREE 페이월 알림 발송: roomName='$roomName', unreadCount=$unreadCount")
        } catch (e: Exception) {
            Log.e(TAG, "💰 페이월 알림 발송 실패: ${e.message}", e)
        }
    }
}
