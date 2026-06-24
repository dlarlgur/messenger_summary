import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:dksw_app_core/dksw_app_core.dart';
import '../models/chat_room.dart';
import '../l10n/app_localizations.dart';
import '../services/local_db_service.dart';
import '../services/notification_settings_service.dart';
import '../services/profile_image_service.dart';
import '../services/auth_service.dart';
import '../services/plan_service.dart';
import '../services/messenger_registry.dart';
import '../services/messenger_settings_service.dart';
import '../services/ad_service.dart';
import '../services/push_service.dart';
import '../services/rating_prompt_service.dart';
import '../services/app_updater.dart';
import '../widgets/update_dialog.dart';
import '../widgets/popup_notice_dialog.dart';
// popup_ad_dialog 는 dksw_app_core v0.3.2 부터 코어로 통합 — 위 import 로 사용.
import '../widgets/adfit_native_top_ad_widget.dart';
import '../widgets/adfit_native_list_ad_widget.dart';
import '../widgets/house_ad_card.dart';
import '../widgets/top_banner_view.dart';
import '../widgets/app_logo.dart';
import '../services/house_ad_service.dart';
import '../theme/app_tokens.dart';
import 'chat_room_detail_screen.dart';
import 'blocked_rooms_screen.dart';
import 'notification_list_screen.dart';
import 'usage_management_screen.dart';
import 'app_settings_screen.dart';
import 'app_guide_screen.dart';
import 'subscription_screen.dart';
import '../widgets/paywall_bottom_sheet.dart';

/// 사선을 그리는 CustomPainter
class SlashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ChatRoomListScreen extends StatefulWidget {
  const ChatRoomListScreen({super.key});

  @override
  State<ChatRoomListScreen> createState() => ChatRoomListScreenState();
}

class ChatRoomListScreenState extends State<ChatRoomListScreen> with WidgetsBindingObserver {

  final LocalDbService _localDb = LocalDbService();
  final ProfileImageService _profileService = ProfileImageService();
  final PlanService _planService = PlanService();
  List<ChatRoom> _chatRooms = [];
  bool _isLoading = true;
  String? _error;
  /// 한 앱 세션 안에서 알림/평점 시퀀스 한 번만 호출 (이걸 안 두면
  /// _loadChatRooms 재호출마다 entry count 증가 + 다이얼로그 즉시 노출 문제).
  bool _ratingSequenceTriggered = false;
  // roomId -> 최신 메시지 텍스트 (내가 보낸 메시지가 최신이면 그것, 아니면 lastMessage)
  final Map<int, String> _lastMessageCache = {};

  // 패키지별 필터링
  String? _selectedPackageName;
  static const String _keyLastSelectedTab = 'chat_list_last_tab';
  bool _isProgrammaticPageChange = false; // 탭 클릭으로 animateToPage 중일 때 true
  final PageController _pageController = PageController();
  final ScrollController _tabScrollController = ScrollController();
  final Map<String, GlobalKey> _tabKeys = {};
  // 탭 드래그 중 좌/우 끝에서 자동 스크롤
  Timer? _tabAutoScrollTimer;
  static const double _tabAutoScrollEdge = 60.0;   // 가장자리 감지 영역
  static const double _tabAutoScrollSpeed = 10.0;  // 16ms 당 픽셀

  // 설정 버튼 클릭 카운터 (5번 누르면 플랜 선택)
  int _settingsClickCount = 0;
  DateTime? _lastSettingsClickTime;
  
  // 플랜 타입 캐시
  String? _cachedPlanType;
  
  // ✅ 핵심 수정: EventChannel 대신 DB Observer 사용
  // Native에서 DB에 저장 → Flutter가 주기적으로 DB 확인
  Timer? _dbObserverTimer;
  DateTime? _lastCheckTime;
  // DB Observer 의 전체 리로드가 진행 중인지 — 버스트(안읽음 급증) 시 중복 리로드 코얼레싱.
  bool _observerReloadInFlight = false;

  // 알림 권한 대기 상태
  bool _wasWaitingForPermission = false;

  // 알림 다이얼로그 표시 중 플래그 (중복 방지)
  bool _isShowingNotificationDialog = false;

  // 읽지 않은 알림 개수 (배지 표시용)
  int _notificationCount = 0;
  
  // 버전 체크 완료 여부 (한 번만 체크)
  bool _hasCheckedVersion = false;

  // 상단 고정 네이티브 광고
  NativeAd? _topNativeAd;
  bool _isTopNativeLoaded = false;
  bool _showTopAdSlot = false; // ✅ 광고 실제 로드 완료 후에만 true
  Timer? _topNativeAdTimeoutTimer;
  // 콘솔 TopBanner 이미지 로딩 실패 시 AdMob/AdFit 폴백 트리거
  bool _topBannerImageFailed = false;

  // 비-첫탭 상단 AdMob 광고 — 탭(패키지)별 별도 인스턴스.
  // 첫 탭은 위 _topNativeAd(preload 등 정교한 흐름)를 그대로 쓰고,
  // 나머지 탭은 "그 탭이 실제로 보일 때만" 단순 로드 → 모든 탭에서 상단 배너 노출.
  // 상단 광고는 탭 전환 시 한 번에 한 화면만 보이므로(동시 노출 X) 같은 unit ID 재사용해도
  // invalid impression 우려 없음. 로드는 노출 직전(active tab)에만 → "loaded but not shown" 회피.
  final Map<String, NativeAd> _tabTopAds = {};
  final Map<String, bool> _tabTopAdLoaded = {};

