import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

/// 1:1 문의 화면 하단에 노출되는 AdMob 네이티브 광고 (small template).
///
/// 베이직 구독자에겐 호출 측에서 미노출 분기 (이 위젯은 분기 X — 받으면 로드).
/// 광고 preload 가 [AdService.preloadInquiryNativeAd] 로 미리 호출돼 있으면
/// 즉시 표시. 아니면 lazy 로드.
class InquiryNativeAdBanner extends StatefulWidget {
  const InquiryNativeAdBanner({super.key});

  /// AdMob 광고 단위 ID — 1:1 문의 네이티브 광고 슬롯.
  static const String adUnitId = 'ca-app-pub-8640148276009977/9903585372';

  @override
  State<InquiryNativeAdBanner> createState() => _InquiryNativeAdBannerState();
}

class _InquiryNativeAdBannerState extends State<InquiryNativeAdBanner> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _ownsAd = false; // preload 받은 ad 는 dispose 안 함 (AdService 에서 관리)

  @override
  void initState() {
    super.initState();
    // 1. AdService 가 미리 로드해둔 광고가 있으면 즉시 사용
    final preloaded = AdService().takePreloadedInquiryAd();
    if (preloaded != null) {
      _ad = preloaded;
      _loaded = true;
      _ownsAd = true; // 받은 ad 는 이 위젯이 소유 — dispose 시 정리
      return;
    }
    // 2. 없으면 즉시 로드 (lazy)
    _loadLazy();
  }

  void _loadLazy() {
    final ad = NativeAd(
      adUnitId: InquiryNativeAdBanner.adUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0E121A)
            : Colors.white,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[InquiryNativeAd] failed: ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    _ownsAd = true;
    ad.load();
  }

  @override
  void dispose() {
    if (_ownsAd) _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) {
      // 로딩 중엔 자리 차지 안 함 (높이 0)
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 90, // small native template 권장 높이
      width: double.infinity,
      child: AdWidget(ad: ad),
    );
  }
}
