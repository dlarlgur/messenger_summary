package com.example.chat_llm

import android.content.ContentValues
import android.content.Context
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
        const val DATABASE_VERSION = 2

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
                if (e.message?.contains("duplicate column") == true) {
                    Log.d(TAG, "reply_intent 컬럼이 이미 존재함 - 스킵")
                } else {
                    Log.e(TAG, "reply_intent 컬럼 추가 실패: ${e.message}", e)
                }
            }
        }
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
    }

    /**
     * 채팅방 저장 또는 업데이트
     * @return roomId
     */
    fun saveOrUpdateRoom(
        roomName: String,
        packageName: String,
        lastMessage: String?,
        lastSender: String?,
        lastMessageTime: Long,
        replyIntent: String? = null
    ): Long {
        val db = writableDatabase
        val now = System.currentTimeMillis()

        // 기존 채팅방 찾기
        val cursor = db.query(
            TABLE_ROOMS,
            arrayOf(ROOM_ID, ROOM_UNREAD_COUNT, ROOM_BLOCKED),
            "$ROOM_NAME = ? AND $ROOM_PACKAGE_NAME = ?",
            arrayOf(roomName, packageName),
            null, null, null
        )

        return if (cursor.moveToFirst()) {
            // 기존 채팅방 업데이트
            val roomId = cursor.getLong(cursor.getColumnIndexOrThrow(ROOM_ID))
            val currentUnread = cursor.getInt(cursor.getColumnIndexOrThrow(ROOM_UNREAD_COUNT))
            val isBlocked = cursor.getInt(cursor.getColumnIndexOrThrow(ROOM_BLOCKED)) == 1
            cursor.close()

            // 차단된 방이면 저장 안 함
            if (isBlocked) {
                Log.d(TAG, "차단된 채팅방 무시: $roomName")
                return -1
            }

            val values = ContentValues().apply {
                put(ROOM_LAST_MESSAGE, lastMessage)
                put(ROOM_LAST_SENDER, lastSender)
                put(ROOM_LAST_MESSAGE_TIME, lastMessageTime)
                put(ROOM_UNREAD_COUNT, currentUnread + 1)
                put(ROOM_UPDATED_AT, now)
                if (replyIntent != null) {
                    put(ROOM_REPLY_INTENT, replyIntent)
                }
            }

            db.update(TABLE_ROOMS, values, "$ROOM_ID = ?", arrayOf(roomId.toString()))
            Log.d(TAG, "채팅방 업데이트: $roomName (id=$roomId)")
            roomId
        } else {
            cursor.close()

            // 새 채팅방 생성
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
                put(ROOM_SUMMARY_ENABLED, 1)
                put(ROOM_CATEGORY, "DAILY")
                put(ROOM_PARTICIPANT_COUNT, 0)
                put(ROOM_CREATED_AT, now)
                put(ROOM_UPDATED_AT, now)
                if (replyIntent != null) {
                    put(ROOM_REPLY_INTENT, replyIntent)
                }
            }

            val roomId = db.insert(TABLE_ROOMS, null, values)
            Log.d(TAG, "새 채팅방 생성: $roomName (id=$roomId)")
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
            Log.d(TAG, "중복 메시지 감지 - 저장 건너뜀: roomId=$roomId, sender=$sender, msgId=$existingMsgId")
            return existingMsgId
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
        Log.d(TAG, "메시지 저장: roomId=$roomId, sender=$sender, msgId=$msgId")
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
            else -> "알 수 없음"
        }
    }
}