  // 채팅방 목록 네이티브 광고 — 슬롯 4·8…을 탭(패키지)별 인스턴스로 관리.
  // 키: "$pkg|$slot" (예: "com.kakao.talk|4"). 모든 탭이 광고를 그리되 각 탭은
  // 자기 패키지 키의 별도 NativeAd 인스턴스를 쓰므로 같은 AdWidget 이 두 탭에
  // 동시 mount 되는 크래시가 없다(인스턴스가 다르면 OK). 로드는 그 탭이 실제로
  // 빌드될 때 지연 로드(_buildAdMobListSlot → _ensureListAdLoaded).
  final Map<String, NativeAd> _listNativeAds = {};
  final Map<String, bool> _listNativeAdLoaded = {};
  final Map<String, Timer> _listNativeAdTimeoutTimers = {};
  // AdSlotResolver의 admob 슬롯과 동일하게 4·8·12·16·20·24·28·32 (slot별 별개 unit ID).
  static const List<int> _admobListSlots = [4, 8, 12, 16, 20, 24, 28, 32];
  String _listAdKey(String pkg, int slot) => '$pkg|$slot';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initProfileService();
    _initializeAndLoadRooms(); // FAQ 채팅방 확인 및 생성 후 대화목록 로드
    _loadNotificationCount(); // 알림 배지 개수 로드
    _startDbObserver(); // ✅ 핵심 수정: DB Observer 시작 (EventChannel 대신)
    _preloadPlanType(); // ✅ 플랜 타입 미리 로드 (컨텍스트 메뉴 지연 방지)
    _loadNativeAds(); // 네이티브 광고 로드 (채팅방과 동시)
    _planService.planTypeNotifier.addListener(_onPlanTypeChanged);
    _restoreLastSelectedTab(); // 마지막 선택된 탭 복원
    _showHomePopups(); // 콘솔 등록 공지/광고 팝업 (있을 때만 1회)
  }

  /// 진입 후 잠깐 지연 두고 콘솔 팝업 표시.
  /// 공지(type=popup)가 있으면 그것 우선, 없으면 광고 팝업 시도.
  /// 둘 다 표시 정책(스킵·1회) 내장이라 호출만 하면 됨.
  void _showHomePopups() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () async {
        if (!mounted) return;
        await PopupNoticeDialog.showIfEligible(context);
        if (!mounted) return;
        // chat_llm 은 PlanService 가 있으니 plan 전달 — 베이직 구독자에게는
        // hide_for_subscribers=1 광고가 서버에서 자동 제외됨.
        // cta_type='internal' 광고 클릭 시 cta_url 식별자 보고 라우팅 분기.
        await PopupAdDialog.showIfEligible(
          context,
          plan: PlanService().getCachedPlanTypeSync(),
          onInternalTap: (ctx, url) {
            Widget target;
            switch (url) {
              case '/subscribe':
                target = const SubscriptionScreen();
                break;
              // 미래 확장 자리 — 새 내부 화면 추가 시 case 한 줄만:
              // case '/events':
              //   target = const EventListScreen();
              //   break;
              default:
                target = const SubscriptionScreen(); // 알 수 없는 식별자는 구독으로
            }
            Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => target));
          },
        );
      });
    });
  }

  /// 마지막으로 선택된 메신저 탭을 SharedPreferences에서 복원
  /// _selectedPackageName의 유일한 초기화 지점 (_buildPackageTabs race condition 방지)
  Future<void> _restoreLastSelectedTab() async {
    // main()에서 unawaited로 호출된 initialize()가 완료되지 않았을 수 있으므로
    // _cachedEnabledPackages가 실제 데이터로 채워지도록 보장
    await MessengerSettingsService().initialize();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = prefs.getString(_keyLastSelectedTab);
    final messengers = MessengerSettingsService().getEnabledMessengers();
    if (messengers.isEmpty) return;

    final target = (saved != null && messengers.any((m) => m.packageName == saved))
        ? saved
        : messengers.first.packageName;

    setState(() => _selectedPackageName = target);
    final idx = messengers.indexWhere((m) => m.packageName == target);
    if (idx > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(idx);
        }
      });
    }
  }

  /// 선택된 탭을 SharedPreferences에 저장
  Future<void> _saveSelectedTab(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSelectedTab, packageName);
  }

  /// FAQ 채팅방 확인 및 생성 후 대화목록 로드
  Future<void> _initializeAndLoadRooms() async {
    // FAQ 채팅방 확인 및 생성
    await _checkAndCreateFAQRoom();
    // 대화목록 로드
    _loadChatRooms();
  }

  /// FAQ 채팅방 확인 및 생성 (하루에 한 번만)
  Future<void> _checkAndCreateFAQRoom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const lastFAQCheckKey = 'last_faq_room_check_time';
      const checkIntervalHours = 24; // 24시간마다 체크
      
      // 마지막 체크 시간 확인
      final lastCheckTimeMillis = prefs.getInt(lastFAQCheckKey);
      if (lastCheckTimeMillis != null) {
        final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheckTimeMillis);
        final hoursSinceLastCheck = DateTime.now().difference(lastCheckTime).inHours;
        
        if (hoursSinceLastCheck < checkIntervalHours) {
          // debugPrint('⏭️ FAQ 채팅방 체크 스킵: ${hoursSinceLastCheck}시간 전에 체크됨 (${checkIntervalHours}시간 간격)');
          return;
        }
      }
      
      debugPrint('🔄 FAQ 채팅방 체크 시작');
      final created = await _localDb.createFAQRoomIfNeeded();
      if (created) {
        debugPrint('✅ FAQ 채팅방이 새로 생성되었습니다.');
      }
      
      // 체크 시간 저장
      await prefs.setInt(lastFAQCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('FAQ 채팅방 생성 실패: $e');
    }
  }

  /// 읽지 않은 알림 개수 로드 (배지 표시용)
  Future<void> _loadNotificationCount() async {
    try {
      final count = await _localDb.getUnreadNotificationCount();
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      debugPrint('알림 개수 로드 실패: $e');
    }
  }

  /// 플랜 타입 미리 로드 (백그라운드에서 비동기 실행)
  /// 컨텍스트 메뉴에서 동기 메서드로 캐시된 값을 사용하기 위함
  void _preloadPlanType() {
    _planService.getCurrentPlanType().then((planType) {
      debugPrint('✅ 플랜 타입 미리 로드 완료: $planType');
    }).catchError((e) {
      debugPrint('⚠️ 플랜 타입 미리 로드 실패: $e');
    });
  }

  /// 선택 업데이트 체크 (대화 목록 로드 시).
  /// 부트스트랩 결과의 [UpdatePolicy]를 SharedPreferences 스킵 정책과 함께 처리.
  ///
  /// charge `_handleUpdateGate` 패턴: 선택 업데이트는 먼저 구글 인앱 업데이트
  /// (flexible)를 시도하고, 시작되지 않으면 커스텀 다이얼로그로 폴백한다.
  Future<void> _checkOptionalUpdate() async {
    try {
      final policy = DkswCore.lastBootstrap?.update;
      if (policy == null) return;
      if (!policy.optionalUpdate || policy.forceUpdate) return; // 강제는 main에서 처리

      // ① 구글 인앱 업데이트(flexible) 먼저 시도.
      final result = await AppUpdater.tryFlexibleUpdate();
      if (result == InAppUpdateResult.started) {
        debugPrint('[UpdateGate] 인앱 업데이트(flexible) 시작 — 다이얼로그 생략');
        return;
      }

      // ② 시작 안 되면(미지원/불가/실패) 커스텀 다이얼로그로 폴백.
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            UpdateDialog.showIfNeeded(context, policy);
          }
        });
      }
    } catch (e) {
      debugPrint('선택 업데이트 체크 실패: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 포그라운드로 돌아올 때 대화목록 자동 새로고침 및 DB Observer 재시작
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 ChatRoomListScreen: 앱 포그라운드 복귀 - 대화목록 새로고침 및 DB Observer 재시작');
      _loadChatRooms();
      // ✅ 핵심 수정: 포그라운드 복귀 시 DB Observer 재시작
      _startDbObserver();
      // 유료 전환 시 광고 슬롯 즉시 숨김
      _refreshAdSlotVisibility();
      // 단가 높은 AdMob 재시도: 세션 중 한 번 AdFit으로 폴백되면 다시는
      // AdMob을 안 띄우므로, 포그라운드 복귀 시점에 재시도 기회를 준다.
      _retryAdMobIfFallback();
      
      // 알림 권한 허용 후 돌아오면 자동으로 알림 켜기
      if (_wasWaitingForPermission) {
        _wasWaitingForPermission = false;
        _checkAndEnableNotificationsAfterPermission();
      }
    }
  }

  void _onPlanTypeChanged() {
    _refreshAdSlotVisibility();
  }

  @override
  void dispose() {
    _planService.planTypeNotifier.removeListener(_onPlanTypeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _dbObserverTimer?.cancel(); // ✅ 핵심 수정: DB Observer 중지
    _topNativeAdTimeoutTimer?.cancel();
    for (final t in _listNativeAdTimeoutTimers.values) {
      t.cancel();
    }
    _listNativeAdTimeoutTimers.clear();
    _topNativeAd?.dispose();
    for (final ad in _tabTopAds.values) {
      ad.dispose();
    }
    _tabTopAds.clear();
    for (final ad in _listNativeAds.values) {
      ad.dispose();
    }
    _listNativeAds.clear();
    _pageController.dispose();
    _tabScrollController.dispose();
    _tabAutoScrollTimer?.cancel();
    super.dispose();
  }

  /// 광고 슬롯 표시 여부 재확인 (포그라운드 복귀 시).
  /// 배너(상단 + 목록) 네이티브 광고는 플랜과 무관하게 항상 노출하므로
  /// 유료 전환 시에도 제거하지 않는다. 아직 로드 전이면 로드만 보장.
  Future<void> _refreshAdSlotVisibility() async {
    if (!_showTopAdSlot) {
      _loadNativeAds();
    }
  }

  /// 포그라운드 복귀 시 AdMob 재시도.
  /// 타임아웃/실패로 AdFit 폴백 중인 슬롯에 대해 AdMob을 다시 로드한다.
  /// AdMob이 실제로 로드되면 render 우선순위에 따라 AdFit을 밀어내고 표시됨.
  void _retryAdMobIfFallback() {
    if (kIsWeb) return;
    if (!_showTopAdSlot) return; // 무료 플랜이 아니면 슬롯 자체가 꺼져 있음
    final adService = AdService();
    if (AdService.useAdFitOnlyOnAndroid && !kIsWeb && Platform.isAndroid) {
      return; // AdFit 전용 모드면 재시도 의미 없음
    }

    bool needRetry = false;

    // 상단: AdFit 폴백 중이고 AdMob 인스턴스가 없으면 재시도
    if (adService.useAdFitForTop && _topNativeAd == null) {
      adService.resetTopAdFallback();
      needRetry = true;
    }

    // 목록: 어떤 슬롯이라도 AdFit 폴백 중이면 모두 해제하고 재시도
    if (adService.anyListSlotInAdFitFallback) {
      adService.resetAllListAdFallbacks();
      needRetry = true;
    }

    if (needRetry) {
      debugPrint('🔁 포그라운드 복귀 - AdMob 재시도');
      _startNativeAdLoadAfterInit(); // 상단 재시도
      // 목록 슬롯은 폴백 해제 후 리빌드 시 _ensureListAdLoaded 가 지연 재로드한다.
      if (mounted) setState(() {});
    }
  }

  /// 네이티브 광고 로드 (Free 티어만)
  /// 캐시된 플랜으로 즉시 광고 로드 시작 → 서버 확인은 병렬로 처리 (지연 최소화)
  Future<void> _loadNativeAds() async {
    // AdMob 네이티브(iOS 등)는 MobileAds.initialize 이후에 로드해야 AdWidget 플랫폼 뷰 오류를 줄임
    await AdService().initialize();

    // 배너(상단 + 채팅방 사이 목록) 네이티브 광고는 **플랜과 무관하게 항상 노출**한다.
    // 구독(유료)자도 배너는 유지 — 유료에서 빠지는 건 리워드/전면광고뿐이며,
    // 그 제외는 AdService.showRewardedAd / showExitAd / showChatDetailAd 에서 처리된다.
    _startNativeAdLoad();
  }

  /// ✅ 캐시된 광고 초기화 (제거됨 - 슬롯 미리 예약 안 함)

  /// 실제 NativeAd 객체 생성 및 로드 (중복 호출 방지 포함)
  void _startNativeAdLoad() {
    final adService = AdService();
    // debugPrint('▶️ _startNativeAdLoad 시작 — useAdFitForTop=${adService.useAdFitForTop}, useAdFitForList=${adService.useAdFitForList}');
    // AdService.initialize()보다 목록이 먼저 뜰 수 있음 — Android AdFit 전용이면 AdMob 네이티브 시도 전에 플래그 동기화
    if (!kIsWeb && Platform.isAndroid && AdService.useAdFitOnlyOnAndroid) {
      adService.switchTopAdToAdFit();
      for (final slot in _admobListSlots) {
        adService.switchListAdToAdFit(slot);
      }
    }

    // 슬롯 공간을 즉시 예약 → 광고 로드 동안 placeholder 표시, 로드되면 자연스럽게 채워짐 (레이아웃 점프 방지)
    if (mounted && !_showTopAdSlot) {
      setState(() => _showTopAdSlot = true);
    }

    // 첫 설치 시 AdMob SDK 콜드 스타트(3~7초)가 2.5초 타임아웃보다 길어
    // AdFit으로 자동 전환되는 문제 방지 — SDK 초기화 완료 후 광고 생성·타임아웃 시작.
    unawaited(adService.initialize().then((_) {
      if (!mounted) return;
      _startNativeAdLoadAfterInit();
    }));
  }

  void _startNativeAdLoadAfterInit() {
    final adService = AdService();

    // 콘솔 등록 top banner가 bypass=true 면 AdMob 요청 자체를 skip.
    // "loaded but not shown" 패턴은 AdMob 정책상 invalid impression 으로
    // 분류될 수 있어 요청 단계에서 막는다.
    final topBypassActive = TopBannerCache.current?.bypassAdmob == true;
    if (topBypassActive) {
      debugPrint('⏭️ 상단 — TopBanner bypass=true, AdMob 요청 skip');
    }

    // 상단 광고 - 이미 존재하면 재생성 금지
    final preloadedTop = (_topNativeAd == null && !adService.useAdFitForTop && !topBypassActive)
        ? adService.takePreloadedTopAd()
        : null;
    if (preloadedTop != null) {
      // 스플래시 동안 preload 된 광고 — 즉시 사용 (깜빡임 X)
      _topNativeAd = preloadedTop;
      _topNativeAdTimeoutTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _showTopAdSlot = true;
            _isTopNativeLoaded = true;
          });
        }
      });
      debugPrint('🎯 상단 네이티브 광고 — preload 즉시 사용');
    } else if (_topNativeAd == null && !adService.useAdFitForTop && !topBypassActive &&
        adService.isTopPreloadInFlight) {
      // preload 가 아직 로딩 중 — 새 ad 를 만들지 말고(중복 로드 방지) 완료를 기다린다.
      // 완료되면 그 광고를 그대로 꽂아 정상 노출 → AdMob 정책상 깨끗한 1요청·1노출.
      debugPrint('⏳ 상단 — preload 로딩 중, 완료 대기 (중복 로드 안 함)');
      if (!_showTopAdSlot) {
        setState(() => _showTopAdSlot = true);
      }
      adService.onTopPreloadReady = () {
        if (!mounted) return;
        final ad = adService.takePreloadedTopAd();
        if (ad != null) {
          _topNativeAd = ad;
          _topNativeAdTimeoutTimer?.cancel();
          // 타임아웃으로 AdFit 이 임시 표시 중이어도 단가 높은 AdMob 우선.
          adService.resetTopAdFallback();
          setState(() {
            _showTopAdSlot = true;
            _isTopNativeLoaded = true;
          });
          debugPrint('🎯 상단 네이티브 광고 — preload 완료 후 사용');
        } else {
          // preload 실패 → AdFit 폴백 (타임아웃 기다리지 않고 즉시)
          _topNativeAdTimeoutTimer?.cancel();
          adService.switchTopAdToAdFit();
          setState(() {
            _showTopAdSlot = true;
            _isTopNativeLoaded = false;
          });
          debugPrint('❌ 상단 preload 실패 → AdFit 폴백');
        }
      };
      // 타임아웃→AdFit 제거: preload 완료/실패 콜백(onTopPreloadReady)만 기다린다.
      // 로딩 동안은 고정높이 placeholder 가 자리를 지키고, 실패 시에만 위에서 AdFit 폴백.
    } else if (_topNativeAd == null && !adService.useAdFitForTop && !topBypassActive) {
      _topNativeAd = NativeAd(
        adUnitId: AdService.nativeTopFixedId,
        factoryId: AdService.nativeTopAdFactoryId,
        listener: NativeAdListener(
          onAdLoaded: (ad) {
            _topNativeAdTimeoutTimer?.cancel();
            // stale 콜백 방지: 현재 맵의 광고와 동일한 인스턴스인지 확인
            if (mounted && _topNativeAd == ad) {
              // 타임아웃으로 AdFit이 잠시 표시되던 상황에서도 AdMob이 오면
              // 단가 높은 AdMob이 우선 노출되도록 폴백 플래그 해제.
              adService.resetTopAdFallback();
              setState(() {
                _showTopAdSlot = true; // ✅ 광고 로드 완료 후에만 슬롯 표시
                _isTopNativeLoaded = true;
              });
            }
            debugPrint('✅ 상단 네이티브 광고 로드 완료');
          },
          onAdFailedToLoad: (ad, error) {
            _topNativeAdTimeoutTimer?.cancel();
            debugPrint('❌ 상단 네이티브 광고 로드 실패: ${error.message}');
            if (_topNativeAd == ad) {
              ad.dispose();
              _topNativeAd = null;
              // AdMob 실패 → AdFit 폴백
              adService.switchTopAdToAdFit();
              if (mounted) {
                setState(() {
                  _isTopNativeLoaded = false;
                  _showTopAdSlot = true;
                });
              }
            }
          },
        ),
        request: const AdRequest(),
      );
      unawaited(_topNativeAd!.load());
      // 타임아웃→AdFit 제거: AdMob 콜백만 기다린다. 로딩 중엔 고정높이 placeholder 가
      // 자리를 지키고, onAdFailedToLoad(진짜 실패) 때만 위에서 AdFit 폴백으로 전환.
      // → AdFit 먼저 떴다 AdMob 으로 갈아치우는 더블 PlatformView mount 제거.
    } else if (adService.useAdFitForTop) {
      // 이미 애드핏으로 전환된 경우 슬롯 표시
      if (mounted) {
        setState(() {
          _showTopAdSlot = true;
        });
      }
    }

    // 채팅방 목록 광고는 **지연 로드**한다 — 8개를 마운트 시점에 한꺼번에 로드·마운트하면
    // PlatformView(AdWidget) 생성이 한 프레임에 몰려 스크롤이 버벅인다. 그래서 각 슬롯은
    // 화면 근처에서 빌드될 때(_buildAdMobListSlot → _ensureListAdLoaded) 비로소 로드해
    // PlatformView 생성을 스크롤 진행에 따라 분산시킨다.
    // (slot별 별도 NativeAd 인스턴스, AdFit 폴백 플래그도 slot별 분리 — _ensureListAdLoaded 참조)

    // 어떤 슬롯이라도 AdFit 폴백 상태면 UI 갱신
    if (adService.anyListSlotInAdFitFallback && mounted) {
      setState(() {});
    }
  }

  /// 목록 슬롯의 AdMob 네이티브를 **그 슬롯이 화면 근처에 올 때 1회** 로드.
  /// PlatformView mount 가 스크롤에 따라 분산되어 버벅임이 줄어든다.
  /// preload 된 광고가 있으면 즉시 사용. AdFit 폴백/​house bypass 슬롯은 skip.
  ///
  /// [pkg] 탭(메신저 패키지)별 별도 NativeAd 인스턴스를 만들어 같은 AdWidget
  /// 인스턴스가 두 탭에 동시 mount 되는 크래시를 회피한다. 키는 "$pkg|$slot".
  void _ensureListAdLoaded(String pkg, int slot) {
    final adService = AdService();
    final key = _listAdKey(pkg, slot);
    if (_listNativeAds.containsKey(key)) return; // 이미 로드/로딩 중
    if (adService.useAdFitForListSlot(slot)) return; // AdFit 모드 → 위젯이 렌더

    // 콘솔 house ad bypass=true 면 AdMob 요청 자체 skip ("loaded but not shown" 회피).
    final houseOverride = HouseAdCache.at(slot);
    if (houseOverride != null && houseOverride.bypassAdmob) return;

    // 스플래시 동안 preload 된 광고가 있으면 즉시 사용 (깜빡임 X).
    // preload 인스턴스는 슬롯당 1개라 take() 한 탭만 가져가고(소비), 나머지 탭은
    // 아래에서 새 NativeAd 를 생성한다 → 인스턴스 공유 없음(AdWidget 안전).
    final preloadedList = adService.takePreloadedListAd(slot);
    if (preloadedList != null) {
      _listNativeAds[key] = preloadedList;
      _listNativeAdTimeoutTimers.remove(key)?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _listNativeAdLoaded[key] = true);
      });
      debugPrint('🎯 목록 네이티브 광고 — preload 즉시 사용 (slot=$slot, $pkg)');
      return;
    }
    final ad = NativeAd(
      adUnitId: AdService.listAdUnitId(slot),
      factoryId: AdService.nativeAdFactoryId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _listNativeAdTimeoutTimers.remove(key)?.cancel();
          if (mounted && _listNativeAds[key] == ad) {
            adService.resetListAdFallback(slot);
            setState(() => _listNativeAdLoaded[key] = true);
          }
          debugPrint('✅ 목록 네이티브 광고 로드 완료 (slot=$slot, $pkg)');
        },
        onAdFailedToLoad: (ad, error) {
          _listNativeAdTimeoutTimers.remove(key)?.cancel();
          debugPrint(
              '❌ 목록 네이티브 광고 로드 실패 (slot=$slot, $pkg): ${error.message}');
          if (_listNativeAds[key] == ad) {
            ad.dispose();
            _listNativeAds.remove(key);
            adService.switchListAdToAdFit(slot);
            if (mounted) setState(() => _listNativeAdLoaded[key] = false);
          }
        },
      ),
      request: const AdRequest(),
    );
    _listNativeAds[key] = ad;
    unawaited(ad.load());

    // 타임아웃 — AdMob 로드가 콜백 없이 멈추면(드물게 발생) 96dp 빈 슬롯이 오래 남는다.
    // AdMob 자체 no-fill 타임아웃(수십 초)을 기다리지 않고 6초 후 AdFit 폴백으로 전환
    // (onAdFailedToLoad 와 동일 처리) → 빈 자리 체류 시간 단축.
    _listNativeAdTimeoutTimers[key]?.cancel();
    _listNativeAdTimeoutTimers[key] = Timer(const Duration(seconds: 6), () {
      _listNativeAdTimeoutTimers.remove(key);
      if (_listNativeAdLoaded[key] == true) return; // 이미 로드됨
      if (_listNativeAds[key] != ad) return;        // 다른 인스턴스로 교체됨
      ad.dispose();
      _listNativeAds.remove(key);
      adService.switchListAdToAdFit(slot);
      if (mounted) setState(() => _listNativeAdLoaded[key] = false);
      debugPrint('⏱️ 목록 네이티브 광고 타임아웃 → AdFit 폴백 (slot=$slot)');
    });
  }

  /// 비-첫탭 상단 AdMob 광고 로드 — 해당 탭이 실제로 보일 때(active) 1회만.
  /// 같은 unit ID(_nativeTopFixedId)를 쓰지만 상단은 한 번에 한 탭만 보이므로 동시 노출 없음.
  void _loadTabTopAd(String pkg) {
    final adService = AdService();
    if (_tabTopAds.containsKey(pkg)) return; // 이미 로드/로딩 중
    if (adService.useAdFitForTop) return; // AdMob 불가 → AdFit 위젯이 렌더 (로드 불필요)
    if (TopBannerCache.current?.bypassAdmob == true) return; // 콘솔 TopBanner 대체 중
    if (kIsWeb || !Platform.isAndroid) {
      // iOS 등은 첫 탭과 동일 정책 — 단순화를 위해 비-첫탭 AdMob 생략(첫 탭 광고 유지).
    }
    final ad = NativeAd(
      adUnitId: AdService.nativeTopFixedId,
      factoryId: AdService.nativeTopAdFactoryId,
      listener: NativeAdListener(
        onAdLoaded: (loaded) {
          if (mounted && _tabTopAds[pkg] == loaded) {
            setState(() => _tabTopAdLoaded[pkg] = true);
          }
          debugPrint('✅ 탭 상단 네이티브 광고 로드 완료 ($pkg)');
        },
        onAdFailedToLoad: (failed, error) {
          debugPrint('❌ 탭 상단 네이티브 광고 로드 실패 ($pkg): ${error.message}');
          if (_tabTopAds[pkg] == failed) {
            failed.dispose();
            _tabTopAds.remove(pkg);
            // 실패 시 AdFit 폴백을 그 탭에 노출 (전역 플래그 전환)
            adService.switchTopAdToAdFit();
            if (mounted) setState(() => _tabTopAdLoaded[pkg] = false);
          }
        },
      ),
      request: const AdRequest(),
    );
    _tabTopAds[pkg] = ad;
    unawaited(ad.load());
  }

  /// ✅ 핵심 수정: DB Observer 시작 (EventChannel 대신)
  /// Native에서 DB에 저장 → Flutter가 주기적으로 DB 확인
  void _startDbObserver() {
    _dbObserverTimer?.cancel();
    _lastCheckTime = DateTime.now();
    
    // 1초마다 DB 변경 확인
    _dbObserverTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _checkDbChanges();
    });
    
    // debugPrint('✅ DB Observer 시작 (1초마다 확인)');
  }
  
  /// ✅ 핵심: DB 변경 확인 (updated_at 기준)
  Future<void> _checkDbChanges() async {
    // 직전 틱의 전체 리로드가 아직 진행 중이면 이번 틱은 건너뛴다.
    // 안읽음이 빠르게 쌓일 때(updated_at 잦은 변경) 전체 리로드+리빌드가 1초마다
    // 겹쳐 쌓이며 버벅이던 것 방지 — _lastCheckTime 을 갱신 안 하므로 다음 틱이
    // 누락 없이 모든 변경을 한 번에 흡수(버스트 코얼레싱).
    if (_observerReloadInFlight) return;
    try {
      final db = await _localDb.database;

      // 마지막 확인 시간 이후 업데이트된 채팅방 확인
      final lastCheckTimestamp = _lastCheckTime?.millisecondsSinceEpoch ?? 0;

      final updatedRooms = await db.query(
        'chat_rooms',
        columns: ['id', 'updated_at'],
        where: 'updated_at > ?',
        whereArgs: [lastCheckTimestamp],
      );

      if (updatedRooms.isNotEmpty) {
        debugPrint('🔄 DB 변경 감지: ${updatedRooms.length}개 채팅방 업데이트됨');
        // 변경이 있으면 목록 새로고침 (코얼레싱 가드로 감쌈)
        _observerReloadInFlight = true;
        try {
          await _loadChatRooms(silent: true);
        } finally {
          _observerReloadInFlight = false;
        }
      }

      _lastCheckTime = DateTime.now();
    } catch (e) {
      debugPrint('❌ DB 변경 확인 실패: $e');
    }
  }

  /// 프로필 이미지 서비스 초기화
  Future<void> _initProfileService() async {
    try {
      await _profileService.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('프로필 서비스 초기화 실패: $e');
    }
  }

  /// 대화방의 프로필 이미지 파일 가져오기
  File? _getProfileImageFile(String roomName, String? packageName) {
    return _profileService.getRoomProfile(roomName, packageName);
  }

  /// 알림 권한 요청 (첫 진입 시, 가이드 건너뛰기/완료 후 메인에 진입했을 때만)
  /// 인앱 확인 다이얼로그 없이 바로 시스템 권한 다이얼로그 표시 (Android 13+)
  /// Android 12 이하는 앱 설정 화면으로 바로 이동
  Future<void> _showNotificationDialogIfNeeded() async {
    if (_isShowingNotificationDialog) return;

    try {
      final hasSeenGuide = await AppGuideScreen.hasSeenGuide();
      if (!hasSeenGuide) return;

      final prefs = await SharedPreferences.getInstance();
      final hasShown = prefs.getBool('has_shown_notification_dialog') ?? false;
      if (hasShown) return;

      final methodChannel = const MethodChannel('com.dksw.app/notification');
      final hasPermission =
          await methodChannel.invokeMethod<bool>('areNotificationsEnabled') ?? false;
      if (hasPermission) {
        await prefs.setBool('has_shown_notification_dialog', true);
        return;
      }

      if (!mounted) return;
      _isShowingNotificationDialog = true;
      await prefs.setBool('has_shown_notification_dialog', true);

      try {
        final raw = await methodChannel.invokeMethod<dynamic>('requestNotificationPermission');
        final map = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
        final fallback = map['fallbackToSettings'] == true;
        if (fallback) {
          _wasWaitingForPermission = true; // 설정 다녀오면 자동으로 알림 켜기
        }
      } catch (e) {
        debugPrint('알림 권한 요청 실패: $e');
      }
    } catch (e) {
      debugPrint('알림 권한 요청 준비 실패: $e');
    } finally {
      _isShowingNotificationDialog = false;
    }
  }

  /// 알림 권한 허용 후 처리.
  /// 주의: 채팅방별 음소거 설정(_mutedRooms)은 OS 권한과 무관하게 사용자가
  /// 직접 끈 설정이므로 이 시점에 일괄 해제하면 안 됨. 권한 확인 + 안내만.
  Future<void> _checkAndEnableNotificationsAfterPermission() async {
    try {
      final methodChannel = const MethodChannel('com.dksw.app/notification');
      final hasPermission = await methodChannel
              .invokeMethod<bool>('areNotificationsEnabled') ??
          false;
      if (hasPermission && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatList_notifPermGranted),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('알림 권한 확인 실패: $e');
    }
  }

  /// 외부에서 호출 가능한 채팅방 목록 새로고침
  void refreshRooms() {
    debugPrint('🔄 refreshRooms() 호출됨 - 대화방 목록 새로고침');
    // 즉시 실행하여 빠른 동기화 보장
    if (mounted) {
      _loadChatRooms(silent: true);
      _loadNotificationCount(); // 알림 배지 개수도 업데이트
    } else {
      debugPrint('⚠️ 위젯이 dispose됨 - refreshRooms() 스킵');
    }
  }

  /// 외부에서 호출 가능한 채팅방 업데이트 메서드
  void updateRoom(Map<String, dynamic> data) {
    final roomName = data['roomName'] as String? ?? '';

    // 프로필 이미지 캐시 무효화
    _profileService.invalidateRoomProfile(roomName);

    // 목록 새로고침
    _loadChatRooms();
  }

  Future<void> _loadChatRooms({bool silent = false, bool skipFAQCheck = false}) async {
    // ⚠️ 보수적 수정: silent 모드에서도 로그 출력 (대화목록 동기화 문제 디버깅용)
    if (silent) {
      debugPrint('🔄 _loadChatRooms(silent=true) 호출됨 - 대화방 목록 새로고침');
    }
    
    if (!silent) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
          _profileService.clearCache();
        });
      }
    }

    try {
      // FAQ 채팅방이 없으면 생성 (하루에 한 번만 확인)
      if (!skipFAQCheck) {
        await _checkAndCreateFAQRoom();
      }
      
      final rooms = await _localDb.getChatRooms();
      debugPrint('📋 DB에서 ${rooms.length}개 대화방 조회 완료');
      
      // 플랜 확인: Free 플랜이면 자동요약 설정 자동으로 끄기
      // ✅ 수정: 첫 설치 시 JWT 없으면 API 호출이 무한 대기해 스피너가 영원히 도는 버그 방지
      // 캐시된 값 우선 사용, 없으면 3초 타임아웃 후 'free' 기본값으로 처리
      final cachedPlan = _planService.getCachedPlanTypeSync();
      final planType = cachedPlan ?? await _planService.getCurrentPlanType().timeout(
        const Duration(seconds: 3),
        onTimeout: () => 'free',
      );
      final isBasicPlan = planType == 'basic';
      
      // Free 플랜이면 자동요약 설정이 켜져 있는 모든 대화방의 자동요약 끄기
      if (!isBasicPlan) {
        final updatedRooms = <ChatRoom>[];
        for (final room in rooms) {
          if (room.autoSummaryEnabled) {
            debugPrint('🔄 Free 플랜 감지: ${room.roomName}의 자동요약 설정 끄기');
            final updatedRoom = await _localDb.updateRoomSettings(
              room.id,
              autoSummaryEnabled: false,
            );
            if (updatedRoom != null) {
              updatedRooms.add(updatedRoom);
            } else {
              // 업데이트 실패 시 기존 room 사용하되 autoSummaryEnabled만 false로
              updatedRooms.add(room.copyWith(autoSummaryEnabled: false));
            }
          } else {
            updatedRooms.add(room);
          }
        }
        // 업데이트된 rooms 사용
        rooms.clear();
        rooms.addAll(updatedRooms);
      }
      
      // 각 채팅방의 최신 메시지 확인 (내가 보낸 메시지가 최신이면 그것을 표시)
      final messageCache = <int, String>{};
      for (final room in rooms) {
        try {
          final latestMessage = await _localDb.getLatestMessage(room.id);
          if (latestMessage != null) {
            final latestSender = latestMessage['sender'] as String;
            final latestMsg = latestMessage['message'] as String;
            
            // 최신 메시지가 내가 보낸 메시지면 그것을 표시
            if (latestSender == '나') {
              messageCache[room.id] = _formatMessageText(latestMsg);
            } else {
              // 최신 메시지가 내가 보낸 것이 아니면 room.lastMessage 표시
              messageCache[room.id] = _formatMessageText(room.lastMessage);
            }
          } else {
            // 최신 메시지가 없으면 room.lastMessage 표시
            messageCache[room.id] = _formatMessageText(room.lastMessage);
          }
        } catch (e) {
          debugPrint('최신 메시지 조회 실패 (roomId: ${room.id}): $e');
          messageCache[room.id] = _formatMessageText(room.lastMessage);
        }
      }
      
      if (!mounted) {
        debugPrint('⚠️ 위젯이 dispose됨 - UI 업데이트 스킵');
        return;
      }
      
      // silent 모드에서도 항상 업데이트하여 새 메시지 반영 보장
      final beforeCount = _chatRooms.length;
      setState(() {
        _chatRooms = rooms;
        _lastMessageCache.clear();
        _lastMessageCache.addAll(messageCache);
        _sortChatRooms(); // 정렬도 함께 수행
        // silent 모드에서도 로딩 상태를 false로 설정하여 UI가 업데이트되도록 함
        _isLoading = false;
      });
      
      // 최초 진입 시 알림 권한 요청 → 평점 안내 순서로 처리 (대화방 목록 로드 완료 후)
      // _loadChatRooms 가 한 세션에 여러 번 호출돼도 시퀀스는 한 번만 (entry count 부풀림 방지).
      if (!silent && _isLoading == false && !_ratingSequenceTriggered) {
        _ratingSequenceTriggered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          debugPrint('⭐ 알림/평점 시퀀스 시작 (silent=$silent)');
          // OS 알림(POST_NOTIFICATIONS) 권한 요청 — 권한 화면/온보딩 끝난 뒤
          // 채팅방 목록 첫 진입 시점에서 자연스러운 동선.
          await PushService.requestNotificationPermission();
          if (!mounted) return;
          await _showNotificationDialogIfNeeded();
          if (!mounted) return;
          // 알림 권한 처리가 끝난 뒤에 평점 안내 (다이얼로그 겹침 방지)
          await RatingPromptService.maybeShow(context);
        });
      } else {
        debugPrint('⭐ 알림/평점 시퀀스 스킵 (silent=$silent, isLoading=$_isLoading, triggered=$_ratingSequenceTriggered)');
      }
      
      // ⚠️ 보수적 수정: silent 모드에서도 로그 출력 (대화목록 동기화 확인용)
      if (silent) {
        debugPrint('✅ 대화방 목록 새로고침 완료: 이전 ${beforeCount}개 → 현재 ${_chatRooms.length}개 대화방');
        if (_chatRooms.isNotEmpty) {
          final latestRoom = _chatRooms.first;
          final lastMsg = latestRoom.lastMessage ?? '';
          final truncatedMsg = lastMsg.length > 30 ? '${lastMsg.substring(0, 30)}...' : lastMsg;
          debugPrint('   최신 대화방: ${latestRoom.roomName}, 마지막 메시지: $truncatedMsg, 읽지않음: ${latestRoom.unreadCount}');
        }
      }
      
      // 일반 업데이트 체크 (대화 목록 로드 시, silent 모드가 아니고 아직 체크하지 않았을 때만)
      if (!silent && mounted && !_hasCheckedVersion) {
        _hasCheckedVersion = true;
        _checkOptionalUpdate();
      } else {
        debugPrint('✅ UI 업데이트 완료: ${_chatRooms.length}개 대화방 표시');
      }
    } catch (e) {
      debugPrint('❌ 대화방 목록 로드 실패: $e');
      if (mounted) {
        setState(() {
          if (!silent) {
            _error = AppLocalizations.of(context).chatList_loadFailed;
          }
          // silent 모드에서도 로딩 상태를 false로 설정
          _isLoading = false;
        });
      }
    }
  }

  /// 특정 채팅방만 업데이트 (전체 새로고침 대신)
  Future<void> _updateSingleRoom(int roomId) async {
    try {
      // 해당 채팅방만 DB에서 조회
      final updatedRoom = await _localDb.getRoomById(roomId);
      if (updatedRoom == null) {
        debugPrint('⚠️ 채팅방을 찾을 수 없음: roomId=$roomId');
        return;
      }

      // 최신 메시지 확인
      String? latestMessageText;
      try {
        final latestMessage = await _localDb.getLatestMessage(roomId);
        if (latestMessage != null) {
          final latestSender = latestMessage['sender'] as String;
          final latestMsg = latestMessage['message'] as String;
          
          if (latestSender == '나') {
            latestMessageText = _formatMessageText(latestMsg);
          } else {
            latestMessageText = _formatMessageText(updatedRoom.lastMessage);
          }
        } else {
          latestMessageText = _formatMessageText(updatedRoom.lastMessage);
        }
      } catch (e) {
        debugPrint('최신 메시지 조회 실패 (roomId: $roomId): $e');
        latestMessageText = _formatMessageText(updatedRoom.lastMessage);
      }

      if (!mounted) return;

      // 목록에서 해당 채팅방 찾아서 업데이트
      setState(() {
        final index = _chatRooms.indexWhere((r) => r.id == roomId);
        if (index >= 0) {
          _chatRooms[index] = updatedRoom;
          if (latestMessageText != null) {
            _lastMessageCache[roomId] = latestMessageText;
          }
          _sortChatRooms();
          debugPrint('✅ 채팅방 업데이트 완료: ${updatedRoom.roomName} (읽지않음: ${updatedRoom.unreadCount})');
        } else {
          // 목록에 없으면 추가 (새 채팅방)
          _chatRooms.add(updatedRoom);
          if (latestMessageText != null) {
            _lastMessageCache[roomId] = latestMessageText;
          }
          _sortChatRooms();
          debugPrint('✅ 새 채팅방 추가: ${updatedRoom.roomName}');
        }
      });
    } catch (e) {
      debugPrint('❌ 채팅방 업데이트 실패 (roomId: $roomId): $e');
      // 실패 시 전체 새로고침 (fallback)
      _loadChatRooms(silent: true, skipFAQCheck: true);
    }
  }

  void _showRoomContextMenu(BuildContext context, ChatRoom room) {
    final notificationService =
        Provider.of<NotificationSettingsService>(context, listen: false);
    final isMuted = notificationService.isMuted(room.roomName, room.packageName, room.chatId);

    // 플랜 타입 확인 (베이직 플랜일 때만 자동 요약 설정 표시)
    // ✅ 동기 메서드 사용: API 호출 없이 캐시된 값 즉시 반환하여 UI 지연 방지
    final planType = _planService.getCachedPlanTypeSync();
    final isBasicPlan = planType == 'basic';

    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
              // 핸들바
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 대화방 이름
              Builder(
                builder: (context) {
                  final profileFile = _getProfileImageFile(room.roomName, room.packageName);
                  final isKakaoTalk = room.packageName == 'com.kakao.talk';
                  final isFAQ = room.packageName == 'com.dksw.app.faq';
                  ImageProvider? bgImage;
                  
                  // FAQ 채팅방은 AI 톡비서 로고 사용
                  if (isFAQ) {
                    bgImage = const AssetImage('assets/ai_talk.png');
                  } else if (profileFile != null && profileFile.existsSync()) {
                    bgImage = FileImage(profileFile);
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: bgImage == null
                              ? (isKakaoTalk ? const Color(0xFFFFE812) : AppTokens.accent2)
                              : AppTokens.accent2,
                          backgroundImage: bgImage,
                          child: bgImage == null
                              ? (isKakaoTalk
                                  ? const Icon(
                                      Icons.chat_bubble_rounded,
                                      color: Color(0xFF3C1E1E),
                                      size: 22,
                                    )
                                  : Text(
                                      room.roomName.isNotEmpty
                                          ? room.roomName[0]
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            room.roomName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF333333),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Divider(height: 1, color: Colors.grey[200]),
              const SizedBox(height: 8),
              // AI 요약 기능 켜기/끄기
              _buildMenuItem(
                icon: Icons.auto_awesome,
                title: room.summaryEnabled ? AppLocalizations.of(context).chatList_summaryToggleOff : AppLocalizations.of(context).chatList_summaryToggleOn,
                subtitle: room.summaryEnabled ? AppLocalizations.of(context).chatList_summaryEnabledSub : AppLocalizations.of(context).chatList_summaryDisabledSub,
                isEnabled: room.summaryEnabled,
                iconColor: room.summaryEnabled ? AppTokens.accent : null,
                onTap: () async {
                  Navigator.pop(context);
                  await _toggleSummaryEnabled(room);
                },
              ),
              // 자동요약기능설정 (AI 요약 기능이 켜져 있을 때 표시, Free는 잠금)
              if (room.summaryEnabled)
                _buildMenuItem(
                  icon: isBasicPlan ? Icons.schedule : Icons.lock_outline,
                  title: AppLocalizations.of(context).chatList_autoSummarySetting,
                  subtitle: isBasicPlan
                      ? (room.autoSummaryEnabled
                          ? AppLocalizations.of(context).chatList_autoSummaryReach(room.autoSummaryMessageCount)
                          : AppLocalizations.of(context).chatList_autoSummaryOff)
                      : AppLocalizations.of(context).chatList_basicOnly,
                  isEnabled: isBasicPlan && room.autoSummaryEnabled,
                  iconColor: isBasicPlan && room.autoSummaryEnabled ? AppTokens.accent : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (!isBasicPlan) {
                      PaywallBottomSheet.show(context, triggerFeature: '자동요약');
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UsageManagementScreen(initialRoomId: room.id),
                        ),
                      );
                    }
                  },
                ),
              // 읽음 처리 (unread가 있을 때만 표시)
              if (room.unreadCount > 0)
                _buildMenuItem(
                  icon: Icons.done_all,
                  title: AppLocalizations.of(context).chatList_markRead,
                  subtitle: AppLocalizations.of(context).chatList_markReadCount(room.unreadCount),
                  iconColor: AppTokens.accent,
                  onTap: () async {
                    Navigator.pop(context);
                    await _markSingleRoomAsRead(room);
                  },
                ),
              // 채팅방 상단 고정
              _buildMenuItem(
                icon: room.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                title: room.pinned ? AppLocalizations.of(context).chatList_pinOff : AppLocalizations.of(context).chatList_pinOn,
                isEnabled: room.pinned,
                iconColor: room.pinned ? AppTokens.accent : null,
                onTap: () async {
                  Navigator.pop(context);
                  await _togglePinned(room);
                },
              ),
              // 알림 켜기/끄기
              _buildMenuItem(
                icon: isMuted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
                title: isMuted ? AppLocalizations.of(context).chatList_muteOn : AppLocalizations.of(context).chatList_muteOff,
                isEnabled: !isMuted,
                iconColor: !isMuted ? AppTokens.accent : null,
                onTap: () async {
                  Navigator.pop(context);
                  // 라인인 경우 chatId를 우선 사용 (roomName이 랜덤으로 변할 수 있음)
                  await notificationService.toggleNotification(room.roomName, room.packageName, room.chatId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isMuted
                              ? AppLocalizations.of(context).chatList_roomNotifOn(room.roomName)
                              : AppLocalizations.of(context).chatList_roomNotifOff(room.roomName),
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              // 구분선
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Divider(height: 1, color: Colors.grey[200]),
              ),
              // 채팅방 차단 — 톤 통일 (절제된 회색)
              _buildMenuItem(
                icon: Icons.block_outlined,
                title: AppLocalizations.of(context).chatList_block,
                textColor: AppTokens.text2,
                iconColor: AppTokens.text2,
                onTap: () {
                  Navigator.pop(context);
                  _showBlockConfirmDialog(room);
                },
              ),
              // 대화방 삭제 — 톤 통일 (절제된 회색, confirm 단계에서만 warn 강조)
              _buildMenuItem(
                icon: Icons.delete_outline,
                title: AppLocalizations.of(context).chatList_deleteRoom,
                textColor: AppTokens.text2,
                iconColor: AppTokens.text2,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(room);
                },
              ),
              const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 설정 메뉴 표시
  void _showSettingsMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 모두 읽음 처리
            InkWell(
              onTap: () async {
                Navigator.pop(context);
                await _markAllAsRead();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Text(
                  AppLocalizations.of(context).chatList_markAllRead,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // 구분선
            Divider(height: 1, color: Colors.grey[200]),
            // 앱 설정
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AppSettingsScreen(),
                  ),
                ).then((_) {
                  _loadChatRooms();
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Text(
                  AppLocalizations.of(context).chatList_appSettings,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 단일 채팅방 읽음 처리
  Future<void> _markSingleRoomAsRead(ChatRoom room) async {
    try {
      await _localDb.markRoomAsRead(room.id!);
      if (mounted) {
        setState(() {
          final idx = _chatRooms.indexWhere((r) => r.id == room.id);
          if (idx >= 0) {
            _chatRooms[idx] = _chatRooms[idx].copyWith(unreadCount: 0);
          }
        });
      }
    } catch (e) {
      debugPrint('읽음 처리 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatList_markReadFailed),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// 모든 채팅방 읽음 처리
  Future<void> _markAllAsRead() async {
    try {
      await _localDb.markAllRoomsAsRead();
      if (mounted) {
        setState(() {
          // 모든 채팅방의 unreadCount를 0으로 업데이트
          for (var i = 0; i < _chatRooms.length; i++) {
            _chatRooms[i] = _chatRooms[i].copyWith(unreadCount: 0);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatList_allMarkedRead),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('모두 읽음 처리 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatList_markReadFailed),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// AI 요약 기능 토글
  Future<void> _toggleSummaryEnabled(ChatRoom room) async {
    final newSummaryEnabled = !room.summaryEnabled;

    // AI 요약 기능을 끄면 자동요약 기능도 함께 끄기
    final newAutoSummaryEnabled = newSummaryEnabled ? room.autoSummaryEnabled : false;

    final result = await _localDb.updateRoomSettings(
      room.id,
      summaryEnabled: newSummaryEnabled,
      autoSummaryEnabled: newAutoSummaryEnabled,
    );

    if (result != null && mounted) {
      setState(() {
        final index = _chatRooms.indexWhere((r) => r.id == room.id);
        if (index >= 0) {
          _chatRooms[index] = room.copyWith(
            summaryEnabled: newSummaryEnabled,
            autoSummaryEnabled: newAutoSummaryEnabled,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newSummaryEnabled
              ? AppLocalizations.of(context).chatList_summaryOn
              : AppLocalizations.of(context).chatList_summaryOff),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatList_summaryToggleFailed),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// 채팅방 상단 고정 토글
  Future<void> _togglePinned(ChatRoom room) async {
    final newPinned = !room.pinned;
    final result = await _localDb.updateRoomSettings(room.id, pinned: newPinned);

    if (result != null && mounted) {
      setState(() {
        final index = _chatRooms.indexWhere((r) => r.id == room.id);
        if (index >= 0) {
          _chatRooms[index] = room.copyWith(pinned: newPinned);
          _sortChatRooms();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newPinned ? AppLocalizations.of(context).chatList_pinned : AppLocalizations.of(context).chatList_unpinned),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 채팅방 목록 정렬 (고정 우선, 최신 메시지 순)
  void _sortChatRooms() {
    _chatRooms.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? textColor,
    bool? isEnabled,
    Color? iconColor,
  }) {
    // 아이콘 색상 결정
    final finalIconColor = iconColor ??
        (isEnabled == true ? AppTokens.accent : (textColor ?? const Color(0xFF555555)));
    // 아이콘 배경색 결정
    final iconBgColor = textColor == Colors.red
        ? Colors.red.withOpacity(0.1)
        : textColor == Colors.orange
            ? Colors.orange.withOpacity(0.1)
            : (isEnabled == true
                ? AppTokens.accent.withOpacity(0.1)
                : Colors.grey.withOpacity(0.08));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: finalIconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor ?? const Color(0xFF333333),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isEnabled != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isEnabled == true
                      ? AppTokens.accent.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isEnabled == true ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: isEnabled == true ? AppTokens.accent : Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemWithCustomIcon({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Color? textColor,
    bool? isEnabled,
    Color? iconColor,
    bool showSlash = false,
  }) {
    // 아이콘 색상 결정: iconColor가 지정되면 사용, 없으면 isEnabled에 따라 파란색 또는 기본색
    final finalIconColor = iconColor ?? (isEnabled == true ? AppTokens.accent : (textColor ?? Colors.black87));
    
    return ListTile(
      leading: showSlash
          ? Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: finalIconColor),
                CustomPaint(
                  size: const Size(24, 24),
                  painter: SlashPainter(),
                ),
              ],
            )
          : Icon(icon, color: finalIconColor),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            )
          : null,
      onTap: onTap,
    );
  }

  /// 대화방 차단 확인 다이얼로그
  void _showBlockConfirmDialog(ChatRoom room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).chatList_block),
        content: Text(AppLocalizations.of(context).chatList_blockConfirmMsg(room.roomName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).chatList_cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _blockRoom(room);
            },
            style: TextButton.styleFrom(foregroundColor: AppTokens.accent),
            child: Text(AppLocalizations.of(context).chatList_blockConfirm),
          ),
        ],
      ),
    );
  }

  /// 대화방 차단
  Future<void> _blockRoom(ChatRoom room) async {
    final result = await _localDb.updateRoomSettings(room.id, blocked: true);

    if (result != null && mounted) {
      setState(() {
        _chatRooms.removeWhere((r) => r.id == room.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).chatList_roomBlocked(room.roomName)),
          duration: const Duration(seconds: 1),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).chatList_blockFailed),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 대화방 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(ChatRoom room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).chatList_deleteRoom),
        content: Text(AppLocalizations.of(context).chatList_deleteRoomConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).chatList_cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _localDb.deleteRoom(room.id);
              if (!mounted) return;

              if (success) {
                setState(() {
                  _chatRooms.removeWhere((r) => r.id == room.id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).chatList_roomDeleted(room.roomName)),
                    duration: const Duration(seconds: 1),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).chatList_deleteRoomFailed),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTokens.accent),
            child: Text(AppLocalizations.of(context).chatList_delete),
          ),
        ],
      ),
    );
  }

  /// 마지막 메시지 포맷팅 (캐시에서 가져오기)
  String _formatLastMessage(ChatRoom room) {
    return _lastMessageCache[room.id] ?? _formatMessageText(room.lastMessage);
  }
  
  /// 메시지 텍스트 포맷팅 (공통 로직)
  String _formatMessageText(String? message) {
    if (message == null || message.isEmpty) return '';
    
    // [IMAGE:경로] 패턴 제거
    final imagePattern = RegExp(r'\[IMAGE:(.+?)\]');
    final hasImage = imagePattern.hasMatch(message);
    String formattedMessage = message.replaceAll(imagePattern, '').trim();
    
    // 이미지만 있고 텍스트가 없으면 원본 메시지에서 이모티콘/스티커 여부 확인
    if (formattedMessage.isEmpty && hasImage) {
      final isEmojiOrSticker = message.contains('이모티콘') || message.contains('스티커');
      return isEmojiOrSticker ? AppLocalizations.of(context).chatList_sentEmoji : AppLocalizations.of(context).chatList_sentPhoto;
    }
    
    // 이미지와 텍스트가 모두 있으면 텍스트만 반환
    return formattedMessage;
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return DateFormat('a h:mm', 'ko_KR').format(time);
    } else if (diff.inDays == 1) {
      return '어제';
    } else if (diff.inDays < 7) {
      return DateFormat('E', 'ko_KR').format(time);
    } else {
      return DateFormat('M월 d일').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationSettingsService>(context);

    return Scaffold(
      // backgroundColor 는 global theme(AppTokens.bg) 사용
      appBar: AppBar(
        // 색·타이틀 폰트는 global appBarTheme 적용. AppLogo 만 leading 으로 주입.
        titleSpacing: 8,
        title: Row(
          children: const [
            AppLogo(),
            SizedBox(width: 10),
            Text('AI 톡비서'),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                color: AppTokens.text2,
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationListScreen(),
                    ),
                  );
                  _loadNotificationCount();
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTokens.accent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _notificationCount > 99 ? '99+' : '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_rounded, color: AppTokens.text2),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: (value) async {
              if (value == 'mark_all_read') {
                await _markAllAsRead();
              } else if (value == 'app_settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AppSettingsScreen(),
                  ),
                ).then((_) {
                  _loadChatRooms();
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'mark_all_read',
                child: Text(AppLocalizations.of(context).chatList_markAllRead),
              ),
              PopupMenuItem<String>(
                value: 'app_settings',
                child: Text(AppLocalizations.of(context).chatList_appSettings),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 패키지별 탭 필터
          _buildPackageTabs(),
          // 채팅방 목록 (PageView로 탭 전환 - 손가락 따라 화면 이동)
          // 상단 네이티브 광고는 각 탭 CustomScrollView 첫 sliver로 들어가 목록과
          // 함께 스크롤 아웃된다 (sticky 방지). 목록 중간 광고는 각 탭이 자기 패키지
          // 키("$pkg|$slot")의 별도 NativeAd 인스턴스를 그려 AdWidget 충돌을 피한다.
          Expanded(
            child: Builder(
              builder: (context) {
                final messengers = MessengerSettingsService().getEnabledMessengers();
                if (messengers.isEmpty) {
                  return Center(child: Text(AppLocalizations.of(context).chatList_noEnabledMessengers));
                }
                return PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    // 탭 클릭으로 animateToPage 중일 때는 중간 페이지 변경 무시
                    if (_isProgrammaticPageChange) return;
                    if (index < messengers.length) {
                      final packageName = messengers[index].packageName;
                      setState(() => _selectedPackageName = packageName);
                      _scrollToSelectedTab(packageName);
                      _saveSelectedTab(packageName);
                    }
                  },
                  itemCount: messengers.length,
                  itemBuilder: (context, pageIndex) {
                    final pagePackageName = messengers[pageIndex].packageName;
                    if (_isLoading) {
                      // native splash 가 떨어진 직후 마운트되는 첫 화면.
                      // 시각 점프 없게 native splash 톤(흰 배경 + 가운데 로고)과 동일하게.
                      return Container(
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 140,
                          height: 140,
                          child: Image(
                            image: AssetImage('assets/ai_talk.png'),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      );
                    }
                    if (_error != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(_error!, style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadChatRooms,
                              child: Text(AppLocalizations.of(context).chatList_retry),
                            ),
                          ],
                        ),
                      );
                    }
                    final filteredRooms = _getFilteredRoomsForPackage(pagePackageName);
                    if (filteredRooms.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(AppLocalizations.of(context).chatList_noRooms,
                                style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context).chatList_noRoomsForPkg(_getPackageDisplayName(pagePackageName)),
                              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: _loadChatRooms,
                      color: AppTokens.accent,
                      child: _buildChatListWithAd(
                        notificationService,
                        packageName: pagePackageName,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 목록 중간 광고 우측: 채팅 행의 시간·메뉴 줄과 비슷한 시각적 무게 (⋯만, AD 문구 없음)
  Widget _buildMidListAdRightGutter() {
    // AdFit 네이티브 레이아웃 안에서 "광고" 표기를 처리하므로,
    // Flutter 쪽은 우측 여백만 남겨 채팅 타일과 리듬만 맞춥니다.
    return const SizedBox(width: 40);
  }

  /// 상단 AdFit 네이티브 — 카드 전폭 (Flutter 쪽 ⓘ/AD 오버레이 없음, 「광고」 문구는 XML 내)
  /// [keySuffix]: 탭(패키지)별 별도 PlatformView 인스턴스를 위해 위젯 키 분리.
  Widget _buildTopAdFitChatListChrome({String? keySuffix}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: AdFitNativeTopAdWidget(
        key: ValueKey<String>('adfit_native_top_${keySuffix ?? 'first'}'),
        adCode: AdService.adFitTopNativeCode,
      ),
    );
  }

  /// 목록 중간 AdFit: 채팅 타일과 동일 좌우 14·하단 구분선, AD는 네이티브 행 안에 표시
  Widget _buildMidListAdFitChrome(String? packageName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 14, right: 6, top: 0, bottom: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: AdFitNativeListAdWidget(
              key: ValueKey<String>('adfit_native_list_${packageName ?? 'all'}'),
              adCode: AdService.adFitChatListBannerCode,
            ),
          ),
          _buildMidListAdRightGutter(),
        ],
      ),
    );
  }

  /// 상단 공유 네이티브 광고 — PageView 밖에 한 번만 렌더링.
  /// AdMob NativeAd는 인스턴스당 하나의 AdWidget만 허용하므로 부모 레벨에 고정.
  /// 렌더 우선순위:
  ///   1. 콘솔 등록 TopBanner + bypass=true → AdMob 자리 가로채 노출
  ///   2. AdMob (단가↑)
  ///   3. AdFit 폴백
  ///   4. 빈 슬롯 placeholder
  /// TopBanner 이미지 로딩 실패 시 [_topBannerImageFailed]가 켜져 다음 build에서 2~4 흐름 복귀.
  Widget _buildSharedTopAd() {
    final adService = AdService();

    // 1) 콘솔 TopBanner + bypass=true (이미지 실패 안 한 경우)
    final topBanner = TopBannerCache.current;
    if (topBanner != null &&
        topBanner.bypassAdmob &&
        !_topBannerImageFailed) {
      return TopBannerView(
        ad: topBanner,
        onImageError: () {
          if (!mounted || _topBannerImageFailed) return;
          debugPrint('⚠️ TopBanner 이미지 로딩 실패 → AdMob/AdFit 폴백');
          setState(() => _topBannerImageFailed = true);
        },
      );
    }

    if (_isTopNativeLoaded && _topNativeAd != null) {
      return _buildTopAdContainer(_topNativeAd!);
    }
    if (adService.useAdFitForTop) {
      return _buildTopAdFitChatListChrome();
    }
    // 광고 로드 전: 슬롯 공간만 예약 (레이아웃 점프 방지)
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const SizedBox(height: 116),
    );
  }

  /// 상단 AdMob 네이티브를 카드 크롬(흰 배경·하단 구분선·높이 116)으로 감싼다.
  /// 첫 탭(_topNativeAd)·비-첫탭(_tabTopAds[pkg]) 모두 동일 외형 공유.
  Widget _buildTopAdContainer(NativeAd ad) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        height: 116,
        // PlatformView(AdWidget) 컴포지팅을 형제 위젯과 격리 → 스크롤 시 주변 재페인트 차단.
        child: RepaintBoundary(child: AdWidget(key: ObjectKey(ad), ad: ad)),
      ),
    );
  }

  /// 해당 페이지(탭)에 표시할 상단 광고 위젯. null이면 슬롯 미표시(접힘).
  ///   - 첫 탭: 기존 _buildSharedTopAd (preload·bypass·AdFit 폴백 정교 흐름)
  ///   - 비-첫탭: 콘솔 TopBanner 대체 > 탭별 AdMob > AdFit 폴백 > (로딩 중) 접힘
  Widget? _buildTopAdFor(String? packageName, bool isFirstPage) {
    if (!_showTopAdSlot) return null;
    if (isFirstPage) return _buildSharedTopAd();

    final adService = AdService();
    // 콘솔 TopBanner + bypass → 첫 탭과 동일 이미지 노출 (탭 무관 단일 이미지 위젯)
    final topBanner = TopBannerCache.current;
    if (topBanner != null && topBanner.bypassAdmob && !_topBannerImageFailed) {
      return _buildSharedTopAd();
    }

    final pkg = packageName;
    // 탭별 AdMob 로드 완료 → AdMob
    if (pkg != null && _tabTopAdLoaded[pkg] == true && _tabTopAds[pkg] != null) {
      return _buildTopAdContainer(_tabTopAds[pkg]!);
    }
    // AdMob 불가/실패 → AdFit 상단 (탭별 키)
    if (adService.useAdFitForTop) {
      return _buildTopAdFitChatListChrome(keySuffix: pkg);
    }
    // 로딩 중 → 접어둠 (회색 버퍼 미표시, 광고 준비되면 끼어듦)
    return null;
  }

  /// 채팅방 목록 + 리스트 네이티브 광고 빌드.
  ///
  /// charge_app과 동일한 슬롯 머지 패턴:
  ///   - 슬롯 4·8 = AdMob 네이티브 (모든 탭, 탭별 별도 인스턴스 키로 AdWidget 안전)
  ///   - 슬롯 12+ = 콘솔 등록 house ad
  ///   - bypass=true house ad 가 4·8에 등록되면 AdMob 자리를 가로챔
  /// 룸 수가 적어 슬롯 위치까지 도달하지 못하면 그 슬롯은 자연히 미표시.
  Widget _buildChatListWithAd(
    NotificationSettingsService notificationService, {
    String? packageName,
  }) {
    final rooms = packageName != null
        ? _getFilteredRoomsForPackage(packageName)
        : _getFilteredRooms();

    final firstPackageName =
        MessengerSettingsService().getEnabledMessengers().firstOrNull?.packageName;
    final isFirstPage = packageName == null || packageName == firstPackageName;
    final isActivePage = packageName == _selectedPackageName ||
        (_selectedPackageName == null && isFirstPage);

    // 비-첫탭이 실제 보이는 순간(active)에만 그 탭 상단 AdMob 로드.
    // (노출 직전 로드 → "loaded but not shown" invalid impression 회피, 이웃 탭 선로드 방지)
    if (!isFirstPage && isActivePage && _showTopAdSlot && packageName != null) {
      final String pkg = packageName;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadTabTopAd(pkg);
      });
    }

    final Widget? topAd = _buildTopAdFor(packageName, isFirstPage);

    // 모든 탭에서 광고 슬롯 머지. 각 탭은 자기 패키지 키("$pkg|$slot")의 별도
    // NativeAd 인스턴스를 그리므로(_buildAdMobListSlot) AdWidget 동시 mount 충돌 없음.
    final List<Object> merged = _mergeRoomsWithAdSlots(rooms);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      cacheExtent: 280,
      slivers: [
        // 상단 네이티브 광고 — 모든 탭, 목록과 함께 스크롤됨.
        if (topAd != null) SliverToBoxAdapter(child: topAd),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = merged[index];
              if (item is _AdMobMarker) {
                return _buildAdMobListSlot(item.slot, packageName);
              }
              if (item is _HouseAdMarker) {
                return HouseAdCard(ad: item.ad);
              }
              final room = item as ChatRoom;
              final isMuted = notificationService.isMuted(
                  room.roomName, room.packageName, room.chatId);
              return _buildChatRoomTile(room, isMuted);
            },
            childCount: merged.length,
          ),
        ),
        // 스크롤 끝에서 마지막 타일이 화면 밑으로 더 보이도록
        SliverToBoxAdapter(
          child: SizedBox(
            height: (MediaQuery.paddingOf(context).bottom) + 36,
          ),
        ),
      ],
    );
  }

  /// charge_app `mergeWithAdSlots` 이식 — pos 1부터 스캔,
  /// admob 슬롯이면 마커 push, house 슬롯이면 HouseAd push, none이면 룸 push.
  List<Object> _mergeRoomsWithAdSlots(List<ChatRoom> rooms) {
    if (rooms.isEmpty) return const [];
    final merged = <Object>[];
    int rIdx = 0;
    int pos = 1;
    while (rIdx < rooms.length) {
      final kind = AdSlotResolver.kindAt(pos);
      switch (kind) {
        case SlotKind.admob:
          merged.add(_AdMobMarker(pos));
          break;
        case SlotKind.house:
          final house = HouseAdCache.at(pos);
          if (house != null) merged.add(_HouseAdMarker(house));
          break;
        case SlotKind.none:
          merged.add(rooms[rIdx]);
          rIdx++;
          break;
      }
      pos++;
      // 안전망 — 광고 슬롯만 잇따르는 비정상 케이스 방지
      if (pos > 200) break;
    }
    return merged;
  }

  /// AdMob 슬롯(4·8·12·16·20·24·28·32) 렌더 — slot별 별개 unit ID.
  /// 우선순위: AdMob(단가↑) > AdFit 폴백 > placeholder.
  Widget _buildAdMobListSlot(int slot, String? packageName) {
    if (packageName == null) return const SizedBox.shrink();
    final adService = AdService();
    final String pkg = packageName;
    final key = _listAdKey(pkg, slot);
    // 이 슬롯이 화면 근처에서 빌드되는 시점에 비로소 로드 → PlatformView mount 분산(버벅임↓).
    // 현재 빌드되는 탭(pkg) 기준으로 로드 → 탭별 별도 인스턴스(현재 탭만 지연 로드).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureListAdLoaded(pkg, slot);
    });
    final ad = _listNativeAds[key];
    final isLoaded = _listNativeAdLoaded[key] == true;
    final useAdFit = adService.useAdFitForListSlot(slot);

    if (isLoaded && ad != null) {
      return SizedBox(
        width: double.infinity,
        height: 96,
        // PlatformView(AdWidget) 컴포지팅을 형제 타일과 격리 → 스크롤 시 주변 재페인트 차단.
        child: RepaintBoundary(child: AdWidget(key: ObjectKey(ad), ad: ad)),
      );
    }
    if (useAdFit) {
      return _buildMidListAdFitChrome(packageName);
    }
    // charge_app 방식: 로딩 중엔 고정 높이(96dp)로 자리만 예약 → AdMob 이 뜰 때
    // 레이아웃 점프 없이 그 자리에 매끄럽게 들어참. (실패 시 위 useAdFit 분기로 AdFit,
    // 그것도 없으면 다음 빌드에서 0높이로 collapse.)
    return const SizedBox(width: double.infinity, height: 96);
  }

  /// 채팅방 리스트 아이템 위젯
  Widget _buildChatRoomTile(ChatRoom room, bool isMuted) {
    return InkWell(
      onTap: () async {
        // 채팅방 진입 전 해당 탭(packageName) 저장
        // → 앱 완전 종료 후 재시작 시 이 탭으로 복원됨
        _saveSelectedTab(room.packageName);
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomDetailScreen(room: room),
          ),
        );
        if (result == true) {
          setState(() {
            _chatRooms.removeWhere((r) => r.id == room.id);
          });
        } else if (result is Map) {
          setState(() {
            final idx = _chatRooms.indexWhere((r) => r.id == room.id);
            if (idx >= 0) {
              if (result['pinned'] != null) {
                _chatRooms[idx] = room.copyWith(pinned: result['pinned']);
              }
              if (result['summaryEnabled'] != null) {
                _chatRooms[idx] =
                    room.copyWith(summaryEnabled: result['summaryEnabled']);
              }
              _sortChatRooms();
            }
          });
        } else {
          _updateSingleRoom(room.id);
        }
        _startDbObserver();
      },
      onLongPress: () => _showRoomContextMenu(context, room),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: AppTokens.surface,
          border: Border(
            bottom: BorderSide(color: AppTokens.hair, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // 프로필 이미지 (아바타 — 사각 라디우스 12px 로 모서리 살짝)
            Stack(
              children: [
                Builder(
                  builder: (context) {
                    final profileFile =
                        _getProfileImageFile(room.roomName, room.packageName);
                    final isFAQ = room.packageName == 'com.dksw.app.faq';
                    ImageProvider? bgImage;

                    if (isFAQ) {
                      bgImage = const AssetImage('assets/ai_talk.png');
                    } else if (profileFile != null) {
                      bgImage = FileImage(profileFile);
                    } else if (room.profileImageUrl != null) {
                      bgImage = NetworkImage(room.profileImageUrl!);
                    }
                    final isKakaoTalk = room.packageName == 'com.kakao.talk';

                    return CircleAvatar(
                      radius: 22,
                      backgroundColor: bgImage == null
                          ? (isKakaoTalk
                              ? const Color(0xFFFFE812)
                              : AppTokens.accent2)
                          : AppTokens.accent2,
                      backgroundImage: bgImage,
                      child: bgImage == null
                          ? (isKakaoTalk
                              ? const Icon(Icons.chat_bubble_rounded,
                                  color: Color(0xFF3C1E1E), size: 22)
                              : Text(
                                  room.roomName.isNotEmpty
                                      ? room.roomName[0]
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ))
                          : null,
                    );
                  },
                ),
                if (room.participantCount > 2)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTokens.text,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${room.participantCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // 채팅방 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.roomName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.text,
                            height: 1.2,
                            letterSpacing: -0.07,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.pinned)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.push_pin,
                              size: 14, color: AppTokens.accent),
                        ),
                      if (room.summaryEnabled)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.auto_awesome,
                                  size: 16, color: AppTokens.accent),
                              if (room.autoSummaryEnabled)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppTokens.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                    child: const Center(
                                      child: Text('A',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 7,
                                            fontWeight: FontWeight.w800,
                                            height: 1.0,
                                          )),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (isMuted)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.notifications_off,
                              size: 14, color: AppTokens.text3),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatLastMessage(room),
                    style: AppText.messagePreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 시간 및 안 읽음 카운트
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(room.lastMessageTime),
                  style: AppText.messageTime,
                ),
                const SizedBox(height: 6),
                if (room.unreadCount > 0)
                  Container(
                    constraints:
                        const BoxConstraints(minWidth: 22, minHeight: 22),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTokens.accent,
                      borderRadius: BorderRadius.circular(
                          AppTokens.radiusPill),
                    ),
                    child: Center(
                      child: Text(
                        room.unreadCount > 999
                            ? '999+'
                            : '${room.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 패키지별 탭 필터 위젯
  Widget _buildPackageTabs() {
    // 활성 메신저 목록 (설정 + 플랜에 따라 동적)
    final enabledMessengers = MessengerSettingsService().getEnabledMessengers();

    // 탭이 없으면 빈 컨테이너 반환 (1개여도 표시)
    if (enabledMessengers.isEmpty) {
      return const SizedBox.shrink();
    }

    // 선택된 패키지가 활성 목록에 없으면 첫 번째로 리셋 (비활성화된 탭 선택 시)
    // _selectedPackageName == null 인 경우는 _restoreLastSelectedTab()에서 처리하므로 제외
    // (race condition 방지: postFrameCallback이 _restoreLastSelectedTab 복원값을 덮어쓰는 문제)
    if (_selectedPackageName != null &&
        !enabledMessengers.any((m) => m.packageName == _selectedPackageName)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final current = MessengerSettingsService().getEnabledMessengers();
          if (current.isEmpty) return;
          // 여전히 유효하지 않은 경우에만 리셋
          if (!current.any((m) => m.packageName == _selectedPackageName)) {
            setState(() {
              _selectedPackageName = current.first.packageName;
            });
            if (_pageController.hasClients) _pageController.jumpToPage(0);
          }
        }
      });
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppTokens.bg,
        border: Border(
          bottom: BorderSide(color: AppTokens.hair, width: 0.5),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          controller: _tabScrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: enabledMessengers.asMap().entries.map((entry) {
              final index = entry.key;
              final messenger = entry.value;
              // _selectedPackageName == null 이면 첫 번째 탭 선택으로 표시 (복원 대기 중)
              final isSelected = _selectedPackageName == null
                  ? index == 0
                  : _selectedPackageName == messenger.packageName;
              final tabKey = _getTabKey(messenger.packageName);

              return LongPressDraggable<int>(
                data: index,
                axis: Axis.horizontal,
                onDragUpdate: (d) => _handleTabDragUpdate(d.globalPosition),
                onDragEnd: (_) => _stopTabAutoScroll(),
                onDraggableCanceled: (_, __) => _stopTabAutoScroll(),
                onDragCompleted: () => _stopTabAutoScroll(),
                feedback: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.transparent,
                  child: _buildTabItem(
                    messenger.alias,
                    true,
                    () {},
                    packageName: messenger.packageName,
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildTabItem(
                    messenger.alias,
                    isSelected,
                    () {},
                    packageName: messenger.packageName,
                  ),
                ),
                child: DragTarget<int>(
                  onAcceptWithDetails: (details) {
                    _reorderTab(details.data, index);
                  },
                  builder: (context, candidateData, rejectedData) {
                    return _buildTabItem(
                      messenger.alias,
                      isSelected,
                      () {
                        setState(() {
                          _selectedPackageName = messenger.packageName;
                          _isProgrammaticPageChange = true;
                        });
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ).then((_) {
                          if (mounted) setState(() => _isProgrammaticPageChange = false);
                        });
                        _scrollToSelectedTab(messenger.packageName);
                        _saveSelectedTab(messenger.packageName);
                      },
                      packageName: messenger.packageName,
                      isDropTarget: candidateData.isNotEmpty,
                      itemKey: tabKey,
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// 탭 키 가져오기 (없으면 생성)
  GlobalKey _getTabKey(String packageName) =>
      _tabKeys.putIfAbsent(packageName, () => GlobalKey());

  /// 선택된 탭이 탭 바에서 보이도록 자동 스크롤
  void _scrollToSelectedTab(String packageName) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _tabKeys[packageName];
      if (key?.currentContext == null) return;
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // 탭을 가운데로
      );
    });
  }

  /// 탭 드래그 중 좌/우 가장자리면 SingleChildScrollView 를 자동 스크롤.
  /// _tabScrollController.position 의 viewport 좌표로 손가락 위치 환산.
  void _handleTabDragUpdate(Offset globalPosition) {
    if (!_tabScrollController.hasClients) return;
    final renderObject =
        _tabScrollController.position.context.notificationContext?.findRenderObject();
    if (renderObject is! RenderBox) return;

    final localX = renderObject.globalToLocal(globalPosition).dx;
    final viewportWidth = renderObject.size.width;

    double? dir;
    if (localX < _tabAutoScrollEdge) {
      dir = -1.0;
    } else if (localX > viewportWidth - _tabAutoScrollEdge) {
      dir = 1.0;
    }

    if (dir == null) {
      _stopTabAutoScroll();
      return;
    }
    if (_tabAutoScrollTimer != null) return; // 이미 동작 중

    final direction = dir;
    _tabAutoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_tabScrollController.hasClients) {
        _stopTabAutoScroll();
        return;
      }
      final pos = _tabScrollController.position;
      final next = (pos.pixels + direction * _tabAutoScrollSpeed)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if (next == pos.pixels) return; // 끝 도달
      _tabScrollController.jumpTo(next);
    });
  }

  void _stopTabAutoScroll() {
    _tabAutoScrollTimer?.cancel();
    _tabAutoScrollTimer = null;
  }

  /// 탭 순서 변경
  void _reorderTab(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    MessengerSettingsService().reorder(oldIndex, newIndex);
    setState(() {});
    // 재정렬 후 선택된 탭의 새 인덱스로 PageController 동기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messengers = MessengerSettingsService().getEnabledMessengers();
      final newIdx = messengers.indexWhere((m) => m.packageName == _selectedPackageName);
      if (newIdx >= 0) _pageController.jumpToPage(newIdx);
    });
  }

  /// 탭 아이템 위젯
  Widget _buildTabItem(String label, bool isSelected, VoidCallback onTap,
      {String? packageName, bool isDropTarget = false, GlobalKey? itemKey}) {
    final messengerInfo = packageName != null
        ? MessengerRegistry.getByPackageName(packageName)
        : null;

    // 해당 패키지의 안 읽은 메시지 개수
    final unreadCount = packageName != null
        ? _chatRooms
            .where((room) => room.packageName == packageName)
            .fold<int>(0, (sum, room) => sum + room.unreadCount)
        : 0;

    // 핸드오프 §7.1.3: 활성 = accentSoft 배경 + accent 보더/텍스트,
    // 비활성 = 투명 배경 + border 보더 + text2 텍스트.
    final bg = isSelected ? AppTokens.accentSoft : Colors.transparent;
    final fg = isSelected ? AppTokens.accent : AppTokens.text2;
    final borderColor = isDropTarget
        ? AppTokens.accent
        : (isSelected ? AppTokens.accent : AppTokens.border);

    return GestureDetector(
      key: itemKey,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          border: Border.all(
            color: borderColor,
            width: isDropTarget ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            messengerInfo?.buildGlyph(color: fg, size: 14) ??
                Icon(Icons.chat, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            // 안 읽음 카운트: 활성 = 흰 배경 + accent, 비활성 = bg + text3
            if (unreadCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppTokens.bg,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: TextStyle(
                      color: isSelected
                          ? AppTokens.accent
                          : AppTokens.text3,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 패키지 이름을 표시 이름으로 변환
  String _getPackageDisplayName(String packageName) {
    final messenger = LocalDbService.supportedMessengers.firstWhere(
      (m) => m['packageName'] == packageName,
      orElse: () => {'alias': AppLocalizations.of(context).chatList_unknownAlias},
    );
    return messenger['alias'] ?? AppLocalizations.of(context).chatList_unknownAlias;
  }

  /// 필터링된 채팅방 목록 반환
  List<ChatRoom> _getFilteredRoomsForPackage(String packageName) {
    const String faqPackageName = 'com.dksw.app.faq';
    final faqRooms = _chatRooms.where((room) => room.packageName == faqPackageName).toList();
    final otherRooms = _chatRooms.where((room) => room.packageName != faqPackageName).toList();
    final filtered = otherRooms.where((room) => room.packageName == packageName).toList();
    return [...filtered, ...faqRooms];
  }

  List<ChatRoom> _getFilteredRooms() {
    const String faqPackageName = 'com.dksw.app.faq';
    
    // FAQ 채팅방은 항상 포함 (맨 아래에)
    final faqRooms = _chatRooms.where((room) => room.packageName == faqPackageName).toList();
    
    // FAQ 채팅방을 제외한 나머지 채팅방
    final otherRooms = _chatRooms.where((room) => room.packageName != faqPackageName).toList();
    
    if (_selectedPackageName == null) {
      if (LocalDbService.supportedMessengers.isNotEmpty) {
        final firstPackage = LocalDbService.supportedMessengers.first['packageName'];
        if (firstPackage != null) {
          final filtered = otherRooms.where((room) => room.packageName == firstPackage).toList();
          // FAQ 채팅방과 합치기 (FAQ는 맨 아래에)
          return [...filtered, ...faqRooms];
        }
      }
      if (otherRooms.isNotEmpty) {
        final firstPackage = otherRooms.first.packageName;
        final filtered = otherRooms.where((room) => room.packageName == firstPackage).toList();
        // FAQ 채팅방과 합치기 (FAQ는 맨 아래에)
        return [...filtered, ...faqRooms];
      }
      return faqRooms;
    }
    
    // 선택된 패키지의 채팅방 + FAQ 채팅방 (FAQ는 맨 아래에)
    final filtered = otherRooms.where((room) => room.packageName == _selectedPackageName).toList();
    return [...filtered, ...faqRooms];
  }

  /// 타이틀 클릭 처리 (5번 누르면 플랜 선택)
  void _handleTitleClick() {
    final now = DateTime.now();
    
    // 3초 이내에 클릭했는지 확인
    if (_lastSettingsClickTime != null &&
        now.difference(_lastSettingsClickTime!) < const Duration(seconds: 3)) {
      _settingsClickCount++;
    } else {
      // 3초 이상 지났으면 카운터 리셋
      _settingsClickCount = 1;
    }
    
    _lastSettingsClickTime = now;

    debugPrint('⚙️ 설정 버튼 클릭: $_settingsClickCount/5');

    // 5번 누르면 플랜 선택 다이얼로그 표시
    if (_settingsClickCount >= 5) {
      _settingsClickCount = 0; // 카운터 리셋
      _showPlanSelectionDialog();
    }
  }

  /// 플랜 선택 다이얼로그 표시
  Future<void> _showPlanSelectionDialog() async {
    // 테스트 모드인지 확인
    final bool isTestMode = PlanService.isTestMode;
    
    if (isTestMode) {
      // 테스트 모드: 기존 방식 (관리자 API 사용)
      final authService = AuthService();
      final deviceIdHash = await authService.getDeviceIdHash();

      if (deviceIdHash == null || deviceIdHash.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatList_deviceInfoFailed),
            duration: const Duration(seconds: 1),
          ),
        );
        return;
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).chatList_planSelectTitle),
          content: Text(AppLocalizations.of(context).chatList_planSelectContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).chatList_cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _setPlan(deviceIdHash, 'free');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text('Free'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _setPlan(deviceIdHash, 'basic');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Basic'),
            ),
          ],
        ),
      );
    } else {
      // 상용 모드: 플랜 구독 화면으로 이동
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubscriptionScreen(),
        ),
      );
    }
  }

  /// 플랜 설정
  Future<void> _setPlan(String deviceIdHash, String planType) async {
    if (!mounted) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final planService = PlanService();
      bool success = false;

      if (planType == 'basic') {
        success = await planService.setBasicPlan(deviceIdHash);
      } else {
        success = await planService.setFreePlan(deviceIdHash);
      }

      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatList_planSet(planType.toUpperCase())),
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).chatList_planSetFailed),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).chatList_planSetError),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}

/// 슬롯 머지에서 룸 / AdMob 슬롯 / House ad 를 한 List에 섞기 위한 마커.
class _AdMobMarker {
  final int slot;
  const _AdMobMarker(this.slot);
}

class _HouseAdMarker {
  final HouseAd ad;
  const _HouseAdMarker(this.ad);
}
