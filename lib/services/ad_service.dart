import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import 'adfit_native.dart';
import 'auth_service.dart';
import 'llm_service.dart';
import 'plan_service.dart';

/// 광고 서비스 (무료 플랜: Android는 Kakao AdFit 위주, AdMob은 iOS·폴백용으로 코드 유지)
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // 실제 광고 ID
  static const String _nativeTopFixedId = 'ca-app-pub-8640148276009977/5771138057';
  static const String _nativeChatListId = 'ca-app-pub-8640148276009977/4210644377';
  static const String _exitAdFullId = 'ca-app-pub-8640148276009977/2877381405';
  static const String _rewardSummaryChargeId = 'ca-app-pub-8640148276009977/7938136398';
  static const String _chatDetailExitAdId = 'ca-app-pub-8640148276009977/4943784306';

  // 애드핏 — **운영** 광고 단위 (대시보드 광고 유형과 일치해야 노출)
  // 상단/목록/팝업 각 슬롯은 반드시 해당 유형의 DAN으로 설정되어야 합니다.
  static const String _adFitTopNativeCode = 'DAN-iOk8xjwCoCapX5ZM';
  static const String _adFitChatListBannerCode = 'DAN-W4WDVrCgPvchmiDQ'; // 네이티브(목록)
  static const String _adFitAppExitCode = 'DAN-wo6sjdtX0Cg10Mwu'; // 앱 종료 팝업
  static const String _adFitPageFlashCode = 'DAN-IPgxRfjgzURGJQu3'; // 앱 전환 팝업
  static const String _adFitRewardSummaryCode = 'DAN-qYNWhkhSCtdZ7uA8'; // 요약 리워드 대체(앱 전환 팝업)

  // 네이티브 광고 팩토리 ID (Android NativeAdFactory에 등록된 이름)
  static const String nativeAdFactoryId = 'chatListNativeAd';      // 목록 사이 (흰색)
  static const String nativeTopAdFactoryId = 'topNativeAd';        // 상단 고정 (연한 회색)

  /// `true`: 뒤로가기 앱 종료 시 **AdMob 전면을 쓰지 않고** Kakao AdFit 종료 팝업만 사용.
  static const bool skipAdMobExitInterstitial = false;

  /// Android 무료 플랜: 상단·목록 **AdMob 네이티브**, 채팅 나가기 **AdMob 전면** 로드 자체를 하지 않고 AdFit만 사용.
  /// (iOS는 AdFit 배너 미연동이라 AdMob 네이티브 유지)
  static const bool useAdFitOnlyOnAndroid = false;

  /// `true`: AdMob 리워드만 쓰고 싶을 때 (아래 폴백도 끔).
  static const bool useAdFitRewardInsteadOfAdMob = false;

  /// AdMob 리워드가 로드 안 됐을 때 Android에서 **AdFit 앱 전환 팝업**으로 대체, **닫힘(ok)** 이면 리워드와 동일 처리.
  static const bool useAdFitRewardWhenAdMobUnavailable = true;

  /// AdMob 리워드·한도 UI 없을 때 표시 (계정 정지 등)
  static const String msgRewardAdUnavailable =
      '현재 광고가 준비되지 않았습니다.\n(AdMob 이용 제한 등으로 잠시 표시가 어려울 수 있습니다.)';

  /// Android에서 배너·전면을 AdFit만 쓰는 모드 여부 (내부용)
  bool get _androidAdFitOnly =>
      useAdFitOnlyOnAndroid && !kIsWeb && Platform.isAndroid;
  
  // 애드핏 광고 사용 여부 (AdMob 로드 실패 시 true)
  bool _useAdFitForTop = false;
  bool _useAdFitForExit = false;
  bool _useAdFitForChatDetail = false;
  // 리스트 광고는 슬롯별(4·8)로 폴백 상태 분리
  final Map<int, bool> _useAdFitForListSlot = {4: false, 8: false};

  // SharedPreferences 키
  static const String _keyRewardDate = 'ad_reward_date';
  static const String _keyRewardCount = 'ad_reward_count';
  static const String _keyFreeSummaryUsed = 'ad_free_summary_used';
  static const String _keyChatDetailExitCount = 'ad_chat_detail_exit_count';
  static const String _keyChatDetailLastAdTime = 'ad_chat_detail_last_time';
  static const int _chatDetailAdCooldownMinutes = 4; // AdMob 설정과 동일한 쿨다운
  // 전면광고 표시 중 앱 종료 감지용 키 (부분 로딩 → 강제 종료 → 재시작 시 블랙화면 방지)
  static const String _keyExitAdShowing = 'ad_exit_showing';
  // ✅ 광고 캐싱 키 (public으로 변경하여 ChatRoomListScreen에서 접근 가능)
  static const String keyTopAdCacheTime = 'ad_top_cache_time';
  static const String keyListAdCacheTime = 'ad_list_cache_time';
  static const int adCacheDurationMinutes = 60; // 60분 캐시

  // 현재 종료 광고가 표시 중인지 추적 (앱 라이프사이클 감지용)
  bool _exitAdCurrentlyShowing = false;

  final PlanService _planService = PlanService();
  bool _isInitialized = false;

  /// 동시에 `initialize()` 여러 번 호출돼도 한 번만 실행되도록 공유 Future
  Future<void>? _initializeFuture;

  // 전면 광고 (앱 종료)
  InterstitialAd? _exitInterstitialAd;
  bool _isExitAdLoaded = false;

  // 전면 광고 (채팅방 나갈 때)
  InterstitialAd? _chatDetailInterstitialAd;
  bool _isChatDetailAdLoaded = false;

  // 리워드 광고
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  /// 리워드 광고 준비 상태 변경 알림 (UI 자동 업데이트용)
  final ValueNotifier<bool> rewardedAdReadyNotifier = ValueNotifier(false);

  /// Free 티어 여부 확인
  /// 오프라인/네트워크 지연 시 캐시 즉시 반환(최대 2초 대기) — 뒤로가기 먹통 방지
  Future<bool> _isFreeTier() async {
    try {
      final planType = await _planService.getCurrentPlanType().timeout(
        const Duration(seconds: 2),
        onTimeout: () => _planService.getCachedPlanTypeSync(),
      );
      return planType == 'free';
    } catch (e) {
      debugPrint('⚠️ 플랜 확인 실패 - 캐시 사용: $e');
      return _planService.getCachedPlanTypeSync() == 'free';
    }
  }

  /// 앱 종료/무료 광고 흐름 여부 (외부에서 동기 전제 깨지지 않게 조회)
  Future<bool> isFreeTierForExitAd() => _isFreeTier();

  /// 초기화 (`main()`과 채팅 목록 등에서 동시 호출 가능 — 한 번만 실행)
  Future<void> initialize() async {
    if (_isInitialized) return;
    _initializeFuture ??= _initializeOnce();
    await _initializeFuture!;
  }

  Future<void> _initializeOnce() async {
    try {
      // Android + AdFit 전용: 무료 플랜에서 AdMob을 전혀 쓰지 않으면 SDK 초기화 생략
      final freeTierEarly = await _isFreeTier();
      final skipMobileAdsEntirelyOnAndroid = _androidAdFitOnly &&
          freeTierEarly &&
          useAdFitRewardInsteadOfAdMob &&
          skipAdMobExitInterstitial;

      if (!skipMobileAdsEntirelyOnAndroid) {
        // 테스트 기기 등록 (개발/QA용)
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: ['4D21F3C8E43D4577D2C5BA909BBCDEC8'],
          ),
        );
        await MobileAds.instance.initialize();
        debugPrint('✅ AdMob SDK 초기화 완료');
      } else {
        debugPrint('⏭️ Android AdFit 전용(무료) — MobileAds.initialize 생략');
      }
      _isInitialized = true;

      // Free 티어만 광고 로드
      final freeTier = freeTierEarly;
      if (!freeTier) {
        debugPrint('✅ 유료 플랜 - 광고 로드 건너뜀');
        return;
      }

      // Android: 목록/상단/채팅 전면을 처음부터 AdFit으로 (AdMob 네이티브·전면 로드 안 함)
      if (_androidAdFitOnly) {
        switchTopAdToAdFit();
        for (final slot in _useAdFitForListSlot.keys) {
          switchListAdToAdFit(slot);
        }
        switchChatDetailAdToAdFit();
        debugPrint('✅ Android — 상단·목록·채팅 전면 AdMob 로드 생략, AdFit 사용');
      }

      // AdMob 앱 종료 전면 (비활성 권장 — AdFit 종료 팝업)
      if (!skipAdMobExitInterstitial) {
        _loadExitInterstitialAd();
      }

      // AdMob 채팅방 나가기 전면
      if (!_androidAdFitOnly) {
        _loadChatDetailInterstitialAd();
      }

      // 리워드: AdFit 전면 모드면 AdMob 리워드 로드 생략
      if (useAdFitRewardInsteadOfAdMob && !kIsWeb && Platform.isAndroid) {
        rewardedAdReadyNotifier.value = true;
        debugPrint('✅ 리워드: AdFit 전환 팝업 모드 — AdMob 리워드 로드 생략');
      } else {
        await _loadRewardedAd();
      }
    } catch (e) {
      debugPrint('❌ 광고(AdMob) 초기화 실패: $e');
      _initializeFuture = null;
    }
  }

  // ─── 네이티브 광고 ID ────────────────────────────────

  /// 상단 고정 네이티브 광고 ID
  static String get nativeTopFixedId => _nativeTopFixedId;

  /// 채팅방 목록 네이티브 광고 ID
  static String get nativeChatListId => _nativeChatListId;

  /// 애드핏 광고 코드 (fallback용)
  static String get adFitTopNativeCode => _adFitTopNativeCode;
  static String get adFitChatListBannerCode => _adFitChatListBannerCode;
  static String get adFitAppExitCode => _adFitAppExitCode;
  static String get adFitPageFlashCode => _adFitPageFlashCode;
  static String get adFitRewardSummaryCode => _adFitRewardSummaryCode;

  /// 애드핏 사용 여부 확인
  bool get useAdFitForTop => _useAdFitForTop;
  bool get useAdFitForExit => _useAdFitForExit;
  bool get useAdFitForChatDetail => _useAdFitForChatDetail;

  /// 리스트 슬롯(4 또는 8)별 AdFit 폴백 상태
  bool useAdFitForListSlot(int slot) =>
      _useAdFitForListSlot[slot] ?? false;

  /// 상단 광고를 애드핏으로 전환
  void switchTopAdToAdFit() {
    _useAdFitForTop = true;
    debugPrint('🔄 상단 광고를 애드핏으로 전환');
  }

  /// 리스트 광고 슬롯(4 또는 8)을 애드핏으로 전환
  void switchListAdToAdFit(int slot) {
    if (!_useAdFitForListSlot.containsKey(slot)) return;
    _useAdFitForListSlot[slot] = true;
    debugPrint('🔄 리스트 광고 슬롯$slot 애드핏으로 전환');
  }

  /// 상단 광고 AdFit 폴백 해제 (AdMob 재시도용 — 포그라운드 복귀 등)
  void resetTopAdFallback() {
    if (!_useAdFitForTop) return;
    _useAdFitForTop = false;
    debugPrint('↩️ 상단 광고 AdFit 폴백 해제 — AdMob 재시도');
  }

  /// 리스트 광고 슬롯별 AdFit 폴백 해제 (AdMob 재시도용)
  void resetListAdFallback(int slot) {
    if (_useAdFitForListSlot[slot] != true) return;
    _useAdFitForListSlot[slot] = false;
    debugPrint('↩️ 리스트 광고 슬롯$slot AdFit 폴백 해제 — AdMob 재시도');
  }

  /// 모든 리스트 슬롯 폴백 일괄 해제
  void resetAllListAdFallbacks() {
    bool changed = false;
    for (final k in _useAdFitForListSlot.keys.toList()) {
      if (_useAdFitForListSlot[k] == true) {
        _useAdFitForListSlot[k] = false;
        changed = true;
      }
    }
    if (changed) {
      debugPrint('↩️ 모든 리스트 광고 슬롯 AdFit 폴백 해제 — AdMob 재시도');
    }
  }

  /// 어떤 리스트 슬롯이라도 AdFit 폴백 중이면 true
  bool get anyListSlotInAdFitFallback =>
      _useAdFitForListSlot.values.any((v) => v == true);

  /// 앱 종료 광고를 애드핏으로 전환
  void switchExitAdToAdFit() {
    _useAdFitForExit = true;
    debugPrint('🔄 앱 종료 광고를 애드핏으로 전환');
  }

  /// 채팅방 나갈 때 광고를 애드핏으로 전환
  void switchChatDetailAdToAdFit() {
    _useAdFitForChatDetail = true;
    debugPrint('🔄 채팅방 나갈 때 광고를 애드핏으로 전환');
  }

  // ─── 전면 광고 (앱 종료 시) ─────────────────────────
  // AdMob 종료 전면: [skipAdMobExitInterstitial]==true 이면 호출되지 않음 → Kakao AdFit 종료 팝업만 사용.

  /// AdMob 전면 광고 로드 (앱 종료) — 비활성 시 미사용
  void _loadExitInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _exitAdFullId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _exitInterstitialAd = ad;
          _isExitAdLoaded = true;
          debugPrint('✅ 전면 광고 로드 완료');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('전면 광고 닫힘');
              ad.dispose();
              _exitInterstitialAd = null;
              _isExitAdLoaded = false;
              // 다음을 위해 다시 로드
              _loadExitInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ 전면 광고 표시 실패: ${error.message}');
              ad.dispose();
              _exitInterstitialAd = null;
              _isExitAdLoaded = false;
              _loadExitInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ 전면 광고 로드 실패: ${error.message}');
          _isExitAdLoaded = false;
          // 종료 시점에 showExitAd에서 AdMob 없으면 AdFit 시도 (플래그만 유지)
        },
      ),
    );
  }

  /// 전면 광고 표시 (앱 종료 시)
  /// 반환: true면 광고가 표시됨 (종료를 잠시 대기)
  /// AdMob 실패 시 애드핏 웹뷰 전면 광고 표시 (onAdDismissed는 외부에서 호출)
  Future<bool> showExitAd({VoidCallback? onAdDismissed}) async {
    if (!await _isFreeTier()) {
      debugPrint('✅ 유료 플랜 - 종료 광고 건너뜀');
      return false;
    }

    // AdMob 종료 전면 (선택). skipAdMobExitInterstitial 이면 항상 아래 AdFit만 사용.
    if (!skipAdMobExitInterstitial &&
        _isExitAdLoaded &&
        _exitInterstitialAd != null) {
      _useAdFitForExit = false;
      // 광고 표시 시작 플래그 (부분 로딩 감지: 이 플래그가 남아있으면 onDismissed 미호출)
      _exitAdCurrentlyShowing = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyExitAdShowing, true);

      _exitInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('전면 광고 닫힘 → 앱 종료 진행');
          _exitAdCurrentlyShowing = false;
          unawaited(prefs.remove(_keyExitAdShowing));
          ad.dispose();
          _exitInterstitialAd = null;
          _isExitAdLoaded = false;
          onAdDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('❌ 전면 광고 표시 실패: ${error.message}');
          _exitAdCurrentlyShowing = false;
          unawaited(prefs.remove(_keyExitAdShowing));
          ad.dispose();
          _exitInterstitialAd = null;
          _isExitAdLoaded = false;
          onAdDismissed?.call();
          // 실패 시에만 재로드 (앱은 종료되지 않음)
          _loadExitInterstitialAd();
        },
      );

      await _exitInterstitialAd!.show();
      return true;
    }

    // AdMob 미준비 → AdFit 폴백 플래그만 켜고 실제 팝업은 호출측에서 띄움
    switchExitAdToAdFit();
    debugPrint(
      skipAdMobExitInterstitial
          ? '🔄 앱 종료: AdMob 전면 생략 설정 → AdFit 종료 팝업 필요'
          : '🔄 AdMob 종료 전면 미준비 → AdFit 앱 종료 팝업 필요',
    );
    return false;
  }

  /// 전면광고 표시 중 앱이 백그라운드로 전환됐을 때 호출
  /// (홈 버튼 → 앱이 AdActivity 뒤에 숨겨진 상태)
  /// finishOnTaskLaunch로 AdActivity가 자동 종료될 경우
  /// onAdDismissedFullScreenContent 없이 재개될 수 있으므로 상태 정리
  Future<void> handleAppResumedAfterAdInterrupt() async {
    if (!_exitAdCurrentlyShowing) return;
    debugPrint('⚠️ 전면광고 표시 중 앱 복귀 감지 - 광고 상태 정리');
    _exitAdCurrentlyShowing = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyExitAdShowing);
    // 광고 객체 정리 및 다음 광고 미리 로드
    _exitInterstitialAd?.dispose();
    _exitInterstitialAd = null;
    _isExitAdLoaded = false;
    if (!skipAdMobExitInterstitial) {
      _loadExitInterstitialAd();
    }
  }

  // ─── 전면 광고 (채팅방 나갈 때, 4번에 1번) ─────────
  // Android [useAdFitOnlyOnAndroid]: AdMob 전면 로드 없음 → Kakao AdFit 전환 팝업.

  /// AdMob 채팅방 이탈 전면 로드 — Android AdFit 전용 모드에서는 호출하지 않음
  void _loadChatDetailInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _chatDetailExitAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _chatDetailInterstitialAd = ad;
          _isChatDetailAdLoaded = true;
          debugPrint('✅ 채팅방 나갈 때 전면 광고 로드 완료');
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ 채팅방 나갈 때 전면 광고 로드 실패: ${error.message}');
          _isChatDetailAdLoaded = false;
          // AdMob 로드 실패 시 애드핏으로 전환
          switchChatDetailAdToAdFit();
          // 30초 후 재시도 (fill rate가 낮을 때 대비)
          Future.delayed(const Duration(seconds: 30), _loadChatDetailInterstitialAd);
        },
      ),
    );
  }

  /// 채팅방 나갈 때 전면 광고 표시 (4번에 1번, 4분 쿨다운)
  /// 반환: true면 광고 표시됨 (광고 닫힐 때까지 대기 후 [onAdDismissed] 호출)
  /// AdMob 실패 시 애드핏 웹뷰 전면 광고 표시 (onAdDismissed는 외부에서 호출)
  Future<bool> showChatDetailAd({VoidCallback? onAdDismissed}) async {
    if (!await _isFreeTier()) {
      debugPrint('✅ 유료 플랜 - 채팅방 나갈 때 광고 건너뜀');
      return false;
    }

    // 나간 횟수 카운트 증가 (앱 전체 누적)
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_keyChatDetailExitCount) ?? 0) + 1;
    await prefs.setInt(_keyChatDetailExitCount, count);

    // 4번에 1번만 광고 표시
    if (count % 4 != 0) {
      debugPrint('📊 채팅방 나가기 $count회 - 광고 건너뜀 (다음 광고: ${4 - (count % 4)}회 후)');
      return false;
    }

    // 마지막 광고 표시 후 쿨다운 체크 (4분)
    final lastAdTime = prefs.getInt(_keyChatDetailLastAdTime) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedMinutes = (now - lastAdTime) / 60000;
    if (lastAdTime > 0 && elapsedMinutes < _chatDetailAdCooldownMinutes) {
      debugPrint('⏱️ 채팅방 광고 쿨다운 중 (${elapsedMinutes.toStringAsFixed(1)}분 / ${_chatDetailAdCooldownMinutes}분)');
      return false;
    }

    // 광고 표시 시각 기록 (쿨다운 계산용 - AdMob/애드핏 공통)
    await prefs.setInt(_keyChatDetailLastAdTime, DateTime.now().millisecondsSinceEpoch);

    // AdMob 광고가 준비되어 있으면 AdMob 표시
    if (_isChatDetailAdLoaded && _chatDetailInterstitialAd != null && !_useAdFitForChatDetail) {
      _chatDetailInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('채팅방 전면 광고 닫힘');
          ad.dispose();
          _chatDetailInterstitialAd = null;
          _isChatDetailAdLoaded = false;
          // Flutter Surface 복원 후 첫 프레임이 실제로 그려진 시점에 pop 실행
          SchedulerBinding.instance.addPostFrameCallback((_) {
            onAdDismissed?.call();
            // pop 완료 후 다음 광고 로드
            Future.delayed(const Duration(milliseconds: 300), _loadChatDetailInterstitialAd);
          });
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('❌ 채팅방 전면 광고 표시 실패: ${error.message}');
          ad.dispose();
          _chatDetailInterstitialAd = null;
          _isChatDetailAdLoaded = false;
          onAdDismissed?.call();
          _loadChatDetailInterstitialAd();
        },
      );

      await _chatDetailInterstitialAd!.show();
      return true;
    }

    // AdMob 실패 또는 애드핏 사용 설정된 경우
    // 애드핏 웹뷰 전면 광고는 UI에서 직접 표시
    if (_useAdFitForChatDetail || (!_isChatDetailAdLoaded && _chatDetailInterstitialAd == null)) {
      debugPrint('🔄 애드핏 채팅방 나갈 때 광고 사용 (AdMob 대신)');
      return true; // UI에서 애드핏 광고 표시하도록 true 반환
    }

    debugPrint('⚠️ 채팅방 전면 광고 미준비 - 건너뜀');
    if (!_androidAdFitOnly) {
      _loadChatDetailInterstitialAd();
    }
    return false;
  }

  // ─── 리워드 광고 (무료 요약 충전) ──────────────────
  //
  // 참고: 테스트 광고는 onUserEarnedReward가 잘 호출되지만, 실광고(특히 매체)에서는
  // 호출이 누락되거나 onAdDismissedFullScreenContent *이후*에 호출될 수 있음.
  // - 콜백 순서 대응: 광고 닫힌 뒤 600ms 지연 후 reward 여부를 확인하도록 처리함.
  // - 여전히 콜백이 안 오는 경우: AdMob 콘솔에서 리워드 광고 유닛 설정(리워드 이름/수량),
  //   매체 파트너, "고참여 광고" 옵션 확인. 일부 네트워크는 리워드 이벤트를 전달하지 않을 수 있음.

  /// 리워드 광고 로드
  /// SSV(Server-Side Verification) 설정: custom_data = deviceIdHash
  /// → AdMob이 광고 시청 완료 시 서버의 /api/v1/reward/admob/callback 호출
  Future<void> _loadRewardedAd() async {
    // SSV custom_data에 넣을 deviceIdHash 조회
    final deviceIdHash = await AuthService().getDeviceIdHash() ?? '';
    if (deviceIdHash.isEmpty) {
      debugPrint('⚠️ [AdService] deviceIdHash 없음 - SSV custom_data 미설정');
    } else {
      debugPrint('✅ [AdService] SSV custom_data 설정: ${deviceIdHash.substring(0, 8)}...');
    }

    RewardedAd.load(
      adUnitId: _rewardSummaryChargeId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) async {
          // ★ 광고 준비 상태를 먼저 설정 (SSV await 실패 시에도 광고 사용 가능하도록)
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          rewardedAdReadyNotifier.value = true;
          debugPrint('✅ 리워드 광고 로드 완료');
          // SSV 설정은 부가 기능이므로 실패해도 광고 재생에 영향 없음
          if (deviceIdHash.isNotEmpty) {
            try {
              await ad.setServerSideOptions(
                ServerSideVerificationOptions(customData: deviceIdHash),
              );
            } catch (e) {
              debugPrint('⚠️ SSV custom_data 설정 실패 (광고는 사용 가능): $e');
            }
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          final msg = error.message;
          final publisherMissing = msg.contains('Publisher data not found') ||
              msg.contains('publisher') && msg.contains('not found');
          // Android는 AdFit 전환 팝업으로 대체 가능 — AdMob 미등록/오류 시 에러 로그만 소음이 됨
          if (!kIsWeb &&
              Platform.isAndroid &&
              useAdFitRewardWhenAdMobUnavailable &&
              _androidAdFitOnly &&
              (publisherMissing || error.code == 3 /* NO_FILL */)) {
            debugPrint(
              'ℹ️ AdMob 리워드 미로드(AdMob 콘솔·앱 등록 확인): $msg — '
              'Android에서는 AdFit 앱 전환 팝업으로 요약 충전을 대체합니다.',
            );
          } else {
            debugPrint('❌ 리워드 광고 로드 실패: $msg');
          }
          _isRewardedAdLoaded = false;
          rewardedAdReadyNotifier.value = false;
          // 30초 후 재시도 (채팅방 전면광고와 동일한 재시도 패턴)
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  /// 리워드 광고 준비 상태 (AdMob 준비됨 또는 Android에서 AdFit 폴백 가능)
  bool get isRewardedAdReady {
    final admob = _isRewardedAdLoaded && _rewardedAd != null;
    if (useAdFitRewardInsteadOfAdMob && !kIsWeb && Platform.isAndroid) {
      return true;
    }
    if (admob) return true;
    if (useAdFitRewardWhenAdMobUnavailable && !kIsWeb && Platform.isAndroid) {
      return true;
    }
    return false;
  }

  /// 오늘 리워드 광고 시청 횟수
  Future<int> getTodayRewardCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyRewardDate) ?? '';
    final today = _todayString();
    if (savedDate != today) return 0;
    return prefs.getInt(_keyRewardCount) ?? 0;
  }

  /// 오늘 남은 리워드 광고 시청 가능 횟수 (서버 maxLimit 없을 때 fallback 사용)
  Future<int> getRemainingRewardCount() async {
    final used = await getTodayRewardCount();
    final maxRewards = UsageConstants.freePlanMaxAdRewardsFallback;
    return (maxRewards - used).clamp(0, maxRewards);
  }

  /// 리워드 광고 표시
  /// 성공 시 free_summary_count 1 증가
  ///
  /// [onRewarded] 인자: 서버 `registerAdReward(source: ...)` 에 넘길 출처 문자열
  /// ([LlmService.rewardSourceAdMobRewarded] / [LlmService.rewardSourceAdFitTransition]).
  Future<bool> showRewardedAd({
    required void Function(String rewardSource) onRewarded,
    VoidCallback? onFailed,
    VoidCallback? onAdClosed,
  }) async {
    if (!await _isFreeTier()) {
      debugPrint('✅ 유료 플랜 - 리워드 광고 건너뜀');
      onFailed?.call();
      return false;
    }

    // 오늘 리워드 광고 한도 초과 체크
    final remaining = await getRemainingRewardCount();
    if (remaining <= 0) {
      debugPrint('⚠️ 오늘 리워드 광고 시청 한도 초과 (하루 ${UsageConstants.freePlanMaxAdRewardsFallback}회)');
      onFailed?.call();
      return false;
    }

    // AdFit 전용 모드: 리워드 전부 AdFit 앱 전환 팝업
    if (useAdFitRewardInsteadOfAdMob && !kIsWeb && Platform.isAndroid) {
      return _showAdFitRewardInPlaceOfAdMob(
        onRewarded: onRewarded,
        onFailed: onFailed,
        onAdClosed: onAdClosed,
      );
    }

    // AdMob 리워드 우선
    if (_isRewardedAdLoaded && _rewardedAd != null) {
      return _showAdMobRewardedInternal(
        onRewarded: onRewarded,
        onFailed: onFailed,
        onAdClosed: onAdClosed,
      );
    }

    // AdMob 없음 → AdFit 앱 전환 팝업 (닫힘=리워드)
    if (useAdFitRewardWhenAdMobUnavailable && !kIsWeb && Platform.isAndroid) {
      debugPrint('🔄 AdMob 리워드 미로드 → AdFit 요약 리워드 팝업(${_adFitRewardSummaryCode})');
      return _showAdFitRewardInPlaceOfAdMob(
        onRewarded: onRewarded,
        onFailed: onFailed,
        onAdClosed: onAdClosed,
      );
    }

    debugPrint('⚠️ 리워드 광고 미준비');
    onFailed?.call();
    return false;
  }

  /// AdFit 앱 전환 팝업: 사용자가 닫으면(ok) AdMob 리워드와 동일하게 1회 충전·서버 등록 콜백
  Future<bool> _showAdFitRewardInPlaceOfAdMob({
    required void Function(String rewardSource) onRewarded,
    VoidCallback? onFailed,
    VoidCallback? onAdClosed,
  }) async {
    final result =
        await AdFitNative.showTransitionPopupAd(_adFitRewardSummaryCode);
    final ok = result != null && result['ok'] == true;
    if (ok) {
      onRewarded(LlmService.rewardSourceAdFitTransition);
      await _incrementTodayRewardCount();
      onAdClosed?.call();
      return true;
    }
    debugPrint('⚠️ AdFit 요약 리워드 팝업 실패/취소: $result');
    onFailed?.call();
    return false;
  }

  Future<bool> _showAdMobRewardedInternal({
    required void Function(String rewardSource) onRewarded,
    VoidCallback? onFailed,
    VoidCallback? onAdClosed,
  }) async {
    bool rewardEarnedInAd = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('리워드 광고 닫힘');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdLoaded = false;
        rewardedAdReadyNotifier.value = false;
        _loadRewardedAd();
        Future.delayed(const Duration(milliseconds: 600), () {
          if (rewardEarnedInAd) {
            unawaited(_incrementTodayRewardCount());
          }
          onAdClosed?.call();
        });
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ 리워드 광고 표시 실패: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdLoaded = false;
        rewardedAdReadyNotifier.value = false;
        onFailed?.call();
        _loadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('🎁 리워드 획득: ${reward.type} x ${reward.amount}');
        rewardEarnedInAd = true;
        onRewarded(LlmService.rewardSourceAdMobRewarded);
      },
    );

    return true;
  }

  /// 오늘 리워드 시청 횟수 증가
  Future<void> _incrementTodayRewardCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final savedDate = prefs.getString(_keyRewardDate) ?? '';

    int count = 0;
    if (savedDate == today) {
      count = prefs.getInt(_keyRewardCount) ?? 0;
    }

    await prefs.setString(_keyRewardDate, today);
    await prefs.setInt(_keyRewardCount, count + 1);
  }

  /// 오늘 날짜 문자열 (yyyy-MM-dd)
  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 오늘 무료 요약 사용 여부 (1일 1회 무료, 자정 기준)
  Future<bool> hasUsedFreeSummaryToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyFreeSummaryUsed) ?? '';
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return savedDate == today;
  }

  /// 오늘 무료 요약 사용 표시
  Future<void> markFreeSummaryUsed() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await prefs.setString(_keyFreeSummaryUsed, today);
  }

  /// 플랜 변경 후 광고 재로드 (유료 → 무료 다운그레이드 시 호출)
  Future<void> reloadAdsForFreePlan() async {
    final freeTier = await _isFreeTier();
    if (!freeTier) return;

    debugPrint('🔄 무료 플랜 전환 감지 - 광고 재로드');
    if (!skipAdMobExitInterstitial &&
        !_isExitAdLoaded &&
        _exitInterstitialAd == null) {
      _loadExitInterstitialAd();
    }
    if (!_androidAdFitOnly &&
        !_isChatDetailAdLoaded &&
        _chatDetailInterstitialAd == null) {
      _loadChatDetailInterstitialAd();
    }
    final skipAdMobReward =
        useAdFitRewardInsteadOfAdMob && !kIsWeb && Platform.isAndroid;
    if (!skipAdMobReward &&
        !_isRewardedAdLoaded &&
        _rewardedAd == null) {
      await _loadRewardedAd();
    } else if (skipAdMobReward) {
      rewardedAdReadyNotifier.value = true;
    }
  }

  /// 리소스 정리
  void dispose() {
    _exitInterstitialAd?.dispose();
    _chatDetailInterstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
