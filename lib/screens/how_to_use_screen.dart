import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_tokens.dart';

/// AI 톡비서 사용 가이드 화면
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  static const Color _primaryBlue = AppTokens.accent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 색·AppBar 는 global theme 사용
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).howTo_appBarTitle),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 필수 설정
              _buildSection(
                context,
                title: AppLocalizations.of(context).howTo_section1Title,
                subtitle: AppLocalizations.of(context).howTo_section1Subtitle,
                icon: Icons.settings,
                iconColor: Colors.orange,
                items: [
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section1Item1,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section1Item2,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section1Item3,
                    isImportant: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. 보안 및 개인정보 보호
              _buildSection(
                context,
                title: AppLocalizations.of(context).howTo_section2Title,
                subtitle: AppLocalizations.of(context).howTo_section2Subtitle,
                icon: Icons.lock,
                iconColor: Colors.green,
                items: [
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section2Item1,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section2Item2,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section2Item3,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section2Item4,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. 채팅방 목록 관리
              _buildSection(
                context,
                title: AppLocalizations.of(context).howTo_section3Title,
                subtitle: AppLocalizations.of(context).howTo_section3Subtitle,
                icon: Icons.list,
                iconColor: _primaryBlue,
                items: [
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section3Item1,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section3Item2,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section3Item3,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section3Item4,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 4. 대화방 내부 주요 기능
              _buildSection(
                context,
                title: AppLocalizations.of(context).howTo_section4Title,
                icon: Icons.chat_bubble,
                iconColor: Colors.purple,
                items: [
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section4Item1,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section4Item2,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section4Item3,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section4Item4,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. 상세 요약 활용법
              _buildSection(
                context,
                title: AppLocalizations.of(context).howTo_section5Title,
                icon: Icons.auto_awesome,
                iconColor: Colors.amber,
                items: [
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section5Item1,
                  ),
                  _buildBulletItem(
                    AppLocalizations.of(context).howTo_section5Item2,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 6. 요금제 및 사용량 확인
              _buildSection(
                context,
                title: AppLocalizations.of(context).howTo_section6Title,
                subtitle: AppLocalizations.of(context).howTo_section6Subtitle,
                icon: Icons.payment,
                iconColor: Colors.teal,
                items: [
                  _buildPlanTable(context),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildBulletItem(String text, {bool isImportant = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 12),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isImportant ? Colors.orange : _primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.5,
                ),
                children: _parseText(text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _parseText(String text) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // 일반 텍스트
        spans.add(TextSpan(text: parts[i]));
      } else {
        // 강조 텍스트 (**로 감싼 부분)
        spans.add(TextSpan(
          text: parts[i],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ));
      }
    }
    
    return spans;
  }

  Widget _buildPlanTable(BuildContext context) {
    return Column(
      children: [
        // 무료 플랜 카드
        _buildPlanCard(
          planName: AppLocalizations.of(context).howTo_freePlanName,
          planColor: AppTokens.accent,
          items: [
            _buildPlanItem(AppLocalizations.of(context).howTo_planLabelCount, '하루 최대 ${UsageConstants.freePlanMaxLimitFallback}회 (${UsageConstants.freePlanMaxAdRewardsFallback}회는 광고 시청 시, 매일 자정 초기화)'),
            _buildPlanItem(AppLocalizations.of(context).howTo_planLabelLimit, AppLocalizations.of(context).howTo_freePlanLimitValue),
            _buildPlanItem(AppLocalizations.of(context).howTo_planLabelFeature, AppLocalizations.of(context).howTo_freePlanFeatureValue),
          ],
        ),
        const SizedBox(height: 12),
        // Basic 플랜 카드
        _buildPlanCard(
          planName: AppLocalizations.of(context).howTo_basicPlanName,
          planColor: Colors.purple,
          items: [
            _buildPlanItem(AppLocalizations.of(context).howTo_planLabelCount, AppLocalizations.of(context).howTo_basicPlanCountValue),
            _buildPlanItem(AppLocalizations.of(context).howTo_planLabelLimit, AppLocalizations.of(context).howTo_basicPlanLimitValue),
            _buildPlanItem(AppLocalizations.of(context).howTo_planLabelFeature, AppLocalizations.of(context).howTo_basicPlanFeatureValue),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String planName,
    required Color planColor,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: planColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: planColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: planColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                planName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: planColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildPlanItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1A1A),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
