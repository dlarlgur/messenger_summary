import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 토글 행 (핸드오프 §8.7).
/// 라벨 + 옵션 서브카피(warn 색 가능) + 우측 토글.
class ToggleRow extends StatelessWidget {
  final String label;
  final String? sub;
  final bool warn;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleRow({
    super.key,
    required this.label,
    this.sub,
    this.warn = false,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.rowPadH,
          vertical: AppTokens.rowPadV,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.rowLabel),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub!,
                        style: warn ? AppText.rowSubWarn : AppText.rowSub),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Toggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: AppTokens.toggleTrackW,
        height: AppTokens.toggleTrackH,
        decoration: BoxDecoration(
          color: value ? AppTokens.accent : AppTokens.togglePadding,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              left: value
                  ? AppTokens.toggleTrackW -
                      AppTokens.toggleKnob -
                      2
                  : 2,
              top: 2,
              child: Container(
                width: AppTokens.toggleKnob,
                height: AppTokens.toggleKnob,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 우측 chevron 이 붙은 nav 행 (핸드오프 §8.8).
/// 탭 시 상세/외부 링크로 이동.
class NavRow extends StatelessWidget {
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final String label;
  final String? sub;
  final String? trailingText;
  final VoidCallback onTap;

  const NavRow({
    super.key,
    this.leadingIcon,
    this.leadingIconColor,
    required this.label,
    this.sub,
    this.trailingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.rowPadH,
          vertical: AppTokens.rowPadV,
        ),
        child: Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon,
                  size: 20, color: leadingIconColor ?? AppTokens.text2),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.rowLabel),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub!, style: AppText.rowSub),
                  ],
                ],
              ),
            ),
            if (trailingText != null && trailingText!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(trailingText!, style: AppText.rowSub),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppTokens.text3),
          ],
        ),
      ),
    );
  }
}
