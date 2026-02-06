import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/plan_service.dart';
import '../services/local_db_service.dart';
import '../services/auto_summary_settings_service.dart';
import '../services/profile_image_service.dart';
import '../models/chat_room.dart';
import 'summary_history_screen.dart';

/// 요약 관리 화면
class UsageManagementScreen extends StatefulWidget {
  final int? initialRoomId;  // 특정 채팅방으로 스크롤하기 위한 ID
  
  const UsageManagementScreen({super.key, this.initialRoomId});

  @override
  State<UsageManagementScreen> createState() => _UsageManagementScreenState();
}

class _UsageManagementScreenState extends State<UsageManagementScreen> {
  final PlanService _planService = PlanService();
  final LocalDbService _localDb = LocalDbService();
  final ProfileImageService _profileService = ProfileImageService();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _roomKeys = {};
  final Map<int, bool> _roomExpandedStates = {}; // 채팅방별 펼침 상태
  
  Map<String, dynamic>? _usageData;
  List<ChatRoom> _summaryEnabledRooms = [];
  bool _isLoading = true;
  bool _isLoadingRooms = false;
  String? _errorMessage;
  // 자동 요약 개수 임시 값 (확인 버튼을 눌러야 저장)
  final Map<int, int> _tempAutoSummaryCounts = {};
  // TextEditingController 관리 (커서 유지를 위해)
  final Map<int, TextEditingController> _textControllers = {};

  @override
  void initState() {
    super.initState();
    // initialRoomId가 있으면 GlobalKey를 미리 생성
    if (widget.initialRoomId != null) {
      _roomKeys[widget.initialRoomId!] = GlobalKey();
    }
    _initProfileService();
    _loadData();
  }

  /// 프로필 이미지 서비스 초기화
  Future<void> _initProfileService() async {
    try {
      await _profileService.initialize();
    } catch (e) {
      debugPrint('프로필 서비스 초기화 실패: $e');
    }
  }

