package com.example.chat_llm

import android.app.Notification
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

class NotificationListener : NotificationListenerService() {
    companion object {
        const val TAG = "NotificationListener"
        const val ACTION_NOTIFICATION_RECEIVED = "com.example.chat_llm.NOTIFICATION_RECEIVED"
        const val ACTION_CANCEL_NOTIFICATION = "com.example.chat_llm.CANCEL_NOTIFICATION"
        const val ACTION_CANCEL_ROOM_NOTIFICATIONS = "com.example.chat_llm.CANCEL_ROOM_NOTIFICATIONS"
        const val ACTION_ROOM_UPDATED = "com.example.chat_llm.ROOM_UPDATED"

        // ⚠️ 알림 수신 대상 메신저 패키지명 목록 (빠른 필터링용)
        // 실제 활성화 여부는 서버 API에서 체크 (SupportedMessenger.enabled)
        // 여기서는 알림을 받을 대상인지만 확인 (네트워크 요청 최소화)
        val SUPPORTED_MESSENGERS = mapOf(
            "com.kakao.talk" to "카카오톡",
            "org.telegram.messenger" to "텔레그램",
            "com.instagram.android" to "인스타그램",
            "com.facebook.orca" to "메신저",
            "com.whatsapp" to "왓츠앱",
            "jp.naver.line.android" to "라인"
        )

        // API 설정
        const val BASE_URL = "https://223.130.151.39"
        const val MESSENGER_ALARM_ENDPOINT = "/api/v1/messenger/alarm"
        const val REFRESH_TOKEN_ENDPOINT = "/api/v1/auth/refresh"

        // Flutter SharedPreferences 키
        const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
        const val SERVER_ACCESS_TOKEN_KEY = "flutter.server_access_token"
        const val SERVER_REFRESH_TOKEN_KEY = "flutter.server_refresh_token"
        const val MUTED_ROOMS_KEY = "flutter.muted_rooms"
    }

