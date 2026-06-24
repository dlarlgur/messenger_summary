import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../l10n/app_localizations.dart';

/// AI 톡비서 소개 화면
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const Color _primaryBlue = AppTokens.accent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 색·AppBar 는 global theme 사용 (AppTokens.bg + appBarTheme)
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).about_appBarTitle),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 메인 소개 카드
              _buildIntroCard(context),
              const SizedBox(height: 24),

              // 주요 기능 섹션
              _buildFeaturesSection(context),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// 메인 소개 카드
  Widget _buildIntroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // 톤다운 — accent → accent2 부드러운 그라데이션
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTokens.accent, AppTokens.accent2],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).about_appTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context).about_introDescription,
                  style: const TextStyle(
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
  Widget _buildFeaturesSection(BuildContext context) {
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
                Text(
                  AppLocalizations.of(context).about_featuresTitle,
                  style: const TextStyle(
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
              iconColor: AppTokens.accent,
              title: AppLocalizations.of(context).about_featureCollectTitle,
              description: AppLocalizations.of(context).about_featureCollectDescription,
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              icon: Icons.auto_awesome,
              iconColor: Colors.purple,
              title: AppLocalizations.of(context).about_featureSummaryTitle,
              description: AppLocalizations.of(context).about_featureSummaryDescription,
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              icon: Icons.history,
              iconColor: Colors.orange,
              title: AppLocalizations.of(context).about_featureHistoryTitle,
              description: AppLocalizations.of(context).about_featureHistoryDescription,
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              icon: Icons.visibility,
              iconColor: Colors.green,
              title: AppLocalizations.of(context).about_featureDeletedTitle,
              description: AppLocalizations.of(context).about_featureDeletedDescription,
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
