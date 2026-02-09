import 'package:flutter/material.dart';

/// AI 톡비서 소개 화면
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'AI 톡비서 란',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 메인 소개 카드
              _buildIntroCard(),
              const SizedBox(height: 24),

              // 주요 기능 섹션
              _buildFeaturesSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// 메인 소개 카드
  Widget _buildIntroCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryBlue,
            _primaryBlue.withValues(alpha: 0.8),
            const Color(0xFF1976D2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 배경 장식
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // AI 아이콘
          Positioned(
            right: 30,
            top: 30,
            child: Icon(
              Icons.psychology,
              color: Colors.white.withValues(alpha: 0.3),
              size: 80,
            ),
          ),
          // 콘텐츠
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'AI 톡비서',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'AI 톡비서는 카카오톡, 라인 등의 메신저 대화를 AI로 요약해주는 스마트한 메신저 어시스턴트입니다.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 주요 기능 섹션
  Widget _buildFeaturesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.stars,
                    color: _primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '주요 기능',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildFeatureItem(
              icon: Icons.collections_bookmark,
              iconColor: Colors.blue,
              title: '메신저 대화 자동 수집',
              description: '카카오톡, 라인 등 다양한 메신저의 대화를 자동으로 수집하여 저장합니다.',
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              icon: Icons.auto_awesome,
              iconColor: Colors.purple,
              title: 'AI 기반 대화 자동 요약',
              description: '강력한 AI 기술로 긴 대화 내용을 간결하고 명확하게 요약해드립니다.',
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              icon: Icons.history,
              iconColor: Colors.orange,
              title: '요약 히스토리 관리',
              description: '과거 요약 내역을 확인하고 관리할 수 있습니다.',
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              icon: Icons.visibility,
              iconColor: Colors.green,
              title: '삭제된 메시지 보기 및 미리보기',
              description: '상대방이 삭제한 메시지도 확인할 수 있으며, 미리보기 기능을 제공합니다.',
            ),
          ],
        ),
      ),
    );
  }

  /// 기능 아이템 위젯
  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
