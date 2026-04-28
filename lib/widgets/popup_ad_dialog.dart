import 'dart:async';

import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/popup_ad_cache.dart';

/// 콘솔에 등록된 팝업 광고를 진입 시 1회 표시.
/// "오늘 보지 않기" 누르면 다음 자정까지 동일 광고 슬롯 전체를 스킵.
/// impressions은 서버 /popup 응답 시 서버에서 +1, 클릭은 [DkswCore.trackAdClick]으로.
class PopupAdDialog extends StatelessWidget {
  final SplashAd ad;

  const PopupAdDialog({super.key, required this.ad});

  static const String _skipKey = 'popup_ad_skip_until';

  /// 진입 시 호출. stale-while-revalidate:
  ///  - 캐시 hit → 즉시 다이얼로그 + 백그라운드로 fresh 갱신
  ///  - 캐시 miss → 네트워크에서 가져와 다이얼로그 + 캐시 저장
  static Future<void> showIfEligible(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final skipUntil = prefs.getInt(_skipKey);
    if (skipUntil != null &&
        DateTime.now().millisecondsSinceEpoch < skipUntil) {
      return;
    }

    final cached = await PopupAdCache.read();
    if (cached != null) {
      final (ad, bytes) = cached;
      final url = DkswCore.resolveAssetUrl(ad.imageUrl);
      await PopupAdCache.installInImageCache(url, bytes);
      // 백그라운드로 새 광고 가져와 디스크 갱신 — 다음 진입 반영.
      unawaited(_refreshInBackground());
      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.7),
        builder: (_) => PopupAdDialog(ad: ad),
      );
      return;
    }

    // 캐시 miss → 네트워크 fetch.
    final fresh = await DkswCore.fetchPopup();
    if (fresh == null) {
      // 서버에 광고 없음 — 이전 캐시가 stale 한 경우 대비해 비움.
      unawaited(PopupAdCache.clear());
      return;
    }
    unawaited(PopupAdCache.save(fresh));
    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => PopupAdDialog(ad: fresh),
    );
  }

  /// 캐시 적중 시 백그라운드에서 호출 — 사용자에게 보이지 않음.
  /// 응답이 없으면 캐시를 비워 다음 진입에 더 이상 노출되지 않게 한다.
  static Future<void> _refreshInBackground() async {
    try {
      final fresh = await DkswCore.fetchPopup();
      if (fresh == null) {
        await PopupAdCache.clear();
        return;
      }
      if (!await PopupAdCache.isSameAsCached(fresh)) {
        await PopupAdCache.save(fresh);
      }
    } catch (_) {}
  }

  Future<void> _skipToday(BuildContext context) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skipKey, tomorrow.millisecondsSinceEpoch);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _handleTap(BuildContext context) async {
    DkswCore.trackAdClick(ad.id);

    final url = ad.ctaUrl;
    if (url == null || url.isEmpty || ad.ctaType == 'none') {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context);
    final uri = Uri.parse(url);
    // 현재는 internal/external 모두 외부 브라우저로. 내부 라우팅이 생기면 분기.
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _handleTap(context),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Image.network(
                        DkswCore.resolveAssetUrl(ad.imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.black26,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // "닫기"는 우상단 X 가 처리 — 중복 제거. "오늘 하루 보지 않기"만 노출.
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _skipToday(context),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    '오늘 하루 보지 않기',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.4),
                      decorationThickness: 1,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
