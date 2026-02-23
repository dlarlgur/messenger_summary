import 'package:flutter/material.dart';
import '../screens/subscription_screen.dart';

/// 구독 유도 페이월 바텀시트
///
/// FREE 유저에게 BASIC 플랜 혜택을 보여주고 구독을 유도하는 바텀시트.
/// [triggerFeature]에 어떤 기능이 잠겨 있는지 전달하면 해당 기능을 강조해서 보여줌.
/// [onWatchAd]가 있으면 "광고 보고 1회 무료 요약" 버튼을 함께 표시.
class PaywallBottomSheet extends StatelessWidget {
  final String? triggerFeature;
  final bool isLimitReached;
  final VoidCallback? onWatchAd;
  final int adRemainingCount;

  const PaywallBottomSheet({
    super.key,
    this.triggerFeature,
    this.isLimitReached = false,
    this.onWatchAd,
    this.adRemainingCount = 0,
  });

  /// 페이월 바텀시트를 표시하는 헬퍼 메서드
  static Future<void> show(
    BuildContext context, {
    String? triggerFeature,
    bool isLimitReached = false,
    VoidCallback? onWatchAd,
    int adRemainingCount = 0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaywallBottomSheet(
        triggerFeature: triggerFeature,
        isLimitReached: isLimitReached,
        onWatchAd: onWatchAd,
        adRemainingCount: adRemainingCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAdOption = isLimitReached && onWatchAd != null && adRemainingCount > 0;

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

          // 무료 횟수 소진 메시지
          if (isLimitReached) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFB74D).withOpacity(0.5),
                ),
              ),
              child: const Row(
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '오늘 무료 요약 횟수를 모두 사용했어요.\nBASIC 플랜으로 계속 이용하세요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFFE65100),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 리워드 광고 옵션 (광고 횟수가 남아있을 때만)
            if (showAdOption) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onWatchAd!();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2196F3),
                    side: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '광고 보고 무료 요약 (오늘 $adRemainingCount회 남음)',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '광고 시청 후 요약 1회가 즉시 충전됩니다',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ] else ...[
              const SizedBox(height: 4),
            ],
          ]
          // Trigger feature hint
          else if (triggerFeature != null) ...[
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
                  '월 150회 대화 요약',
                  '자동+수동 통합 월 150회 한도',
                  highlight: triggerFeature?.contains('요약') == true,
                ),
                const Divider(height: 16, color: Color(0xFFEEEEEE)),
                _buildBenefit(
                  Icons.message_rounded,
                  '메시지 최대 200개까지 요약',
                  'FREE 50개, BASIC 200개',
                  highlight: triggerFeature?.contains('개') == true,
                ),
                const Divider(height: 16, color: Color(0xFFEEEEEE)),
                _buildBenefit(
                  Icons.auto_awesome_rounded,
                  '자동요약 및 자동요약 푸시알림',
                  '메시지 N개 도달 시 자동 분석 및 푸시알림',
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
