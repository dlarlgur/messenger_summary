import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/app_tokens.dart';

/// 앱 종료 확인 다이얼로그 + AdMob 네이티브 광고 (charge_app 패턴 이식).
///
/// 이전엔 종료 직전 전면(Interstitial)을 띄웠으나 AdMob 비허용 배치
/// ("앱 종료 시 전면광고")라 게재 제한 → 단위 삭제. 종료 확인 다이얼로그 안에
/// 네이티브 광고를 넣는 허용 패턴으로 전환.
///  · 광고 표기: SDK 내장 템플릿이 'Ad' 배지를 자동 렌더 (정책 요건).
///  · 오클릭 방지: 광고 영역과 종료/취소 버튼 사이 20dp 여백 (정책 요건).
///  · 미로드 시: 다이얼로그를 띄우지 않고 false 반환 → 호출측이 기존
///    AdFit 종료 팝업으로 폴백 (사용자 요구: AdFit 은 AdMob 실패 시 폴백 유지).
class ExitNativeAdService {
  ExitNativeAdService._();
  static final ExitNativeAdService instance = ExitNativeAdService._();

  // AdMob 네이티브 고급형 — "앱 종료 다이얼로그" 전용 신규 단위 (2026-07 생성).
  static const String _exitNativeId = 'ca-app-pub-8640148276009977/8830044376';

  NativeAd? _ad;
  bool _loaded = false;
  bool _loading = false;

  /// 광고 미리 로드 (앱 시작 시 1회 + 다이얼로그 소비 후 재호출).
  void preload() {
    if (_ad != null || _loading) return;
    _loading = true;
    final ad = NativeAd(
      adUnitId: _exitNativeId,
      request: const AdRequest(),
      // SDK 내장 미디엄 템플릿 — 'Ad' 어트리뷰션 배지 자동 포함.
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppTokens.accent,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF1A1A2E),
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFF64748B),
          size: 12,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          _loaded = true;
          _loading = false;
          debugPrint('✅ [ExitNativeAd] 종료 네이티브 로드 완료');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('⚠️ [ExitNativeAd] 로드 실패: ${error.message} → AdFit 폴백 예정');
          ad.dispose();
          _ad = null;
          _loaded = false;
          _loading = false;
        },
      ),
    );
    _ad = ad;
    _loaded = false;
    ad.load();
  }

  NativeAd? _takeIfLoaded() => _loaded ? _ad : null;

  /// 다이얼로그에서 광고를 소비(노출)한 뒤 — 폐기하고 다음 노출용 재로드.
  void _consumeAndReload() {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _loading = false;
    preload();
  }

  /// 종료 확인 다이얼로그(취소/종료 + 네이티브 광고) 표시 시도.
  ///
  /// true  = 광고가 로드돼 있어 다이얼로그가 종료 플로우를 처리함
  ///         (취소면 앱 유지, 종료면 여기서 SystemNavigator.pop 까지).
  /// false = 광고 미로드 → 호출측이 AdFit 종료 팝업으로 폴백.
  Future<bool> tryShowExitDialog(BuildContext context) async {
    final ad = _takeIfLoaded();
    if (ad == null) return false;

    // 미디엄 템플릿 필요 높이는 다이얼로그 '폭'에 비례:
    // 미디어(폭×9/16) + 고정 행(아이콘·제목·본문·CTA ≈ 175dp). — charge_app 실기기 검증값.
    final screen = MediaQuery.of(context).size;
    final contentW =
        (screen.width - 48 /*insetPadding*/ - 40 /*내부 padding*/).clamp(200.0, 420.0);
    final adHeight =
        (contentW * 9 / 16 + 175.0).clamp(280.0, screen.height * 0.55);

    final exit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('앱을 종료할까요?',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 5),
                  const Text('다음에 또 만나요',
                      style:
                          TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: adHeight,
                      width: double.infinity,
                      child: AdWidget(ad: ad),
                    ),
                  ),
                  // 광고와 버튼 사이 여백 — 오클릭 방지 (AdMob 정책 요건).
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD8DEE6)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('취소',
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A2E))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTokens.accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('종료',
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // 노출된 광고 소비 처리 — 다음 종료 시도용 재로드.
    _consumeAndReload();
    if (exit == true) await SystemNavigator.pop();
    return true;
  }
}
