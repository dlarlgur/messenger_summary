import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/chat_room.dart';
import '../services/local_db_service.dart';
import '../services/notification_settings_service.dart';
import '../services/profile_image_service.dart';
import '../services/auth_service.dart';
import '../services/plan_service.dart';
import 'chat_room_detail_screen.dart';
import 'blocked_rooms_screen.dart';
import 'notification_list_screen.dart';
import 'usage_management_screen.dart';
import 'app_settings_screen.dart';
import 'subscription_screen.dart';

/// 사선을 그리는 CustomPainter
class SlashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ChatRoomListScreen extends StatefulWidget {
  const ChatRoomListScreen({super.key});

  @override
  State<ChatRoomListScreen> createState() => ChatRoomListScreenState();
}

class ChatRoomListScreenState extends State<ChatRoomListScreen> with WidgetsBindingObserver {
  final LocalDbService _localDb = LocalDbService();
  final ProfileImageService _profileService = ProfileImageService();
  final PlanService _planService = PlanService();
  List<ChatRoom> _chatRooms = [];
  bool _isLoading = true;
  String? _error;
  // roomId -> 최신 메시지 텍스트 (내가 보낸 메시지가 최신이면 그것, 아니면 lastMessage)
  final Map<int, String> _lastMessageCache = {};

  // 패키지별 필터링
  String? _selectedPackageName;

  // 설정 버튼 클릭 카운터 (5번 누르면 플랜 선택)
  int _settingsClickCount = 0;
  DateTime? _lastSettingsClickTime;
  
  // 플랜 타입 캐시
  String? _cachedPlanType;
  
