import 'package:flutter/material.dart';
import '../screens/subscription_screen.dart';

/// 구독 유도 페이월 바텀시트
///
/// FREE 유저에게 BASIC 플랜 혜택을 보여주고 구독을 유도하는 바텀시트.
/// [triggerFeature]에 어떤 기능이 잠겨 있는지 전달하면 해당 기능을 강조해서 보여줌.
class PaywallBottomSheet extends StatelessWidget {
  final String? triggerFeature;

  const PaywallBottomSheet({super.key, this.triggerFeature});

  /// 페이월 바텀시트를 표시하는 헬퍼 메서드
  static Future<void> show(BuildContext context, {String? triggerFeature}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaywallBottomSheet(triggerFeature: triggerFeature),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Crown icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'BASIC 플랜으로 업그레이드',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),

          // Trigger feature hint
          if (triggerFeature != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '🔒  $triggerFeature 기능 잠금 해제',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const Text(
              '더 많은 메시지를 분석하고 스마트하게 관리하세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Benefits
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildBenefit(
                  Icons.summarize_rounded,
                  '월 150회 수동 요약',
                  'FREE 하루 1회 → 150회/월',
                  highlight: triggerFeature?.contains('요약') == true,
                ),
                const Divider(height: 16, color: Color(0xFFEEEEEE)),
                _buildBenefit(
                  Icons.message_rounded,
                  '메시지 최대 200개까지 요약',
                  'FREE 50개 → BASIC 200개',
                  highlight: triggerFeature?.contains('개') == true,
                ),
                const Divider(height: 16, color: Color(0xFFEEEEEE)),
                _buildBenefit(
                  Icons.auto_awesome_rounded,
                  '자동요약 하루 5회',
                  '메시지 N개 쌓이면 자동 분석',
                  highlight: triggerFeature?.contains('자동') == true,
                ),
                const Divider(height: 16, color: Color(0xFFEEEEEE)),
                _buildBenefit(
                  Icons.block_rounded,
                  '광고 완전 제거',
                  '배너, 전면 광고 없음',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // CTA button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'BASIC 구독하기 · 월 2,900원',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Dismiss
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '나중에',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(
    IconData icon,
    String title,
    String subtitle, {
    bool highlight = false,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: highlight
                ? const Color(0xFF4CAF50).withOpacity(0.15)
                : const Color(0xFF2196F3).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: highlight ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      highlight ? FontWeight.w700 : FontWeight.w600,
                  color: highlight
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF2A2A2A),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
        ),
        if (highlight)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'BASIC',
              style: TextStyle(
                fontSize: 9,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
