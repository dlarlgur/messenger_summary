/// 채팅방 요약 카테고리
enum RoomCategory {
  DAILY('일상/잡담', '💬'),
  WORK('업무/회의', '🧑‍💼'),
  INFO('정보/공지', '📢'),
  TRADE('거래/돈', '💰'),
  STUDY('학습/지식', '📚'),
  HOBBY('취미/관심사', '🎮'),
  DECISION('의사결정/계획', '🧭');

  final String displayName;
  final String emoji;

  const RoomCategory(this.displayName, this.emoji);

  static RoomCategory fromString(String? value) {
    if (value == null) return RoomCategory.DAILY;
    return RoomCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RoomCategory.DAILY,
    );
  }
}

class ChatRoom {
  final int id;
  final String roomName;
  final String? lastMessage;
  final String? lastSender;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final int participantCount;
  final String? profileImageUrl;
  final bool pinned;
  final RoomCategory category;
  final bool summaryEnabled;  // AI 요약 기능 사용 여부
  final bool blocked;  // 차단 여부
  final String packageName;  // 패키지 이름 (com.kakao.talk, org.telegram.messenger 등)
  final String packageAlias;  // 패키지 표시 이름 (카카오톡, 텔레그램, 인스타그램 등)
  final bool autoSummaryEnabled;  // 자동 요약 활성화 여부
  final int autoSummaryMessageCount;  // 자동 요약 메시지 개수 (5~300)

  ChatRoom({
    required this.id,
    required this.roomName,
    this.lastMessage,
    this.lastSender,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.participantCount = 0,
    this.profileImageUrl,
    this.pinned = false,
    this.category = RoomCategory.DAILY,
    this.summaryEnabled = true,  // 기본값: 사용
    this.blocked = false,  // 기본값: 정상
    this.packageName = 'com.kakao.talk',  // 기본값: 카카오톡
    this.packageAlias = '카카오톡',  // 기본값: 카카오톡
    this.autoSummaryEnabled = false,  // 기본값: 비활성화
    this.autoSummaryMessageCount = 50,  // 기본값: 50개
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['roomId'] ?? json['id'],  // 서버는 roomId 반환
      roomName: json['roomName'] ?? '',
      lastMessage: json['lastMessage'],
      lastSender: json['lastSender'],
      lastMessageTime: _parseDateTime(json['lastMessageTime']),
      unreadCount: json['unreadCount'] ?? 0,
      participantCount: json['participantCount'] ?? 0,
      profileImageUrl: json['profileImageUrl'],
      pinned: json['pinned'] ?? false,
      category: RoomCategory.fromString(json['category']),
      summaryEnabled: json['summaryEnabled'] ?? true,  // 기본값: 사용
      blocked: json['blocked'] ?? false,  // 기본값: 정상
      packageName: json['packageName'] ?? 'com.kakao.talk',  // 기본값: 카카오톡
      packageAlias: json['packageAlias'] ?? '알 수 없음',  // 서버에서 반드시 제공해야 함
      autoSummaryEnabled: json['autoSummaryEnabled'] == 1 || json['autoSummaryEnabled'] == true,  // DB에서는 INTEGER, JSON에서는 bool
      autoSummaryMessageCount: json['autoSummaryMessageCount'] ?? 50,  // 기본값: 50개
    );
  }

  /// 서버에서 오는 다양한 DateTime 형식 파싱
  /// - 배열 형식: [2026, 1, 28, 8, 29, 13] (년, 월, 일, 시, 분, 초)
  /// - 문자열 형식: "2026-01-28T08:29:13"
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    try {
      if (value is List) {
        // 배열 형식: [년, 월, 일, 시, 분, 초, 나노초(선택)]
        if (value.length >= 3) {
          // dynamic을 int로 안전하게 변환
          int toInt(dynamic v) => v is int ? v : int.parse(v.toString());
          return DateTime(
            toInt(value[0]),                          // 년
            toInt(value[1]),                          // 월
            toInt(value[2]),                          // 일
            value.length > 3 ? toInt(value[3]) : 0,   // 시
            value.length > 4 ? toInt(value[4]) : 0,   // 분
            value.length > 5 ? toInt(value[5]) : 0,   // 초
          );
        }
      } else if (value is String) {
        // ISO 8601 문자열 형식
        return DateTime.parse(value);
      }
    } catch (e) {
      print('DateTime 파싱 실패: $value, 오류: $e');
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomName': roomName,
      'lastMessage': lastMessage,
      'lastSender': lastSender,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
      'participantCount': participantCount,
      'profileImageUrl': profileImageUrl,
      'pinned': pinned,
      'category': category.name,
      'summaryEnabled': summaryEnabled,
      'blocked': blocked,
      'packageName': packageName,
      'packageAlias': packageAlias,
      'autoSummaryEnabled': autoSummaryEnabled,
      'autoSummaryMessageCount': autoSummaryMessageCount,
    };
  }

  /// pinned, category, summaryEnabled, blocked, packageName, packageAlias, unreadCount, autoSummaryEnabled, autoSummaryMessageCount 업데이트된 새 인스턴스 반환
  ChatRoom copyWith({
    bool? pinned,
    RoomCategory? category,
    bool? summaryEnabled,
    bool? blocked,
    String? packageName,
    String? packageAlias,
    int? unreadCount,
    bool? autoSummaryEnabled,
    int? autoSummaryMessageCount,
  }) {
    return ChatRoom(
      id: id,
      roomName: roomName,
      lastMessage: lastMessage,
      lastSender: lastSender,
      lastMessageTime: lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      participantCount: participantCount,
      profileImageUrl: profileImageUrl,
      pinned: pinned ?? this.pinned,
      category: category ?? this.category,
      summaryEnabled: summaryEnabled ?? this.summaryEnabled,
      blocked: blocked ?? this.blocked,
      packageName: packageName ?? this.packageName,
      packageAlias: packageAlias ?? this.packageAlias,
      autoSummaryEnabled: autoSummaryEnabled ?? this.autoSummaryEnabled,
      autoSummaryMessageCount: autoSummaryMessageCount ?? this.autoSummaryMessageCount,
    );
  }
  
  /// 패키지 표시 이름 반환 (packageAlias 사용)
  String get appName => packageAlias;
}
