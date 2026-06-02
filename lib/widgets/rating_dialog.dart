import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 평점 요청 단순 확인 다이얼로그 (C1 Soft Modern Blue 톤).
///
/// 사용자에게 "앱 만족스러우신가요? 평점 남겨주세요" 안내 후
/// [onConfirm] (평점 남기기) / [onLater] (나중에) 분기.
class RatingDialog extends StatelessWidget {
  final Future<void> Function() onConfirm;
  final VoidCallback? onLater;

  const RatingDialog({
    super.key,
    required this.onConfirm,
    this.onLater,
  });

  static Future<void> show({
    required BuildContext context,
    required Future<void> Function() onConfirm,
    VoidCallback? onLater,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => RatingDialog(
        onConfirm: onConfirm,
        onLater: onLater,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusHero),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTokens.gradStart, Colors.white],
            stops: [0.0, 1.0],
          ),
          boxShadow: AppTokens.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.of(context).pop();
                  onLater?.call();
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppTokens.text3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppTokens.accentSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 30,
                color: AppTokens.accent,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '톡비서가 마음에 드시나요?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTokens.text,
                letterSpacing: -0.34,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              '평점 한 번이면 저희에게\n정말 큰 힘이 됩니다 🙏',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTokens.text2,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _SecondaryButton(
                    label: '나중에',
                    onTap: () {
                      Navigator.of(context).pop();
                      onLater?.call();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PrimaryButton(
                    label: '평점 남기기',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await onConfirm();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Future<void> Function() onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.accent,
      borderRadius: BorderRadius.circular(AppTokens.radiusCta),
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(AppTokens.radiusCta),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Center(
            child: Text(label, style: AppText.cta),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTokens.radiusCta),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusCta),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusCta),
            border: Border.all(color: AppTokens.border, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTokens.text2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
