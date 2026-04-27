import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/material.dart';

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
          child: hasImage
              ? Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      DkswCore.resolveAssetUrl(imageUrl),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          _defaultBody(context, isDark),
                    ),
                  ),
                )
              : _defaultBody(context, isDark),
        ),
      ),
    );
  }

  Widget _defaultBody(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.build_rounded,
              size: 64,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            const SizedBox(height: 20),
            Text(
              maintenance.title.isEmpty ? '점검 중입니다' : maintenance.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              maintenance.body.isEmpty
                  ? '잠시 후 다시 이용해주세요.'
                  : maintenance.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
