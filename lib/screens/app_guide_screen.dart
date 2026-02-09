import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

class AppGuideScreen extends StatefulWidget {
  const AppGuideScreen({super.key});

  static const String _hasSeenGuideKey = 'has_seen_app_guide';

  static Future<bool> hasSeenGuide() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenGuideKey) ?? false;
  }

  static Future<void> markGuideSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenGuideKey, true);
  }

  @override
  State<AppGuideScreen> createState() => _AppGuideScreenState();
}

class _AppGuideScreenState extends State<AppGuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeGuide();
    }
  }

  Future<void> _completeGuide() async {
    await AppGuideScreen.markGuideSeen();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 스킵 버튼
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _completeGuide,
                child: Text(
                  '건너뛰기',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            // 페이지 뷰
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPage1NotificationSetup(),
                  _buildPage2AiSummary(),
                  _buildPage3DeletedMessage(),
                ],
              ),
            ),
            // 하단 인디케이터 + 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  // 도트 인디케이터
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF2196F3)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // 다음/시작하기 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _totalPages - 1 ? '시작하기' : '다음',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 페이지 1: 카카오톡 알림 설정 =====
  Widget _buildPage1NotificationSetup() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            '카카오톡 알림 설정',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '메시지를 정확히 읽으려면\n아래와 같이 설정해 주세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // 모킹: 알림 화면
          Expanded(
            child: _buildNotificationMockup(),
          ),
          const SizedBox(height: 16),
          // 설정 경로 안내
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFF9A825), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '카카오톡 설정 → 알림 → 알림 표시 → 알림 내용\n"이름 + 메시지"로 설정',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationMockup() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 상태바
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '5:59',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.signal_cellular_alt, color: Colors.white.withOpacity(0.7), size: 16),
                  const SizedBox(width: 4),
                  Icon(Icons.wifi, color: Colors.white.withOpacity(0.7), size: 16),
                  const SizedBox(width: 4),
                  Icon(Icons.battery_full, color: Colors.white.withOpacity(0.7), size: 16),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 알림 카드
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 프로필 이미지
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE500),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble, color: Color(0xFF3C1E1E), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '부장님',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '오후 5:59',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '김대리 오늘 퇴근 전 까지 사장님께 드릴 보고서 작성해서 보내.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // 안내 텍스트
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '톡이 오면 위 스크린샷처럼\n스마트폰 상단 알림창에 보여야 합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== 페이지 2: AI 요약 기능 =====
  Widget _buildPage2AiSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'AI 대화 요약',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '긴 대화도 한눈에 파악하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildSummaryMockup(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMockup() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 채팅방 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_back_ios, size: 18, color: Colors.black54),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI 톡비서 구독자 모임',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.search, size: 20, color: Colors.grey[600]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // AI 요약 카드
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI 요약 뱃지
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: Color(0xFF1976D2)),
                          SizedBox(width: 4),
                          Text(
                            'AI 요약',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 제목
                const Text(
                  'AI 톡비서 사용 방법 안내',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                // 통계 카드
                Row(
                  children: [
                    _buildStatCard(Icons.message, '5개', '메시지'),
                    const SizedBox(width: 8),
                    _buildStatCard(Icons.people, '5명', '참여자'),
                    const SizedBox(width: 8),
                    _buildStatCard(Icons.access_time, '8분', '소요시간'),
                  ],
                ),
                const SizedBox(height: 14),
                // 요약 내용
                Text(
                  'AI 톡비서 사용 방법에 대해 서로 공유하며, 요약 기능이 너무 편해서 스트레스가 훨씬 줄었다는 내용을 공유하고 있습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // 하단 안내
          Text(
            '채팅방에서 요약 버튼을 눌러보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1976D2)),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 페이지 3: 삭제된 메시지 & 몰래보기 =====
  Widget _buildPage3DeletedMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            '삭제된 메시지 복원',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '삭제된 메시지를 볼 수 있고,\n상대 몰래 메시지를 미리 볼 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildDeletedMessageMockup(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedMessageMockup() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFB2C7D9),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 대화 내용
          Expanded(
            child: Column(
              children: [
                // 상대방 메시지
                _buildChatBubble('부장님,', false, hasUnread: true),
                const SizedBox(height: 6),
                // 삭제된 메시지
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '메시지가 삭제되었습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 구분선 + AI 톡비서 뱃지
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'AI 톡비서',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 복원된 메시지
                _buildChatBubble('부장님,', false),
                const SizedBox(height: 6),
                _buildChatBubble('완전 짜증나!!!', false),
                const Spacer(),
                // 하단 설명
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '이제부터 삭제된 메시지를 볼 수 있고,',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '상대 몰래 메시지를 미리 볼 수 있어요.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isMine, {bool hasUnread = false}) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isMine ? const Color(0xFFFEE500) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          if (hasUnread) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE500),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '1',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3C1E1E),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