  /// 대화방의 프로필 이미지 파일 가져오기
  File? _getProfileImageFile(String roomName) {
    return _profileService.getRoomProfile(roomName);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // TextEditingController 정리
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUsage(),
      _loadSummaryEnabledRooms(),
    ]);

    // 두 로딩이 모두 완료된 후 initialRoomId로 스크롤
    if (widget.initialRoomId != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToInitialRoom();
      });
    }
  }

  Future<void> _loadUsage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final usageData = await _planService.getUsage();
      if (mounted) {
        setState(() {
          _usageData = usageData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '사용량 정보를 불러오는데 실패했습니다.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSummaryEnabledRooms() async {
    setState(() {
      _isLoadingRooms = true;
    });

    try {
      final rooms = await _localDb.getSummaryEnabledRooms();
      
      // initialRoomId가 있으면 해당 채팅방도 로드
      if (widget.initialRoomId != null) {
        try {
          final allRooms = await _localDb.getChatRooms();
          final matchingRooms = allRooms.where((r) => r.id == widget.initialRoomId);
          if (matchingRooms.isNotEmpty) {
            final initialRoom = matchingRooms.first;
            // 목록에 없으면 추가
            final exists = rooms.any((r) => r.id == initialRoom.id);
            if (!exists) {
              rooms.add(initialRoom);
            }
          }
        } catch (e) {
          debugPrint('초기 채팅방 로드 실패: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _summaryEnabledRooms = rooms;
          _isLoadingRooms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRooms = false;
        });
      }
    }
  }

  Future<void> _toggleSummaryEnabled(ChatRoom room) async {
    final newSummaryEnabled = !room.summaryEnabled;
    final result = await _localDb.updateRoomSettings(room.id, summaryEnabled: newSummaryEnabled);

    if (result != null && mounted) {
      // 목록에서 제거하거나 업데이트
      setState(() {
        if (!newSummaryEnabled) {
          _summaryEnabledRooms.removeWhere((r) => r.id == room.id);
        } else {
          final index = _summaryEnabledRooms.indexWhere((r) => r.id == room.id);
          if (index >= 0) {
            _summaryEnabledRooms[index] = room.copyWith(summaryEnabled: newSummaryEnabled);
          } else {
            _summaryEnabledRooms.add(room.copyWith(summaryEnabled: newSummaryEnabled));
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newSummaryEnabled
              ? '${room.roomName}의 요약 기능이 켜졌습니다.'
              : '${room.roomName}의 요약 기능이 꺼졌습니다.'),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('요약 기능 설정 변경에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  String _formatNextResetDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) {
        return '오늘 자정';
      } else if (dateOnly == today.add(const Duration(days: 1))) {
        return '내일 자정';
      } else {
        return DateFormat('M월 d일 자정', 'ko_KR').format(date);
      }
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('요약 관리'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsage,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsage,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_usageData == null) {
      return const Center(
        child: Text(
          '사용량 정보를 불러올 수 없습니다.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    final planType = _usageData!['planType'] as String? ?? 'free';
    final currentUsage = _usageData!['currentUsage'] as int? ?? 0;
    final limit = _usageData!['limit'] as int? ?? 0;
    final period = _usageData!['period'] as String? ?? 'daily';
    final nextResetDate = _usageData!['nextResetDate'] as String?;

    final isFree = planType == 'free';
    final usagePercent = limit > 0 ? (currentUsage / limit).clamp(0.0, 1.0) : 0.0;
    final remaining = (limit - currentUsage).clamp(0, limit);
    // 사용량이 제한을 초과하면 제한값으로 표시 (예: 4/3 → 3/3)
    final displayUsage = currentUsage > limit ? limit : currentUsage;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 플랜 정보 카드
            _buildPlanCard(isFree, period),
            const SizedBox(height: 24),
            
            // 사용량 게이지 카드
            _buildUsageGaugeCard(
              currentUsage: currentUsage,
              limit: limit,
              usagePercent: usagePercent,
              remaining: remaining,
              period: period,
            ),
            const SizedBox(height: 24),
            
            // 다음 리셋 날짜 정보
            if (nextResetDate != null)
              _buildResetDateCard(nextResetDate, period),
            
            const SizedBox(height: 24),
            
            // 요약 기능 켜진 채팅방 목록
            _buildSummaryEnabledRoomsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(bool isFree, String period) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFree
              ? [
                  const Color(0xFF2196F3).withOpacity(0.1),
                  const Color(0xFF2196F3).withOpacity(0.05),
                ]
              : [
                  const Color(0xFF4CAF50).withOpacity(0.1),
                  const Color(0xFF4CAF50).withOpacity(0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFree
              ? const Color(0xFF2196F3).withOpacity(0.3)
              : const Color(0xFF4CAF50).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isFree
                    ? [
                        const Color(0xFF2196F3),
                        const Color(0xFF1976D2),
                      ]
                    : [
                        const Color(0xFF4CAF50),
                        const Color(0xFF388E3C),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isFree ? const Color(0xFF2196F3) : const Color(0xFF4CAF50))
                      .withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isFree ? Icons.free_breakfast : Icons.star,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFree ? '무료 플랜' : '베이직 플랜',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  period == 'daily' ? '일일 요약 제한' : '월간 요약 제한',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageGaugeCard({
    required int currentUsage,
    required int limit,
    required double usagePercent,
    required int remaining,
    required String period,
  }) {
    final isNearLimit = usagePercent >= 0.8;
    final isExceeded = currentUsage >= limit;
    // 사용량이 제한을 초과하면 제한값으로 표시 (예: 4/3 → 3/3)
    final displayUsage = currentUsage > limit ? limit : currentUsage;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '사용량',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isExceeded
                      ? Colors.red.withOpacity(0.1)
                      : isNearLimit
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isExceeded
                      ? '초과'
                      : isNearLimit
                          ? '거의 다 사용'
                          : '정상',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isExceeded
                        ? Colors.red
                        : isNearLimit
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 게이지
          Stack(
            children: [
              // 배경 게이지
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // 진행 게이지
              FractionallySizedBox(
                widthFactor: usagePercent,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isExceeded
                          ? [
                              Colors.red[400]!,
                              Colors.red[600]!,
                            ]
                          : isNearLimit
                              ? [
                                  Colors.orange[400]!,
                                  Colors.orange[600]!,
                                ]
                              : [
                                  const Color(0xFF2196F3),
                                  const Color(0xFF1976D2),
                                ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isExceeded
                                ? Colors.red
                                : isNearLimit
                                    ? Colors.orange
                                    : const Color(0xFF2196F3))
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 사용량 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$displayUsage / $limit',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(usagePercent * 100).toStringAsFixed(1)}% 사용',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '남은 횟수',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$remaining회',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: remaining == 0
                          ? Colors.red
                          : remaining <= 3
                              ? Colors.orange
                              : const Color(0xFF2196F3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResetDateCard(String nextResetDate, String period) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period == 'daily' ? '다음 리셋' : '다음 달 리셋',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNextResetDate(nextResetDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryEnabledRoomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '요약 기능 켜진 채팅방',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            if (_isLoadingRooms)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 채팅방 목록
        if (_summaryEnabledRooms.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '요약 기능이 켜진 채팅방이 없습니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _summaryEnabledRooms.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey[200],
                indent: 20,
                endIndent: 20,
              ),
              itemBuilder: (context, index) {
                final room = _summaryEnabledRooms[index];
                final isInitialRoom = widget.initialRoomId != null && room.id == widget.initialRoomId;
                
                // GlobalKey 생성 (초기 방인 경우)
                if (isInitialRoom && !_roomKeys.containsKey(room.id)) {
                  _roomKeys[room.id] = GlobalKey();
                }
                
                return _buildRoomItem(room, isInitialRoom: isInitialRoom);
              },
            ),
          ),
      ],
    );
  }

  /// 베이직 플랜인지 확인
  bool get _isBasicPlan {
    return _usageData?['planType'] == 'basic';
  }

  Widget _buildRoomItem(ChatRoom room, {bool isInitialRoom = false}) {
    final key = isInitialRoom ? _roomKeys[room.id] : null;
    final isExpanded = _roomExpandedStates[room.id] ?? isInitialRoom;
    
    // 초기 상태 설정
    if (!_roomExpandedStates.containsKey(room.id)) {
      _roomExpandedStates[room.id] = isInitialRoom;
    }
    
    // 프로필 이미지 가져오기
    final profileFile = _getProfileImageFile(room.roomName);
    ImageProvider? bgImage;
    if (profileFile != null) {
      bgImage = FileImage(profileFile);
    } else if (room.profileImageUrl != null) {
      bgImage = NetworkImage(room.profileImageUrl!);
    }
    
    return Container(
      key: key,
      child: ExpansionTile(
        initiallyExpanded: isInitialRoom,  // 특정 채팅방으로 이동한 경우 자동으로 펼침
        onExpansionChanged: (expanded) {
          setState(() {
            _roomExpandedStates[room.id] = expanded;
          });
        },
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFF64B5F6),
          backgroundImage: bgImage,
          child: bgImage == null
              ? Text(
                  room.roomName.isNotEmpty ? room.roomName[0] : '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
              : null,
        ),
        title: Text(
          room.roomName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          room.packageAlias.isNotEmpty ? room.packageAlias : '채팅방',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: room.summaryEnabled,
              onChanged: (value) => _toggleSummaryEnabled(room),
              activeColor: const Color(0xFF2196F3),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey[600],
              size: 24,
            ),
          ],
        ),
      children: [
        // 요약 히스토리로 가기
        ListTile(
          leading: const Icon(
            Icons.history,
            color: Color(0xFF2196F3),
          ),
          title: const Text('요약 히스토리'),
          subtitle: Text(
            '이 채팅방의 요약 기록 보기',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: Colors.grey,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SummaryHistoryScreen(
                  roomId: room.id,
                  roomName: room.roomName,
                ),
              ),
            );
          },
        ),
        // 자동 요약 설정 (베이직 플랜 전용 - 베이직일 때만 표시)
        if (_isBasicPlan)
          Consumer<AutoSummarySettingsService>(
            builder: (context, autoSummarySettings, _) {
              // 베이직 플랜인 경우 자동 요약 설정 표시
              return Column(
              children: [
                ListTile(
                  title: const Text('자동 요약'),
                  subtitle: Text(
                    room.autoSummaryEnabled
                        ? '${room.autoSummaryMessageCount}개 메시지 도달 시 자동 요약'
                        : '자동 요약이 꺼져 있습니다',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  trailing: Switch(
                    value: room.autoSummaryEnabled,
                    onChanged: (value) => _toggleAutoSummary(room, value),
                    activeColor: const Color(0xFF2196F3),
                  ),
                ),
                if (room.autoSummaryEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '메시지 개수',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2A2A2A),
                                ),
                              ),
                              Text(
                                '${_tempAutoSummaryCounts[room.id] ?? room.autoSummaryMessageCount}개',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // 숫자 입력 필드
                          Builder(
                            builder: (context) {
                              // TextEditingController 초기화 또는 재사용
                              if (!_textControllers.containsKey(room.id)) {
                                _textControllers[room.id] = TextEditingController(
                                  text: (_tempAutoSummaryCounts[room.id] ?? room.autoSummaryMessageCount).toString(),
                                );
                              } else {
                                // 값이 변경되었을 때만 업데이트 (커서 위치 유지)
                                final currentValue = _textControllers[room.id]!.text;
                                final newValue = (_tempAutoSummaryCounts[room.id] ?? room.autoSummaryMessageCount).toString();
                                if (currentValue != newValue && !_textControllers[room.id]!.selection.isValid) {
                                  // 커서가 없을 때만 업데이트
                                  _textControllers[room.id]!.text = newValue;
                                }
                              }
                              
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  key: ValueKey('auto_summary_count_${room.id}'),
                                  controller: _textControllers[room.id]!,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '5 ~ 300',
                                    suffixText: '개',
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  onChanged: (value) {
                                    final count = int.tryParse(value);
                                    if (count != null && count >= 5 && count <= 300) {
                                      // setState 없이 직접 업데이트 (커서 유지)
                                      _tempAutoSummaryCounts[room.id] = count;
                                      // 위의 개수 표시만 업데이트
                                      setState(() {});
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          // 슬라이더
                          Slider(
                            value: (_tempAutoSummaryCounts[room.id] ?? room.autoSummaryMessageCount).toDouble().clamp(5.0, 300.0),
                            min: 5,
                            max: 300,
                            divisions: 59,
                            activeColor: const Color(0xFF2196F3),
                            inactiveColor: Colors.grey[300],
                            onChanged: (value) {
                              final intValue = value.toInt();
                              _tempAutoSummaryCounts[room.id] = intValue;
                              // TextField 값도 업데이트
                              if (_textControllers.containsKey(room.id)) {
                                _textControllers[room.id]!.text = intValue.toString();
                              }
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: 12),
                          // 범위 표시
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '5개',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '300개',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // 확인 버튼
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _saveAutoSummaryMessageCount(room),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2196F3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                '확인',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
      ),
    );
  }

  Future<void> _toggleAutoSummary(ChatRoom room, bool enabled) async {
    // 베이직 플랜이 아니면 자동 요약 활성화 불가
    if (enabled && !_isBasicPlan) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('자동 요약 기능은 베이직 플랜에서만 사용 가능합니다.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final result = await _localDb.updateRoomSettings(
      room.id,
      autoSummaryEnabled: enabled,
    );

    if (result != null && mounted) {
      setState(() {
        final index = _summaryEnabledRooms.indexWhere((r) => r.id == room.id);
        if (index >= 0) {
          _summaryEnabledRooms[index] = room.copyWith(
            autoSummaryEnabled: enabled,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled
              ? '${room.roomName}의 자동 요약이 켜졌습니다.'
              : '${room.roomName}의 자동 요약이 꺼졌습니다.'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _saveAutoSummaryMessageCount(ChatRoom room) async {
    // 베이직 플랜이 아니면 설정 변경 불가
    if (!_isBasicPlan) {
      return;
    }

    // 임시 값이 없으면 현재 값을 사용
    final tempCount = _tempAutoSummaryCounts[room.id] ?? room.autoSummaryMessageCount;
    final clampedCount = tempCount.clamp(5, 300);
    
    final result = await _localDb.updateRoomSettings(
      room.id,
      autoSummaryMessageCount: clampedCount,
    );

    if (result != null && mounted) {
      setState(() {
        final index = _summaryEnabledRooms.indexWhere((r) => r.id == room.id);
        if (index >= 0) {
          _summaryEnabledRooms[index] = room.copyWith(
            autoSummaryMessageCount: clampedCount,
          );
        }
        // 임시 값 제거
        _tempAutoSummaryCounts.remove(room.id);
        // TextEditingController 정리
        _textControllers[room.id]?.dispose();
        _textControllers.remove(room.id);
      });

      // 저장 완료 토스트 표시 (항상 표시)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${room.roomName}의 자동 요약 개수가 ${clampedCount}개로 저장되었습니다.'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF2196F3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  /// initialRoomId가 있으면 해당 채팅방으로 스크롤
  void _scrollToInitialRoom([int retryCount = 0]) {
    if (widget.initialRoomId == null || !mounted) return;

    final key = _roomKeys[widget.initialRoomId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1, // 상단에서 10% 위치에 배치
      );
    } else if (retryCount < 3) {
      // 위젯이 아직 렌더링되지 않았으면 다음 프레임에서 재시도
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToInitialRoom(retryCount + 1);
      });
    }
  }
}