  // ✅ 핵심 수정: EventChannel 대신 DB Observer 사용
  // Native에서 DB에 저장 → Flutter가 주기적으로 DB 확인
  Timer? _dbObserverTimer;
  DateTime? _lastCheckTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initProfileService();
    _loadChatRooms();
    _startDbObserver(); // ✅ 핵심 수정: DB Observer 시작 (EventChannel 대신)
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 포그라운드로 돌아올 때 대화목록 자동 새로고침 및 DB Observer 재시작
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 ChatRoomListScreen: 앱 포그라운드 복귀 - 대화목록 새로고침 및 DB Observer 재시작');
      _loadChatRooms();
      // ✅ 핵심 수정: 포그라운드 복귀 시 DB Observer 재시작
      _startDbObserver();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dbObserverTimer?.cancel(); // ✅ 핵심 수정: DB Observer 중지
    super.dispose();
  }
  
  /// ✅ 핵심 수정: DB Observer 시작 (EventChannel 대신)
  /// Native에서 DB에 저장 → Flutter가 주기적으로 DB 확인
  void _startDbObserver() {
    _dbObserverTimer?.cancel();
    _lastCheckTime = DateTime.now();
    
    // 1초마다 DB 변경 확인
    _dbObserverTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkDbChanges();
    });
    
    debugPrint('✅ DB Observer 시작 (1초마다 확인)');
  }
  
  /// ✅ 핵심: DB 변경 확인 (updated_at 기준)
  Future<void> _checkDbChanges() async {
    try {
      final db = await _localDb.database;
      
      // 마지막 확인 시간 이후 업데이트된 채팅방 확인
      final lastCheckTimestamp = _lastCheckTime?.millisecondsSinceEpoch ?? 0;
      
      final updatedRooms = await db.query(
        'chat_rooms',
        columns: ['id', 'updated_at'],
        where: 'updated_at > ?',
        whereArgs: [lastCheckTimestamp],
      );
      
      if (updatedRooms.isNotEmpty) {
        debugPrint('🔄 DB 변경 감지: ${updatedRooms.length}개 채팅방 업데이트됨');
        // 변경이 있으면 목록 새로고침
        await _loadChatRooms(silent: true);
      }
      
      _lastCheckTime = DateTime.now();
    } catch (e) {
      debugPrint('❌ DB 변경 확인 실패: $e');
    }
  }

  /// 프로필 이미지 서비스 초기화
  Future<void> _initProfileService() async {
    try {
      await _profileService.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('프로필 서비스 초기화 실패: $e');
    }
  }

  /// 대화방의 프로필 이미지 파일 가져오기
  File? _getProfileImageFile(String roomName) {
    return _profileService.getRoomProfile(roomName);
  }

  /// 외부에서 호출 가능한 채팅방 목록 새로고침
  void refreshRooms() {
    debugPrint('🔄 refreshRooms() 호출됨 - 대화방 목록 새로고침');
    // 즉시 실행하여 빠른 동기화 보장
    if (mounted) {
      _loadChatRooms(silent: true);
    } else {
      debugPrint('⚠️ 위젯이 dispose됨 - refreshRooms() 스킵');
    }
  }

  /// 외부에서 호출 가능한 채팅방 업데이트 메서드
  void updateRoom(Map<String, dynamic> data) {
    final roomName = data['roomName'] as String? ?? '';

    // 프로필 이미지 캐시 무효화
    _profileService.invalidateRoomProfile(roomName);

    // 목록 새로고침
    _loadChatRooms();
  }

  Future<void> _loadChatRooms({bool silent = false}) async {
    // ⚠️ 보수적 수정: silent 모드에서도 로그 출력 (대화목록 동기화 문제 디버깅용)
    if (silent) {
      debugPrint('🔄 _loadChatRooms(silent=true) 호출됨 - 대화방 목록 새로고침');
    }
    
    if (!silent) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
          _profileService.clearCache();
        });
      }
    }

    try {
      final rooms = await _localDb.getChatRooms();
      debugPrint('📋 DB에서 ${rooms.length}개 대화방 조회 완료');
      
      // 각 채팅방의 최신 메시지 확인 (내가 보낸 메시지가 최신이면 그것을 표시)
      final messageCache = <int, String>{};
      for (final room in rooms) {
        try {
          final latestMessage = await _localDb.getLatestMessage(room.id);
          if (latestMessage != null) {
            final latestSender = latestMessage['sender'] as String;
            final latestMsg = latestMessage['message'] as String;
            
            // 최신 메시지가 내가 보낸 메시지면 그것을 표시
            if (latestSender == '나') {
              messageCache[room.id] = _formatMessageText(latestMsg);
            } else {
              // 최신 메시지가 내가 보낸 것이 아니면 room.lastMessage 표시
              messageCache[room.id] = _formatMessageText(room.lastMessage);
            }
          } else {
            // 최신 메시지가 없으면 room.lastMessage 표시
            messageCache[room.id] = _formatMessageText(room.lastMessage);
          }
        } catch (e) {
          debugPrint('최신 메시지 조회 실패 (roomId: ${room.id}): $e');
          messageCache[room.id] = _formatMessageText(room.lastMessage);
        }
      }
      
      if (!mounted) {
        debugPrint('⚠️ 위젯이 dispose됨 - UI 업데이트 스킵');
        return;
      }
      
      // silent 모드에서도 항상 업데이트하여 새 메시지 반영 보장
      final beforeCount = _chatRooms.length;
      setState(() {
        _chatRooms = rooms;
        _lastMessageCache.clear();
        _lastMessageCache.addAll(messageCache);
        _sortChatRooms(); // 정렬도 함께 수행
        // silent 모드에서도 로딩 상태를 false로 설정하여 UI가 업데이트되도록 함
        _isLoading = false;
      });
      
      // ⚠️ 보수적 수정: silent 모드에서도 로그 출력 (대화목록 동기화 확인용)
      if (silent) {
        debugPrint('✅ 대화방 목록 새로고침 완료: 이전 ${beforeCount}개 → 현재 ${_chatRooms.length}개 대화방');
        if (_chatRooms.isNotEmpty) {
          final latestRoom = _chatRooms.first;
          final lastMsg = latestRoom.lastMessage ?? '';
          final truncatedMsg = lastMsg.length > 30 ? '${lastMsg.substring(0, 30)}...' : lastMsg;
          debugPrint('   최신 대화방: ${latestRoom.roomName}, 마지막 메시지: $truncatedMsg, 읽지않음: ${latestRoom.unreadCount}');
        }
      } else {
        debugPrint('✅ UI 업데이트 완료: ${_chatRooms.length}개 대화방 표시');
      }
    } catch (e) {
      debugPrint('❌ 대화방 목록 로드 실패: $e');
      if (mounted) {
        setState(() {
          if (!silent) {
            _error = '대화방 목록을 불러오는데 실패했습니다.';
          }
          // silent 모드에서도 로딩 상태를 false로 설정
          _isLoading = false;
        });
      }
    }
  }

  void _showRoomContextMenu(BuildContext context, ChatRoom room) async {
    final notificationService =
        Provider.of<NotificationSettingsService>(context, listen: false);
    final isMuted = notificationService.isMuted(room.roomName);
    
    // 플랜 타입 확인 (베이직 플랜일 때만 자동 요약 설정 표시)
    final planType = await _planService.getCurrentPlanType();
    final isBasicPlan = planType == 'basic';

    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 대화방 이름
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  room.roomName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              // AI 요약 기능 켜기/끄기
              _buildMenuItem(
                icon: room.summaryEnabled ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                title: room.summaryEnabled ? 'AI 요약 기능 끄기' : 'AI 요약 기능 켜기',
                subtitle: room.summaryEnabled ? '요약 기능이 활성화되어 있습니다' : '요약 기능이 비활성화되어 있습니다',
                isEnabled: room.summaryEnabled,
                iconColor: room.summaryEnabled ? const Color(0xFF2196F3) : null,
                onTap: () async {
                  Navigator.pop(context);
                  await _toggleSummaryEnabled(room);
                },
              ),
              // 채팅방 상단 고정
              _buildMenuItem(
                icon: room.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                title: room.pinned ? '채팅방 고정 해제' : '채팅방 상단 고정',
                isEnabled: room.pinned,
                iconColor: room.pinned ? const Color(0xFF2196F3) : null,
                onTap: () async {
                  Navigator.pop(context);
                  await _togglePinned(room);
                },
              ),
              // 알림 켜기/끄기
              _buildMenuItem(
                icon: isMuted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
                title: isMuted ? '채팅방 알림 켜기' : '채팅방 알림 끄기',
                isEnabled: !isMuted,
                iconColor: !isMuted ? const Color(0xFF2196F3) : null,
                onTap: () async {
                  Navigator.pop(context);
                  await notificationService.toggleNotification(room.roomName);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isMuted
                              ? '${room.roomName} 알림이 켜졌습니다.'
                              : '${room.roomName} 알림이 꺼졌습니다.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              // 자동요약기능설정 (베이직 플랜 전용 - 베이직일 때만 표시)
              if (isBasicPlan)
                _buildMenuItem(
                  icon: Icons.schedule,
                  title: '자동요약기능설정',
                  subtitle: room.autoSummaryEnabled 
                      ? '${room.autoSummaryMessageCount}개 메시지 도달 시 자동 요약'
                      : '베이직 플랜 전용',
                  isEnabled: room.autoSummaryEnabled,
                  iconColor: room.autoSummaryEnabled ? const Color(0xFF2196F3) : null,
                  onTap: () {
                    Navigator.pop(context);
                    // 요약 관리 페이지로 이동 (해당 채팅방으로 스크롤)
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UsageManagementScreen(initialRoomId: room.id),
                      ),
                    );
                  },
                ),
              // 대화방 차단
              _buildMenuItem(
                icon: Icons.block,
                title: '채팅방 차단',
                textColor: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showBlockConfirmDialog(room);
                },
              ),
              // 대화방 삭제
              _buildMenuItem(
                icon: Icons.delete_outline,
                title: '대화방 삭제',
                textColor: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(room);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// 설정 메뉴 표시
  void _showSettingsMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 모두 읽음 처리
            InkWell(
              onTap: () async {
                Navigator.pop(context);
                await _markAllAsRead();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: const Text(
                  '모두 읽음 처리',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // 구분선
            Divider(height: 1, color: Colors.grey[200]),
            // 앱 설정
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AppSettingsScreen(),
                  ),
                ).then((_) {
                  _loadChatRooms();
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: const Text(
                  '앱 설정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 모든 채팅방 읽음 처리
  Future<void> _markAllAsRead() async {
    try {
      await _localDb.markAllRoomsAsRead();
      if (mounted) {
        setState(() {
          // 모든 채팅방의 unreadCount를 0으로 업데이트
          for (var i = 0; i < _chatRooms.length; i++) {
            _chatRooms[i] = _chatRooms[i].copyWith(unreadCount: 0);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 채팅방이 읽음 처리되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('모두 읽음 처리 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('읽음 처리에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// AI 요약 기능 토글
  Future<void> _toggleSummaryEnabled(ChatRoom room) async {
    final newSummaryEnabled = !room.summaryEnabled;
    final result = await _localDb.updateRoomSettings(room.id, summaryEnabled: newSummaryEnabled);

    if (result != null && mounted) {
      setState(() {
        final index = _chatRooms.indexWhere((r) => r.id == room.id);
        if (index >= 0) {
          _chatRooms[index] = room.copyWith(summaryEnabled: newSummaryEnabled);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newSummaryEnabled
              ? '✨ AI 요약 기능이 켜졌습니다.'
              : 'AI 요약 기능이 꺼졌습니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('요약 기능 설정 변경에 실패했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 채팅방 상단 고정 토글
  Future<void> _togglePinned(ChatRoom room) async {
    final newPinned = !room.pinned;
    final result = await _localDb.updateRoomSettings(room.id, pinned: newPinned);

    if (result != null && mounted) {
      setState(() {
        final index = _chatRooms.indexWhere((r) => r.id == room.id);
        if (index >= 0) {
          _chatRooms[index] = room.copyWith(pinned: newPinned);
          _sortChatRooms();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newPinned ? '상단에 고정되었습니다.' : '고정이 해제되었습니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 채팅방 목록 정렬 (고정 우선, 최신 메시지 순)
  void _sortChatRooms() {
    _chatRooms.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? textColor,
    bool? isEnabled,
    Color? iconColor,
  }) {
    // 아이콘 색상 결정: iconColor가 지정되면 사용, 없으면 isEnabled에 따라 파란색 또는 기본색
    final finalIconColor = iconColor ?? (isEnabled == true ? const Color(0xFF2196F3) : (textColor ?? Colors.black87));
    
    return ListTile(
      leading: Icon(icon, color: finalIconColor),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildMenuItemWithCustomIcon({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? textColor,
    bool? isEnabled,
    Color? iconColor,
    bool showSlash = false,
  }) {
    // 아이콘 색상 결정: iconColor가 지정되면 사용, 없으면 isEnabled에 따라 파란색 또는 기본색
    final finalIconColor = iconColor ?? (isEnabled == true ? const Color(0xFF2196F3) : (textColor ?? Colors.black87));
    
    return ListTile(
      leading: showSlash
          ? Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: finalIconColor),
                CustomPaint(
                  size: const Size(24, 24),
                  painter: SlashPainter(),
                ),
              ],
            )
          : Icon(icon, color: finalIconColor),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  /// 대화방 차단 확인 다이얼로그
  void _showBlockConfirmDialog(ChatRoom room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('채팅방 차단'),
        content: Text('${room.roomName}을(를) 차단하시겠습니까?\n\n차단된 채팅방은 목록에서 숨겨지고,\n새 메시지도 저장되지 않습니다.\n\n설정 > 차단방 관리에서 해제할 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _blockRoom(room);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('차단'),
          ),
        ],
      ),
    );
  }

  /// 대화방 차단
  Future<void> _blockRoom(ChatRoom room) async {
    final result = await _localDb.updateRoomSettings(room.id, blocked: true);

    if (result != null && mounted) {
      setState(() {
        _chatRooms.removeWhere((r) => r.id == room.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${room.roomName} 채팅방이 차단되었습니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('채팅방 차단에 실패했습니다.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 대화방 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(ChatRoom room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('대화방 삭제'),
        content: const Text('메시지, 요약 전부 사라집니다.\n정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _localDb.deleteRoom(room.id);
              if (!mounted) return;

              if (success) {
                setState(() {
                  _chatRooms.removeWhere((r) => r.id == room.id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${room.roomName} 대화방이 삭제되었습니다.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('대화방 삭제에 실패했습니다.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 마지막 메시지 포맷팅 (캐시에서 가져오기)
  String _formatLastMessage(ChatRoom room) {
    return _lastMessageCache[room.id] ?? _formatMessageText(room.lastMessage);
  }
  
  /// 메시지 텍스트 포맷팅 (공통 로직)
  String _formatMessageText(String? message) {
    if (message == null || message.isEmpty) return '';
    
    // [IMAGE:경로] 패턴 제거
    final imagePattern = RegExp(r'\[IMAGE:(.+?)\]');
    final hasImage = imagePattern.hasMatch(message);
    String formattedMessage = message.replaceAll(imagePattern, '').trim();
    
    // 이미지만 있고 텍스트가 없으면 원본 메시지에서 이모티콘/스티커 여부 확인
    if (formattedMessage.isEmpty && hasImage) {
      final isEmojiOrSticker = message.contains('이모티콘') || message.contains('스티커');
      return isEmojiOrSticker ? '이모티콘을 보냈습니다' : '사진을 보냈습니다';
    }
    
    // 이미지와 텍스트가 모두 있으면 텍스트만 반환
    return formattedMessage;
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return DateFormat('a h:mm', 'ko_KR').format(time);
    } else if (diff.inDays == 1) {
      return '어제';
    } else if (diff.inDays < 7) {
      return DateFormat('E', 'ko_KR').format(time);
    } else {
      return DateFormat('M월 d일').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationSettingsService>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: GestureDetector(
          onTap: _handleTitleClick,
          child: const Text(
            'AI 톡비서',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationListScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.white),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: (value) async {
              if (value == 'mark_all_read') {
                await _markAllAsRead();
              } else if (value == 'app_settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AppSettingsScreen(),
                  ),
                ).then((_) {
                  _loadChatRooms();
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'mark_all_read',
                child: Text('모두 읽음 처리'),
              ),
              const PopupMenuItem<String>(
                value: 'app_settings',
                child: Text('앱 설정'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 패키지별 탭 필터
          _buildPackageTabs(),
          // 채팅방 목록
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadChatRooms,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      )
                    : _getFilteredRooms().isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 80, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text(
                                  '대화방이 없습니다',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedPackageName != null
                                      ? '${_getPackageDisplayName(_selectedPackageName!)} 대화방이 없습니다'
                                      : '알림을 수신하면 대화방이 생성됩니다',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadChatRooms,
                            color: const Color(0xFF2196F3),
                            child: ListView.builder(
                              itemCount: _getFilteredRooms().length,
                              itemBuilder: (context, index) {
                                final room = _getFilteredRooms()[index];
                                final isMuted =
                                    notificationService.isMuted(room.roomName);

                                return InkWell(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ChatRoomDetailScreen(room: room),
                                      ),
                                    );
                                    if (result == true) {
                                      // 대화방 삭제
                                      setState(() {
                                        _chatRooms.removeWhere((r) => r.id == room.id);
                                      });
                                    } else if (result is Map) {
                                      // 특정 속성 업데이트
                                      setState(() {
                                        final index = _chatRooms.indexWhere((r) => r.id == room.id);
                                        if (index >= 0) {
                                          if (result['pinned'] != null) {
                                            _chatRooms[index] = room.copyWith(pinned: result['pinned']);
                                          }
                                          if (result['summaryEnabled'] != null) {
                                            _chatRooms[index] = room.copyWith(summaryEnabled: result['summaryEnabled']);
                                          }
                                          _sortChatRooms();
                                        }
                                      });
                                    }
                                    // ✅ 핵심 수정: 상세화면에서 나올 때 무조건 새로고침하여 읽음 상태 등 최신 정보 반영
                                    debugPrint('🔄 상세화면에서 복귀 - 대화목록 새로고침 및 DB Observer 재시작');
                                    _loadChatRooms(silent: true);
                                    // ✅ 핵심 수정: DB Observer 재시작 (EventChannel 대신)
                                    _startDbObserver();
                                  },
                                  onLongPress: () => _showRoomContextMenu(context, room),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey[200]!,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // 프로필 이미지
                                        Stack(
                                          children: [
                                            Builder(
                                              builder: (context) {
                                                final profileFile = _getProfileImageFile(room.roomName);
                                                ImageProvider? bgImage;
                                                if (profileFile != null) {
                                                  bgImage = FileImage(profileFile);
                                                } else if (room.profileImageUrl != null) {
                                                  bgImage = NetworkImage(room.profileImageUrl!);
                                                }
                                                return CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor: const Color(0xFF64B5F6),
                                                  backgroundImage: bgImage,
                                                  child: bgImage == null
                                                      ? Text(
                                                          room.roomName.isNotEmpty
                                                              ? room.roomName[0]
                                                              : '?',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 20,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        )
                                                      : null,
                                                );
                                              },
                                            ),
                                            if (room.participantCount > 2)
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[700],
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    '${room.participantCount}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 12),
                                        // 채팅방 정보
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      room.roomName,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        height: 1.2,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (room.pinned)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(left: 4),
                                                      child: Icon(
                                                        Icons.push_pin,
                                                        size: 14,
                                                        color: const Color(0xFF2196F3),
                                                      ),
                                                    ),
                                                  if (room.summaryEnabled)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(left: 4),
                                                      child: Stack(
                                                        clipBehavior: Clip.none,
                                                        children: [
                                                          Icon(
                                                            Icons.auto_awesome,
                                                            size: 16,
                                                            color: Colors.amber[600],
                                                          ),
                                                          if (room.autoSummaryEnabled)
                                                            Positioned(
                                                              right: -4,
                                                              top: -4,
                                                              child: Container(
                                                                width: 10,
                                                                height: 10,
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFF2196F3),
                                                                  shape: BoxShape.circle,
                                                                  border: Border.all(
                                                                    color: Colors.white,
                                                                    width: 1.5,
                                                                  ),
                                                                ),
                                                                child: const Center(
                                                                  child: Text(
                                                                    'A',
                                                                    style: TextStyle(
                                                                      color: Colors.white,
                                                                      fontSize: 7,
                                                                      fontWeight: FontWeight.w800,
                                                                      height: 1.0,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (isMuted)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(left: 4),
                                                      child: Icon(
                                                        Icons.notifications_off,
                                                        size: 16,
                                                        color: Colors.grey[400],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatLastMessage(room),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                softWrap: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // 시간 및 읽지 않은 메시지 수
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _formatTime(room.lastMessageTime),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (room.unreadCount > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF2196F3),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  room.unreadCount > 999
                                                      ? '999+'
                                                      : '${room.unreadCount}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// 패키지별 탭 필터 위젯
  Widget _buildPackageTabs() {
    // 지원 메신저 목록 (하드코딩)
    final tabItems = LocalDbService.supportedMessengers;

    // 탭이 없으면 빈 컨테이너 반환 (1개여도 표시)
    if (tabItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // 선택된 패키지가 없으면 첫 번째 패키지 자동 선택
    if (_selectedPackageName == null && tabItems.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedPackageName == null) {
          setState(() {
            _selectedPackageName = tabItems.first['packageName'];
          });
        }
      });
    }

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tabItems.length,
        itemBuilder: (context, index) {
          final item = tabItems[index];
          final packageName = item['packageName']!;
          final packageAlias = item['alias']!;
          final isSelected = _selectedPackageName == packageName;

          return _buildTabItem(
            packageAlias,
            isSelected,
            () => setState(() => _selectedPackageName = packageName),
            packageName: packageName,
          );
        },
      ),
    );
  }

  /// 탭 아이템 위젯
  Widget _buildTabItem(String label, bool isSelected, VoidCallback onTap, {String? packageName}) {
    // 카카오톡인지 확인
    final isKakaoTalk = packageName == 'com.kakao.talk';
    // 카카오톡 노란색: #FEE500
    final selectedColor = isKakaoTalk ? const Color(0xFFFEE500) : const Color(0xFF2196F3);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 카카오톡 아이콘
              if (isKakaoTalk && isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.chat_bubble,
                    size: 16,
                    color: Colors.black87,
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? (isKakaoTalk ? Colors.black87 : Colors.white)
                      : Colors.black87,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 패키지 이름을 표시 이름으로 변환
  String _getPackageDisplayName(String packageName) {
    final messenger = LocalDbService.supportedMessengers.firstWhere(
      (m) => m['packageName'] == packageName,
      orElse: () => {'alias': '알 수 없음'},
    );
    return messenger['alias'] ?? '알 수 없음';
  }

  /// 필터링된 채팅방 목록 반환
  List<ChatRoom> _getFilteredRooms() {
    if (_selectedPackageName == null) {
      if (LocalDbService.supportedMessengers.isNotEmpty) {
        final firstPackage = LocalDbService.supportedMessengers.first['packageName'];
        if (firstPackage != null) {
          return _chatRooms.where((room) => room.packageName == firstPackage).toList();
        }
      }
      if (_chatRooms.isNotEmpty) {
        final firstPackage = _chatRooms.first.packageName;
        return _chatRooms.where((room) => room.packageName == firstPackage).toList();
      }
      return [];
    }
    return _chatRooms.where((room) => room.packageName == _selectedPackageName).toList();
  }

  /// 타이틀 클릭 처리 (5번 누르면 플랜 선택)
  void _handleTitleClick() {
    final now = DateTime.now();
    
    // 3초 이내에 클릭했는지 확인
    if (_lastSettingsClickTime != null &&
        now.difference(_lastSettingsClickTime!) < const Duration(seconds: 3)) {
      _settingsClickCount++;
    } else {
      // 3초 이상 지났으면 카운터 리셋
      _settingsClickCount = 1;
    }
    
    _lastSettingsClickTime = now;

    debugPrint('⚙️ 설정 버튼 클릭: $_settingsClickCount/5');

    // 5번 누르면 플랜 선택 다이얼로그 표시
    if (_settingsClickCount >= 5) {
      _settingsClickCount = 0; // 카운터 리셋
      _showPlanSelectionDialog();
    }
  }

  /// 플랜 선택 다이얼로그 표시
  Future<void> _showPlanSelectionDialog() async {
    // 테스트 모드인지 확인
    final bool isTestMode = PlanService.isTestMode;
    
    if (isTestMode) {
      // 테스트 모드: 기존 방식 (관리자 API 사용)
      final authService = AuthService();
      final deviceIdHash = await authService.getDeviceIdHash();

      if (deviceIdHash == null || deviceIdHash.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('기기 정보를 가져올 수 없습니다. 앱을 재시작해주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('플랜 선택 (테스트용)'),
          content: const Text(
            '사용할 플랜을 선택하세요.\n\n'
            '• Free: 일 3회, 메시지 최대 100개\n'
            '• Basic: 월 200회, 메시지 최대 300개',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _setPlan(deviceIdHash, 'free');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text('Free'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _setPlan(deviceIdHash, 'basic');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Basic'),
            ),
          ],
        ),
      );
    } else {
      // 상용 모드: 플랜 구독 화면으로 이동
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubscriptionScreen(),
        ),
      );
    }
  }

  /// 플랜 설정
  Future<void> _setPlan(String deviceIdHash, String planType) async {
    if (!mounted) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final planService = PlanService();
      bool success = false;

      if (planType == 'basic') {
        success = await planService.setBasicPlan(deviceIdHash);
      } else {
        success = await planService.setFreePlan(deviceIdHash);
      }

      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('플랜이 ${planType.toUpperCase()}로 설정되었습니다.'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('플랜 설정에 실패했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('플랜 설정 중 오류가 발생했습니다: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
