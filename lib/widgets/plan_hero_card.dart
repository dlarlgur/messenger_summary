import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 무료플랜 → Basic 업그레이드 히어로 카드 (핸드오프 §7.2 §8.9).
///
/// 그라데이션 배경 + ✦ 장식 + 체크리스트 + CTA 버튼.
/// items 비어있어도 안전 (체크리스트 줄만 생략).
class PlanHeroCard extends StatelessWidget {
  final String pillLabel;
  final String headline;
  final List<String> items;
  final String ctaLabel;
  final VoidCallback onCta;

  const PlanHeroCard({
    super.key,
    required this.pillLabel,
    required this.headline,
    required this.items,
    required this.ctaLabel,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.pagePadH),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusHero),
          border: Border.all(color: AppTokens.border, width: 1),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTokens.gradStart, Colors.white],
            stops: [0.0, 1.0],
          ),
          boxShadow: AppTokens.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Stack(
          children: [
            // 우상단 ✦ 장식
            Positioned(
              top: 0,
              right: 0,
              child: Icon(
                Icons.auto_awesome,
                size: 24,
                color: AppTokens.accent2,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Pill(label: pillLabel),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(headline, style: AppText.heroHeadline),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final item in items) _CheckItem(text: item),
                ],
                const SizedBox(height: 14),
                _CtaButton(label: ctaLabel, onTap: onCta),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: AppTokens.border, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTokens.accent,
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              color: AppTokens.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check, size: 11, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.heroCheck)),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CtaButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppTokens.accent,
        borderRadius: BorderRadius.circular(AppTokens.radiusCta),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusCta),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Center(child: Text(label, style: AppText.cta)),
          ),
        ),
      ),
    );
  }
}
