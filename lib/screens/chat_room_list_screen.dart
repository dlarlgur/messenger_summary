import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/chat_room.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_settings_service.dart';
import '../services/profile_image_service.dart';
import 'chat_room_detail_screen.dart';
import 'consent_screen.dart';
import 'login_screen.dart';
import 'blocked_rooms_screen.dart';

class ChatRoomListScreen extends StatefulWidget {
  const ChatRoomListScreen({super.key});

  @override
  State<ChatRoomListScreen> createState() => ChatRoomListScreenState();
}

class ChatRoomListScreenState extends State<ChatRoomListScreen> {
  final ApiService _apiService = ApiService();
  final ProfileImageService _profileService = ProfileImageService();
  List<ChatRoom> _chatRooms = [];
  bool _isLoading = true;
  String? _error;
  
  // 패키지별 필터링
  String? _selectedPackageName;  // null이면 전체, 'com.kakao.talk'이면 카카오톡만
  
  // 지원 메신저 목록 (서버에서 가져옴)
  List<Map<String, dynamic>> _supportedMessengers = [];

  @override
  void initState() {
    super.initState();
    _initProfileService();
    _loadSupportedMessengers();
    _loadChatRooms();
  }
  
  /// 지원 메신저 목록 로드
  Future<void> _loadSupportedMessengers() async {
    try {
      final messengers = await _apiService.getSupportedMessengers();
      if (mounted) {
        setState(() {
          _supportedMessengers = messengers;
        });
      }
    } catch (e) {
      debugPrint('지원 메신저 목록 로드 실패: $e');
    }
  }

  /// 프로필 이미지 서비스 초기화
  Future<void> _initProfileService() async {
    try {
      await _profileService.initialize();
      // 화면 갱신하여 프로필 이미지 로드
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('프로필 서비스 초기화 실패: $e');
    }
  }

  /// 대화방의 프로필 이미지 파일 가져오기
  File? _getProfileImageFile(String roomName) {
    return _profileService.getRoomProfile(roomName);
  }

  /// 외부에서 호출 가능한 채팅방 업데이트 메서드
  void updateRoom(Map<String, dynamic> data) {
    final roomId = data['roomId'] as int? ?? 0;
    final roomName = data['roomName'] as String? ?? '';

    // 프로필 이미지 캐시 무효화 (새로운 알림에서 이미지가 갱신되었을 수 있음)
    _profileService.invalidateRoomProfile(roomName);
    final unreadCount = data['unreadCount'] as int? ?? 0;
    final lastMessage = data['lastMessage'] as String? ?? '';
    final lastMessageTimeStr = data['lastMessageTime'] as String? ?? '';

    // lastMessageTime 파싱 (서버에서 배열 또는 문자열로 올 수 있음)
    DateTime? lastMessageTime;
    if (lastMessageTimeStr.isNotEmpty) {
      try {
        // 배열 형식 "[2026, 1, 28, 8, 29, 13]" 파싱
        if (lastMessageTimeStr.startsWith('[')) {
          final parts = lastMessageTimeStr
              .replaceAll('[', '')
              .replaceAll(']', '')
              .split(',')
              .map((e) => int.parse(e.trim()))
              .toList();
          if (parts.length >= 3) {
            lastMessageTime = DateTime(
              parts[0],
              parts[1],
              parts[2],
              parts.length > 3 ? parts[3] : 0,
              parts.length > 4 ? parts[4] : 0,
              parts.length > 5 ? parts[5] : 0,
            );
          }
        } else {
          lastMessageTime = DateTime.parse(lastMessageTimeStr);
        }
      } catch (e) {
        debugPrint('lastMessageTime 파싱 실패: $e');
      }
    }

    setState(() {
      // 기존 채팅방 업데이트 또는 새로 추가
      final existingIndex = _chatRooms.indexWhere(
        (r) => r.id == roomId || r.roomName == roomName,
      );

      // 서버 응답에서 pinned, category, summaryEnabled 파싱 (없으면 기존 값 유지)
      final pinned = data['pinned'] as bool? ??
          (existingIndex >= 0 ? _chatRooms[existingIndex].pinned : false);
      final categoryStr = data['category'] as String?;
      final category = categoryStr != null
          ? RoomCategory.fromString(categoryStr)
          : (existingIndex >= 0 ? _chatRooms[existingIndex].category : RoomCategory.DAILY);
      final summaryEnabled = data['summaryEnabled'] as bool? ??
          (existingIndex >= 0 ? _chatRooms[existingIndex].summaryEnabled : true);

      final packageName = data['packageName'] as String? ?? 'com.kakao.talk';
      final packageAlias = data['packageAlias'] as String? ?? 
          (packageName == 'com.kakao.talk' ? '카카오톡' : packageName);
      
      final updatedRoom = ChatRoom(
        id: roomId,
        roomName: roomName,
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        unreadCount: unreadCount,
        pinned: pinned,
        category: category,
        summaryEnabled: summaryEnabled,
        packageName: packageName,
        packageAlias: packageAlias,
      );

      if (existingIndex >= 0) {
        _chatRooms[existingIndex] = updatedRoom;
      } else {
        _chatRooms.insert(0, updatedRoom);
      }

      // 고정 우선, 최신 메시지 순으로 정렬
      _sortChatRooms();
    });

    debugPrint('채팅방 목록 업데이트 완료: $roomName');
  }

