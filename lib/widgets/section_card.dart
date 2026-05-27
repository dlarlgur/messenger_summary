import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// 설정 화면의 섹션 카드 (핸드오프 §8.6).
///
/// 위에 14px 라벨 행 (accent 아이콘 + 13/700 제목) + 카드 컨테이너 안에
/// 자식 행들을 헤어라인으로 구분해 쌓는다.
///
/// 사용 예:
/// ```dart
/// SectionCard(
///   label: '알림',
///   icon: Icons.notifications_none_rounded,
///   children: [
///     ToggleRow(...),
///     ToggleRow(...),
///   ],
/// )
/// ```
class SectionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const SectionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: AppTokens.pagePadH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Icon(icon, size: 14, color: AppTokens.accent),
                const SizedBox(width: 6),
                Text(label, style: AppText.sectionLabel),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTokens.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(color: AppTokens.border, width: 1),
              boxShadow: AppTokens.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: _Hairlined(children: children),
          ),
        ],
      ),
    );
  }
}

/// 자식 위젯들 사이에 헤어라인 자동 삽입.
class _Hairlined extends StatelessWidget {
  final List<Widget> children;
  const _Hairlined({required this.children});

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i < children.length - 1) {
        out.add(const Divider(height: 0.5, thickness: 0.5));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: out,
    );
  }
}
