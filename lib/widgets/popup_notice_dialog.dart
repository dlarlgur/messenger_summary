import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// 콘솔에 등록된 type=popup 공지를 진입 시 1회 표시.
/// "오늘 보지 않기" 누르면 해당 공지 id가 다음 자정까지 스킵.
class PopupNoticeDialog extends StatelessWidget {
  final NoticeItem notice;

  const PopupNoticeDialog({super.key, required this.notice});

  static const String _skipPrefix = 'popup_notice_skip_';

  /// 부트스트랩 응답의 popup 공지 중 첫 번째 미스킵 항목 1개만 표시.
  static Future<void> showIfEligible(BuildContext context) async {
    final notices = DkswCore.lastBootstrap?.notices ?? const [];
    final popups = notices.where((n) => n.type == 'popup').toList();
    if (popups.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final n in popups) {
      final skipUntil = prefs.getInt('$_skipPrefix${n.id}');
      if (skipUntil != null && now < skipUntil) continue;
      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => PopupNoticeDialog(notice: n),
      );
      return; // 한 번에 하나만
    }
  }

  Future<void> _skipToday(BuildContext context) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_skipPrefix${notice.id}',
      tomorrow.millisecondsSinceEpoch,
    );
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF141823) : Colors.white;
    final primary = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondary = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final divider = isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0);
    final accent = const Color(0xFF2563EB);

    final hasImage =
        notice.imageUrl != null && notice.imageUrl!.isNotEmpty;
    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                notice.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: primary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasImage)
                      Image.network(
                        DkswCore.resolveAssetUrl(notice.imageUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                    if (notice.body.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            20, hasImage ? 14 : 0, 20, 16),
                        child: Html(
                          data: notice.body,
                          onLinkTap: (url, _, __) async {
                            if (url == null) return;
                            await launchUrl(
                              Uri.parse(url),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: divider),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _skipToday(context),
                    style: TextButton.styleFrom(
                      foregroundColor: secondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: const Text('오늘 보지 않기',
                        style: TextStyle(fontSize: 14)),
                  ),
                ),
                Container(width: 1, height: 20, color: divider),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(),
                    ),
                    child: const Text(
                      '닫기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
