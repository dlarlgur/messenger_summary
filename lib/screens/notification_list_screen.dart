import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/local_db_service.dart';
import 'summary_history_screen.dart';
import 'chat_room_detail_screen.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final LocalDbService _localDb = LocalDbService();
  static const MethodChannel _methodChannel = MethodChannel('com.example.chat_llm/notification');
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _markAllAsReadAndUpdateBadge();
  }

  /// 모든 알림을 읽음 처리하고 배지 업데이트
  Future<void> _markAllAsReadAndUpdateBadge() async {
    try {
      // 모든 알림을 읽음 처리
      await _localDb.markAllNotificationsAsRead();
      
      // 배지 업데이트 (0으로 설정)
      await _updateBadge(0);
    } catch (e) {
      debugPrint('알림 읽음 처리 실패: $e');
    }
  }

  /// 배지 업데이트
  Future<void> _updateBadge(int count) async {
    try {
      await _methodChannel.invokeMethod('updateNotificationBadge', {'count': count});
    } catch (e) {
      debugPrint('배지 업데이트 실패: $e');
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 자동요약 알림만 조회
      final notifications = await _localDb.getNotifications(autoSummaryOnly: true);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('알림 목록 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(int postTime) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(postTime);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '방금 전';
        }
        return '${difference.inMinutes}분 전';
      }
      return '${difference.inHours}시간 전';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return DateFormat('yyyy.MM.dd').format(dateTime);
    }
  }

  String _getPackageAlias(String packageName) {
    switch (packageName) {
      case 'com.kakao.talk':
        return '카카오톡';
      default:
        return packageName;
    }
  }

  Future<void> _deleteNotification(int id) async {
    final success = await _localDb.deleteNotification(id);
    if (success && mounted) {
      _loadNotifications();
      // 배지 업데이트
      final unreadCount = await _localDb.getUnreadNotificationCount();
      await _updateBadge(unreadCount);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('알림이 삭제되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모든 알림 삭제'),
        content: const Text('모든 알림을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _localDb.deleteAllNotifications();
      if (success && mounted) {
        _loadNotifications();
        // 배지 업데이트 (0으로 설정)
        await _updateBadge(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 알림이 삭제되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: const Text(
          '자동 요약 알림',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _deleteAllNotifications,
              tooltip: '모두 삭제',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '저장된 자동 요약 알림이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final packageName = notification['package_name'] as String? ?? '';
                      final sender = notification['sender'] as String? ?? '';
                      final message = notification['message'] as String? ?? '';
                      final roomName = notification['room_name'] as String? ?? '';
                      final postTime = notification['post_time'] as int? ?? 0;
                      final id = notification['id'] as int? ?? 0;
                      final isRead = (notification['is_read'] as int? ?? 0) == 1;

                      // roomName에서 패키지명 제거 (예: "com.example.chat_llm 테스트방" → "테스트방")
                      String displayRoomName = roomName;
                      if (roomName.startsWith('com.') && roomName.contains(' ')) {
                        displayRoomName = roomName.substring(roomName.indexOf(' ') + 1);
                      }

                      return Dismissible(
                        key: Key('notification_$id'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (direction) {
                          _deleteNotification(id);
                        },
                        child: InkWell(
                          onTap: () async {
                            // summaryId가 있으면 요약 히스토리로 이동
                            final summaryId = notification['summary_id'] as int?;
                            if (summaryId != null && summaryId > 0) {
                              // summaryId로 roomId 찾기
                              final roomId = await _localDb.getRoomIdBySummaryId(summaryId);
                              if (roomId != null) {
                                // roomId로 채팅방 정보 가져오기
                                final room = await _localDb.getRoomById(roomId);
                                if (room != null && mounted) {
                                  // 요약 히스토리 화면으로 이동
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => SummaryHistoryScreen(
                                        roomId: roomId,
                                        roomName: room.roomName,
                                        initialSummaryId: summaryId,
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }
                            }
                            
                            // summaryId가 없거나 찾을 수 없으면 채팅방으로 이동 시도
                            final room = await _localDb.findRoom(roomName, packageName);
                            if (room != null && mounted) {
                              // 채팅방 상세 화면으로 이동
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ChatRoomDetailScreen(room: room),
                                ),
                              );
                            } else if (mounted) {
                              // 채팅방을 찾을 수 없으면 메시지 표시
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('해당 요약을 찾을 수 없습니다.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              // 읽음/안읽음에 따라 배경색 구분
                              color: isRead ? Colors.grey[50] : const Color(0xFF2196F3).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isRead ? Colors.grey[200]! : const Color(0xFF2196F3).withOpacity(0.3),
                                width: isRead ? 1 : 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        // 안읽음 표시 점
                                        if (!isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(right: 8),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF2196F3),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        // 채팅방 이름
                                        Flexible(
                                          child: Text(
                                            displayRoomName.isNotEmpty ? displayRoomName : '알 수 없는 채팅방',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                                              color: const Color(0xFF2A2A2A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatTime(postTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isRead ? Colors.grey[600] : const Color(0xFF2A2A2A),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                    },
                  ),
                ),
    );
  }
}
