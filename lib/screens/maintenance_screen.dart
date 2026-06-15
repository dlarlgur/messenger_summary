import 'package:cached_network_image/cached_network_image.dart';
import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 서버 점검 안내 풀스크린.
/// 부트스트랩에서 [Maintenance]가 응답되면 진입 차단용으로 노출.
/// 뒤로가기로 닫을 수 없으며, 점검이 끝나기 전엔 다른 화면으로 못 넘어간다.
class MaintenanceScreen extends StatelessWidget {
  final Maintenance maintenance;

  const MaintenanceScreen({super.key, required this.maintenance});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = maintenance.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0C0E13) : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: hasImage
                    ? Center(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: CachedNetworkImage(
                            imageUrl: DkswCore.resolveAssetUrl(imageUrl),
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) =>
                                _defaultBody(context, isDark),
                          ),
                        ),
                      )
                    : _defaultBody(context, isDark),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => SystemNavigator.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E2330) : const Color(0xFF1F2937),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('앱 종료',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultBody(BuildContext context, bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final iconBg = isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(Icons.build_rounded, size: 44, color: iconColor),
            ),
            const SizedBox(height: 28),
            Text(
              _plainText(maintenance.title).isEmpty
                  ? '점검 중입니다'
                  : _plainText(maintenance.title),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _plainText(maintenance.body).isEmpty
                  ? '더 나은 서비스를 위해 점검 중입니다.\n잠시 후 다시 이용해주세요.'
                  : _plainText(maintenance.body),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.6, color: bodyColor),
            ),
          ],
        ),
      ),
    );
  }
}

// 본문이 HTML(<p> 등)로 저장되므로 점검 화면 표시용으로 태그 제거 + 줄바꿈 보존.
String _plainText(String html) {
  return html
      .replaceAll(RegExp(r'</p>|<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}
