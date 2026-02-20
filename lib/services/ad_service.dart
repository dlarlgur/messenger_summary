import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'plan_service.dart';

/// AdMob 광고 관리 서비스
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // 광고 단위 ID (TODO: AdMob 계정 승인 후 실제 ID로 교체)
  // 실제 ID (승인 후 사용)
  // static const String _nativeTopFixedId = 'ca-app-pub-8640148276009977/5771138057';
  // static const String _nativeChatListId = 'ca-app-pub-8640148276009977/4210644377';
  // static const String _exitAdFullId = 'ca-app-pub-8640148276009977/2877381405';
  // static const String _rewardSummaryChargeId = 'ca-app-pub-8640148276009977/7938136398';

  // 테스트 ID (Google 공식 테스트 광고)
  static const String _nativeTopFixedId = 'ca-app-pub-3940256099942544/2247696110';
  static const String _nativeChatListId = 'ca-app-pub-3940256099942544/2247696110';
  static const String _exitAdFullId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _rewardSummaryChargeId = 'ca-app-pub-3940256099942544/5224354917';

  // 네이티브 광고 팩토리 ID (Android NativeAdFactory에 등록된 이름)
  static const String nativeAdFactoryId = 'chatListNativeAd';      // 목록 사이 (흰색)
  static const String nativeTopAdFactoryId = 'topNativeAd';        // 상단 고정 (연한 회색)

  // SharedPreferences 키
  static const String _keyRewardDate = 'ad_reward_date';
  static const String _keyRewardCount = 'ad_reward_count';
  static const String _keyFreeSummaryUsed = 'ad_free_summary_used';

  final PlanService _planService = PlanService();
  bool _isInitialized = false;

  // 전면 광고
  InterstitialAd? _exitInterstitialAd;
  bool _isExitAdLoaded = false;

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

    _exitInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('전면 광고 닫힘 → 앱 종료 진행');
        ad.dispose();
        _exitInterstitialAd = null;
        _isExitAdLoaded = false;
        onAdDismissed?.call();
        _loadExitInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ 전면 광고 표시 실패: ${error.message}');
        ad.dispose();
        _exitInterstitialAd = null;
        _isExitAdLoaded = false;
        onAdDismissed?.call();
        _loadExitInterstitialAd();
      },
    );

    await _exitInterstitialAd!.show();
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
          // ★ SSV 설정: 광고 시청 완료 시 Google이 서버로 deviceIdHash를 전송
          if (deviceIdHash.isNotEmpty) {
            await ad.setServerSideOptions(
              ServerSideVerificationOptions(customData: deviceIdHash),
            );
          }
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          rewardedAdReadyNotifier.value = true;
          debugPrint('✅ 리워드 광고 로드 완료');
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ 리워드 광고 로드 실패: ${error.message}');
          _isRewardedAdLoaded = false;
          rewardedAdReadyNotifier.value = false;
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

    if (savedDate != today) {
      return 0;
    }
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

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('리워드 광고 닫힘');
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdLoaded = false;
        rewardedAdReadyNotifier.value = false;
        _loadRewardedAd(); // 다음 광고 미리 로드 (SSV 포함)
        onAdClosed?.call();
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
      onUserEarnedReward: (ad, reward) async {
        debugPrint('🎁 리워드 획득: ${reward.type} x ${reward.amount}');
        // 오늘 시청 횟수 증가
        await _incrementTodayRewardCount();
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

  /// 오늘 무료 요약 사용 여부 (1일 1회 무료)
  Future<bool> hasUsedFreeSummaryToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_keyFreeSummaryUsed) ?? '';
    return savedDate == _todayString();
  }

  /// 오늘 무료 요약 사용 표시
  Future<void> markFreeSummaryUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFreeSummaryUsed, _todayString());
  }

  /// 오늘 날짜 문자열 (yyyy-MM-dd)
  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 리소스 정리
  void dispose() {
    _exitInterstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
