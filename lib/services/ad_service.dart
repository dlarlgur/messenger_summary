import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'plan_service.dart';

/// AdMob 광고 관리 서비스
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

  // 네이티브 광고 팩토리 ID (Android NativeAdFactory에 등록된 이름)
  static const String nativeAdFactoryId = 'chatListNativeAd';      // 목록 사이 (흰색)
  static const String nativeTopAdFactoryId = 'topNativeAd';        // 상단 고정 (연한 회색)

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
  Future<bool> _isFreeTier() async {
    final planType = await _planService.getCurrentPlanType();
    return planType == 'free';
  }

  /// 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // 테스트 기기 등록 (개발/QA용 - 출시 시 제거하거나 유지해도 무방)
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: ['4D21F3C8E43D4577D2C5BA909BBCDEC8'],
        ),
      );
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('✅ AdMob 초기화 완료');

      // Free 티어만 광고 로드
      final freeTier = await _isFreeTier();
      if (!freeTier) {
        debugPrint('✅ 유료 플랜 - 광고 로드 건너뜀');
        return;
      }
      // 전면 광고 미리 로드
      _loadExitInterstitialAd();
      // 채팅방 나갈 때 전면 광고 미리 로드
      _loadChatDetailInterstitialAd();
      // 리워드 광고 미리 로드 (deviceIdHash SSV 설정 포함)
      await _loadRewardedAd();
    } catch (e) {
      debugPrint('❌ AdMob 초기화 실패: $e');
    }
  }

  // ─── 네이티브 광고 ID ────────────────────────────────

  /// 상단 고정 네이티브 광고 ID
  static String get nativeTopFixedId => _nativeTopFixedId;

  /// 채팅방 목록 네이티브 광고 ID
  static String get nativeChatListId => _nativeChatListId;

  // ─── 전면 광고 (앱 종료 시) ─────────────────────────

  /// 전면 광고 로드
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
        },
      ),
    );
  }

  /// 전면 광고 표시 (앱 종료 시)
  /// 반환: true면 광고가 표시됨 (종료를 잠시 대기)
  Future<bool> showExitAd({VoidCallback? onAdDismissed}) async {
    if (!await _isFreeTier()) {
      debugPrint('✅ 유료 플랜 - 종료 광고 건너뜀');
      return false;
    }
    if (!_isExitAdLoaded || _exitInterstitialAd == null) {
      debugPrint('⚠️ 전면 광고 미준비 - 바로 종료');
      return false;
    }

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
        // ✅ 수정: SystemNavigator.pop() 이후 광고 재로드 금지
        // 앱이 종료되는 시점에 AdMob SDK가 새 요청을 시작하면
        // Dart VM이 완전히 죽지 않아 다음 실행 시 검은 화면 발생
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
    _loadExitInterstitialAd();
  }

  // ─── 전면 광고 (채팅방 나갈 때, 4번에 1번) ─────────

  /// 채팅방 나갈 때 전면 광고 로드
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
          // 30초 후 재시도 (fill rate가 낮을 때 대비)
          Future.delayed(const Duration(seconds: 30), _loadChatDetailInterstitialAd);
        },
      ),
    );
  }

  /// 채팅방 나갈 때 전면 광고 표시 (4번에 1번)
  /// 반환: true면 광고 표시됨 (광고 닫힐 때까지 대기 후 [onAdDismissed] 호출)
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

    // 마지막 광고 표시 후 쿨다운 체크 (AdMob 설정과 동일하게 코드에서도 적용)
    final lastAdTime = prefs.getInt(_keyChatDetailLastAdTime) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedMinutes = (now - lastAdTime) / 60000;
    if (lastAdTime > 0 && elapsedMinutes < _chatDetailAdCooldownMinutes) {
      debugPrint('⏱️ 채팅방 광고 쿨다운 중 (${elapsedMinutes.toStringAsFixed(1)}분 / ${_chatDetailAdCooldownMinutes}분)');
      return false;
    }

    if (!_isChatDetailAdLoaded || _chatDetailInterstitialAd == null) {
      debugPrint('⚠️ 채팅방 전면 광고 미준비 - 건너뜀');
      _loadChatDetailInterstitialAd();
      return false;
    }

    _chatDetailInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('채팅방 전면 광고 닫힘');
        ad.dispose();
        _chatDetailInterstitialAd = null;
        _isChatDetailAdLoaded = false;
        // Flutter Surface 복원 후 첫 프레임이 실제로 그려진 시점에 pop 실행
        // 고정 딜레이(300ms) 대신 프레임 콜백을 사용하여 블랙화면 방지
        SchedulerBinding.instance.addPostFrameCallback((_) {
          onAdDismissed?.call();
          // pop 완료 후 다음 광고 로드 (Surface 복원과 네트워크 요청 경합 방지)
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

    // 광고 표시 시각 기록 (쿨다운 계산용)
    await prefs.setInt(_keyChatDetailLastAdTime, DateTime.now().millisecondsSinceEpoch);
    await _chatDetailInterstitialAd!.show();
    return true;
  }

  // ─── 리워드 광고 (무료 요약 충전) ──────────────────

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
        onAdFailedToLoad: (error) {
          debugPrint('❌ 리워드 광고 로드 실패: ${error.message}');
          _isRewardedAdLoaded = false;
          rewardedAdReadyNotifier.value = false;
          // 30초 후 재시도 (채팅방 전면광고와 동일한 재시도 패턴)
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  /// 리워드 광고 준비 상태
  bool get isRewardedAdReady => _isRewardedAdLoaded && _rewardedAd != null;

  /// 오늘 리워드 광고 시청 횟수
  Future<int> getTodayRewardCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyRewardDate) ?? '';
    final today = _todayString();
    if (savedDate != today) return 0;
    return prefs.getInt(_keyRewardCount) ?? 0;
  }

  /// 오늘 남은 리워드 광고 시청 가능 횟수 (최대 3회)
  Future<int> getRemainingRewardCount() async {
    final used = await getTodayRewardCount();
    return (3 - used).clamp(0, 3);
  }

  /// 리워드 광고 표시
  /// 성공 시 free_summary_count 1 증가
  Future<bool> showRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onFailed,
    VoidCallback? onAdClosed,
  }) async {
    if (!await _isFreeTier()) {
      debugPrint('✅ 유료 플랜 - 리워드 광고 건너뜀');
      onFailed?.call();
      return false;
    }
    if (!_isRewardedAdLoaded || _rewardedAd == null) {
      debugPrint('⚠️ 리워드 광고 미준비');
      onFailed?.call();
      return false;
    }

    // 오늘 3회 초과 체크
    final remaining = await getRemainingRewardCount();
    if (remaining <= 0) {
      debugPrint('⚠️ 오늘 리워드 광고 시청 한도 초과 (3회)');
      onFailed?.call();
      return false;
    }

    bool rewardEarnedInAd = false; // 광고 강제종료 시 로컬 카운트 차감 방지용

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('리워드 광고 닫힘');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdLoaded = false;
        rewardedAdReadyNotifier.value = false;
        _loadRewardedAd(); // 다음 광고 미리 로드 (SSV 포함)
        // 광고를 정상적으로 닫았을 때만 로컬 카운트 차감
        // (광고 시청 후 앱 강제종료 시 차감되지 않도록 onUserEarnedReward에서 이동)
        if (rewardEarnedInAd) {
          unawaited(_incrementTodayRewardCount());
        }
        // Flutter surface 복원 대기 후 콜백 (채팅방 전면광고와 동일한 300ms 패턴)
        Future.delayed(const Duration(milliseconds: 300), () {
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
        _loadRewardedAd(); // 다음 광고 미리 로드 (SSV 포함)
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('🎁 리워드 획득: ${reward.type} x ${reward.amount}');
        rewardEarnedInAd = true;
        // 로컬 카운트는 광고가 정상 닫힌 후 차감 (onAdDismissedFullScreenContent)
        // 서버 리워드 등록만 여기서 수행
        onRewarded();
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
    if (!_isExitAdLoaded && _exitInterstitialAd == null) {
      _loadExitInterstitialAd();
    }
    if (!_isChatDetailAdLoaded && _chatDetailInterstitialAd == null) {
      _loadChatDetailInterstitialAd();
    }
    if (!_isRewardedAdLoaded && _rewardedAd == null) {
      await _loadRewardedAd();
    }
  }

  /// 리소스 정리
  void dispose() {
    _exitInterstitialAd?.dispose();
    _chatDetailInterstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
