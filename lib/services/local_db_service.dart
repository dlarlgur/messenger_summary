import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  // Android ChatDatabase.kt와 동일한 DB 이름 사용
  static const String _databaseName = 'chat_llm.db';
  static const int _databaseVersion = 4; // push_notifications 테이블 추가

  // 테이블 이름 (Android와 동일)
  static const String _tableRooms = 'chat_rooms';
  static const String _tableMessages = 'chat_messages';
  static const String _tableSummaries = 'chat_summaries';
  static const String _tableNotifications = 'push_notifications';

  Database? _database;
  bool _isInitialized = false;

  /// 지원 메신저 목록 (카카오톡만)
  static const List<Map<String, String>> supportedMessengers = [
    {'packageName': 'com.kakao.talk', 'alias': '카카오톡'},
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _database = await _initDatabase();
    _isInitialized = true;
    debugPrint('LocalDbService 초기화 완료 (sqflite)');
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    
    debugPrint('DB 경로: $path');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // 채팅방 테이블 (Android ChatDatabase.kt와 동일한 스키마)
    await db.execute('''
      CREATE TABLE $_tableRooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_name TEXT NOT NULL,
        package_name TEXT NOT NULL,
        package_alias TEXT,
        last_message TEXT,
        last_sender TEXT,
        last_message_time INTEGER,
        unread_count INTEGER DEFAULT 0,
        pinned INTEGER DEFAULT 0,
        blocked INTEGER DEFAULT 0,
        muted INTEGER DEFAULT 0,
        summary_enabled INTEGER DEFAULT 1,
        category TEXT DEFAULT 'DAILY',
        participant_count INTEGER DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER,
        auto_summary_enabled INTEGER DEFAULT 0,
        auto_summary_message_count INTEGER DEFAULT 50,
        UNIQUE(room_name, package_name)
      )
    ''');

    // 메시지 테이블
    await db.execute('''
      CREATE TABLE $_tableMessages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        sender TEXT NOT NULL,
        message TEXT NOT NULL,
        create_time INTEGER NOT NULL,
        room_name TEXT,
        FOREIGN KEY(room_id) REFERENCES $_tableRooms(id) ON DELETE CASCADE
      )
    ''');

    // 요약 테이블
    await db.execute('''
      CREATE TABLE $_tableSummaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id INTEGER NOT NULL,
        summary_name TEXT,
        summary_message TEXT NOT NULL,
        summary_detail_message TEXT,
        summary_from INTEGER,
        summary_to INTEGER,
        created_at INTEGER,
        FOREIGN KEY(room_id) REFERENCES $_tableRooms(id) ON DELETE CASCADE
      )
    ''');

    // 푸시 알림 테이블
    await db.execute('''
      CREATE TABLE $_tableNotifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        sender TEXT,
        message TEXT,
        room_name TEXT,
        post_time INTEGER NOT NULL,
        created_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    // 인덱스 생성
    await db.execute('CREATE INDEX idx_rooms_name_package ON $_tableRooms(room_name, package_name)');
    await db.execute('CREATE INDEX idx_messages_room_id ON $_tableMessages(room_id)');
    await db.execute('CREATE INDEX idx_messages_create_time ON $_tableMessages(create_time)');
    await db.execute('CREATE INDEX idx_summaries_room_id ON $_tableSummaries(room_id)');
    await db.execute('CREATE INDEX idx_notifications_post_time ON $_tableNotifications(post_time)');

    debugPrint('데이터베이스 테이블 생성 완료');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('데이터베이스 업그레이드: $oldVersion -> $newVersion');
    
    // 버전별 마이그레이션
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      if (version == 2) {
        // summary_detail_message 컬럼 추가
        await _ensureColumnExists(db, _tableSummaries, 'summary_detail_message', 'TEXT');
      }
      if (version == 3) {
        // auto_summary_enabled, auto_summary_message_count 컬럼 추가
        await _ensureColumnExists(db, _tableRooms, 'auto_summary_enabled', 'INTEGER DEFAULT 0');
        await _ensureColumnExists(db, _tableRooms, 'auto_summary_message_count', 'INTEGER DEFAULT 50');
      }
      if (version == 4) {
        // push_notifications 테이블 추가
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $_tableNotifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT NOT NULL,
            sender TEXT,
            message TEXT,
            room_name TEXT,
            post_time INTEGER NOT NULL,
            created_at INTEGER DEFAULT (strftime('%s', 'now'))
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_post_time ON $_tableNotifications(post_time)');
      }
    }
  }

  /// 컬럼이 존재하는지 확인하고 없으면 추가
  Future<void> _ensureColumnExists(Database db, String tableName, String columnName, String columnType) async {
    try {
      // 테이블 정보 조회
      final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
      final columnExists = tableInfo.any((column) => column['name'] == columnName);
      
      if (!columnExists) {
        await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnType');
        debugPrint('✅ 컬럼 추가 완료: $tableName.$columnName');
      } else {
        debugPrint('ℹ️ 컬럼 이미 존재: $tableName.$columnName');
      }
    } catch (e) {
      debugPrint('❌ 컬럼 확인/추가 실패: $tableName.$columnName - $e');
      // 에러가 발생해도 계속 진행 (컬럼이 이미 존재할 수 있음)
    }
  }

  // ============ 채팅방 관련 ============

  /// 채팅방 저장 또는 업데이트 (roomName + packageName으로 식별)
  Future<ChatRoom> saveOrUpdateRoom({
    required String roomName,
    required String packageName,
    String? lastMessage,
    String? lastSender,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final packageAlias = _getPackageAlias(packageName);

    // 기존 채팅방 찾기
    final existing = await db.query(
      _tableRooms,
      where: 'room_name = ? AND package_name = ?',
      whereArgs: [roomName, packageName],
    );

    if (existing.isNotEmpty) {
      // 기존 채팅방 업데이트
      final roomId = existing.first['id'] as int;
      final currentUnread = existing.first['unread_count'] as int? ?? 0;

      final updateData = <String, dynamic>{
        'updated_at': now,
      };
      if (lastMessage != null) updateData['last_message'] = lastMessage;
      if (lastSender != null) updateData['last_sender'] = lastSender;
      if (lastMessageTime != null) {
        updateData['last_message_time'] = lastMessageTime.millisecondsSinceEpoch;
      }
      if (unreadCount != null) {
        updateData['unread_count'] = unreadCount;
      } else {
        updateData['unread_count'] = currentUnread + 1;
      }

      await db.update(
        _tableRooms,
        updateData,
        where: 'id = ?',
        whereArgs: [roomId],
      );

      final updated = await db.query(
        _tableRooms,
        where: 'id = ?',
        whereArgs: [roomId],
      );
      return _mapToRoom(updated.first);
    } else {
      // 새 채팅방 생성
      final roomData = {
        'room_name': roomName,
        'package_name': packageName,
        'package_alias': packageAlias,
        'last_message': lastMessage,
        'last_sender': lastSender,
        'last_message_time': lastMessageTime?.millisecondsSinceEpoch,
        'unread_count': 1,
        'pinned': 0,
        'blocked': 0,
        'muted': 0,
        'summary_enabled': 1,
        'category': 'DAILY',
        'participant_count': 0,
        'created_at': now,
        'updated_at': now,
      };

      final roomId = await db.insert(_tableRooms, roomData);
      
      final created = await db.query(
        _tableRooms,
        where: 'id = ?',
        whereArgs: [roomId],
      );
      return _mapToRoom(created.first);
    }
  }

  /// 모든 채팅방 조회 (차단되지 않은 것만)
  /// 요약 기능이 켜진 채팅방 목록 조회
  Future<List<ChatRoom>> getSummaryEnabledRooms() async {
    final db = await database;
    final results = await db.query(
      _tableRooms,
      where: 'summary_enabled = ? AND blocked = ?',
      whereArgs: [1, 0], // summary_enabled = 1 (켜짐), blocked = 0 (차단 안됨)
      orderBy: 'last_message_time DESC',
    );
    return results.map((row) => _mapToRoom(row)).toList();
  }

  Future<List<ChatRoom>> getChatRooms() async {
    final db = await database;
    final results = await db.query(
      _tableRooms,
      where: 'blocked = 0',
      orderBy: 'pinned DESC, last_message_time DESC',
    );
    return results.map((row) => _mapToRoom(row)).toList();
  }

  /// 차단된 채팅방 목록 조회
  Future<List<ChatRoom>> getBlockedRooms() async {
    final db = await database;
    final results = await db.query(
      _tableRooms,
      where: 'blocked = 1',
    );
    return results.map((row) => _mapToRoom(row)).toList();
  }

  /// 채팅방 ID로 조회
  Future<ChatRoom?> getRoomById(int roomId) async {
    final db = await database;
    final results = await db.query(
      _tableRooms,
      where: 'id = ?',
      whereArgs: [roomId],
    );
    if (results.isEmpty) return null;
    return _mapToRoom(results.first);
  }

  /// 채팅방 설정 업데이트
  Future<ChatRoom?> updateRoomSettings(
    int roomId, {
    bool? pinned,
    String? category,
    bool? summaryEnabled,
    bool? blocked,
    bool? muted,
    bool? autoSummaryEnabled,
    int? autoSummaryMessageCount,
  }) async {
    final db = await database;
    final updateData = <String, dynamic>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (pinned != null) updateData['pinned'] = pinned ? 1 : 0;
    if (category != null) updateData['category'] = category;
    if (summaryEnabled != null) updateData['summary_enabled'] = summaryEnabled ? 1 : 0;
    if (blocked != null) updateData['blocked'] = blocked ? 1 : 0;
    if (muted != null) updateData['muted'] = muted ? 1 : 0;
    if (autoSummaryEnabled != null) updateData['auto_summary_enabled'] = autoSummaryEnabled ? 1 : 0;
    if (autoSummaryMessageCount != null) {
      // 5~300 사이로 제한
      final clampedCount = autoSummaryMessageCount.clamp(5, 300);
      updateData['auto_summary_message_count'] = clampedCount;
    }

    await db.update(
      _tableRooms,
      updateData,
      where: 'id = ?',
      whereArgs: [roomId],
    );

    return getRoomById(roomId);
  }

  /// 채팅방의 unreadCount를 0으로 리셋
  Future<void> markRoomAsRead(int roomId) async {
    final db = await database;
    await db.update(
      _tableRooms,
      {'unread_count': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [roomId],
    );
  }

  /// 모든 채팅방을 읽음 처리
  Future<void> markAllRoomsAsRead() async {
    final db = await database;
    await db.update(
      _tableRooms,
      {'unread_count': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
    );
  }

  /// 채팅방 삭제 (메시지도 함께 삭제 - CASCADE)
  Future<bool> deleteRoom(int roomId) async {
    final db = await database;
    final count = await db.delete(
      _tableRooms,
      where: 'id = ?',
      whereArgs: [roomId],
    );
    return count > 0;
  }

  // ============ 메시지 관련 ============

  /// 메시지 저장
  Future<void> saveMessage({
    required int roomId,
    required String sender,
    required String message,
    required DateTime createTime,
    required String roomName,
  }) async {
    final db = await database;
    await db.insert(_tableMessages, {
      'room_id': roomId,
      'sender': sender,
      'message': message,
      'create_time': createTime.millisecondsSinceEpoch,
      'room_name': roomName,
    });
  }

  /// 메시지 삭제
  Future<bool> deleteMessage(int messageId) async {
    final db = await database;
    final count = await db.delete(
      _tableMessages,
      where: 'id = ?',
      whereArgs: [messageId],
    );
    return count > 0;
  }

  /// 여러 메시지 삭제
  Future<int> deleteMessages(List<int> messageIds) async {
    if (messageIds.isEmpty) return 0;
    final db = await database;
    final placeholders = messageIds.map((_) => '?').join(',');
    final count = await db.delete(
      _tableMessages,
      where: 'id IN ($placeholders)',
      whereArgs: messageIds,
    );
    return count;
  }

  /// 채팅방의 메시지 조회 (페이지네이션)
  Future<RoomMessagesResponse> getRoomMessages(
    int roomId, {
    int page = 0,
    int size = 50,
  }) async {
    final db = await database;
    
    // 전체 개수
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableMessages WHERE room_id = ?',
      [roomId],
    );
    final totalCount = Sqflite.firstIntValue(countResult) ?? 0;
    final totalPages = (totalCount / size).ceil();

    // 페이지네이션된 메시지 조회 (최신순)
    final results = await db.query(
      _tableMessages,
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'create_time DESC',
      limit: size,
      offset: page * size,
    );

    final messages = results.map((row) => MessageItem.fromJson({
      'messageId': row['id'] as int,
      'sender': row['sender'] as String? ?? '',
      'message': row['message'] as String? ?? '',
      'createTime': DateTime.fromMillisecondsSinceEpoch(row['create_time'] as int),
    })).toList();

    final room = await getRoomById(roomId);

    return RoomMessagesResponse(
      roomId: roomId,
      roomName: room?.roomName ?? '',
      messages: messages,
      page: page,
      size: size,
      totalCount: totalCount,
      totalPages: totalPages,
      hasMore: page < totalPages - 1,
    );
  }

  /// 채팅방의 최신 메시지 조회 (1개만)
  Future<Map<String, dynamic>?> getLatestMessage(int roomId) async {
    final db = await database;
    final results = await db.query(
      _tableMessages,
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'create_time DESC',
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    
    final row = results.first;
    return {
      'sender': row['sender'] as String? ?? '',
      'message': row['message'] as String? ?? '',
      'createTime': DateTime.fromMillisecondsSinceEpoch(row['create_time'] as int),
    };
  }

  // ============ 요약 관련 ============

  /// 요약 저장
  Future<void> saveSummary({
    required int roomId,
    required String summaryName,
    required String summaryMessage,
    String? summaryDetailMessage,
    DateTime? summaryFrom,
    DateTime? summaryTo,
  }) async {
    final db = await database;
    
    // 컬럼 존재 여부 확인 및 추가 (안전장치)
    await _ensureColumnExists(db, _tableSummaries, 'summary_detail_message', 'TEXT');
    
    // 저장할 데이터 준비
    final data = <String, dynamic>{
      'room_id': roomId,
      'summary_name': summaryName,
      'summary_message': summaryMessage,
      'summary_from': summaryFrom?.millisecondsSinceEpoch,
      'summary_to': summaryTo?.millisecondsSinceEpoch,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    
    // summary_detail_message가 있으면 추가
    if (summaryDetailMessage != null) {
      data['summary_detail_message'] = summaryDetailMessage;
    }
    
    await db.insert(_tableSummaries, data);
  }

  /// 채팅방의 요약 목록 조회
  Future<RoomDetailResponse> getRoomSummaries(int roomId) async {
    final db = await database;
    final results = await db.query(
      _tableSummaries,
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'id DESC',
    );

    final summaries = results.map((row) => SummaryItem(
      summaryId: row['id'] as int,
      summaryName: row['summary_name'] as String? ?? '',
      summaryMessage: row['summary_message'] as String? ?? '',
      summaryDetailMessage: row['summary_detail_message'] as String?,
      summaryFrom: row['summary_from'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['summary_from'] as int)
          : null,
      summaryTo: row['summary_to'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['summary_to'] as int)
          : null,
    )).toList();

    final room = await getRoomById(roomId);

    return RoomDetailResponse(
      roomId: roomId,
      roomName: room?.roomName ?? '',
      summaries: summaries,
    );
  }

  /// summaryId로 roomId 찾기
  Future<int?> getRoomIdBySummaryId(int summaryId) async {
    final db = await database;
    final results = await db.query(
      _tableSummaries,
      columns: ['room_id'],
      where: 'id = ?',
      whereArgs: [summaryId],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return results.first['room_id'] as int?;
    }
    return null;
  }

  /// 요약 삭제
  Future<bool> deleteSummary(int summaryId) async {
    final db = await database;
    final count = await db.delete(
      _tableSummaries,
      where: 'id = ?',
      whereArgs: [summaryId],
    );
    return count > 0;
  }

  /// 빈 요약 메시지 삭제 (내용이 없는 요약 정리)
  Future<int> deleteEmptySummaries() async {
    final db = await database;
    final count = await db.delete(
      _tableSummaries,
      where: "summary_message IS NULL OR summary_message = ''",
    );
    debugPrint('🗑️ 빈 요약 $count개 삭제됨');
    return count;
  }

  // ============ 헬퍼 메서드 ============

  String _getPackageAlias(String packageName) {
    final messenger = supportedMessengers.firstWhere(
      (m) => m['packageName'] == packageName,
      orElse: () => {'alias': '알 수 없음'},
    );
    return messenger['alias'] ?? '알 수 없음';
  }

  ChatRoom _mapToRoom(Map<String, dynamic> row) {
    return ChatRoom(
      id: row['id'] as int,
      roomName: row['room_name'] as String? ?? '',
      lastMessage: row['last_message'] as String?,
      lastSender: row['last_sender'] as String?,
      lastMessageTime: row['last_message_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_message_time'] as int)
          : null,
      unreadCount: row['unread_count'] as int? ?? 0,
      participantCount: row['participant_count'] as int? ?? 0,
      pinned: (row['pinned'] as int? ?? 0) == 1,
      blocked: (row['blocked'] as int? ?? 0) == 1,
      summaryEnabled: (row['summary_enabled'] as int? ?? 1) == 1,
      category: RoomCategory.fromString(row['category'] as String?),
      packageName: row['package_name'] as String? ?? 'com.kakao.talk',
      packageAlias: row['package_alias'] as String? ?? '알 수 없음',
      autoSummaryEnabled: (row['auto_summary_enabled'] as int? ?? 0) == 1,
      autoSummaryMessageCount: row['auto_summary_message_count'] as int? ?? 50,
    );
  }

  /// 지원 메신저인지 확인
  bool isSupportedMessenger(String packageName) {
    return supportedMessengers.any((m) => m['packageName'] == packageName);
  }

  /// roomName과 packageName으로 채팅방 찾기
  Future<ChatRoom?> findRoom(String roomName, String packageName) async {
    final db = await database;
    final results = await db.query(
      _tableRooms,
      where: 'room_name = ? AND package_name = ?',
      whereArgs: [roomName, packageName],
    );
    if (results.isEmpty) return null;
    return _mapToRoom(results.first);
  }

  /// 채팅방 음소거 상태 확인
  Future<bool> isRoomMuted(int roomId) async {
    final db = await database;
    final results = await db.query(
      _tableRooms,
      columns: ['muted'],
      where: 'id = ?',
      whereArgs: [roomId],
    );
    if (results.isEmpty) return false;
    return (results.first['muted'] as int? ?? 0) == 1;
  }

  /// DB 닫기
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
    }
  }

  // ============ 푸시 알림 관련 ============

  /// 푸시 알림 저장
  Future<int?> saveNotification({
    required String packageName,
    String? sender,
    String? message,
    String? roomName,
    required int postTime,
  }) async {
    try {
      final db = await database;
      debugPrint('📝 알림 저장 시도: packageName=$packageName, sender=$sender, message=${message?.substring(0, message.length > 50 ? 50 : message.length)}..., roomName=$roomName, postTime=$postTime');
      
      final id = await db.insert(
        _tableNotifications,
        {
          'package_name': packageName,
          'sender': sender,
          'message': message,
          'room_name': roomName,
          'post_time': postTime,
        },
      );
      
      debugPrint('✅ 알림 저장 성공: id=$id');
      return id;
    } catch (e, stackTrace) {
      debugPrint('❌ 알림 저장 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return null;
    }
  }

  /// 푸시 알림 목록 조회 (최신순)
  Future<List<Map<String, dynamic>>> getNotifications({
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await database;
      final results = await db.query(
        _tableNotifications,
        orderBy: 'post_time DESC',
        limit: limit,
        offset: offset,
      );
      return results;
    } catch (e) {
      debugPrint('알림 목록 조회 실패: $e');
      return [];
    }
  }

  /// 푸시 알림 개수 조회
  Future<int> getNotificationCount() async {
    try {
      final db = await database;
      final results = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableNotifications');
      return Sqflite.firstIntValue(results) ?? 0;
    } catch (e) {
      debugPrint('알림 개수 조회 실패: $e');
      return 0;
    }
  }

  /// 푸시 알림 삭제
  Future<bool> deleteNotification(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        _tableNotifications,
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    } catch (e) {
      debugPrint('알림 삭제 실패: $e');
      return false;
    }
  }

  /// 모든 푸시 알림 삭제
  Future<bool> deleteAllNotifications() async {
    try {
      final db = await database;
      await db.delete(_tableNotifications);
      return true;
    } catch (e) {
      debugPrint('모든 알림 삭제 실패: $e');
      return false;
    }
  }
}
