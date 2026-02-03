package com.example.chat_llm

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
        const val ACTION_NOTIFICATION_RECEIVED = "com.example.chat_llm.NOTIFICATION_RECEIVED"
        const val ACTION_CANCEL_NOTIFICATION = "com.example.chat_llm.CANCEL_NOTIFICATION"
        const val ACTION_CANCEL_ROOM_NOTIFICATIONS = "com.example.chat_llm.CANCEL_ROOM_NOTIFICATIONS"
        const val ACTION_ROOM_UPDATED = "com.example.chat_llm.ROOM_UPDATED"
        const val ACTION_SEND_MESSAGE = "com.example.chat_llm.SEND_MESSAGE"

        // 알림 수신 대상 메신저 (카카오톡만)
        val SUPPORTED_MESSENGERS = mapOf(
            "com.kakao.talk" to "카카오톡"
        )

        // Flutter SharedPreferences 키 (음소거 설정용)
        const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
        const val MUTED_ROOMS_KEY = "flutter.muted_rooms"
        const val AUTO_SUMMARY_NOTIFICATION_ENABLED_KEY = "flutter.auto_summary_notification_enabled"
        const val VIBRATION_ENABLED_KEY = "flutter.notification_vibration_enabled"
        
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

    // 자동 요약 진행 중인 채팅방 ID (중복 실행 방지)
    private val autoSummaryInProgress = mutableSetOf<Long>()

    // 로그 샘플링 카운터 (성능 최적화 - 배터리/성능 영향 최소화)
    // Long으로 선언하여 overflow 방지, 주기적 reset으로 메모리 최적화
    private var logCounter = 0L
    private val logSampleRate = 50L // 50개 중 1개만 로그 출력
    private val logResetThreshold = 10000L // 10000개마다 리셋하여 overflow 방지

    // ★★★ 디버그 모드: true로 설정하면 모든 알림 데이터를 상세히 로그 출력 ★★★
    private val DEBUG_NOTIFICATION_DATA = true
    
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
     * 대화방 프로필 사진을 앱 filesDir에 저장 (캐시 삭제해도 유지)
     * 저장 경로: /data/data/com.example.chat_llm/files/profile/room/{roomName}.jpg
     */
    private fun saveRoomProfileImage(roomName: String, bitmap: Bitmap?) {
        if (bitmap == null) return

        try {
            val safeRoomName = roomName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
            val profileDir = File(applicationContext.filesDir, "profile/room")
            if (!profileDir.exists()) {
                profileDir.mkdirs()
            }

            val profileFile = File(profileDir, "$safeRoomName.jpg")
            FileOutputStream(profileFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
            }
            Log.d(TAG, "대화방 프로필 사진 저장: ${profileFile.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "대화방 프로필 사진 저장 실패: ${e.message}", e)
        }
    }

    /**
     * 보낸사람 프로필 사진을 앱 filesDir에 저장 (캐시 삭제해도 유지)
     * 저장 경로: /data/data/com.example.chat_llm/files/profile/sender/{hash}.jpg
     * 해시 기반 파일명으로 충돌 방지 (packageName + roomName + senderName)
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

        try {
            val profileDir = File(applicationContext.filesDir, "profile/sender")
            if (!profileDir.exists()) {
                val created = profileDir.mkdirs()
                Log.d(TAG, "프로필 디렉토리 생성: ${profileDir.absolutePath} (성공: $created)")
            }

            // 해시 기반 파일명 생성 (충돌 방지)
            val fileKey = getSenderProfileKey(packageName, roomName, senderName)
            val profileFile = File(profileDir, "$fileKey.jpg")
            
            // 기존 파일이 있으면 덮어쓰기
            if (profileFile.exists()) {
                Log.d(TAG, "기존 프로필 파일 덮어쓰기: ${profileFile.absolutePath}")
            }
            
            FileOutputStream(profileFile).use { out ->
                val compressed = bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                out.flush()
                Log.d(TAG, "비트맵 압축 성공: $compressed")
            }
            
            // 저장 확인
            val fileSize = profileFile.length()
            val fileExists = profileFile.exists()
            
            Log.i(TAG, "✅ 보낸사람 프로필 사진 저장 완료:")
            Log.i(TAG, "   패키지: '$packageName'")
            Log.i(TAG, "   대화방: '$roomName'")
            Log.i(TAG, "   보낸사람: '$senderName'")
            Log.i(TAG, "   파일 키: '$fileKey'")
            Log.i(TAG, "   저장 경로: ${profileFile.absolutePath}")
            Log.i(TAG, "   파일 존재: $fileExists")
            Log.i(TAG, "   파일 크기: $fileSize bytes")
            Log.i(TAG, "   비트맵 크기: ${bitmap.width}x${bitmap.height}")
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
    private fun saveNotificationImage(roomName: String, bitmap: Bitmap?, postTime: Long): String? {
        if (bitmap == null) {
            Log.w(TAG, "이미지 저장 실패: bitmap이 null")
            return null
        }

        val safeRoomName = roomName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val fileName = "img_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date(postTime))}.jpg"

        try {
            // 앱 내부 저장소 사용 (갤러리에 보이지 않음)
            val imagesDir = File(applicationContext.filesDir, "images/$safeRoomName")
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
        Log.i(TAG, "🖼️ ========== extractSharedImage 시작 ==========")
        Log.i(TAG, "🖼️ 메시지 텍스트: '$messageText'")

        // 이모티콘/스티커 여부 확인
        val isEmojiOrSticker = messageText.contains("이모티콘", ignoreCase = true) ||
                               messageText.contains("스티커", ignoreCase = true)

        if (isEmojiOrSticker) {
            // 이모티콘은 emoticon_dir 경로라 FileProvider 권한 없음 - URI 접근 시도 안 함
            Log.d(TAG, "🎨 이모티콘/스티커 → URI 접근 스킵, 텍스트만 저장")
            return null
        }

        // 일반 사진/링크 이미지 추출
        Log.d(TAG, "--- 일반 사진 이미지 추출 모드 ---")
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
            Log.i(TAG, "🎨 EXTRA_MESSAGES 개수: ${messages?.size ?: 0}")

            if (messages != null && messages.isNotEmpty()) {
                val latestMessage = messages[messages.size - 1] as? Bundle
                if (latestMessage != null) {
                    Log.i(TAG, "🎨 --- 최신 메시지 Bundle 상세 정보 (이모티콘) ---")
                    for (key in latestMessage.keySet()) {
                        val value = latestMessage.get(key)
                        Log.i(TAG, "🎨   키: '$key' = ${value?.javaClass?.simpleName ?: "null"} / 값: ${value?.toString()?.take(100)}")
                    }

                    // 1. 먼저 Bundle에서 직접 Bitmap 찾기
                    for (key in latestMessage.keySet()) {
                        val value = latestMessage.get(key)
                        if (value is Bitmap) {
                            Log.i(TAG, "✅ 이모티콘 Bundle에서 직접 Bitmap 발견: 키='$key' (크기: ${value.width}x${value.height})")
                            return value
                        }
                    }
                    
                    // 2. URI 확인 (이모티콘은 Message Bundle의 uri 키에 있음)
                    var uri: android.net.Uri? = null
                    
                    // Uri 객체로 시도
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        uri = latestMessage.getParcelable("uri", android.net.Uri::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        uri = latestMessage.getParcelable("uri") as? android.net.Uri
                    }
                    
                    // String으로 시도
                    if (uri == null) {
                        val uriStr = latestMessage.getString("uri")
                        Log.i(TAG, "🎨 URI String 값: '${uriStr?.take(200) ?: "null"}'")
                        if (uriStr != null && uriStr.isNotEmpty()) {
                            try {
                                uri = android.net.Uri.parse(uriStr)
                                Log.i(TAG, "🎨 ✅ 이모티콘 URI 발견 (String 파싱): $uri")
                            } catch (e: Exception) {
                                Log.w(TAG, "🎨 ❌ 이모티콘 URI 파싱 실패: $uriStr, error: ${e.message}")
                            }
                        } else {
                            Log.i(TAG, "🎨 ⚠️ URI String이 null이거나 비어있음")
                        }
                    } else {
                        Log.i(TAG, "🎨 ✅ 이모티콘 URI 발견 (Uri 객체): $uri")
                    }

                    // MIME 타입 확인
                    val mimeType = latestMessage.getString("type") ?: ""
                    Log.i(TAG, "🎨 MIME 타입: '$mimeType'")
                    
                    // URI에서 이미지 로드 (MIME 타입이 image/로 시작하거나, emoticon_dir 경로가 있으면)
                    if (uri != null) {
                        val uriString = uri.toString()
                        val isEmoticonPath = uriString.contains("emoticon_dir", ignoreCase = true) ||
                                            uriString.contains("sticker", ignoreCase = true)

                        Log.i(TAG, "🎨 URI 분석: isEmoticonPath=$isEmoticonPath, mimeType='$mimeType', uriString=${uriString.take(200)}")

                        if (mimeType.startsWith("image/") || isEmoticonPath || mimeType.isEmpty()) {
                            Log.i(TAG, "🎨 URI에서 이모티콘 이미지 로드 시도: $uri")
                            val bitmap = loadBitmapFromUri(uri)
                            if (bitmap != null) {
                                Log.i(TAG, "🎨 ✅ 이모티콘/스티커 이미지 추출 성공 (크기: ${bitmap.width}x${bitmap.height})")
                                return bitmap
                            } else {
                                // ⚠️ 파일 경로 시도는 loadBitmapFromUri 내부에서 이미 했으므로 중복 제거
                                Log.w(TAG, "🎨 ⚠️ 이모티콘 URI에서 Bitmap 로드 실패: $uri")
                            }
                        } else {
                            Log.i(TAG, "🎨 ⚠️ MIME 타입이 image가 아님: '$mimeType' → 이미지 로드 스킵")
                        }
                    } else {
                        Log.w(TAG, "🎨 ❌ 이모티콘 URI를 찾을 수 없음 (uri=null)")
                    }
                } else {
                    Log.i(TAG, "🎨 ⚠️ latestMessage가 null")
                }
            } else {
                Log.i(TAG, "🎨 ⚠️ EXTRA_MESSAGES가 null이거나 비어있음")
            }
        } catch (e: Exception) {
            Log.e(TAG, "🎨 ❌ 이모티콘 이미지 추출 실패: ${e.message}", e)
        }

        Log.i(TAG, "🎨 ========== 이모티콘/스티커 이미지 추출 완료 (실패) ==========")
        return null
    }
    
    /**
     * 일반 사진 이미지 추출 (EXTRA_PICTURE, largeIcon 등에서)
     * ⚠️ 복구: LargeIcon에서 사진 추출 로직 활성화 (크기 조건 200x200 이상)
     */
    @Suppress("DEPRECATION")
    private fun extractPhotoImage(notification: Notification, extras: Bundle): Bitmap? {
        Log.d(TAG, "일반 사진 이미지 추출 시작...")

        // Bundle의 모든 키 확인 (디버깅용)
        val hasReducedImages = extras.getBoolean("android.reduced.images", false)
        if (hasReducedImages) {
            Log.w(TAG, "⚠️ android.reduced.images=true - 이미지가 축소되었거나 다른 위치에 있을 수 있음")
        }
        
        // 0.5. extras의 모든 Bundle을 재귀적으로 탐색 (강화된 검색)
        Log.d(TAG, "--- extras 전체 재귀적 이미지 검색 ---")
        val recursiveBitmap = findBitmapRecursively(extras, maxDepth = 5)
        if (recursiveBitmap != null) {
            Log.i(TAG, "✅ 재귀적 검색으로 Bitmap 발견 (크기: ${recursiveBitmap.width}x${recursiveBitmap.height})")
            return recursiveBitmap
        }
        
        // android.reduced.images가 true일 때 추가 확인
        if (hasReducedImages) {
            Log.d(TAG, "--- reduced.images=true인 경우 추가 이미지 검색 ---")
            for (key in extras.keySet()) {
                val value = extras.get(key)
                if (value is Bundle) {
                    Log.d(TAG, "  Bundle '$key'에서 이미지 검색...")
                    for (bundleKey in value.keySet()) {
                        val bundleValue = value.get(bundleKey)
                        if (bundleValue is Bitmap) {
                            Log.i(TAG, "✅ Bundle '$key'의 '$bundleKey'에서 Bitmap 발견 (크기: ${bundleValue.width}x${bundleValue.height})")
                            return bundleValue
                        } else if (bundleValue is android.net.Uri) {
                            val bitmap = loadBitmapFromUri(bundleValue)
                            if (bitmap != null) {
                                Log.i(TAG, "✅ Bundle에서 URI로 이미지 로드 성공 (크기: ${bitmap.width}x${bitmap.height})")
                                return bitmap
                            }
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
        if (picture != null) {
            Log.i(TAG, "✅ EXTRA_PICTURE에서 사진 발견 (크기: ${picture.width}x${picture.height})")
            return picture
        }
        
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
                if (image != null) {
                    Log.i(TAG, "✅ 키 '$key'에서 사진 발견 (크기: ${image.width}x${image.height})")
                    return image
                }
            }
        }

        // 3. MessagingStyle 메시지에서 이미지 URI 추출 시도 (사진용)
        try {
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            Log.d(TAG, "EXTRA_MESSAGES 개수: ${messages?.size ?: 0}")
            
            if (messages != null && messages.isNotEmpty()) {
                // 모든 메시지에서 Bitmap 직접 확인 (URI보다 먼저)
                Log.d(TAG, "--- 모든 메시지에서 Bitmap 직접 검색 ---")
                for (i in messages.size - 1 downTo 0) {
                    val msg = messages[i] as? Bundle
                    if (msg != null) {
                        // 각 메시지의 모든 키에서 Bitmap 직접 확인
                        for (key in msg.keySet()) {
                            val value = msg.get(key)
                            if (value is Bitmap && (value.width > 200 || value.height > 200)) {
                                Log.i(TAG, "✅ 메시지[$i]의 키 '$key'에서 Bitmap 직접 발견 (크기: ${value.width}x${value.height})")
                                return value
                            }
                        }
                        // Bundle 내부도 재귀적으로 검색
                        val bitmap = findBitmapRecursively(msg, maxDepth = 3)
                        if (bitmap != null) {
                            Log.i(TAG, "✅ 메시지[$i]에서 재귀 검색으로 Bitmap 발견 (크기: ${bitmap.width}x${bitmap.height})")
                            return bitmap
                        }
                    }
                }
                
                // 가장 최신 메시지에서 이미지 확인
                val latestMessage = messages[messages.size - 1] as? Bundle
                if (latestMessage != null) {
                    // Bundle의 모든 키와 값을 로그로 출력 (디버깅용)
                    Log.d(TAG, "--- 최신 메시지 Bundle 상세 정보 ---")
                    for (key in latestMessage.keySet()) {
                        val value = latestMessage.get(key)
                        val valueType = when (value) {
                            is Bundle -> {
                                // Bundle인 경우 내부 키도 확인
                                val bundleKeys = value.keySet().joinToString(", ")
                                "Bundle(${value.keySet().size} keys: $bundleKeys)"
                            }
                            is android.net.Uri -> "Uri($value)"
                            is Bitmap -> "Bitmap(${value.width}x${value.height})"
                            else -> value?.javaClass?.simpleName ?: "null"
                        }
                        Log.d(TAG, "  키: '$key' = $valueType")
                        
                        // extras Bundle이면 내부도 확인
                        if (value is Bundle && key == "extras") {
                            Log.d(TAG, "    --- extras Bundle 내부 ---")
                            for (extrasKey in value.keySet()) {
                                val extrasValue = value.get(extrasKey)
                                Log.d(TAG, "      키: '$extrasKey' = ${extrasValue?.javaClass?.simpleName ?: "null"}")
                            }
                        }
                    }
                    
                    // 이미지 URI 확인 (uri는 Uri 객체일 수도 있고 String일 수도 있음)
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
                        
                        if (uri != null) {
                            Log.d(TAG, "✅ Uri 객체로 발견: 키='$key', URI=$uri")
                            break
                        }
                    }
                    
                    // 방법 2: String으로 가져오기 (Uri 객체가 아닌 경우)
                    if (uri == null) {
                        for (key in uriKeys) {
                            val uriStr = latestMessage.getString(key)
                            if (uriStr != null && uriStr.isNotEmpty()) {
                                try {
                                    uri = android.net.Uri.parse(uriStr)
                                    Log.d(TAG, "✅ String에서 URI 파싱 성공: 키='$key', URI=$uri")
                                    break
                                } catch (e: Exception) {
                                    Log.w(TAG, "String에서 URI 파싱 실패: 키='$key', 값='$uriStr', ${e.message}")
                                }
                            }
                        }
                    }
                    
                    // 방법 3: extras Bundle 내부에서 URI 찾기 (모든 키 확인)
                    if (uri == null) {
                        val extrasBundle = latestMessage.getBundle("extras")
                        if (extrasBundle != null) {
                            Log.d(TAG, "extras Bundle에서 URI 찾기 시도...")
                            // 먼저 uriKeys로 시도
                            for (key in uriKeys) {
                                // Uri 객체로 시도
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    uri = extrasBundle.getParcelable(key, android.net.Uri::class.java)
                                } else {
                                    @Suppress("DEPRECATION")
                                    uri = extrasBundle.getParcelable(key) as? android.net.Uri
                                }
                                
                                if (uri != null) {
                                    Log.d(TAG, "✅ extras Bundle에서 Uri 객체 발견: 키='$key', URI=$uri")
                                    break
                                }
                                
                                // String으로 시도
                                val uriStr = extrasBundle.getString(key)
                                if (uriStr != null && uriStr.isNotEmpty()) {
                                    try {
                                        uri = android.net.Uri.parse(uriStr)
                                        Log.d(TAG, "✅ extras Bundle에서 String URI 파싱 성공: 키='$key', URI=$uri")
                                        break
                                    } catch (e: Exception) {
                                        Log.w(TAG, "extras Bundle에서 URI 파싱 실패: 키='$key', 값='$uriStr'")
                                    }
                                }
                            }
                            
                            // uriKeys로 찾지 못했으면 모든 키를 확인 (오픈채팅 대응)
                            if (uri == null) {
                                for (key in extrasBundle.keySet()) {
                                    val value = extrasBundle.get(key)
                                    if (value is android.net.Uri) {
                                        uri = value
                                        Log.d(TAG, "✅ extras Bundle에서 URI 발견 (모든 키 확인): 키='$key', URI=$uri")
                                        break
                                    } else if (value is String && value.startsWith("content://")) {
                                        try {
                                            uri = android.net.Uri.parse(value)
                                            Log.d(TAG, "✅ extras Bundle에서 URI String 파싱 성공 (모든 키 확인): 키='$key', URI=$uri")
                                            break
                                        } catch (e: Exception) {
                                            Log.w(TAG, "extras Bundle에서 URI String 파싱 실패: 키='$key', 값='$value'")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 방법 4: 모든 메시지에서 이미지 URI 찾기 (오픈채팅 대응 - 최신 메시지에서 못 찾았을 때)
                    if (uri == null && messages != null && messages.size > 1) {
                        Log.d(TAG, "최신 메시지에서 URI를 찾지 못함 - 모든 메시지 확인 중...")
                        for (i in messages.size - 2 downTo 0) {
                            val msg = messages[i] as? Bundle
                            if (msg != null) {
                                // 각 메시지의 모든 키 확인
                                for (key in msg.keySet()) {
                                    val value = msg.get(key)
                                    if (value is android.net.Uri) {
                                        uri = value
                                        Log.d(TAG, "✅ 메시지[$i]에서 URI 발견: 키='$key', URI=$uri")
                                        break
                                    } else if (value is String && value.startsWith("content://")) {
                                        try {
                                            uri = android.net.Uri.parse(value)
                                            Log.d(TAG, "✅ 메시지[$i]에서 URI String 파싱 성공: 키='$key', URI=$uri")
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
                            Log.d(TAG, "✅ MIME 타입 발견: 키='$key', 타입='$mimeType'")
                            break
                        }
                    }

                    Log.d(TAG, "최종 결과 - URI: $uri, MIME: '$mimeType'")

                    // 사진용 URI 추출: 이모티콘/스티커 경로는 제외
                    if (uri != null) {
                        val uriString = uri.toString()
                        val isEmoticonPath = uriString.contains("emoticon_dir", ignoreCase = true) || 
                                            uriString.contains("sticker", ignoreCase = true)
                        
                        if (isEmoticonPath) {
                            Log.d(TAG, "⚠️ 이모티콘/스티커 경로 감지 - 사진 추출에서 제외: $uri")
                        } else if (mimeType.startsWith("image/") || mimeType.isEmpty()) {
                            // content:// URI에서 Bitmap 로드
                            Log.d(TAG, "URI에서 사진 Bitmap 로드 시도: $uri (MIME: '$mimeType')")
                            val bitmap = loadBitmapFromUri(uri)
                            if (bitmap != null) {
                                // 사진은 보통 크기가 큼 (200x200 이상)
                                if (bitmap.width >= 200 || bitmap.height >= 200) {
                                    Log.i(TAG, "✅ MessagingStyle 메시지에서 사진 추출 성공 (크기: ${bitmap.width}x${bitmap.height})")
                                    return bitmap
                                } else {
                                    Log.d(TAG, "⚠️ 이미지 크기가 작아서 프로필 이미지로 간주: ${bitmap.width}x${bitmap.height}")
                                }
                            } else {
                                // ⚠️ 파일 경로 시도는 loadBitmapFromUri 내부에서 이미 했으므로 중복 제거
                                Log.d(TAG, "⚠️ URI에서 Bitmap 로드 실패: $uri")
                            }
                        } else {
                            Log.d(TAG, "❌ MIME 타입이 image가 아님: '$mimeType'")
                        }
                    } else {
                        Log.d(TAG, "❌ URI를 찾을 수 없음 (MIME: '$mimeType')")
                    }
                } else {
                    Log.d(TAG, "최신 메시지가 Bundle이 아님")
                }
            } else {
                Log.d(TAG, "EXTRA_MESSAGES가 null이거나 비어있음")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ MessagingStyle 사진 이미지 추출 실패: ${e.message}", e)
            e.printStackTrace()
        }

        // ⚠️ 복구: 마지막 수단으로 LargeIcon에서 이미지 추출 시도
        // 다른 방법이 모두 실패한 경우에만 LargeIcon 확인
        // 카카오톡에서 사진/이모티콘 알림 시 LargeIcon에 썸네일이 있을 수 있음
        Log.d(TAG, "--- LargeIcon에서 이미지 추출 시도 (마지막 수단) ---")
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
                    if (bitmap.width >= 200 || bitmap.height >= 200) {
                        Log.i(TAG, "✅ LargeIcon에서 사진 발견 (크기: ${bitmap.width}x${bitmap.height})")
                        return bitmap
                    } else {
                        Log.d(TAG, "⚠️ LargeIcon 크기가 작음 (${bitmap.width}x${bitmap.height}) - 프로필 이미지로 간주")
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "LargeIcon에서 이미지 추출 실패: ${e.message}")
            }
        }

        Log.d(TAG, "========== extractPhotoImage 종료 (이미지 없음) ==========")
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
                    // 프로필 이미지보다 큰 경우에만 사진으로 간주
                    if (value.width > 200 || value.height > 200) {
                        Log.d(TAG, "재귀 검색: 키 '$key'에서 Bitmap 발견 (크기: ${value.width}x${value.height})")
                        return value
                    }
                }
                
                // Uri 발견
                if (value is android.net.Uri) {
                    val uriString = value.toString()
                    // 이모티콘/스티커 경로는 제외
                    if (!uriString.contains("emoticon_dir", ignoreCase = true) && 
                        !uriString.contains("sticker", ignoreCase = true)) {
                        val bitmap = loadBitmapFromUri(value)
                        if (bitmap != null && (bitmap.width > 200 || bitmap.height > 200)) {
                            Log.d(TAG, "재귀 검색: 키 '$key'에서 URI로 Bitmap 로드 성공 (크기: ${bitmap.width}x${bitmap.height})")
                            return bitmap
                        }
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
                            if (bitmap != null && (bitmap.width > 200 || bitmap.height > 200)) {
                                Log.d(TAG, "재귀 검색: 키 '$key'에서 String URI로 Bitmap 로드 성공 (크기: ${bitmap.width}x${bitmap.height})")
                                return bitmap
                            }
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
                            Log.d(TAG, "재귀 검색: Array에서 Bitmap 발견 (크기: ${item.width}x${item.height})")
                            return item
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "재귀 검색 중 오류: ${e.message}")
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
     * ⚠️ 보수적 수정: 카카오톡 FileProvider URI 접근 문제 해결
     * - 먼저 FileProvider URI에서 파일 경로 추출 시도 (권한 우회)
     * - 그 다음 ContentResolver.openInputStream() 사용
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
        Log.i(TAG, "========== extractSenderProfileImage 시작 ==========")
        Log.i(TAG, "isPrivateChat: $isPrivateChat")
        
        // 1. MessagingStyle의 Message Bundle에서 sender(Person).icon 추출 시도
        try {
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            Log.i(TAG, "EXTRA_MESSAGES 개수: ${messages?.size ?: 0}")
            
            if (messages != null && messages.isNotEmpty()) {
                // 모든 메시지 확인 (디버깅용)
                Log.i(TAG, "--- 모든 EXTRA_MESSAGES 확인 ---")
                messages.forEachIndexed { index, msg ->
                    Log.i(TAG, "  messages[$index] 타입: ${msg?.javaClass?.simpleName}")
                    if (msg is Bundle) {
                        Log.i(TAG, "  messages[$index] Bundle 키들: ${msg.keySet()}")
                        for (key in msg.keySet()) {
                            val value = msg.get(key)
                            Log.i(TAG, "    $key: $value (${value?.javaClass?.simpleName})")
                        }
                    }
                }
                
                // 가장 최신 메시지에서 sender 추출
                val messageBundle = messages[messages.size - 1] as? Bundle  // 마지막이 최신일 수 있음
                    ?: messages[0] as? Bundle  // 또는 첫 번째
                Log.i(TAG, "선택된 messageBundle: ${messageBundle != null}")
                
                if (messageBundle != null) {
                    Log.i(TAG, "messageBundle 키들: ${messageBundle.keySet()}")
                    
                    // Bundle 내의 sender_person 키에서 Person 추출 (sender는 String이므로 sender_person 먼저!)
                    val sender: android.app.Person? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        messageBundle.getParcelable("sender_person", android.app.Person::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        messageBundle.getParcelable("sender_person") as? android.app.Person
                    }

                    if (sender != null) {
                        Log.i(TAG, "✅ sender Person 발견!")
                        Log.i(TAG, "   sender.name: ${sender.name}")
                        Log.i(TAG, "   sender.key: ${sender.key}")
                        Log.i(TAG, "   sender.uri: ${sender.uri}")
                        Log.i(TAG, "   sender.isBot: ${sender.isBot}")
                        Log.i(TAG, "   sender.isImportant: ${sender.isImportant}")
                        
                        val icon = sender.icon
                        Log.i(TAG, "   sender.icon 존재: ${icon != null}")
                        
                        if (icon != null) {
                            Log.i(TAG, "   icon.type: ${icon.type}")
                            // Icon 타입별 처리 (BITMAP=1, RESOURCE=2, DATA=3, URI=4, ADAPTIVE_BITMAP=5)
                            // resId는 RESOURCE 타입(2)에서만 유효하므로 type 체크 필요
                            when (icon.type) {
                                android.graphics.drawable.Icon.TYPE_RESOURCE -> {
                                    try {
                                        Log.i(TAG, "   icon.resId: ${icon.resId}")
                                    } catch (e: Exception) {
                                        Log.w(TAG, "   icon.resId 접근 불가")
                                    }
                                }
                                android.graphics.drawable.Icon.TYPE_BITMAP -> {
                                    Log.i(TAG, "   icon 타입: BITMAP (직접 비트맵 추출)")
                                }
                                android.graphics.drawable.Icon.TYPE_ADAPTIVE_BITMAP -> {
                                    Log.i(TAG, "   icon 타입: ADAPTIVE_BITMAP")
                                }
                                else -> {
                                    Log.i(TAG, "   icon 타입: ${icon.type}")
                                }
                            }
                            
                            // loadDrawable로 모든 Icon 타입에서 Bitmap 추출 시도
                            val drawable = icon.loadDrawable(applicationContext)
                            Log.i(TAG, "   drawable 로드 성공: ${drawable != null}")
                            
                            if (drawable != null) {
                                Log.i(TAG, "   drawable 크기: ${drawable.intrinsicWidth}x${drawable.intrinsicHeight}")
                                
                                if (drawable.intrinsicWidth > 0 && drawable.intrinsicHeight > 0) {
                                    val bitmap = Bitmap.createBitmap(
                                        drawable.intrinsicWidth,
                                        drawable.intrinsicHeight,
                                        Bitmap.Config.ARGB_8888
                                    )
                                    val canvas = android.graphics.Canvas(bitmap)
                                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                                    drawable.draw(canvas)
                                    Log.i(TAG, "✅✅✅ sender.icon에서 프로필 추출 성공: ${bitmap.width}x${bitmap.height}")
                                    return bitmap
                                } else {
                                    Log.w(TAG, "⚠️ drawable 크기가 0")
                                }
                            }
                        } else {
                            Log.w(TAG, "⚠️ sender.icon이 null")
                        }
                    } else {
                        Log.w(TAG, "⚠️ messageBundle에 sender/sender_person이 없음")
                    }
                }
            } else {
                Log.w(TAG, "⚠️ EXTRA_MESSAGES가 null이거나 비어있음")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Message sender.icon 추출 실패: ${e.message}", e)
        }
        
        // 2. extras에서 다른 프로필 관련 필드 확인
        Log.i(TAG, "--- extras에서 추가 프로필 정보 확인 ---")
        try {
            // android.messagingUser (MessagingStyle의 user)
            val messagingUser: android.app.Person? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                extras.getParcelable("android.messagingUser", android.app.Person::class.java)
            } else {
                @Suppress("DEPRECATION")
                extras.getParcelable("android.messagingUser") as? android.app.Person
            }
            if (messagingUser != null) {
                Log.i(TAG, "messagingUser 발견: ${messagingUser.name}, icon=${messagingUser.icon != null}")
            }
            
            // android.remoteInputHistory
            val remoteInputHistory = extras.getCharSequenceArray("android.remoteInputHistory")
            Log.i(TAG, "remoteInputHistory: ${remoteInputHistory?.size ?: 0}개")
            
            // android.people.list
            val peopleList = extras.getParcelableArrayList<android.app.Person>("android.people.list")
            Log.i(TAG, "people.list: ${peopleList?.size ?: 0}개")
            peopleList?.forEachIndexed { index, person ->
                Log.i(TAG, "  person[$index]: ${person.name}, icon=${person.icon != null}")
                if (person.icon != null) {
                    val drawable = person.icon?.loadDrawable(applicationContext)
                    if (drawable != null && drawable.intrinsicWidth > 0) {
                        Log.i(TAG, "  ✅ people.list[$index]에서 아이콘 발견! ${drawable.intrinsicWidth}x${drawable.intrinsicHeight}")
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
            Log.e(TAG, "extras 추가 정보 확인 실패: ${e.message}")
        }

        // 3. 개인톡의 경우에만 LargeIcon을 보낸사람 프로필로 사용
        if (isPrivateChat) {
            Log.i(TAG, "개인톡: LargeIcon을 보낸사람 프로필로 시도")
            val largeIconBitmap = extractRoomProfileImage(notification)
            if (largeIconBitmap != null) {
                Log.i(TAG, "✅ 개인톡: LargeIcon 사용 (${largeIconBitmap.width}x${largeIconBitmap.height})")
                return largeIconBitmap
            }
        }

        // 4. 그룹톡/오픈톡에서 Person.icon이 없으면 저장하지 않음
        if (!isPrivateChat) {
            Log.w(TAG, "⚠️ 그룹톡/오픈톡: 개인 프로필 아이콘 없음 → sender 프로필 저장 안 함")
        }

        Log.i(TAG, "========== extractSenderProfileImage 종료 (실패) ==========")
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

    /**
     * 채팅방이 음소거 상태인지 확인
     * Flutter SharedPreferences에서 muted_rooms 목록을 읽어서 확인
     * ★ 화면 켜짐 방지를 위해 최대한 빠르게 처리 ★
     */
    private fun isRoomMuted(roomName: String): Boolean {
        try {
            // SharedPreferences 직접 읽기 (캐시 없이 항상 최신 상태 확인)
            val prefs = applicationContext.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            val mutedRoomsJson = prefs.getString(MUTED_ROOMS_KEY, null)

            Log.d(TAG, "🔇 음소거 확인: roomName='$roomName', mutedRoomsJson=${mutedRoomsJson?.take(100) ?: "null"}")

            if (mutedRoomsJson != null && mutedRoomsJson.isNotEmpty()) {
                val mutedRooms = JSONArray(mutedRoomsJson)
                for (i in 0 until mutedRooms.length()) {
                    val mutedRoom = mutedRooms.getString(i)
                    if (mutedRoom == roomName) {
                        Log.i(TAG, "🔇 ✅ 음소거된 채팅방 발견: '$roomName' → 알림 즉시 삭제")
                        return true
                    }
                }
                Log.d(TAG, "🔇 음소거 목록에 없음: '$roomName' (목록 크기: ${mutedRooms.length()})")
            } else {
                Log.d(TAG, "🔇 음소거 목록 비어있음 또는 null")
            }
        } catch (e: Exception) {
            Log.e(TAG, "🔇 ❌ 음소거 목록 확인 실패: ${e.message}", e)
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
            val isSupportedMessenger = SUPPORTED_MESSENGERS.containsKey(packageName)
            
            // ★★★ 지원 메신저의 음소거/차단 알림은 최대한 빨리 취소 (화면 켜짐 방지) ★★★
            // extras 파싱 최소화: 필요한 필드만 빠르게 추출
            if (isSupportedMessenger) {
                val extras: Bundle? = notification.notification.extras
                if (extras != null) {
                    // 최소한의 extras만 파싱 (성능 최적화)
                    val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
                    val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
                    // 개인톡은 subText 비어있음 -> title이 채팅방 이름
                    val roomName = if (subText.isEmpty()) title else subText
                    
                    // ★★★ 음소거 또는 차단된 채팅방: 즉시 알림 취소 (화면 켜짐 방지) ★★★
                    // 최대한 빠르게 처리하여 화면이 켜지기 전에 알림을 삭제
                    if (roomName.isNotEmpty()) {
                        Log.d(TAG, "🚨 알림 즉시 삭제 체크 시작: roomName='$roomName', key=${notification.key}")

                        // 1. 차단 확인 (DB 조회) - 가장 먼저
                        val isBlocked = isRoomBlocked(roomName, packageName)
                        val isMuted = isRoomMuted(roomName)
                        if(isBlocked || isMuted){
                            try {
                                cancelNotification(notification.key)
                            } catch (e: Exception) {
                                Log.e(TAG, "🚫 ❌ 알림 삭제 실패: ${e.message}", e)
                            }
                            if(isBlocked)
                                return
                        }
                    }
                }
            }
            
            val extras: Bundle? = notification.notification.extras
            val noti = notification.notification
            val messengerName = SUPPORTED_MESSENGERS[packageName] ?: packageName

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

                    // 유효성 검사
                    // 개인톡: subText 비어있음, title = 상대방 이름 (= 채팅방 이름)
                    // 그룹톡: subText = 채팅방 이름, title = 발신자 이름
                    val roomName = if (subText.isEmpty()) title else subText
                    var sender = title  // 항상 title이 발신자 (내가 보낸 메시지일 경우 "나"로 변경 가능)
                    val message = text
                    val isPrivateChat = subText.isEmpty()
                    
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

                    // 이미지 처리
                    // savedImagePath를 상위 스코프에 선언하고 명시적으로 초기화 (이전 값이 남아있지 않도록)
                    var savedImagePath: String? = null
                    var imageMessage: String? = null
                    
                    if (roomName.isNotEmpty()) {
                        if (shouldLog) {
                            Log.d(TAG, "========== 프로필 이미지 처리 시작 ==========")
                            Log.d(TAG, "roomName: '$roomName'")
                            Log.d(TAG, "sender: '$sender'")
                            Log.d(TAG, "isPrivateChat: $isPrivateChat")
                        }
                        
                        // 1. 대화방 프로필 사진 저장 (LargeIcon - 대화방 이미지)
                        // null 체크 후 저장 (crash 예방)
                        extractRoomProfileImage(noti)?.let { roomProfileBitmap ->
                            if (shouldLog) {
                                Log.d(TAG, "✅ 대화방 프로필 이미지 추출 성공: ${roomProfileBitmap.width}x${roomProfileBitmap.height}")
                            }
                            saveRoomProfileImage(roomName, roomProfileBitmap)
                        }

                        // 2. 보낸사람 프로필 사진 저장 (개인톡: LargeIcon, 그룹톡: Person.icon)
                        // null 체크 후 저장 (crash 예방)
                        extractSenderProfileImage(noti, bundle, isPrivateChat)?.let { senderProfileBitmap ->
                            if (shouldLog) {
                                Log.d(TAG, "✅ 보낸사람 프로필 이미지 추출 성공: ${senderProfileBitmap.width}x${senderProfileBitmap.height}")
                            }
                            // 해시 기반 파일명으로 저장 (packageName + roomName + sender 조합)
                            saveSenderProfileImage(packageName, roomName, sender, senderProfileBitmap)
                        }

                        // 3. 공유된 사진/이모티콘이 있으면 앱 내부 저장소에 저장
                        
                        // 이미지가 있을 가능성이 있는 메시지인지 확인 (시스템 메시지 패턴 체크)
                        val systemMessagePatterns = listOf(
                            "사진을 보냈습니다", "사진을 보냈습니다.", "사진을 보냈습니다!", "사진을 보냈습니다?", "사진을 보냈습니다~",
                            "이미지를 보냈습니다", "이미지를 보냈습니다.",
                            "이모티콘을 보냈습니다", "이모티콘을 보냈습니다.", "이모티콘을 보냈습니다!", "이모티콘을 보냈습니다?", "이모티콘을 보냈습니다~",
                            "스티커를 보냈습니다", "스티커를 보냈습니다.", "스티커를 보냈습니다!", "스티커를 보냈습니다?", "스티커를 보냈습니다~",
                            "사진", "사진.", "사진!", "사진~",
                            "이모티콘", "이모티콘.", "이모티콘!", "이모티콘~",
                            "스티커", "스티커.", "스티커!", "스티커~",
                        )
                        
                        val isSystemMessage = systemMessagePatterns.any { pattern ->
                            message.contains(pattern, ignoreCase = true)
                        }
                        
                        // 이모티콘/스티커 여부 확인 (이미지 추출 시도 여부 결정)
                        val isEmojiOrStickerMessage = message.contains("이모티콘", ignoreCase = true) || 
                                                       message.contains("스티커", ignoreCase = true)
                        
                        // 링크 메시지 여부 확인 (URL이 포함되어 있는지)
                        val urlPattern = Regex("""(https?://|www\.)[^\s]+""", RegexOption.IGNORE_CASE)
                        val isLinkMessage = urlPattern.containsMatchIn(message)
                        
                        // ⚠️ 보수적 수정: savedImagePath를 명시적으로 null로 초기화 (이전 값이 남아있지 않도록)
                        savedImagePath = null
                        imageMessage = null
                        
                        // ⚠️ 이미지 추출은 항상 시도하되, 크기 검증을 엄격하게 함
                        // 일반 텍스트 메시지에서도 이미지가 포함될 수 있으므로 추출은 시도
                        // 하지만 프로필 이미지(작은 크기)는 사진으로 저장하지 않음
                        if (shouldLog) {
                            Log.d(TAG, ">>> 이미지 추출 시도: message='$message', isSystemMessage=$isSystemMessage, isLinkMessage=$isLinkMessage")
                        }
                        
                        val sharedImage = extractSharedImage(noti, bundle, message)
                        
                        if (sharedImage != null) {
                            // ⚠️ 이미지 크기 검증을 엄격하게: 프로필 이미지가 아닌 실제 사진인지 확인
                            // 프로필 이미지는 보통 200x200 이하이므로, 300x300 이상만 사진으로 간주
                            // 단, 시스템 메시지나 링크 메시지인 경우에는 200x200 이상도 허용
                            val minSize = if (isSystemMessage || isLinkMessage) 200 else 300
                            val isLargeEnough = sharedImage.width >= minSize || sharedImage.height >= minSize
                            
                            if (isLargeEnough) {
                                Log.i(TAG, "📷 공유 이미지 발견! 저장 시도... (크기: ${sharedImage.width}x${sharedImage.height}, 최소크기: $minSize)")
                                savedImagePath = saveNotificationImage(roomName, sharedImage, notification.postTime)
                                
                                // ⚠️ 보수적 수정: 파일 검증을 더 엄격하게 (저장 직후 즉시 확인)
                                if (savedImagePath != null) {
                                    val imageFile = java.io.File(savedImagePath)
                                    // 파일 존재 여부와 크기를 모두 확인
                                    if (imageFile.exists() && imageFile.length() > 0) {
                                        Log.i(TAG, "✅ 이미지 저장 성공: $savedImagePath (파일 크기: ${imageFile.length()} bytes)")
                                    } else {
                                        Log.e(TAG, "❌ 이미지 파일 검증 실패: 존재=${imageFile.exists()}, 크기=${imageFile.length()} bytes")
                                        savedImagePath = null // 저장 실패로 간주
                                    }
                                } else {
                                    Log.e(TAG, "❌ 이미지 저장 실패: saveNotificationImage가 null 반환")
                                }
                            } else {
                                if (shouldLog) {
                                    Log.d(TAG, "⚠️ 이미지 크기가 작아서 프로필 이미지로 간주 (크기: ${sharedImage.width}x${sharedImage.height}, 최소크기: $minSize) - 사진으로 저장하지 않음")
                                }
                            }
                        } else {
                            // 이미지 추출 실패
                            if (isSystemMessage) {
                                Log.w(TAG, "⚠️ 시스템 메시지인데 이미지 추출 실패: '$message'")
                            } else if (isLinkMessage) {
                                if (shouldLog) {
                                    Log.d(TAG, "링크 메시지인데 이미지 추출 실패: '$message' (링크 메시지로 저장)")
                                }
                            } else {
                                if (shouldLog) {
                                    Log.d(TAG, "일반 텍스트 메시지 또는 이미지 없음: '$message'")
                                }
                            }
                        }
                        
                        if (shouldLog) {
                            Log.d(TAG, "========== 프로필 이미지 처리 완료 ==========")
                        }
                        
                        // ⚠️ 보수적 수정: 이미지 메시지 처리 - savedImagePath가 null이 아니고 실제로 파일이 존재할 때만 이미지 메시지로 처리
                        if (savedImagePath != null) {
                            // 저장된 파일이 실제로 존재하는지 다시 한 번 확인 (이중 검증)
                            val imageFile = java.io.File(savedImagePath)
                            if (imageFile.exists() && imageFile.length() > 0) {
                                // 이미지가 저장된 경우
                                if (isLinkMessage) {
                                    // 링크 메시지: 이미지와 원본 메시지를 함께 저장 [LINK:이미지경로]원본메시지 형식
                                    imageMessage = "[LINK:$savedImagePath]$message"
                                    Log.i(TAG, ">>> 링크 메시지 감지: 원본텍스트='$message', 이미지와 함께 저장: '$imageMessage'")
                                } else {
                                    // 일반 이미지 메시지: 이미지만 저장 (시스템 메시지 "사진을 보냈습니다" 등 무시)
                                    val isEmojiOrSticker = message.contains("이모티콘", ignoreCase = true) || 
                                                           message.contains("스티커", ignoreCase = true)
                                    
                                    imageMessage = if (isEmojiOrSticker) {
                                        "[IMAGE:$savedImagePath]이모티콘을 보냈습니다"
                                    } else {
                                        "[IMAGE:$savedImagePath]사진을 보냈습니다"
                                    }
                                    
                                    Log.i(TAG, ">>> 이미지 메시지 생성: 원본텍스트='$message', 이미지타입=${if (isEmojiOrSticker) "이모티콘" else "사진"}, 저장메시지='$imageMessage'")
                                }
                            } else {
                                Log.e(TAG, "❌ 이미지 파일 이중 검증 실패: 존재=${imageFile.exists()}, 크기=${imageFile.length()} bytes - 일반 메시지로 처리")
                                savedImagePath = null // null로 설정하여 일반 메시지로 처리되도록
                                imageMessage = null
                            }
                        } else if (isLinkMessage) {
                            // 링크 메시지인데 이미지가 없는 경우 - 링크만 저장
                            imageMessage = message
                            Log.i(TAG, ">>> 링크 메시지 감지 (이미지 없음): 원본텍스트='$message' 그대로 저장")
                        }
                        
                        // 이미지 메시지가 있는 경우 저장 (이미지가 있거나 링크 메시지인 경우)
                        if (imageMessage != null) {
                            Log.i(TAG, ">>> 이미지 메시지 저장 시작: imageMessage='$imageMessage', savedImagePath=$savedImagePath")
                            
                            // 음소거 여부 (알림은 이미 위에서 즉시 취소됨, API는 계속 호출)
                            val isMuted = roomName.isNotEmpty() && isRoomMuted(roomName)

                            // 약관 동의 여부 확인 (동의하지 않으면 데이터 저장 안 함)
                            val agreementAccepted = isAgreementAccepted()
                            if (!agreementAccepted) {
                                Log.w(TAG, ">>> [$messengerName] ⚠️ 약관 동의하지 않음 - 이미지 메시지 저장 건너뜀: roomName=$roomName, sender=$sender")
                                return
                            }

                            // ★★★ SQLite에 직접 저장 (백그라운드에서도 동작) ★★★
                            if (sender.isNotEmpty() && roomName.isNotEmpty()) {
                                try {
                                    val db = ChatDatabase.getInstance(applicationContext)
                                    val postTime = notification.postTime
                                    
                                    // PendingIntent 추출 (contentIntent 또는 reply action의 intent)
                                    val replyIntentUri = extractReplyIntent(noti)
                                    val replyData = extractReplyIntentData(noti)
                                    
                                    // 채팅방 저장/업데이트 및 roomId 반환
                                    // 개인채팅은 요약 끄기, 그룹/오픈채팅은 요약 켜기
                                    val roomId = db.saveOrUpdateRoom(
                                        roomName = roomName,
                                        packageName = packageName,
                                        lastMessage = imageMessage,
                                        lastSender = sender,
                                        lastMessageTime = postTime,
                                        replyIntent = replyIntentUri,
                                        isPrivateChat = isPrivateChat
                                    )

                                    // PendingIntent 및 RemoteInput 캐시에 저장
                                    if (roomId > 0 && replyData != null) {
                                        replyIntentCache[roomId] = replyData
                                        if (shouldLog) {
                                            Log.d(TAG, "✅ ReplyIntent 캐시 저장: roomId=$roomId, hasRemoteInput=${replyData.remoteInput != null}, actionTitle=${replyData.actionTitle}")
                                        }
                                    } else {
                                        if (shouldLog) {
                                            Log.w(TAG, "⚠️ ReplyIntent 캐시 저장 실패: roomId=$roomId, replyData=${replyData != null}")
                                        }
                                    }
                                    
                                    // 메시지 저장 (roomId가 유효한 경우에만)
                                    if (roomId > 0) {
                                        try {
                                            db.saveMessage(
                                                roomId = roomId,
                                                sender = sender,
                                                message = imageMessage,
                                                createTime = postTime,
                                                roomName = roomName
                                            )
                                            
                                            if (savedImagePath != null) {
                                                Log.i(TAG, ">>> [$messengerName] ✅ 이미지 메시지 SQLite 저장 완료: roomId=$roomId, sender='$sender', imagePath=$savedImagePath, roomName='$roomName'")
                                            } else {
                                                Log.i(TAG, ">>> [$messengerName] ✅ 링크 메시지 SQLite 저장 완료: roomId=$roomId, sender='$sender', message='$imageMessage', roomName='$roomName'")
                                            }
                                            
                                            // 업데이트된 unreadCount 가져오기
                                            val updatedUnreadCount = db.getUnreadCount(roomId)
                                            
                                            // ⚠️ 보수적 수정: 채팅방 업데이트 브로드캐스트 (Flutter UI 갱신용) - 메시지 저장 후 즉시 동기화
                                            val roomUpdateIntent = Intent(ACTION_ROOM_UPDATED).apply {
                                                putExtra("roomId", roomId)
                                                putExtra("roomName", roomName)
                                                putExtra("lastMessage", imageMessage)
                                                putExtra("lastSender", sender)
                                                putExtra("lastMessageTime", postTime.toString())
                                                putExtra("unreadCount", updatedUnreadCount)
                                                setPackage(this@NotificationListener.packageName)
                                                // 명시적으로 플래그 추가하여 백그라운드에서도 전달되도록
                                                addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                                            }
                                            
                                            // 브로드캐스트 전송 (1회만 - 중복 전송 제거로 성능 개선)
                                            sendBroadcast(roomUpdateIntent)
                                            Log.i(TAG, ">>> ✅ 이미지 메시지 채팅방 업데이트 브로드캐스트 전송: roomName=$roomName, unreadCount=$updatedUnreadCount, roomId=$roomId, lastMessage='${imageMessage.take(50)}...'")
                                            
                                            // 자동 요약 체크 (안 읽은 메시지 개수가 설정값에 도달했는지 확인)
                                            checkAndTriggerAutoSummary(roomId, roomName, updatedUnreadCount)
                                            
                                        } catch (e: Exception) {
                                            Log.e(TAG, ">>> [$messengerName] ❌ 이미지 메시지 저장 중 예외 발생: ${e.message}", e)
                                        }
                                    } else {
                                        Log.w(TAG, ">>> [$messengerName] ⚠️ roomId가 0이거나 유효하지 않음 - 채팅방이 차단되었거나 저장 실패: roomName='$roomName', sender='$sender', imagePath=$savedImagePath")
                                    }
                                } catch (e: Exception) {
                                    Log.e(TAG, "이미지 메시지 SQLite 저장 실패: ${e.message}", e)
                                }
                            } else {
                                Log.w(TAG, ">>> [$messengerName] ⚠️ 필수 필드 누락으로 이미지 메시지 저장 건너뜀: sender='$sender' (비어있음=${sender.isEmpty()}), roomName='$roomName' (비어있음=${roomName.isEmpty()})")
                            }
                            
                            // 이미지 메시지 저장 완료 - 일반 메시지 저장은 건너뜀
                            Log.d(TAG, ">>> 이미지 메시지 저장 완료 - 일반 메시지 저장 건너뜀")
                            return
                        } else {
                            if (shouldLog) {
                                Log.d(TAG, ">>> 이미지 메시지 없음 (imageMessage=null) - 일반 메시지 저장 진행: message='$message'")
                            }
                        }
                    } else {
                        if (shouldLog) {
                            Log.d(TAG, ">>> roomName이 비어있음 - 일반 메시지 저장 진행: message='$message'")
                        }
                    }

                    // 음소거 여부 (알림은 이미 위에서 즉시 취소됨, API는 계속 호출)
                    val isMuted = roomName.isNotEmpty() && isRoomMuted(roomName)

                    // 약관 동의 여부 확인 (동의하지 않으면 데이터 저장 안 함)
                    val agreementAccepted = isAgreementAccepted()
                    if (!agreementAccepted) {
                        Log.w(TAG, ">>> [$messengerName] ⚠️ 약관 동의하지 않음 - 데이터 저장 건너뜀: roomName=$roomName, sender=$sender, message=$message")
                        return
                    }

                    // ★★★ SQLite에 직접 저장 (백그라운드에서도 동작) ★★★
                    Log.d(TAG, ">>> [$messengerName] 일반 메시지 저장 조건 확인: sender='$sender' (비어있음=${sender.isEmpty()}), message='$message' (비어있음=${message.isEmpty()}), roomName='$roomName' (비어있음=${roomName.isEmpty()})")
                    
                    if (sender.isNotEmpty() && message.isNotEmpty() && roomName.isNotEmpty()) {
                        Log.i(TAG, ">>> [$messengerName] ✅ 일반 메시지 저장 시도: sender='$sender', message='$message', roomName='$roomName'")
                        try {
                            val db = ChatDatabase.getInstance(applicationContext)
                            val postTime = notification.postTime
                            
                            // ★★★ 시스템 메시지 (이모티콘, 사진 등)도 저장 ★★★
                            // 이전: 이미지 추출 실패 시 시스템 메시지 필터링 → 저장 안 됨
                            // 수정: 이미지 추출 실패해도 메시지 텍스트는 저장
                            // 이유: 목록에 보이지만 상세에서 안 보이는 문제 해결
                            val systemMessagePatterns = listOf(
                                "사진을 보냈습니다", "이미지를 보냈습니다",
                                "이모티콘을 보냈습니다", "스티커를 보냈습니다"
                            )

                            val isSystemMessage = systemMessagePatterns.any { pattern ->
                                message.contains(pattern, ignoreCase = true)
                            }

                            Log.i(TAG, ">>> 메시지 타입 분석: isSystemMessage=$isSystemMessage, savedImagePath=$savedImagePath, message='$message'")

                            // ★ 시스템 메시지도 저장 (이미지 추출 실패해도 텍스트 저장)
                            // 이미지가 추출되었으면 위에서 이미 처리됨, 여기서는 텍스트로 저장
                            if (isSystemMessage && savedImagePath == null) {
                                Log.i(TAG, ">>> ✅ 시스템 메시지 저장 (이미지 추출 실패): '$message'")
                                // return 제거! 메시지 저장 계속 진행
                            }

                            Log.i(TAG, ">>> 메시지 저장 진행: message='$message'")
                            
                            // 이모티콘/스티커를 보낼 때 원본 텍스트가 함께 오는 경우 필터링
                            // 시스템 메시지 필터링에서 이미 처리되지만, 혹시 모를 경우를 대비
                            // 일반 메시지 저장 부분에서는 이미지 추출 여부를 알 수 없으므로
                            // 시스템 메시지 패턴만으로 필터링 (위에서 이미 처리됨)
                            
                            val finalMessage = message
                            
                            // PendingIntent 추출 (contentIntent 또는 reply action의 intent)
                            val replyIntentUri = extractReplyIntent(noti)
                            val replyData = extractReplyIntentData(noti)
                            
                            // 채팅방 저장/업데이트 및 roomId 반환
                            // 개인채팅은 요약 끄기, 그룹/오픈채팅은 요약 켜기
                            val roomId = db.saveOrUpdateRoom(
                                roomName = roomName,
                                packageName = packageName,
                                lastMessage = finalMessage,
                                lastSender = sender,
                                lastMessageTime = postTime,
                                replyIntent = replyIntentUri,
                                isPrivateChat = isPrivateChat
                            )

                            // PendingIntent 및 RemoteInput 캐시에 저장
                            if (roomId > 0 && replyData != null) {
                                replyIntentCache[roomId] = replyData
                                Log.d(TAG, "✅ ReplyIntent 캐시 저장: roomId=$roomId, hasRemoteInput=${replyData.remoteInput != null}, actionTitle=${replyData.actionTitle}, 캐시 크기: ${replyIntentCache.size}")
                            } else {
                                Log.w(TAG, "⚠️ ReplyIntent 캐시 저장 실패: roomId=$roomId, replyData=${replyData != null}")
                            }
                            
                            // 메시지 저장 (roomId가 유효한 경우에만)
                            if (roomId > 0) {
                                try {
                                    db.saveMessage(
                                        roomId = roomId,
                                        sender = sender,
                                        message = finalMessage,
                                        createTime = postTime,
                                        roomName = roomName
                                    )
                                    Log.i(TAG, ">>> [$messengerName] ✅ SQLite 저장 완료: roomId=$roomId, sender='$sender', message='${finalMessage.take(50)}...', roomName='$roomName'")
                                    
                                    // 업데이트된 unreadCount 가져오기
                                    val updatedUnreadCount = db.getUnreadCount(roomId)
                                    
                                    // ⚠️ 보수적 수정: 채팅방 업데이트 브로드캐스트 (Flutter UI 갱신용) - 메시지 저장 후 즉시 동기화
                                    val roomUpdateIntent = Intent(ACTION_ROOM_UPDATED).apply {
                                        putExtra("roomId", roomId)
                                        putExtra("roomName", roomName)
                                        putExtra("lastMessage", finalMessage)
                                        putExtra("lastSender", sender)
                                        putExtra("lastMessageTime", postTime.toString())
                                        putExtra("unreadCount", updatedUnreadCount)
                                        setPackage(this@NotificationListener.packageName)
                                        // 명시적으로 플래그 추가하여 백그라운드에서도 전달되도록
                                        addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                                    }
                                    
                                    // 브로드캐스트 전송 (1회만 - 중복 전송 제거로 성능 개선)
                                    sendBroadcast(roomUpdateIntent)
                                    Log.i(TAG, ">>> ✅ 일반 메시지 채팅방 업데이트 브로드캐스트 전송: roomName=$roomName, unreadCount=$updatedUnreadCount, roomId=$roomId, lastMessage='${finalMessage.take(50)}...'")
                                    
                                    // 자동 요약 체크 (안 읽은 메시지 개수가 설정값에 도달했는지 확인)
                                    checkAndTriggerAutoSummary(roomId, roomName, updatedUnreadCount)
                                    
                                } catch (e: Exception) {
                                    Log.e(TAG, ">>> [$messengerName] ❌ 메시지 저장 중 예외 발생: ${e.message}", e)
                                }
                            } else {
                                Log.w(TAG, ">>> [$messengerName] ⚠️ roomId가 0이거나 유효하지 않음 - 채팅방이 차단되었거나 저장 실패: roomName='$roomName', sender='$sender', message='${message.take(50)}...'")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "SQLite 저장 실패: ${e.message}", e)
                        }
                    } else {
                        Log.w(TAG, ">>> [$messengerName] ⚠️ 필수 필드 누락으로 저장 건너뜀: sender='$sender' (비어있음=${sender.isEmpty()}), message='${message.take(50)}...' (비어있음=${message.isEmpty()}), roomName='$roomName' (비어있음=${roomName.isEmpty()})")
                    }
                } else {
                    Log.d(TAG, ">>> 지원하지 않는 앱: $packageName")
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

            val channel = NotificationChannel(
                AUTO_SUMMARY_CHANNEL_ID,
                AUTO_SUMMARY_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "AI 톡비서 자동 요약 완료 알림"

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

                // 진동 패턴 설정
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                enableVibration(true)

                // LED 설정
                enableLights(true)
                lightColor = android.graphics.Color.BLUE
            }

            notificationManager.createNotificationChannel(channel)
            Log.i(TAG, "✅ 자동 요약 알림 채널 생성 완료")
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
                if (SUPPORTED_MESSENGERS.containsKey(sbn.packageName)) {
                    val extras = sbn.notification.extras
                    val subText = extras?.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
                    val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
                    // 개인톡은 subText가 비어있고 title이 채팅방 이름
                    val notificationRoomName = if (subText.isEmpty()) title else subText
                    if (notificationRoomName == roomName) {
                        cancelNotification(sbn.key)
                        val messengerName = SUPPORTED_MESSENGERS[sbn.packageName] ?: sbn.packageName
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

                // 자동 요약 설정 확인
                val (autoSummaryEnabled, autoSummaryMessageCount) = db.getAutoSummarySettings(roomId)

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
                            summaryTo = lastMessageTime
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
                        Log.w(TAG, "🤖 ⚠️ 요약 결과가 비어있음")
                    }
                }
            } else {
                Log.e(TAG, "🤖 ❌ 자동 요약 API 실패: ${response.code}, ${response.body?.string()}")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "🤖 ❌ 자동 요약 실행 실패: ${e.message}", e)
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
            // 자동 요약 알림 활성화 여부 확인
            val prefs = getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
            val notificationEnabled = prefs.getBoolean(AUTO_SUMMARY_NOTIFICATION_ENABLED_KEY, true)

            if (!notificationEnabled) {
                Log.d(TAG, "🤖 자동 요약 알림 비활성화 - 알림 생성 안 함")
                return
            }

            // 진동 설정 확인
            val vibrationEnabled = prefs.getBoolean(VIBRATION_ENABLED_KEY, true)

            // 알림 채널 재생성 (진동 설정 반영)
            updateNotificationChannelVibration(vibrationEnabled)

            // MainActivity로 이동하는 Intent 생성
            val intent = Intent(applicationContext, Class.forName("com.example.chat_llm.MainActivity")).apply {
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
                notificationBuilder.setDefaults(Notification.DEFAULT_SOUND)
                if (vibrationEnabled) {
                    notificationBuilder.setVibrate(longArrayOf(0, 300, 200, 300))
                }
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(summaryId, notificationBuilder.build())

            Log.i(TAG, "🤖 ✅ 자동 요약 알림 생성 완료: roomName=$roomName, messageCount=$messageCount, vibration=$vibrationEnabled")

        } catch (e: Exception) {
            Log.e(TAG, "🤖 ❌ 자동 요약 알림 생성 실패: ${e.message}", e)
        }
    }

    /**
     * 알림 채널 진동 설정 업데이트
     */
    private fun updateNotificationChannelVibration(vibrationEnabled: Boolean) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 기존 채널 삭제
            notificationManager.deleteNotificationChannel(AUTO_SUMMARY_CHANNEL_ID)

            // 새 채널 생성 (진동 설정 반영)
            val channel = NotificationChannel(
                AUTO_SUMMARY_CHANNEL_ID,
                AUTO_SUMMARY_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "AI 톡비서 자동 요약 완료 알림"

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
            Log.d(TAG, "🔔 알림 채널 업데이트: vibration=$vibrationEnabled")
        }
    }
}
