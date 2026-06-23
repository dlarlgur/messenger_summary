import 'dart:io';

import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_tokens.dart';

/// 앱 업데이트 다이얼로그.
/// SDK [UpdatePolicy]를 받아 강제/선택 업데이트를 분기 처리한다.
/// 선택 업데이트는 "1일/7일 보지 않기" 옵션을 SharedPreferences에 저장.
class UpdateDialog extends StatefulWidget {
  final UpdatePolicy policy;

  const UpdateDialog({super.key, required this.policy});

  static const String _packageName = 'com.dksw.app';
  static const String _appName = 'AI 톡비서';
  static const String _skipUntilKey = 'update_skip_until';

  /// 강제/선택 업데이트가 필요할 때만 다이얼로그 표시.
  /// 선택 업데이트인데 스킵 기간 안이면 표시 생략.
  static Future<void> showIfNeeded(
    BuildContext context,
    UpdatePolicy policy,
  ) async {
    if (!policy.forceUpdate && !policy.optionalUpdate) return;

    if (policy.optionalUpdate && !policy.forceUpdate) {
      final prefs = await SharedPreferences.getInstance();
      final skipUntil = prefs.getInt(_skipUntilKey);
      if (skipUntil != null &&
          DateTime.now().millisecondsSinceEpoch < skipUntil) {
        debugPrint(
            '[UpdateDialog] 선택 업데이트 스킵 (${DateTime.fromMillisecondsSinceEpoch(skipUntil)}까지)');
        return;
      }
    }
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => UpdateDialog(policy: policy),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  // 브랜드 블루 hero 그라데이션 (AppTokens.accent 기준 진한 2색).
  static const Color _heroStart = Color(0xFF3B6DFF); // AppTokens.accent
  static const Color _heroEnd = Color(0xFF1E48D6); // 더 진한 블루

  int? _selectedSkipDays;

  Future<void> _openStore() async {
    final storeUrl = widget.policy.storeUrl;
    if (storeUrl != null && storeUrl.isNotEmpty) {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (Platform.isAndroid) {
      // market:// 스킴이 캐시 우회 측면에서 우선
      final marketUri =
          Uri.parse('market://details?id=${UpdateDialog._packageName}');
      try {
        final ok =
            await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      } catch (_) {}
      final webUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=${UpdateDialog._packageName}');
      if (await canLaunchUrl(webUri)) {
        launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } else {
      // iOS: storeUrl이 없으면 안내만 (chat_llm은 Android 우선 배포)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('스토어를 열 수 없습니다.')),
        );
      }
    }
  }

  Future<void> _handleLater() async {
    if (_selectedSkipDays != null) {
      final prefs = await SharedPreferences.getInstance();
      final skipUntil = DateTime.now()
          .add(Duration(days: _selectedSkipDays!))
          .millisecondsSinceEpoch;
      await prefs.setInt(UpdateDialog._skipUntilKey, skipUntil);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isForced = widget.policy.forceUpdate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final latestVersion = widget.policy.latestVersion ?? '';
    final releaseNote = widget.policy.releaseNote ?? '';
    // 강제/선택 모두 브랜드 블루 톤으로 통일 (charge 패턴: 알람 빨강 대신 깔끔하게).
    final accent = AppTokens.accent;

    final bg = isDark ? const Color(0xFF161B24) : AppTokens.surface;
    final textPrimary = isDark ? Colors.white : AppTokens.text;
    final textSecondary = isDark ? Colors.white70 : AppTokens.text2;

    return PopScope(
      canPop: !isForced,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero header (브랜드 블루 그라데이션)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_heroStart, _heroEnd],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isForced
                              ? Icons.system_update_rounded
                              : Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isForced ? '필수 업데이트' : '새 버전이 나왔어요',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${UpdateDialog._appName} $latestVersion',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (releaseNote.isNotEmpty) ...[
                        Text(
                          '변경 사항',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : AppTokens.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : AppTokens.border,
                            ),
                          ),
                          constraints: const BoxConstraints(maxHeight: 160),
                          child: SingleChildScrollView(
                            child: Text(
                              releaseNote,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: textPrimary,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (isForced) ...[
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 15, color: textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '원활한 이용을 위해 최신 버전으로 업데이트해 주세요.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isForced) ...[
                        const SizedBox(height: 16),
                        _SkipTile(
                          label: '하루 동안 보지 않기',
                          selected: _selectedSkipDays == 1,
                          accent: accent,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedSkipDays =
                              _selectedSkipDays == 1 ? null : 1),
                        ),
                        const SizedBox(height: 6),
                        _SkipTile(
                          label: '일주일 동안 보지 않기',
                          selected: _selectedSkipDays == 7,
                          accent: accent,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedSkipDays =
                              _selectedSkipDays == 7 ? null : 7),
                        ),
                      ],
                    ],
                  ),
                ),
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      if (!isForced) ...[
                        Expanded(
                          child: TextButton(
                            onPressed: _handleLater,
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              '나중에',
                              style: TextStyle(
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        flex: isForced ? 1 : 2,
                        child: ElevatedButton(
                          onPressed: _openStore,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 18),
                              SizedBox(width: 6),
                              Text(
                                '지금 업데이트',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _SkipTile({
    required this.label,
    required this.selected,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.15 : 0.08)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : AppTokens.bg),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.5)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppTokens.border),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: selected
                    ? accent
                    : (isDark ? Colors.white54 : AppTokens.text3),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? accent
                      : (isDark ? Colors.white70 : AppTokens.text2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
