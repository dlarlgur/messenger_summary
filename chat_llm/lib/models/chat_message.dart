/// 서버에서 오는 다양한 DateTime 형식 파싱 헬퍼
DateTime? parseServerDateTime(dynamic value) {
  if (value == null) return null;

  try {
    // DateTime 객체면 그대로 반환
    if (value is DateTime) {
      return value;
    }
    if (value is List) {
      // 배열 형식: [년, 월, 일, 시, 분, 초, 나노초(선택)]
      if (value.length >= 3) {
        // dynamic을 int로 안전하게 변환
        int toInt(dynamic v) => v is int ? v : int.parse(v.toString());
        return DateTime(
          toInt(value[0]),
          toInt(value[1]),
          toInt(value[2]),
          value.length > 3 ? toInt(value[3]) : 0,
          value.length > 4 ? toInt(value[4]) : 0,
          value.length > 5 ? toInt(value[5]) : 0,
        );
      }
    } else if (value is String) {
      return DateTime.parse(value);
    }
  } catch (e) {
    print('DateTime 파싱 실패: $value, 오류: $e');
  }
  return null;
}

class ChatMessage {
  final int? id;
  final String sender;
  final String message;
  final DateTime createTime;
  final String roomName;

  ChatMessage({
    this.id,
    required this.sender,
    required this.message,
    required this.createTime,
    required this.roomName,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      sender: json['sender'] ?? '',
      message: json['message'] ?? '',
      createTime: parseServerDateTime(json['createTime']) ?? DateTime.now(),
      roomName: json['roomName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'message': message,
      'createTime': createTime.toIso8601String(),
      'roomName': roomName,
    };
  }
}

// 요약 항목
class SummaryItem {
  final int summaryId;
  final String summaryName;
  final String summaryMessage;
  final String? summaryDetailMessage; // 상세 요약 메시지
  final DateTime? summaryFrom;
  final DateTime? summaryTo;

  SummaryItem({
    required this.summaryId,
    required this.summaryName,
    required this.summaryMessage,
    this.summaryDetailMessage,
    this.summaryFrom,
    this.summaryTo,
  });

  factory SummaryItem.fromJson(Map<String, dynamic> json) {
    return SummaryItem(
      summaryId: json['summaryId'] ?? 0,
      summaryName: json['summaryName'] ?? '',
      summaryMessage: json['summaryMessage'] ?? '',
      summaryDetailMessage: json['summaryDetailMessage'],
      summaryFrom: parseServerDateTime(json['summaryFrom']),
      summaryTo: parseServerDateTime(json['summaryTo']),
    );
  }
}

// 대화방 상세 응답 (요약 목록 포함, 페이지네이션 지원)
class RoomDetailResponse {
  final int roomId;
  final String roomName;
  final List<SummaryItem> summaries;
  // 페이지네이션 정보
  final int page;
  final int size;
  final int totalCount;
  final int totalPages;
  final bool hasMore;

  RoomDetailResponse({
    required this.roomId,
    required this.roomName,
    required this.summaries,
    this.page = 0,
    this.size = 50,
    this.totalCount = 0,
    this.totalPages = 0,
    this.hasMore = false,
  });

  factory RoomDetailResponse.fromJson(Map<String, dynamic> json) {
    return RoomDetailResponse(
      roomId: json['roomId'] ?? 0,
      roomName: json['roomName'] ?? '',
      summaries: (json['summaries'] as List<dynamic>?)
              ?.map((e) => SummaryItem.fromJson(e))
              .toList() ??
          [],
      page: json['page'] ?? 0,
      size: json['size'] ?? 50,
      totalCount: json['totalCount'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      hasMore: json['hasMore'] ?? false,
    );
  }
}

// 메시지 항목
class MessageItem {
  final int messageId;
  final String sender;
  final String message;
  final DateTime createTime;
  final String? imagePath; // 이미지 경로 (있을 경우)
  final bool isLinkMessage; // 링크 메시지 여부

