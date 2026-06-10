import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// AdMob 네이티브 광고 워밍업. (charge_app `AdMobWarmup` 이식)
///
/// 앱 시작 시 목록 인-피드 광고 단위 ID 들로 NativeAd.load() 를 미리 호출해
/// AdMob SDK 내부 응답 캐시를 데운다. 결과 NativeAd 자체는 쓰지 않고 dispose 하며,
/// 이후 ChatRoomListScreen 이 같은 단위 ID 로 load() 하면 SDK 가 캐시된 응답을
/// 빠르게 돌려줘 첫 광고 표시까지의 지연(회색 플레이스홀더 노출 시간)을 줄인다.
///
/// chat_llm 은 목록 슬롯이 8칸(4·8·12·16·20·24·28·32)이지만 고유 unit ID 는
/// 4개(슬롯 4·8·12·16)뿐이고 20~32 은 같은 ID 를 재사용하므로, 고유 ID 4개만 데운다.
///  - 4, 8  : 즉시 (첫 화면 노출용)
///  - 12, 16: +3초 (스크롤 직후 노출용, burst 부담 분산)
class AdMobWarmup {
  AdMobWarmup._();

  static bool _done = false;

  static void run() {
    if (_done) return;
    // Android AdFit 전용 모드면 MobileAds 미초기화 → 워밍업 불가, skip.
    if (!kIsWeb && Platform.isAndroid && AdService.useAdFitOnlyOnAndroid) {
      return;
    }
    _done = true;

    // 첫 화면 즉시 노출 슬롯
    _warmSlot(AdService.listAdUnitId(4));
    _warmSlot(AdService.listAdUnitId(8));
    // 스크롤 직후 노출 슬롯 — 3초 후
    Future.delayed(const Duration(seconds: 3), () {
      _warmSlot(AdService.listAdUnitId(12));
      _warmSlot(AdService.listAdUnitId(16));
    });
  }

  static void _warmSlot(String unitId) {
    NativeAd? warm;
    warm = NativeAd(
      adUnitId: unitId,
      factoryId: AdService.nativeAdFactoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          // 즉시 dispose — 인스턴스는 재사용 안 하지만 SDK 내부 응답 캐시에는 남음.
          warm?.dispose();
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
        },
      ),
    )..load();
  }
}
