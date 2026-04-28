import 'dart:async';

import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/splash_ad_cache.dart';

/// 스플래시 광고 화면.
///
/// stale-while-revalidate 패턴:
/// - 디스크 캐시된 이전 세션의 광고를 즉시 노출 (네트워크 대기 0초)
/// - 부트스트랩에 의한 캐시 갱신은 main()이 백그라운드에서 처리
/// - displayMs 만료 후 [MainScreen]으로 pushReplacement
///
/// 첫 실행/캐시 없음/만료 등의 경우 광고 없이 곧장 다음 화면으로.
class SplashScreen extends StatefulWidget {
  /// 광고 종료(또는 캐시 없음) 시 이동할 위젯 빌더.
  /// MainScreen import 순환 방지를 위해 주입식.
  final WidgetBuilder nextBuilder;

  const SplashScreen({super.key, required this.nextBuilder});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  SplashAd? _ad;
  Timer? _autoClose;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cached = await SplashAdCache.read();
      if (!mounted) return;

      if (cached != null) {
        final (ad, bytes) = cached;
        final resolvedUrl = DkswCore.resolveAssetUrl(ad.imageUrl);
        // 이미지 캐시에 미리 꽂아두면 Image.network 첫 프레임이 즉시 그려져 깜빡임 0.
        await SplashAdCache.installInImageCache(resolvedUrl, bytes);
        if (!mounted) return;
        setState(() => _ad = ad);
        _autoClose = Timer(
          Duration(milliseconds: ad.displayMs),
          _navigateNext,
        );
        return;
      }
    } catch (e) {
      debugPrint('[SplashScreen] start 실패: $e');
    }
    // 캐시 없음/실패 → 즉시 다음 화면
    _navigateNext();
  }

  void _navigateNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _autoClose?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.nextBuilder),
    );
  }

  Future<void> _onTap() async {
    final ad = _ad;
    if (ad == null) return;
    DkswCore.trackAdClick(ad.id);
    final url = ad.ctaUrl;
    if (url != null && url.isNotEmpty) {
      try {
        await launchUrl(Uri.parse(url),
            mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Native splash 가 0.3초 동안 위에 깔려 로고 노출 → 그 사이 캐시 광고 push.
    // 광고 없으면 native splash 내려가면서 다음 화면으로 (이 Scaffold 의 흰/검 배경만 잠깐).
    // charge_app 의 splash_screen.dart 와 동일 패턴.
    final isDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0E13) : Colors.white,
      body: _ad == null
          ? const SizedBox.expand()  // native splash 가 위에 있어 로고 보임
          : GestureDetector(
              onTap: _onTap,
              child: SizedBox.expand(
                child: Image.network(
                  DkswCore.resolveAssetUrl(_ad!.imageUrl),
                  fit: BoxFit.cover,
                  // 로딩 중엔 native splash 가 아래에 깔려있어 깜빡임 X
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : const SizedBox.shrink(),
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
    );
  }
}