  MessageItem({
    required this.messageId,
    required this.sender,
    required this.message,
    required this.createTime,
    this.imagePath,
    this.isLinkMessage = false,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    String messageText = json['message'] ?? '';
    String? imagePath;
    bool isLinkMessage = false;
    
    // 메시지에서 링크 메시지 패턴 추출 [LINK:이미지경로]원본메시지 형식
    final linkPattern = RegExp(r'\[LINK:(.+?)\](.+)');
    final linkMatch = linkPattern.firstMatch(messageText);
    if (linkMatch != null) {
      imagePath = linkMatch.group(1);
      messageText = linkMatch.group(2) ?? '';
      isLinkMessage = true;
    } else {
      // 메시지에서 이미지 경로 추출 [IMAGE:경로] 형식
      final imagePattern = RegExp(r'\[IMAGE:(.+?)\]');
      final match = imagePattern.firstMatch(messageText);
      if (match != null) {
        imagePath = match.group(1);
        // 메시지에서 이미지 마커 제거
        messageText = messageText.replaceAll(imagePattern, '').trim();
      }
    }
    
    // 이미지가 있을 때는 시스템 메시지("사진을 보냈습니다" 등) 필터링
    if (messageText.isNotEmpty) {
      final systemMessagePatterns = [
        RegExp(r'사진을 보냈습니다\.?', caseSensitive: false),
        RegExp(r'사진을?\s*보냈?습니다?\.?', caseSensitive: false),
        RegExp(r'이미지를?\s*보냈?습니다?\.?', caseSensitive: false),
        RegExp(r'이모티콘을 보냈습니다\.?', caseSensitive: false),
        RegExp(r'이모티콘을?\s*보냈?습니다?\.?', caseSensitive: false),
        RegExp(r'스티커를 보냈습니다\.?', caseSensitive: false),
        RegExp(r'스티커를?\s*보냈?습니다?\.?', caseSensitive: false),
      ];
      
      bool isSystemMessage = false;
      for (final pattern in systemMessagePatterns) {
        if (pattern.hasMatch(messageText)) {
          isSystemMessage = true;
          break;
        }
      }
      
      if (isSystemMessage) {
        messageText = ''; // 시스템 메시지 제거
      }
    }
    
    // 메시지가 비어있으면 원본 메시지에서 이모티콘/스티커 여부 확인
    if (messageText.isEmpty) {
      final originalMessage = json['message'] ?? '';
      final isEmojiOrSticker = originalMessage.contains('이모티콘') || 
                               originalMessage.contains('스티커');
      messageText = isEmojiOrSticker ? '이모티콘을 보냈습니다' : '사진을 보냈습니다';
    }
    
    return MessageItem(
      messageId: json['messageId'] ?? 0,
      sender: json['sender'] ?? '',
      message: messageText,
      createTime: parseServerDateTime(json['createTime']) ?? DateTime.now(),
      imagePath: imagePath,
      isLinkMessage: isLinkMessage,
    );
  }
}

// 대화방 메시지 목록 응답 (페이지네이션 지원)
class RoomMessagesResponse {
  final int roomId;
  final String roomName;
  final List<MessageItem> messages;
  final int page;
  final int size;
  final int totalCount;
  final int totalPages;
  final bool hasMore;

  RoomMessagesResponse({
    required this.roomId,
    required this.roomName,
    required this.messages,
    this.page = 0,
    this.size = 50,
    this.totalCount = 0,
    this.totalPages = 0,
    this.hasMore = false,
  });

  factory RoomMessagesResponse.fromJson(Map<String, dynamic> json) {
    return RoomMessagesResponse(
      roomId: json['roomId'] ?? 0,
      roomName: json['roomName'] ?? '',
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => MessageItem.fromJson(e))
              .toList() ??
          [],
      page: json['page'] ?? 0,
      size: json['size'] ?? 50,
      totalCount: json['totalCount'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      hasMore: json['hasMore'] ?? false,
    );
  }
}
