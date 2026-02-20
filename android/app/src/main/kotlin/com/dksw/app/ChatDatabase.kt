package com.dksw.app

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log

/**
 * 채팅 메시지 저장용 SQLite 데이터베이스
 * Android NotificationListener와 Flutter 양쪽에서 접근
 */
class ChatDatabase(context: Context) : SQLiteOpenHelper(
    context,
    DATABASE_NAME,
    null,
    DATABASE_VERSION
) {
    companion object {
        const val TAG = "ChatDatabase"
        const val DATABASE_NAME = "chat_llm.db"
        const val DATABASE_VERSION = 6  // Flutter와 버전 일치

        // 채팅방 테이블
        const val TABLE_ROOMS = "chat_rooms"
        const val ROOM_ID = "id"
        const val ROOM_NAME = "room_name"
        const val ROOM_PACKAGE_NAME = "package_name"
        const val ROOM_PACKAGE_ALIAS = "package_alias"
        const val ROOM_LAST_MESSAGE = "last_message"
        const val ROOM_LAST_SENDER = "last_sender"
        const val ROOM_LAST_MESSAGE_TIME = "last_message_time"
        const val ROOM_UNREAD_COUNT = "unread_count"
        const val ROOM_PINNED = "pinned"
        const val ROOM_BLOCKED = "blocked"
        const val ROOM_MUTED = "muted"
        const val ROOM_SUMMARY_ENABLED = "summary_enabled"
        const val ROOM_CATEGORY = "category"
        const val ROOM_PARTICIPANT_COUNT = "participant_count"
        const val ROOM_CREATED_AT = "created_at"
        const val ROOM_UPDATED_AT = "updated_at"
        const val ROOM_REPLY_INTENT = "reply_intent"  // PendingIntent를 위한 Intent 직렬화 데이터
        const val ROOM_CHAT_ID = "chat_id"  // 메신저별 대화방 고유 식별자 (LINE shortcutId 등)
        const val ROOM_AUTO_SUMMARY_ENABLED = "auto_summary_enabled"  // 자동 요약 활성화 여부
        const val ROOM_AUTO_SUMMARY_MESSAGE_COUNT = "auto_summary_message_count"  // 자동 요약 메시지 개수

        // 메시지 테이블
        const val TABLE_MESSAGES = "chat_messages"
        const val MSG_ID = "id"
        const val MSG_ROOM_ID = "room_id"
        const val MSG_SENDER = "sender"
        const val MSG_MESSAGE = "message"
        const val MSG_CREATE_TIME = "create_time"
        const val MSG_ROOM_NAME = "room_name"

        // 요약 테이블
        const val TABLE_SUMMARIES = "chat_summaries"
        const val SUMMARY_ID = "id"
        const val SUMMARY_ROOM_ID = "room_id"
        const val SUMMARY_NAME = "summary_name"
        const val SUMMARY_MESSAGE = "summary_message"
        const val SUMMARY_DETAIL_MESSAGE = "summary_detail_message"
        const val SUMMARY_FROM = "summary_from"
        const val SUMMARY_TO = "summary_to"
        const val SUMMARY_CREATED_AT = "created_at"

        @Volatile
        private var instance: ChatDatabase? = null

        fun getInstance(context: Context): ChatDatabase {
            return instance ?: synchronized(this) {
                instance ?: ChatDatabase(context.applicationContext).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        // 채팅방 테이블 생성
        db.execSQL("""
            CREATE TABLE $TABLE_ROOMS (
                $ROOM_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $ROOM_NAME TEXT NOT NULL,
                $ROOM_PACKAGE_NAME TEXT NOT NULL,
                $ROOM_PACKAGE_ALIAS TEXT,
                $ROOM_LAST_MESSAGE TEXT,
                $ROOM_LAST_SENDER TEXT,
                $ROOM_LAST_MESSAGE_TIME INTEGER,
                $ROOM_UNREAD_COUNT INTEGER DEFAULT 0,
                $ROOM_PINNED INTEGER DEFAULT 0,
                $ROOM_BLOCKED INTEGER DEFAULT 0,
                $ROOM_MUTED INTEGER DEFAULT 0,
                $ROOM_SUMMARY_ENABLED INTEGER DEFAULT 1,
                $ROOM_CATEGORY TEXT DEFAULT 'DAILY',
                $ROOM_PARTICIPANT_COUNT INTEGER DEFAULT 0,
                $ROOM_CREATED_AT INTEGER,
                $ROOM_UPDATED_AT INTEGER,
                $ROOM_REPLY_INTENT TEXT,
                $ROOM_AUTO_SUMMARY_ENABLED INTEGER DEFAULT 0,
                $ROOM_AUTO_SUMMARY_MESSAGE_COUNT INTEGER DEFAULT 50,
                $ROOM_CHAT_ID TEXT,
                UNIQUE($ROOM_NAME, $ROOM_PACKAGE_NAME)
            )
        """.trimIndent())

        // 메시지 테이블 생성
        db.execSQL("""
            CREATE TABLE $TABLE_MESSAGES (
                $MSG_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $MSG_ROOM_ID INTEGER NOT NULL,
                $MSG_SENDER TEXT NOT NULL,
                $MSG_MESSAGE TEXT NOT NULL,
                $MSG_CREATE_TIME INTEGER NOT NULL,
                $MSG_ROOM_NAME TEXT,
                FOREIGN KEY($MSG_ROOM_ID) REFERENCES $TABLE_ROOMS($ROOM_ID) ON DELETE CASCADE
            )
        """.trimIndent())

        // 요약 테이블 생성
        db.execSQL("""
            CREATE TABLE $TABLE_SUMMARIES (
                $SUMMARY_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $SUMMARY_ROOM_ID INTEGER NOT NULL,
                $SUMMARY_NAME TEXT,
                $SUMMARY_MESSAGE TEXT NOT NULL,
                $SUMMARY_DETAIL_MESSAGE TEXT,
                $SUMMARY_FROM INTEGER,
                $SUMMARY_TO INTEGER,
                $SUMMARY_CREATED_AT INTEGER,
                FOREIGN KEY($SUMMARY_ROOM_ID) REFERENCES $TABLE_ROOMS($ROOM_ID) ON DELETE CASCADE
            )
        """.trimIndent())

        // 인덱스 생성
        db.execSQL("CREATE INDEX idx_rooms_name_package ON $TABLE_ROOMS($ROOM_NAME, $ROOM_PACKAGE_NAME)")
        db.execSQL("CREATE INDEX idx_messages_room_id ON $TABLE_MESSAGES($MSG_ROOM_ID)")
        db.execSQL("CREATE INDEX idx_messages_create_time ON $TABLE_MESSAGES($MSG_CREATE_TIME)")
        db.execSQL("CREATE INDEX idx_summaries_room_id ON $TABLE_SUMMARIES($SUMMARY_ROOM_ID)")

        Log.i(TAG, "데이터베이스 생성 완료")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        Log.i(TAG, "데이터베이스 업그레이드: $oldVersion -> $newVersion")
        if (oldVersion < 2) {
            // reply_intent 컬럼 추가 (이미 존재하면 에러 발생하므로 try-catch로 처리)
            try {
                db.execSQL("ALTER TABLE $TABLE_ROOMS ADD COLUMN $ROOM_REPLY_INTENT TEXT")
                Log.i(TAG, "reply_intent 컬럼 추가 완료")
            } catch (e: Exception) {
                // 컬럼이 이미 존재하는 경우 무시
                if (e.message?.contains("duplicate column") == true || 
                    e.message?.contains("already exists") == true) {
                    Log.d(TAG, "reply_intent 컬럼이 이미 존재함 - 스킵")
                } else {
                    Log.e(TAG, "reply_intent 컬럼 추가 실패: ${e.message}", e)
                }
            }
        }
        if (oldVersion < 3) {
            // auto_summary_enabled, auto_summary_message_count 컬럼 추가
            try {
                db.execSQL("ALTER TABLE $TABLE_ROOMS ADD COLUMN $ROOM_AUTO_SUMMARY_ENABLED INTEGER DEFAULT 0")
                Log.i(TAG, "auto_summary_enabled 컬럼 추가 완료")
            } catch (e: Exception) {
                if (e.message?.contains("duplicate column") == true || 
                    e.message?.contains("already exists") == true) {
                    Log.d(TAG, "auto_summary_enabled 컬럼이 이미 존재함 - 스킵")
                } else {
                    Log.e(TAG, "auto_summary_enabled 컬럼 추가 실패: ${e.message}", e)
                }
            }
            try {
                db.execSQL("ALTER TABLE $TABLE_ROOMS ADD COLUMN $ROOM_AUTO_SUMMARY_MESSAGE_COUNT INTEGER DEFAULT 50")
                Log.i(TAG, "auto_summary_message_count 컬럼 추가 완료")
            } catch (e: Exception) {
                if (e.message?.contains("duplicate column") == true || 
                    e.message?.contains("already exists") == true) {
                    Log.d(TAG, "auto_summary_message_count 컬럼이 이미 존재함 - 스킵")
                } else {
                    Log.e(TAG, "auto_summary_message_count 컬럼 추가 실패: ${e.message}", e)
                }
            }
        }
        if (oldVersion < 4) {
            // 버전 4: push_notifications 테이블은 Flutter에서만 사용하므로 Android에서는 마이그레이션 불필요
            // summary_detail_message 컬럼 추가
            try {
                db.execSQL("ALTER TABLE $TABLE_SUMMARIES ADD COLUMN $SUMMARY_DETAIL_MESSAGE TEXT")
                Log.i(TAG, "summary_detail_message 컬럼 추가 완료")
            } catch (e: Exception) {
                if (e.message?.contains("duplicate column") == true || 
                    e.message?.contains("already exists") == true) {
                    Log.d(TAG, "summary_detail_message 컬럼이 이미 존재함 - 스킵")
                } else {
                    Log.e(TAG, "summary_detail_message 컬럼 추가 실패: ${e.message}", e)
                }
            }
            Log.i(TAG, "데이터베이스 버전 4로 업그레이드 완료")
        }
        if (oldVersion < 5) {
            // 버전 5: push_notifications 테이블의 is_auto_summary, summary_id 필드는 Flutter에서만 사용
            // Android에서는 마이그레이션 불필요 (테이블 자체가 Flutter에서만 관리됨)
            Log.i(TAG, "데이터베이스 버전 5로 업그레이드 완료 (push_notifications 테이블 변경사항은 Flutter에서만 적용)")
        }
    }

    override fun onDowngrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        // SQLite는 다운그레이드를 기본적으로 허용하지 않음
        // 하지만 Flutter와 Android 네이티브가 같은 DB를 공유하므로,
        // 버전이 더 높은 쪽(Flutter)이 먼저 업그레이드한 경우를 대비해 허용
        Log.w(TAG, "⚠️ 데이터베이스 다운그레이드 시도 감지: $oldVersion -> $newVersion")
        Log.w(TAG, "⚠️ 다운그레이드는 지원하지 않습니다. DB 버전을 확인하세요.")
        // 실제로는 다운그레이드를 허용하지 않으므로 예외를 발생시키지 않고 로그만 남김
        // Flutter와 Android 네이티브의 버전을 일치시켜야 함
    }

    override fun onOpen(db: SQLiteDatabase) {
        super.onOpen(db)
        // 데이터베이스가 열릴 때마다 필요한 컬럼들이 존재하는지 확인하고 없으면 추가
        ensureReplyIntentColumn(db)
        ensureAutoSummaryColumns(db)
        ensureSummaryDetailMessageColumn(db)
        ensureChatIdColumn(db)
    }

    /**
     * reply_intent 컬럼이 존재하는지 확인하고 없으면 추가
     */
    private fun ensureReplyIntentColumn(db: SQLiteDatabase) {
        try {
            // 컬럼 존재 여부 확인
            val cursor = db.rawQuery(
                "PRAGMA table_info($TABLE_ROOMS)",
                null
            )
            var columnExists = false
            while (cursor.moveToNext()) {
                val columnName = cursor.getString(cursor.getColumnIndexOrThrow("name"))
                if (columnName == ROOM_REPLY_INTENT) {
                    columnExists = true
                    break
                }
            }
            cursor.close()

            if (!columnExists) {
                // 컬럼이 없으면 추가
                db.execSQL("ALTER TABLE $TABLE_ROOMS ADD COLUMN $ROOM_REPLY_INTENT TEXT")
                Log.i(TAG, "✅ reply_intent 컬럼이 없어서 추가 완료")
            }
        } catch (e: Exception) {
            Log.e(TAG, "reply_intent 컬럼 확인/추가 실패: ${e.message}", e)
        }
    }

    /**
     * auto_summary 관련 컬럼들이 존재하는지 확인하고 없으면 추가
     */
    private fun ensureAutoSummaryColumns(db: SQLiteDatabase) {
        try {
            val cursor = db.rawQuery("PRAGMA table_info($TABLE_ROOMS)", null)
            val existingColumns = mutableSetOf<String>()
            while (cursor.moveToNext()) {
                val columnName = cursor.getString(cursor.getColumnIndexOrThrow("name"))
                existingColumns.add(columnName)
            }
            cursor.close()

            if (!existingColumns.contains(ROOM_AUTO_SUMMARY_ENABLED)) {
                db.execSQL("ALTER TABLE $TABLE_ROOMS ADD COLUMN $ROOM_AUTO_SUMMARY_ENABLED INTEGER DEFAULT 0")
                Log.i(TAG, "✅ auto_summary_enabled 컬럼 추가 완료 (onOpen)")
            }
            if (!existingColumns.contains(ROOM_AUTO_SUMMARY_MESSAGE_COUNT)) {
                db.execSQL("ALTER TABLE $TABLE_ROOMS ADD COLUMN $ROOM_AUTO_SUMMARY_MESSAGE_COUNT INTEGER DEFAULT 50")
                Log.i(TAG, "✅ auto_summary_message_count 컬럼 추가 완료 (onOpen)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "auto_summary 컬럼 확인/추가 실패: ${e.message}", e)
        }
    }

    /**
     * summary_detail_message 컬럼이 존재하는지 확인하고 없으면 추가
     */
    private fun ensureSummaryDetailMessageColumn(db: SQLiteDatabase) {
        try {
            val cursor = db.rawQuery("PRAGMA table_info($TABLE_SUMMARIES)", null)
            val existingColumns = mutableSetOf<String>()
            while (cursor.moveToNext()) {
                val columnName = cursor.getString(cursor.getColumnIndexOrThrow("name"))
                existingColumns.add(columnName)
            }
            cursor.close()

            if (!existingColumns.contains(SUMMARY_DETAIL_MESSAGE)) {
                db.execSQL("ALTER TABLE $TABLE_SUMMARIES ADD COLUMN $SUMMARY_DETAIL_MESSAGE TEXT")
                Log.i(TAG, "✅ summary_detail_message 컬럼 추가 완료 (onOpen)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "summary_detail_message 컬럼 확인/추가 실패: ${e.message}", e)
        }
    }

    private fun ensureChatIdColumn(db: SQLiteDatabase) {
        try {
            val cursor = db.rawQuery("PRAGMA table_info($TABLE_ROOMS)", null)
            var columnExists = false
            while (cursor.moveToNext()) {
                if (cursor.getString(cursor.getColumnIndexOrThrow("name")) == ROOM_CHAT_ID) {
                    columnExists = true
                    break
                }
            }
            cursor.close()
            if (!columnExists) {
                db.execSQL("ALTER TABLE $TABLE_ROOMS ADD COLUMN $ROOM_CHAT_ID TEXT")
                Log.i(TAG, "✅ chat_id 컬럼 추가 완료 (onOpen)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "chat_id 컬럼 확인/추가 실패: ${e.message}", e)
        }
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
    }

    /**
     * 채팅방 저장 또는 업데이트
     * @param isPrivateChat 개인채팅 여부 (true: 개인채팅, false: 그룹/오픈채팅)
     *        - 새 채팅방 생성 시 개인채팅이면 요약 끄기, 그룹/오픈채팅이면 요약 켜기
     * @return roomId
     */
    fun saveOrUpdateRoom(
        roomName: String,
        packageName: String,
        lastMessage: String?,
        lastSender: String?,
        lastMessageTime: Long,
        replyIntent: String? = null,
        isPrivateChat: Boolean = false,
        chatId: String? = null
    ): Long {


        val db = writableDatabase
        val now = System.currentTimeMillis()

        // 기존 채팅방 찾기: chatId가 있으면 chatId+packageName으로 우선 조회
        var foundByChatId = false
        var cursor: Cursor = if (!chatId.isNullOrEmpty()) {
            val chatIdCursor = db.query(
                TABLE_ROOMS,
                arrayOf(ROOM_ID, ROOM_UNREAD_COUNT, ROOM_BLOCKED, ROOM_NAME),
                "$ROOM_CHAT_ID = ? AND $ROOM_PACKAGE_NAME = ?",
                arrayOf(chatId, packageName),
                null, null, null
            )
            if (chatIdCursor.moveToFirst()) {
                foundByChatId = true
                chatIdCursor
            } else {
                chatIdCursor.close()
                // chatId로 못 찾으면 roomName으로 폴백
                db.query(
                    TABLE_ROOMS,
                    arrayOf(ROOM_ID, ROOM_UNREAD_COUNT, ROOM_BLOCKED, ROOM_NAME),
                    "$ROOM_NAME = ? AND $ROOM_PACKAGE_NAME = ?",
                    arrayOf(roomName, packageName),
                    null, null, null
                )
            }
        } else {
            db.query(
                TABLE_ROOMS,
                arrayOf(ROOM_ID, ROOM_UNREAD_COUNT, ROOM_BLOCKED, ROOM_NAME),
                "$ROOM_NAME = ? AND $ROOM_PACKAGE_NAME = ?",
                arrayOf(roomName, packageName),
                null, null, null
            )
        }

        return if (foundByChatId || cursor.moveToFirst()) {
            // 기존 채팅방 업데이트
            val roomId = cursor.getLong(cursor.getColumnIndexOrThrow(ROOM_ID))
            val currentUnread = cursor.getInt(cursor.getColumnIndexOrThrow(ROOM_UNREAD_COUNT))
            val isBlocked = cursor.getInt(cursor.getColumnIndexOrThrow(ROOM_BLOCKED)) == 1
            val existingRoomName = cursor.getString(cursor.getColumnIndexOrThrow(ROOM_NAME))
            cursor.close()


            // 차단된 방이면 저장 안 함
            if (isBlocked) return -1

            val values = ContentValues().apply {
                put(ROOM_LAST_MESSAGE, lastMessage)
                put(ROOM_LAST_SENDER, lastSender)
                put(ROOM_LAST_MESSAGE_TIME, lastMessageTime)
                put(ROOM_UNREAD_COUNT, currentUnread + 1)
                put(ROOM_UPDATED_AT, now)
                if (replyIntent != null) {
                    put(ROOM_REPLY_INTENT, replyIntent)
                }
                // chatId가 있으면 저장/업데이트
                if (!chatId.isNullOrEmpty()) {
                    put(ROOM_CHAT_ID, chatId)
                }
            }

            db.update(TABLE_ROOMS, values, "$ROOM_ID = ?", arrayOf(roomId.toString()))
            roomId
        } else {
            cursor.close()

            // 새 채팅방 생성
            // 개인채팅은 요약 끄기 (0), 그룹/오픈채팅은 요약 켜기 (1)
            val defaultSummaryEnabled = if (isPrivateChat) 0 else 1
            val packageAlias = getPackageAlias(packageName)
            val values = ContentValues().apply {
                put(ROOM_NAME, roomName)
                put(ROOM_PACKAGE_NAME, packageName)
                put(ROOM_PACKAGE_ALIAS, packageAlias)
                put(ROOM_LAST_MESSAGE, lastMessage)
                put(ROOM_LAST_SENDER, lastSender)
                put(ROOM_LAST_MESSAGE_TIME, lastMessageTime)
                put(ROOM_UNREAD_COUNT, 1)
                put(ROOM_PINNED, 0)
                put(ROOM_BLOCKED, 0)
                put(ROOM_MUTED, 0)
                put(ROOM_SUMMARY_ENABLED, defaultSummaryEnabled)
                put(ROOM_CATEGORY, "DAILY")
                put(ROOM_PARTICIPANT_COUNT, 0)
                put(ROOM_CREATED_AT, now)
                put(ROOM_UPDATED_AT, now)
                put(ROOM_AUTO_SUMMARY_ENABLED, 0)
                put(ROOM_AUTO_SUMMARY_MESSAGE_COUNT, 50)
                if (replyIntent != null) {
                    put(ROOM_REPLY_INTENT, replyIntent)
                }
                if (!chatId.isNullOrEmpty()) {
                    put(ROOM_CHAT_ID, chatId)
                }
            }

            val roomId = db.insert(TABLE_ROOMS, null, values)
            if (roomId <= 0) {
                Log.e(TAG, "채팅방 생성 실패: roomName='$roomName'")
            }
            roomId
        }
    }

    /**
     * 채팅방의 unreadCount 가져오기
     */
    fun getUnreadCount(roomId: Long): Int {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_ROOMS,
            arrayOf(ROOM_UNREAD_COUNT),
            "$ROOM_ID = ?",
            arrayOf(roomId.toString()),
            null, null, null
        )
        return if (cursor.moveToFirst()) {
            val unreadCount = cursor.getInt(cursor.getColumnIndexOrThrow(ROOM_UNREAD_COUNT))
            cursor.close()
            unreadCount
        } else {
            cursor.close()
            0
        }
    }

    /**
     * 중복 메시지 감지 시 unread 카운트 1 감소
     */
    private fun decrementUnreadCount(roomId: Long) {
        val db = writableDatabase
        db.execSQL(
            "UPDATE $TABLE_ROOMS SET $ROOM_UNREAD_COUNT = MAX($ROOM_UNREAD_COUNT - 1, 0) WHERE $ROOM_ID = ?",
            arrayOf(roomId.toString())
        )
        val newCount = getUnreadCount(roomId)
    }

    /**
     * 메시지 저장 (중복 체크 포함)
     */
    fun saveMessage(
        roomId: Long,
        sender: String,
        message: String,
        createTime: Long,
        roomName: String?
    ): Long {
        if (roomId < 0) return -1

        val db = writableDatabase

        // 중복 메시지 체크: 같은 roomId, sender, message, createTime이면 저장하지 않음
        // 시간 범위: ±1초 내에 같은 메시지가 있으면 중복으로 간주
        val timeWindow = 1000L // 1초
        val cursor = db.query(
            TABLE_MESSAGES,
            arrayOf(MSG_ID),
            "$MSG_ROOM_ID = ? AND $MSG_SENDER = ? AND $MSG_MESSAGE = ? AND ABS($MSG_CREATE_TIME - ?) <= ?",
            arrayOf(roomId.toString(), sender, message, createTime.toString(), timeWindow.toString()),
            null, null, null, "1"
        )

        if (cursor.moveToFirst()) {
            val existingMsgId = cursor.getLong(cursor.getColumnIndexOrThrow(MSG_ID))
            cursor.close()
            // 중복 메시지: unread 카운트 롤백
            decrementUnreadCount(roomId)
            return -2 // 중복 메시지 표시
        }
        cursor.close()

        val values = ContentValues().apply {
            put(MSG_ROOM_ID, roomId)
            put(MSG_SENDER, sender)
            put(MSG_MESSAGE, message)
            put(MSG_CREATE_TIME, createTime)
            put(MSG_ROOM_NAME, roomName)
        }

        val msgId = db.insert(TABLE_MESSAGES, null, values)

        if (msgId <= 0) {
            Log.e(TAG, "메시지 저장 실패: roomId=$roomId, sender='$sender'")
        }
        return msgId
    }

    /**
     * 채팅방이 차단되었는지 확인
     */
    fun isRoomBlocked(roomName: String, packageName: String): Boolean {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_ROOMS,
            arrayOf(ROOM_BLOCKED),
            "$ROOM_NAME = ? AND $ROOM_PACKAGE_NAME = ?",
            arrayOf(roomName, packageName),
            null, null, null
        )

        val isBlocked = if (cursor.moveToFirst()) {
            cursor.getInt(cursor.getColumnIndexOrThrow(ROOM_BLOCKED)) == 1
        } else {
            false
        }
        cursor.close()
        return isBlocked
    }

    /**
     * 패키지 이름을 별칭으로 변환
     */
    private fun getPackageAlias(packageName: String): String {
        return when (packageName) {
            "com.kakao.talk" -> "카카오톡"
            "jp.naver.line.android" -> "LINE"
            "org.telegram.messenger" -> "Telegram"
            "com.instagram.android" -> "Instagram"
            "com.Slack" -> "Slack"
            else -> "알 수 없음"
        }
    }

    /**
     * 채팅방의 자동 요약 설정 조회
     */
    fun getAutoSummarySettings(roomId: Long): Triple<Boolean, Boolean, Int> {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_ROOMS,
            arrayOf(ROOM_SUMMARY_ENABLED, ROOM_AUTO_SUMMARY_ENABLED, ROOM_AUTO_SUMMARY_MESSAGE_COUNT),
            "$ROOM_ID = ?",
            arrayOf(roomId.toString()),
            null, null, null
        )
        return if (cursor.moveToFirst()) {
            val summaryEnabled = cursor.getInt(cursor.getColumnIndexOrThrow(ROOM_SUMMARY_ENABLED)) == 1
            val autoSummaryEnabled = cursor.getInt(cursor.getColumnIndexOrThrow(ROOM_AUTO_SUMMARY_ENABLED)) == 1
            val messageCount = cursor.getInt(cursor.getColumnIndexOrThrow(ROOM_AUTO_SUMMARY_MESSAGE_COUNT))
            cursor.close()
            Triple(summaryEnabled, autoSummaryEnabled, messageCount)
        } else {
            cursor.close()
            Triple(false, false, 50)
        }
    }

    /**
     * 채팅방의 안 읽은 메시지 목록 조회 (최근 N개)
     */
    fun getUnreadMessages(roomId: Long, limit: Int): List<Map<String, Any>> {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_MESSAGES,
            arrayOf(MSG_ID, MSG_SENDER, MSG_MESSAGE, MSG_CREATE_TIME),
            "$MSG_ROOM_ID = ?",
            arrayOf(roomId.toString()),
            null, null,
            "$MSG_CREATE_TIME DESC",
            limit.toString()
        )
        val messages = mutableListOf<Map<String, Any>>()
        while (cursor.moveToNext()) {
            messages.add(mapOf(
                "id" to cursor.getLong(cursor.getColumnIndexOrThrow(MSG_ID)),
                "sender" to cursor.getString(cursor.getColumnIndexOrThrow(MSG_SENDER)),
                "message" to cursor.getString(cursor.getColumnIndexOrThrow(MSG_MESSAGE)),
                "createTime" to cursor.getLong(cursor.getColumnIndexOrThrow(MSG_CREATE_TIME))
            ))
        }
        cursor.close()
        return messages.reversed() // 시간순 정렬
    }

    /**
     * 요약 저장
     */
    fun saveSummary(
        roomId: Long,
        summaryName: String,
        summaryMessage: String,
        summaryFrom: Long,
        summaryTo: Long,
        summaryDetailMessage: String? = null
    ): Long {
        val db = writableDatabase
        val now = System.currentTimeMillis()
        val values = ContentValues().apply {
            put(SUMMARY_ROOM_ID, roomId)
            put(SUMMARY_NAME, summaryName)
            put(SUMMARY_MESSAGE, summaryMessage)
            put(SUMMARY_FROM, summaryFrom)
            put(SUMMARY_TO, summaryTo)
            put(SUMMARY_CREATED_AT, now)
            if (summaryDetailMessage != null) {
                put(SUMMARY_DETAIL_MESSAGE, summaryDetailMessage)
            }
        }
        return db.insert(TABLE_SUMMARIES, null, values)
    }

    /**
     * 채팅방의 안 읽은 메시지 개수 초기화 (읽음 처리)
     */
    fun resetUnreadCount(roomId: Long): Boolean {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(ROOM_UNREAD_COUNT, 0)
            put(ROOM_UPDATED_AT, System.currentTimeMillis())
        }
        val updateCount = db.update(TABLE_ROOMS, values, "$ROOM_ID = ?", arrayOf(roomId.toString()))
        val success = updateCount > 0
        return success
    }
}