    private var cancelReceiver: BroadcastReceiver? = null
    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.IO + serviceJob)

    // SSL 인증서 우회를 위한 TrustManager
    private val trustAllCerts = arrayOf<TrustManager>(object : X509TrustManager {
        override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
        override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
        override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
    })

    private val httpClient: OkHttpClient by lazy {
        val sslContext = SSLContext.getInstance("SSL")
        sslContext.init(null, trustAllCerts, SecureRandom())

        OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .sslSocketFactory(sslContext.socketFactory, trustAllCerts[0] as X509TrustManager)
            .hostnameVerifier { _, _ -> true }
            .build()
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
     */
    private fun saveNotificationImage(roomName: String, bitmap: Bitmap?, postTime: Long) {
        if (bitmap == null) return

        val safeRoomName = roomName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val fileName = "img_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date(postTime))}.jpg"

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10 이상: MediaStore 사용
                val contentValues = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                    put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/ChatLLM/$safeRoomName")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }

                val resolver = applicationContext.contentResolver
                val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)

                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { out ->
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                    }
                    contentValues.clear()
                    contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                    resolver.update(uri, contentValues, null, null)
                    Log.i(TAG, "이미지 저장 완료 (MediaStore): Pictures/ChatLLM/$safeRoomName/$fileName")
                }
            } else {
                // Android 9 이하: 기존 방식
                @Suppress("DEPRECATION")
                val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                val appDir = File(picturesDir, "ChatLLM")
                val roomDir = File(appDir, safeRoomName)

                if (!roomDir.exists()) {
                    roomDir.mkdirs()
                }

                val imageFile = File(roomDir, fileName)
                FileOutputStream(imageFile).use { out ->
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                }
                Log.i(TAG, "이미지 저장 완료: ${imageFile.absolutePath}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "이미지 저장 실패: ${e.message}", e)
        }
    }

    /**
     * Notification에서 공유된 사진 Bitmap 추출 (BigPictureStyle)
     */
    @Suppress("DEPRECATION")
    private fun extractSharedImage(extras: Bundle): Bitmap? {
        // EXTRA_PICTURE (BigPictureStyle에서 사용하는 큰 이미지 - 공유된 사진)
        val picture = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            extras.getParcelable(Notification.EXTRA_PICTURE, Bitmap::class.java)
        } else {
            extras.getParcelable(Notification.EXTRA_PICTURE) as? Bitmap
        }
        if (picture != null) {
            Log.d(TAG, "EXTRA_PICTURE에서 공유 이미지 발견")
            return picture
        }
        return null
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

    private fun getAccessToken(): String? {
        return getFlutterPrefs().getString(SERVER_ACCESS_TOKEN_KEY, null)
    }

    private fun getRefreshToken(): String? {
        return getFlutterPrefs().getString(SERVER_REFRESH_TOKEN_KEY, null)
    }

    private fun saveAccessToken(token: String) {
        getFlutterPrefs().edit().putString(SERVER_ACCESS_TOKEN_KEY, token).apply()
    }

    /**
     * 채팅방이 음소거 상태인지 확인
     * Flutter SharedPreferences에서 muted_rooms 목록을 읽어서 확인
     */
    private fun isRoomMuted(roomName: String): Boolean {
        try {
            val mutedRoomsJson = getFlutterPrefs().getString(MUTED_ROOMS_KEY, null)
            if (mutedRoomsJson != null) {
                val mutedRooms = JSONArray(mutedRoomsJson)
                for (i in 0 until mutedRooms.length()) {
                    if (mutedRooms.getString(i) == roomName) {
                        return true
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "음소거 목록 확인 실패: ${e.message}")
        }
        return false
    }

    private suspend fun refreshAccessToken(): Boolean {
        val refreshToken = getRefreshToken() ?: return false

        try {
            val json = JSONObject().apply {
                put("refreshToken", refreshToken)
            }

            val request = Request.Builder()
                .url("$BASE_URL$REFRESH_TOKEN_ENDPOINT")
                .post(json.toString().toRequestBody("application/json".toMediaType()))
                .build()

            val response = httpClient.newCall(request).execute()

            if (response.isSuccessful) {
                val body = response.body?.string()
                if (body != null) {
                    val data = JSONObject(body)
                    val newAccessToken = data.optString("accessToken")
                    if (newAccessToken.isNotEmpty()) {
                        saveAccessToken(newAccessToken)
                        Log.d(TAG, "토큰 갱신 성공")
                        return true
                    }
                }
            }
            Log.e(TAG, "토큰 갱신 실패: ${response.code}")
        } catch (e: Exception) {
            Log.e(TAG, "토큰 갱신 오류: ${e.message}")
        }
        return false
    }

    private suspend fun sendMessengerAlarm(
        packageName: String,
        sender: String,
        message: String,
        roomName: String,
        createTime: String
    ): Boolean {
        var accessToken = getAccessToken()

        if (accessToken == null) {
            Log.w(TAG, "액세스 토큰이 없습니다. API 호출 스킵")
            return false
        }

        val messengerName = SUPPORTED_MESSENGERS[packageName] ?: "알 수 없음"
        Log.d(TAG, ">>> sendMessengerAlarm 시작: messenger=$messengerName, sender=$sender, roomName=$roomName")

        try {
            val json = JSONObject().apply {
                put("packageName", packageName)
                put("sender", sender)
                put("message", message)
                put("roomName", roomName)
                put("createTime", createTime)
            }

            Log.d(TAG, ">>> API 요청 바디: ${json.toString()}")

            var request = Request.Builder()
                .url("$BASE_URL$MESSENGER_ALARM_ENDPOINT")
                .addHeader("Content-Type", "application/json")
                .addHeader("Authorization", "Bearer $accessToken")
                .post(json.toString().toRequestBody("application/json".toMediaType()))
                .build()

            Log.d(TAG, ">>> API 요청 전송: $BASE_URL$MESSENGER_ALARM_ENDPOINT")
            var response = httpClient.newCall(request).execute()
            Log.d(TAG, ">>> API 응답 코드: ${response.code}")

            // 토큰 만료 시 갱신 후 재시도
            if (response.code == 401) {
                Log.d(TAG, "토큰 만료, 갱신 시도...")
                if (refreshAccessToken()) {
                    accessToken = getAccessToken()
                    request = Request.Builder()
                        .url("$BASE_URL$MESSENGER_ALARM_ENDPOINT")
                        .addHeader("Content-Type", "application/json")
                        .addHeader("Authorization", "Bearer $accessToken")
                        .post(json.toString().toRequestBody("application/json".toMediaType()))
                        .build()
                    response = httpClient.newCall(request).execute()
                    Log.d(TAG, ">>> 토큰 갱신 후 재시도 응답 코드: ${response.code}")
                }
            }

            if (response.isSuccessful) {
                val responseBody = response.body?.string()
                Log.i(TAG, "알림 API 호출 성공: [$messengerName] $roomName - $sender")
                Log.d(TAG, "서버 응답: $responseBody")

                // 서버 응답을 Flutter로 브로드캐스트
                if (responseBody != null) {
                    try {
                        val roomData = JSONObject(responseBody)
                        broadcastRoomUpdate(roomData)
                    } catch (e: Exception) {
                        Log.e(TAG, "응답 파싱 실패: ${e.message}")
                    }
                }
                return true
            } else {
                Log.e(TAG, "알림 API 호출 실패: ${response.code}")
                val errorBody = response.body?.string()
                Log.e(TAG, ">>> 에러 응답: $errorBody")
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "알림 API 호출 오류: ${e.message}", e)
            return false
        }
    }

    /**
     * 채팅방 업데이트 정보를 Flutter로 브로드캐스트
     */
    private fun broadcastRoomUpdate(roomData: JSONObject) {
        val intent = Intent(ACTION_ROOM_UPDATED).apply {
            putExtra("roomId", roomData.optLong("roomId", 0))
            putExtra("roomName", roomData.optString("roomName", ""))
            putExtra("unreadCount", roomData.optInt("unreadCount", 0))
            putExtra("lastMessage", roomData.optString("lastMessage", ""))
            // lastMessageTime은 배열로 올 수 있으므로 JSON 문자열로 전달
            val lastMessageTime = roomData.opt("lastMessageTime")
            putExtra("lastMessageTime", lastMessageTime?.toString() ?: "")
            // pinned, category 추가
            putExtra("pinned", roomData.optBoolean("pinned", false))
            putExtra("category", roomData.optString("category", "DAILY"))
            setPackage(this@NotificationListener.packageName)
        }
        sendBroadcast(intent)
        Log.d(TAG, "채팅방 업데이트 브로드캐스트 전송: roomId=${roomData.optLong("roomId")}, pinned=${roomData.optBoolean("pinned")}")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn?.let { notification ->
            val packageName = notification.packageName
            val extras: Bundle? = notification.notification.extras
            val noti = notification.notification

            // 지원하는 메신저인지 확인
            val isSupportedMessenger = SUPPORTED_MESSENGERS.containsKey(packageName)
            val messengerName = SUPPORTED_MESSENGERS[packageName] ?: packageName

            // ★★★ 지원 메신저의 음소거 알림은 최대한 빨리 취소 (화면 켜짐 방지) ★★★
            if (isSupportedMessenger && extras != null) {
                val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""
                val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
                // 개인톡은 subText 비어있음 -> title이 채팅방 이름
                val roomName = if (subText.isEmpty()) title else subText
                if (roomName.isNotEmpty() && isRoomMuted(roomName)) {
                    // 즉시 알림 취소 - 로깅보다 먼저!
                    try {
                        cancelNotification(notification.key)
                        Log.i(TAG, "[$messengerName] 음소거 채팅방 알림 즉시 취소: $roomName")
                    } catch (e: Exception) {
                        Log.e(TAG, "알림 즉시 취소 실패: ${e.message}")
                    }
                }
            }

            // 모든 알림 로그 (디버깅용)
            Log.d(TAG, "========== 알림 수신 ==========")
            Log.d(TAG, "패키지명: $packageName")
            Log.d(TAG, "알림 ID: ${notification.id}")
            Log.d(TAG, "알림 시간: ${notification.postTime}")

            // StatusBarNotification 추가 정보
            Log.d(TAG, "--- StatusBarNotification 정보 ---")
            Log.d(TAG, "Tag: ${notification.tag}")
            Log.d(TAG, "Key: ${notification.key}")
            Log.d(TAG, "GroupKey: ${notification.groupKey}")
            Log.d(TAG, "OverrideGroupKey: ${notification.overrideGroupKey}")
            Log.d(TAG, "User: ${notification.user}")
            Log.d(TAG, "IsGroup: ${notification.isGroup}")
            Log.d(TAG, "IsClearable: ${notification.isClearable}")
            Log.d(TAG, "IsOngoing: ${notification.isOngoing}")

            // Notification 추가 정보
            Log.d(TAG, "--- Notification 정보 ---")
            Log.d(TAG, "Category: ${noti.category}")
            Log.d(TAG, "ChannelId: ${noti.channelId}")
            Log.d(TAG, "Group: ${noti.group}")
            Log.d(TAG, "SortKey: ${noti.sortKey}")
            Log.d(TAG, "TickerText: ${noti.tickerText}")
            Log.d(TAG, "Number: ${noti.number}")
            Log.d(TAG, "Flags: ${noti.flags}")
            Log.d(TAG, "Visibility: ${noti.visibility}")
            Log.d(TAG, "Color: ${noti.color}")
            Log.d(TAG, "Actions 개수: ${noti.actions?.size ?: 0}")
            noti.actions?.forEachIndexed { index, action ->
                Log.d(TAG, "  Action[$index]: ${action.title}")
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

                Log.d(TAG, "제목(TITLE): $title")
                Log.d(TAG, "내용(TEXT): $text")
                Log.d(TAG, "서브텍스트(SUB_TEXT): $subText")
                Log.d(TAG, "빅텍스트(BIG_TEXT): $bigText")
                Log.d(TAG, "정보텍스트(INFO_TEXT): $infoText")
                Log.d(TAG, "요약텍스트(SUMMARY_TEXT): $summaryText")
                Log.d(TAG, "대화 제목(CONVERSATION_TITLE): $conversationTitle")
                Log.d(TAG, "자신 표시명(SELF_DISPLAY_NAME): $selfDisplayName")
                Log.d(TAG, "그룹 대화 여부: $isGroupConversation")
                Log.d(TAG, "메시지 배열: ${messages?.size ?: 0}개")
                messages?.forEachIndexed { index, msg ->
                    Log.d(TAG, "  Message[$index]: $msg (${msg?.javaClass?.simpleName})")
                }
                Log.d(TAG, "RemotePerson: $remotePerson")
                Log.d(TAG, "MessagingPerson: $messagingPerson")

                // 모든 extras 키 출력 (디버깅용)
                Log.d(TAG, "--- 모든 Extras 키 ---")
                for (key in bundle.keySet()) {
                    val value = bundle.get(key)
                    Log.d(TAG, "  $key: $value (${value?.javaClass?.simpleName})")
                }

                // 지원하는 메신저 알림인 경우 API 호출
                if (isSupportedMessenger) {
                    // ★★★ 빈 알림/선행 알림/요약 알림 필터링 ★★★
                    // 카카오톡은 실제 알림 전에 빈 알림을 먼저 보내거나, 그룹화된 요약 알림을 보냄
                    // 이런 알림들은 이미지 추출 시도도 하지 않고 바로 무시
                    
                    // 1. 빈 알림 (title, text 모두 비어있음) - 선행 알림 또는 무의미한 알림
                    if (title.isEmpty() && text.isEmpty()) {
                        // 요약 알림인 경우 (subText에 "안 읽은 메시지" 포함)
                        if (subText.contains("안 읽은 메시지") || subText.contains("unread message")) {
                            Log.d(TAG, ">>> [$messengerName] 요약 알림 무시: $subText")
                        } else {
                            Log.d(TAG, ">>> [$messengerName] 빈 알림 무시 (선행 알림)")
                        }
                        Log.d(TAG, "================================")
                        return
                    }
                    
                    Log.i(TAG, "########## [$messengerName] 알림 감지! ##########")
                    Log.i(TAG, "발신자: $title")
                    Log.i(TAG, "메시지: $text")
                    if (bigText.isNotEmpty()) {
                        Log.i(TAG, "전체 메시지: $bigText")
                    }

                    // 유효성 검사
                    // 개인톡: subText 비어있음, title = 상대방 이름 (= 채팅방 이름)
                    // 그룹톡: subText = 채팅방 이름, title = 발신자 이름
                    val isPrivateChat = subText.isEmpty()
                    val sender = if (isPrivateChat) title else title  // 둘 다 title이 발신자
                    val message = text
                    val roomName = if (isPrivateChat) title else subText  // 개인톡은 title이 채팅방 이름

                    Log.d(TAG, ">>> [$messengerName] 개인톡 여부: $isPrivateChat")
                    Log.d(TAG, ">>> 필드 검증 전: sender='$sender' (isEmpty=${sender.isEmpty()}), message='$message' (isEmpty=${message.isEmpty()}), roomName='$roomName' (isEmpty=${roomName.isEmpty()})")

                    // 이미지 처리
                    if (roomName.isNotEmpty()) {
                        Log.d(TAG, "========== 프로필 이미지 처리 시작 ==========")
                        Log.d(TAG, "roomName: '$roomName'")
                        Log.d(TAG, "sender: '$sender'")
                        Log.d(TAG, "isPrivateChat: $isPrivateChat")
                        
                        // 1. 대화방 프로필 사진 저장 (LargeIcon - 대화방 이미지)
                        val roomProfileBitmap = extractRoomProfileImage(noti)
                        if (roomProfileBitmap != null) {
                            Log.d(TAG, "✅ 대화방 프로필 이미지 추출 성공: ${roomProfileBitmap.width}x${roomProfileBitmap.height}")
                            saveRoomProfileImage(roomName, roomProfileBitmap)
                        } else {
                            Log.w(TAG, "⚠️ 대화방 프로필 이미지 추출 실패")
                        }

                        // 2. 보낸사람 프로필 사진 저장 (개인톡: LargeIcon, 그룹톡: Person.icon)
                        Log.d(TAG, "--- 보낸사람 프로필 추출 시작 ---")
                        val senderProfileBitmap = extractSenderProfileImage(noti, bundle, isPrivateChat)
                        if (senderProfileBitmap != null) {
                            Log.d(TAG, "✅ 보낸사람 프로필 이미지 추출 성공: ${senderProfileBitmap.width}x${senderProfileBitmap.height}")
                            // 해시 기반 파일명으로 저장 (packageName + roomName + sender 조합)
                            saveSenderProfileImage(packageName, roomName, sender, senderProfileBitmap)
                        } else {
                            Log.w(TAG, "❌ 보낸사람 프로필 이미지 추출 실패")
                            Log.w(TAG, "   sender: '$sender'")
                            Log.w(TAG, "   roomName: '$roomName'")
                            Log.w(TAG, "   isPrivateChat: $isPrivateChat")
                        }

                        // 3. 공유된 사진이 있으면 Pictures 폴더에 저장
                        val sharedImage = extractSharedImage(bundle)
                        if (sharedImage != null) {
                            Log.i(TAG, "📷 공유 이미지 발견! 저장 시도...")
                            saveNotificationImage(roomName, sharedImage, notification.postTime)
                        }
                        
                        Log.d(TAG, "========== 프로필 이미지 처리 완료 ==========")
                    }

                    // 음소거 여부 (알림은 이미 위에서 즉시 취소됨, API는 계속 호출)
                    val isMuted = roomName.isNotEmpty() && isRoomMuted(roomName)

                    if (sender.isNotEmpty() && message.isNotEmpty() && roomName.isNotEmpty()) {
                        // 백그라운드에서 API 호출
                        val createTime = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
                            .format(Date(notification.postTime))

                        Log.d(TAG, ">>> [$messengerName] 알람 저장 API 호출 시작: sender=$sender, roomName=$roomName, isMuted=$isMuted")
                        serviceScope.launch {
                            try {
                                val result = sendMessengerAlarm(
                                    packageName = packageName,
                                    sender = sender,
                                    message = message,
                                    roomName = roomName,
                                    createTime = createTime
                                )
                                Log.d(TAG, ">>> [$messengerName] 알람 저장 API 호출 결과: $result")
                            } catch (e: Exception) {
                                Log.e(TAG, ">>> [$messengerName] 알람 저장 API 호출 중 예외 발생", e)
                            }
                        }
                    } else {
                        Log.d(TAG, "필수 필드 누락으로 API 호출 스킵: sender=${sender.isEmpty()}, message=${message.isEmpty()}, roomName=${roomName.isEmpty()}")
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

            Log.d(TAG, "================================")
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
        registerCancelReceiver()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.i(TAG, "NotificationListenerService 연결 해제됨!")
        unregisterCancelReceiver()
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
        serviceJob.cancel()
        unregisterCancelReceiver()
    }
}