  Future<void> _loadChatRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
      // 프로필 이미지 메모리 캐시 클리어 (새로운 이미지 반영)
      _profileService.clearCache();
    });

    try {
      final rooms = await _apiService.getChatRooms();
      setState(() {
        _chatRooms = rooms;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      // 인증 실패 - 로그인 화면으로 이동
      debugPrint('인증 실패: $e');
      if (mounted) {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.logout();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } on ConsentRequiredException catch (e) {
      // 동의 필요 - 동의 화면으로 이동
      debugPrint('동의 필요: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ConsentScreen(
              onConsentComplete: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ChatRoomListScreen()),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = '대화방 목록을 불러오는데 실패했습니다.';
        _isLoading = false;
      });
    }
  }

  void _showRoomContextMenu(BuildContext context, ChatRoom room) {
    final notificationService =
        Provider.of<NotificationSettingsService>(context, listen: false);
    final isMuted = notificationService.isMuted(room.roomName);

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
                onTap: () async {
                  Navigator.pop(context);
                  await _toggleSummaryEnabled(room);
                },
              ),
              // 채팅방 요약 설정
              _buildMenuItem(
                icon: Icons.summarize_outlined,
                title: '채팅방 요약 설정',
                subtitle: '${room.category.emoji} ${room.category.displayName}',
                onTap: () {
                  Navigator.pop(context);
                  _showCategorySelectorDialog(room);
                },
              ),
              // 채팅방 상단 고정
              _buildMenuItem(
                icon: room.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                title: room.pinned ? '채팅방 고정 해제' : '채팅방 상단 고정',
                onTap: () async {
                  Navigator.pop(context);
                  await _togglePinned(room);
                },
              ),
              // 알림 켜기/끄기
              _buildMenuItem(
                icon: isMuted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                title: isMuted ? '채팅방 알림 켜기' : '채팅방 알림 끄기',
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

  /// AI 요약 기능 토글
  Future<void> _toggleSummaryEnabled(ChatRoom room) async {
    final newSummaryEnabled = !room.summaryEnabled;
    final result = await _apiService.updateRoomSettings(room.id, summaryEnabled: newSummaryEnabled);

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
    final result = await _apiService.updateRoomSettings(room.id, pinned: newPinned);

    if (result != null && mounted) {
      setState(() {
        final index = _chatRooms.indexWhere((r) => r.id == room.id);
        if (index >= 0) {
          _chatRooms[index] = room.copyWith(pinned: newPinned);
          // 고정 우선 정렬
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
      // 고정된 방 우선
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      // 최신 메시지 순
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
  }

  /// 채팅방 요약 카테고리 선택 다이얼로그
  void _showCategorySelectorDialog(ChatRoom room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
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
            // 헤더
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    '이 채팅방은 어떤 방인가요?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '카테고리에 따라 요약 방식이 달라집니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 카테고리 목록
            Expanded(
              child: ListView.builder(
                itemCount: RoomCategory.values.length,
                itemBuilder: (context, index) {
                  final category = RoomCategory.values[index];
                  final isSelected = room.category == category;
                  return ListTile(
                    leading: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      category.displayName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF2196F3) : Colors.black87,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFF2196F3))
                        : null,
                    onTap: () async {
                      Navigator.pop(context);
                      await _updateCategory(room, category);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 채팅방 카테고리 업데이트
  Future<void> _updateCategory(ChatRoom room, RoomCategory category) async {
    if (room.category == category) return;

    final result = await _apiService.updateRoomSettings(room.id, category: category.name);

    if (result != null && mounted) {
      setState(() {
        final index = _chatRooms.indexWhere((r) => r.id == room.id);
        if (index >= 0) {
          _chatRooms[index] = room.copyWith(category: category);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('요약 설정이 "${category.emoji} ${category.displayName}"으로 변경되었습니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.black87),
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
    final result = await _apiService.updateRoomSettings(room.id, blocked: true);

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
              final success = await _apiService.deleteRoom(room.id);
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
    final authService = Provider.of<AuthService>(context);
    final notificationService = Provider.of<NotificationSettingsService>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: const Text(
          '채팅',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // TODO: 검색 기능
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
            onPressed: () {
              // TODO: 새 채팅
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'logout') {
                await authService.logout();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              } else if (value == 'blocked_rooms') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BlockedRoomsScreen()),
                ).then((_) {
                  // 차단 해제 후 목록 새로고침
                  _loadChatRooms();
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'blocked_rooms',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('차단방 관리'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('설정'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.grey),
                    SizedBox(width: 12),
                    Text('로그아웃'),
                  ],
                ),
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
                              // 상세 화면에서 돌아오면 목록 새로고침 (unreadCount 초기화 또는 삭제된 방 제거)
                              if (result == true) {
                                // 대화방이 삭제된 경우 목록에서 제거
                                setState(() {
                                  _chatRooms.removeWhere((r) => r.id == room.id);
                                });
                              } else if (result is Map) {
                                // 설정 변경된 경우 (pinned, summaryEnabled 등)
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
                              } else {
                                // 일반적으로 돌아온 경우 목록 새로고침
                                _loadChatRooms();
                              }
                            },
                            onLongPress: () => _showRoomContextMenu(context, room),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
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
                                            radius: 28,
                                            backgroundColor: const Color(0xFF64B5F6),
                                            backgroundImage: bgImage,
                                            child: bgImage == null
                                                ? Text(
                                                    room.roomName.isNotEmpty
                                                        ? room.roomName[0]
                                                        : '?',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  )
                                                : null,
                                          );
                                        },
                                      ),
                                      // 참여자 수 표시 (그룹 채팅인 경우)
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
                                  const SizedBox(width: 14),
                                  // 채팅방 정보
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // 대화명
                                            Expanded(
                                              child: Text(
                                                room.roomName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            // 고정 아이콘 (대화명 오른쪽)
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
                                            // AI 요약 기능 아이콘 (대화명 오른쪽)
                                            if (room.summaryEnabled)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(left: 4),
                                                child: Icon(
                                                  Icons.auto_awesome,
                                                  size: 16,
                                                  color: Colors.amber[600],
                                                ),
                                              ),
                                            // 알림 끔 아이콘 (대화명 오른쪽)
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
                                          room.lastMessage ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
    // 지원 메신저 목록을 기반으로 탭 생성
    // 서버에서 가져온 supportedMessengers 사용
    final List<Map<String, String>> tabItems = [];

    // 서버에서 가져온 지원 메신저 목록 사용
    for (final messenger in _supportedMessengers) {
      final packageName = messenger['packageName'] as String? ?? '';
      final packageAlias = messenger['packageAlias'] as String? ?? packageName;
      if (packageName.isNotEmpty) {
        tabItems.add({
          'packageName': packageName,
          'packageAlias': packageAlias,
        });
      }
    }

    // 서버에서 목록이 없으면 실제 데이터에서 추출
    if (tabItems.isEmpty) {
      final uniquePackages = <String, String>{};
      for (final room in _chatRooms) {
        if (!uniquePackages.containsKey(room.packageName)) {
          uniquePackages[room.packageName] = room.packageAlias;
        }
      }
      for (final entry in uniquePackages.entries) {
        tabItems.add({
          'packageName': entry.key,
          'packageAlias': entry.value,
        });
      }
    }

    // 탭이 없으면 빈 컨테이너 반환
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
          final packageAlias = item['packageAlias']!;
          final isSelected = _selectedPackageName == packageName;

          return _buildTabItem(
            packageAlias,
            isSelected,
            () => setState(() => _selectedPackageName = packageName),
          );
        },
      ),
    );
  }

  /// 탭 아이템 위젯
  Widget _buildTabItem(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 패키지 이름을 표시 이름으로 변환 (packageAlias 사용)
  String _getPackageDisplayName(String packageName) {
    // 지원 메신저 목록에서 찾기
    final messenger = _supportedMessengers.firstWhere(
      (m) => m['packageName'] == packageName,
      orElse: () => <String, dynamic>{},
    );
    
    if (messenger.isNotEmpty && messenger['packageAlias'] != null) {
      return messenger['packageAlias'] as String;
    }
    
    // 없으면 실제 데이터에서 찾기
    final room = _chatRooms.firstWhere(
      (r) => r.packageName == packageName,
      orElse: () => ChatRoom(id: 0, roomName: '', packageName: packageName),
    );
    return room.packageAlias;
  }

  /// 필터링된 채팅방 목록 반환
  List<ChatRoom> _getFilteredRooms() {
    if (_selectedPackageName == null) {
      // 선택된 패키지가 없으면 첫 번째 패키지로 필터링
      if (_supportedMessengers.isNotEmpty) {
        final firstPackage = _supportedMessengers.first['packageName'] as String?;
        if (firstPackage != null) {
          return _chatRooms.where((room) => room.packageName == firstPackage).toList();
        }
      }
      // 지원 메신저 목록도 없으면 첫 번째 채팅방의 패키지로 필터링
      if (_chatRooms.isNotEmpty) {
        final firstPackage = _chatRooms.first.packageName;
        return _chatRooms.where((room) => room.packageName == firstPackage).toList();
      }
      return [];
    }
    return _chatRooms.where((room) => room.packageName == _selectedPackageName).toList();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
