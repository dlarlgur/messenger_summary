import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/local_db_service.dart';
import 'services/notification_settings_service.dart';
import 'services/auto_summary_settings_service.dart';
import 'services/profile_image_service.dart';
import 'services/auth_service.dart';
import 'services/app_version_service.dart';
import 'services/plan_service.dart';
import 'services/in_app_purchase_service.dart';
import 'services/messenger_settings_service.dart';
import 'services/ad_service.dart';
import 'screens/chat_room_list_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/summary_history_screen.dart';
import 'screens/app_guide_screen.dart';
import 'screens/subscription_screen.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 즉시 UI 표시 (권한 화면 바로 노출) - 모든 초기화는 백그라운드에서
  runApp(const MyApp());

  // 모두 백그라운드에서 초기화 (UI를 블록하지 않음)
  unawaited(initializeDateFormatting('ko_KR', null));
  unawaited(LocalDbService().initialize());
  unawaited(MessengerSettingsService().initialize());
  unawaited(ProfileImageService().initialize());
  unawaited(AdService().initialize());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationSettingsService()),
        ChangeNotifierProvider(create: (_) => AutoSummarySettingsService()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'AI 톡비서',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
            primary: const Color(0xFF2196F3),
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2196F3),
            foregroundColor: Colors.white,
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

// 메인 화면 - 알림 수신 및 처리
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  static const methodChannel =
      MethodChannel('com.dksw.app/notification');
  static const mainMethodChannel =
      MethodChannel('com.dksw.app/main');
  static const eventChannel =
      EventChannel('com.dksw.app/notification_stream');

  StreamSubscription? _subscription;
  StreamSubscription? _mainMethodSubscription;
  bool _isPermissionGranted = true; // 초기값을 true로 설정 (권한 체크 후 결정)
  bool _isCheckingPermissions = false; // ⚠️ 수정: 권한 확인 중이면 로딩 표시하지 않음 (권한 화면이 잠깐 보이는 것 방지)
  bool _isForceUpdateRequired = false; // 강제 업데이트 필요 여부
  bool _showGuide = false; // 사용 가이드 표시 여부
  VersionCheckResult? _versionCheckResult; // 버전 체크 결과
  final GlobalKey<ChatRoomListScreenState> _chatRoomListKey = GlobalKey();
  final LocalDbService _localDb = LocalDbService();
  final Set<int> _processedSummaryIds = {}; // 이미 처리한 summaryId 추적

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fastInitialize();
    _setupMainMethodChannel();
    _checkPendingSummaryId();
    // ⚠️ 수정: 권한 확인 완료 전까지는 리스너 시작하지 않음
    // _startListening();
  }

  /// 빠른 초기화: 권한 체크를 항상 먼저 실행해 화면을 즉시 표시
  Future<void> _fastInitialize() async {
    try {
      // ✅ 1. OnboardingActivity에서 넘어왔는지 확인
      final prefs = await SharedPreferences.getInstance();
      final fromOnboarding = prefs.getBool('flutter.from_onboarding') ?? false;
      if (fromOnboarding) {
        // OnboardingActivity에서 넘어온 경우 플래그 제거
        await prefs.remove('flutter.from_onboarding');
        // 권한 확인을 await로 기다림 (권한이 없을 가능성이 높음)
        await _checkPermissionsOnly();
      } else {
        // 일반 앱 시작 시에는 백그라운드에서 실행 (화면 깜빡임 방지)
        // 권한이 이미 있으면 메인 화면 바로 표시
        unawaited(_checkPermissionsOnly());
      }

      // ✅ 2. JWT 토큰 확인 및 나머지 초기화는 백그라운드에서 실행
      Future.microtask(() async {
        try {
          final authService = AuthService();
          final token = await authService.getJwtToken();

          if (token != null) {
            _backgroundInitialize();
          } else {
            // JWT 없으면 버전체크 + JWT 발급 동시 실행 후 구독 체크
            await Future.wait([_checkVersion(), _getJwtToken()]);
            await _checkSubscription();
            if (mounted) {
              final notificationService =
                  Provider.of<NotificationSettingsService>(context, listen: false);
              final autoSummarySettingsService =
                  Provider.of<AutoSummarySettingsService>(context, listen: false);
              await notificationService.initialize();
              await autoSummarySettingsService.initialize();
            }
          }
        } catch (e) {
          debugPrint('❌ 백그라운드 초기화 실패: $e');
        }
      });
    } catch (e) {
      debugPrint('❌ 빠른 초기화 실패: $e');
    }
  }

  /// 전체 초기화 (JWT 토큰이 없을 때)
  Future<void> _fullInitialize() async {
    // 권한 체크를 먼저 진행 (화면 표시를 위해)
    await _checkPermissionsOnly();
    
    // 백그라운드에서 나머지 초기화 작업 진행
    Future.microtask(() async {
      try {
        // 버전 체크와 JWT 토큰 발급을 비동기로 동시에 실행
        final versionCheckFuture = _checkVersion();
        final jwtTokenFuture = _getJwtToken();
        
        // 두 작업 모두 완료될 때까지 대기
        await Future.wait([versionCheckFuture, jwtTokenFuture]);
        
        // JWT 토큰이 발급된 후 구독 정보 조회
        await _checkSubscription();
        
        // 서비스 초기화 (알림 설정, 자동 요약 설정)
        final notificationService =
            Provider.of<NotificationSettingsService>(context, listen: false);
        final autoSummarySettingsService =
            Provider.of<AutoSummarySettingsService>(context, listen: false);
        await notificationService.initialize();
        await autoSummarySettingsService.initialize();
      } catch (e) {
        debugPrint('❌ 전체 초기화 오류: $e');
      }
    });
  }

  /// 권한만 빠르게 체크 (화면 표시용)
  Future<void> _checkPermissionsOnly() async {
    // ✅ 두 권한 확인을 병렬로 실행 (순차 → 동시)
    bool notificationPermissionGranted = false;
    bool batteryOptimizationDisabled = false;

    try {
      final results = await Future.wait([
        methodChannel.invokeMethod<bool>('isNotificationListenerEnabled'),
        methodChannel.invokeMethod<bool>('isBatteryOptimizationDisabled'),
      ]);
      notificationPermissionGranted = results[0] ?? false;
      batteryOptimizationDisabled = results[1] ?? false;
    } catch (e) {
      debugPrint('❌ 권한 확인 실패 - 개별 재시도: $e');
      try {
        notificationPermissionGranted =
            await methodChannel.invokeMethod<bool>('isNotificationListenerEnabled') ?? false;
      } catch (e2) {
        debugPrint('❌ 알림 권한 확인 실패: $e2');
      }
      try {
        batteryOptimizationDisabled =
            await methodChannel.invokeMethod<bool>('isBatteryOptimizationDisabled') ?? false;
      } catch (e2) {
        debugPrint('❌ 배터리 최적화 권한 확인 실패: $e2');
      }
    }

    if (mounted) {
      // 필수 권한이 모두 없으면 권한 화면으로 이동
      if (!notificationPermissionGranted || !batteryOptimizationDisabled) {
        // 권한이 없으면 권한 화면으로 이동
        setState(() {
          _isPermissionGranted = false; // 권한 화면 표시
          _isCheckingPermissions = false; // 권한 확인 완료
        });
      } else {
        // 모든 필수 권한이 있으면 메인 화면 유지
        // 가이드 표시 여부 확인
        final hasSeenGuide = await AppGuideScreen.hasSeenGuide();

        setState(() {
          _isPermissionGranted = true;
          _isCheckingPermissions = false; // 권한 확인 완료
          _showGuide = !hasSeenGuide;
        });

        // 가이드를 보여줄 때는 리스너/배지 시작 불필요 (가이드 끝나면 MainScreen 재생성)
        if (hasSeenGuide) {
          // 권한이 있으면 리스너 시작
          _startListening();

          // 배지 업데이트
          _updateNotificationBadge();
        }
      }
    }
  }

  /// 백그라운드 초기화 (JWT 토큰이 있을 때)
  /// 권한 체크와 독립적으로 실행 (버전 체크, 구독 동기화 등)
  void _backgroundInitialize() {
    // 모든 작업을 백그라운드에서 비동기로 처리
    Future.microtask(() async {
      try {
        // 1. 버전 체크 (강제 업데이트만 체크)
        await _checkVersion();
        
        // 2. 구독 정보 조회 (기기 변경 시 구독 부활 포함)
        await _checkSubscription();
        
        // 3. 서비스 초기화 (알림 설정, 자동 요약 설정)
        // 권한 체크는 이미 완료되었으므로 여기서는 서비스만 초기화
        final notificationService =
            Provider.of<NotificationSettingsService>(context, listen: false);
        final autoSummarySettingsService =
            Provider.of<AutoSummarySettingsService>(context, listen: false);
        await notificationService.initialize();
        await autoSummarySettingsService.initialize();
      } catch (e) {
        debugPrint('❌ 백그라운드 초기화 오류: $e');
      }
    });
  }
  
  /// 버전 체크 (비동기, 백그라운드에서 실행)
  Future<void> _checkVersion() async {
    try {
      final versionService = AppVersionService();
      final result = await versionService.checkVersion();

      if (result.updateRequired && result.updateType == UpdateType.force) {
        // 강제 업데이트만 앱 시작 시 처리
        _versionCheckResult = result;
        if (mounted) {
          setState(() {
            _isForceUpdateRequired = true;
            _isCheckingPermissions = false;
          });

          // 다이얼로그 표시
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              UpdateDialog.show(context, result);
            }
          });
        }
        return;
      }
      // 일반 업데이트는 대화 목록 화면에서 처리
    } catch (e) {
      debugPrint('❌ 버전 체크 실패: $e');
      // 버전 체크 실패 시 앱 사용 허용
    }
  }
  
  /// JWT 토큰 발급 (비동기)
  Future<void> _getJwtToken() async {
    try {
      final authService = AuthService();
      await authService.getJwtToken();
    } catch (e) {
      debugPrint('❌ JWT 토큰 발급 오류: $e');
    }
  }
  
  /// 구독 체크 (백그라운드에서 실행, 최적화됨)
  Future<void> _checkSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const lastSyncKey = 'last_subscription_sync_time';
      const syncIntervalHours = 24; // 24시간마다 동기화
      
      // 마지막 동기화 시간 확인
      final lastSyncTimeMillis = prefs.getInt(lastSyncKey);
      if (lastSyncTimeMillis != null) {
        final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncTimeMillis);
        final hoursSinceLastSync = DateTime.now().difference(lastSyncTime).inHours;
        
        if (hoursSinceLastSync < syncIntervalHours) {
          return;
        }
      }

      final planService = PlanService();
      final purchaseService = InAppPurchaseService();
      
      // 1. 인앱 결제 서비스 초기화 (백그라운드에서)
      final initialized = await purchaseService.initialize();
      if (!initialized) {
        // 인앱 결제 초기화 실패해도 구독 정보는 조회 시도
        final currentPlan = await planService.getCurrentPlan();
        if (currentPlan != null) {
          await prefs.setInt(lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        }
        return;
      }

      // 2. 과거 구매 내역 조회 및 purchaseToken 대기 (기기 변경 시 구독 부활용)
      // Completer 기반으로 purchaseToken이 수신될 때까지 최대 5초 대기
      final purchaseToken = await purchaseService.queryPastPurchasesAndWaitForToken(
        timeout: const Duration(seconds: 5),
      );
      
      // 3. 구독 정보 동기화 (purchaseToken이 있으면 함께 전송)
      final currentPlan = await planService.getCurrentPlan(
        purchaseToken: purchaseToken,
      );
      
      if (currentPlan != null) {
        // 동기화 시간 저장
        await prefs.setInt(lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('❌ 구독 정보 동기화 오류: $e');
    }
  }

  /// Main MethodChannel 설정 (summaryId / openSubscription 수신용)
  void _setupMainMethodChannel() {
    mainMethodChannel.setMethodCallHandler((call) async {
      if (call.method == 'openSummary') {
        final summaryId = call.arguments as int?;
        if (summaryId != null && summaryId > 0) {
          _openSummaryFromNotification(summaryId);
        }
      } else if (call.method == 'openSubscription') {
        _openSubscriptionFromNotification();
      }
    });
  }

  /// 페이월 알림 클릭 시 구독 화면 열기
  void _openSubscriptionFromNotification() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = MyApp.navigatorKey.currentState;
      if (navigator != null) {
        navigator.push(
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      }
    });
  }

  /// 대기 중인 summaryId 또는 openSubscription 확인 및 처리
  Future<void> _checkPendingSummaryId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 구독 화면 열기 대기 확인
      final pendingSubscription = prefs.getBool('flutter.pending_open_subscription') ?? false;
      if (pendingSubscription) {
        await prefs.remove('flutter.pending_open_subscription');
        _openSubscriptionFromNotification();
        return;
      }

      // 먼저 MethodChannel에서 확인
      final summaryIdFromChannel = await mainMethodChannel.invokeMethod<int?>('getPendingSummaryId');
      int? summaryId = summaryIdFromChannel;

      // MethodChannel에 없으면 SharedPreferences에서 확인
      if (summaryId == null || summaryId <= 0) {
        summaryId = prefs.getInt('flutter.pending_summary_id');
        if (summaryId != null && summaryId > 0) {
          await prefs.remove('flutter.pending_summary_id');
        }
      }

      if (summaryId != null && summaryId > 0) {
        _openSummaryFromNotification(summaryId);
      }
    } catch (e) {
      debugPrint('❌ 대기 중인 summaryId 처리 실패: $e');
    }
  }

  /// 알림에서 받은 summaryId로 요약 히스토리 열기
  Future<void> _openSummaryFromNotification(int summaryId) async {
    // 이미 처리한 summaryId는 무시 (중복 방지)
    if (_processedSummaryIds.contains(summaryId)) {
      return;
    }
    _processedSummaryIds.add(summaryId);

    try {
      // summaryId로 roomId 찾기
      final roomId = await _localDb.getRoomIdBySummaryId(summaryId);
      
      if (roomId != null) {
        // roomId로 채팅방 정보 가져오기
        final room = await _localDb.getRoomById(roomId);
        
        if (room != null) {
          // 앱이 완전히 로드된 후 요약 히스토리 화면으로 이동
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final navigator = MyApp.navigatorKey.currentState;
            if (navigator != null) {
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => SummaryHistoryScreen(
                    roomId: roomId,
                    roomName: room.roomName,
                    initialSummaryId: summaryId,
                  ),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 요약 히스토리 열기 실패: $e');
    }
  }
  
  Future<void> _initializeAndCheckPermissions() async {
    final notificationService =
        Provider.of<NotificationSettingsService>(context, listen: false);
    final autoSummarySettingsService =
        Provider.of<AutoSummarySettingsService>(context, listen: false);

    // 알림 설정 초기화
    await notificationService.initialize();
    // 자동 요약 설정 초기화
    await autoSummarySettingsService.initialize();

    // 필수 권한 확인 (알림 접근 권한 + 배터리 최적화 제외)
    bool notificationPermissionGranted = false;
    bool batteryOptimizationDisabled = false;

    try {
      notificationPermissionGranted =
          await methodChannel.invokeMethod<bool>('isNotificationListenerEnabled') ?? false;
    } catch (e) {
      debugPrint('❌ 알림 권한 확인 실패: $e');
    }

    try {
      batteryOptimizationDisabled =
          await methodChannel.invokeMethod<bool>('isBatteryOptimizationDisabled') ?? false;
    } catch (e) {
      debugPrint('❌ 배터리 최적화 권한 확인 실패: $e');
    }

    if (mounted) {
      // 필수 권한이 모두 없으면 권한 화면으로 이동
      if (!notificationPermissionGranted || !batteryOptimizationDisabled) {
        // 권한이 없으면 권한 화면으로 이동
        setState(() {
          _isPermissionGranted = false; // 권한 화면 표시
          _isCheckingPermissions = false; // 권한 확인 완료
        });
      } else {
        // 모든 필수 권한이 있으면 메인 화면 유지
        // 가이드 표시 여부 확인
        final hasSeenGuide = await AppGuideScreen.hasSeenGuide();

        setState(() {
          _isPermissionGranted = true;
          _isCheckingPermissions = false; // 권한 확인 완료
          _showGuide = !hasSeenGuide;
        });

        // 가이드를 보여줄 때는 리스너/배지 시작 불필요 (가이드 끝나면 MainScreen 재생성)
        if (hasSeenGuide) {
          // ⚠️ 수정: 권한이 있으면 리스너 시작
          _startListening();

          // 배지 업데이트
          _updateNotificationBadge();
        }
      }
    }
  }

  /// 자동요약 알림 설정 팝업 표시 (최초 진입 시에만)
  Future<void> _checkAndShowAutoSummaryNotificationDialog() async {
    try {
      final autoSummarySettingsService =
          Provider.of<AutoSummarySettingsService>(context, listen: false);
      
      // 이미 팝업을 표시했는지 확인
      final shouldShow = await autoSummarySettingsService.shouldShowNotificationDialog();
      
      if (shouldShow && mounted) {
        // 시스템 알림 권한 확인
        final systemPermissionEnabled = await methodChannel.invokeMethod<bool>('areNotificationsEnabled') ?? false;
        
        if (systemPermissionEnabled) {
          // 시스템 권한이 있으면 팝업 표시
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showAutoSummaryNotificationDialog(autoSummarySettingsService);
            }
          });
        } else {
          // 시스템 권한이 없으면 팝업 표시하지 않고, 팝업 표시 완료로 표시
          await autoSummarySettingsService.markNotificationDialogShown();
        }
      }
    } catch (e) {
      debugPrint('❌ 자동요약 알림 팝업 확인 실패: $e');
    }
  }

  /// 자동요약 알림 설정 팝업 표시
  void _showAutoSummaryNotificationDialog(AutoSummarySettingsService autoSummarySettingsService) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('자동 요약 알림'),
        content: const Text(
          '자동 요약이 완료되면 푸시 알림을 받으시겠습니까?\n\n'
          '알림을 받으려면 알림 권한이 필요합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // 거부 - 팝업 표시 완료로 표시하고 닫기
              await autoSummarySettingsService.markNotificationDialogShown();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('나중에'),
          ),
          TextButton(
            onPressed: () async {
              // 동의 - 자동요약 알림 켜기
              final success = await autoSummarySettingsService.setAutoSummaryNotificationEnabled(true);
              await autoSummarySettingsService.markNotificationDialogShown();
              
              if (mounted) {
                Navigator.of(context).pop();
                
                if (!success) {
                  // 시스템 권한이 없으면 설정 화면으로 이동 안내
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('알림 권한이 필요합니다. 설정에서 알림을 허용해주세요.'),
                      action: SnackBarAction(
                        label: '설정',
                        onPressed: () async {
                          try {
                            await methodChannel.invokeMethod('openAppSettings');
                          } catch (e) {
                            debugPrint('❌ 설정 화면 열기 실패: $e');
                          }
                        },
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            child: const Text('알림 받기'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아올 때 배지 업데이트
      _updateNotificationBadge();
      if (!mounted) return;
      // 이벤트 리스너 재구독 (백그라운드에서 끊어졌을 수 있음)
      _subscription?.cancel();
      _startListening();
      // 대화목록 즉시 새로고침
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _chatRoomListKey.currentState?.refreshRooms();
          // 앱이 포그라운드로 돌아올 때도 summaryId 확인
          _checkPendingSummaryId();
          // 시스템 알림 권한 상태 새로고침
          final autoSummarySettingsService =
              Provider.of<AutoSummarySettingsService>(context, listen: false);
          autoSummarySettingsService.refreshSystemNotificationPermission();
        }
      });
    }
  }


  void _startListening() {
    _subscription?.cancel(); // 기존 구독 취소
    _subscription = eventChannel.receiveBroadcastStream().listen(
      (event) async {
        if (event is Map) {
          final data = Map<String, dynamic>.from(event);
          final eventType = data['type'] ?? 'notification';

          if (eventType == 'room_updated') {
            // 채팅방 업데이트 이벤트 처리
            await _handleRoomUpdate(data);
          } else {
            // 새 알림 처리 → 로컬 DB에 저장
            await _handleNotification(data);
          }
        }
      },
      onError: (error) {
        debugPrint('❌ 스트림 에러: $error');
        // 에러 발생 시 재구독 시도
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _startListening();
          }
        });
      },
      cancelOnError: false, // 에러 발생해도 구독 유지
    );
  }

  /// 채팅방 업데이트 처리
  Future<void> _handleRoomUpdate(Map<String, dynamic> data) async {
    // ChatRoomListScreen에 업데이트 전달 - 즉시 실행하여 빠른 동기화 보장
    if (mounted) {
      if (_chatRoomListKey.currentState != null) {
        _chatRoomListKey.currentState!.refreshRooms();
      } else {
        // 위젯이 아직 초기화되지 않았을 수 있으므로 잠시 후 다시 시도
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _chatRoomListKey.currentState != null) {
            _chatRoomListKey.currentState!.refreshRooms();
          }
        });
      }
    }
  }

  /// 배지 업데이트
  Future<void> _updateNotificationBadge() async {
    try {
      final unreadCount = await _localDb.getUnreadNotificationCount();
      await methodChannel.invokeMethod('updateNotificationBadge', {'count': unreadCount});
    } catch (e) {
      debugPrint('❌ 배지 업데이트 실패: $e');
    }
  }

  /// 알림 수신 → UI 갱신 (Android 네이티브에서 이미 DB에 저장됨)
  Future<void> _handleNotification(Map<String, dynamic> data) async {
    final packageName = data['packageName'] ?? '';
    final type = data['type'] ?? 'notification';
    final isAutoSummary = data['isAutoSummary'] == true || type == 'auto_summary';
    final summaryId = data['summaryId'] as int?;

    // 자동요약 알림인 경우 별도 처리
    if (isAutoSummary) {
      
      int postTime;
      if (data['postTime'] != null) {
        if (data['postTime'] is int) {
          postTime = data['postTime'] as int;
        } else if (data['postTime'] is num) {
          postTime = (data['postTime'] as num).toInt();
        } else {
          postTime = DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        postTime = DateTime.now().millisecondsSinceEpoch;
      }

      final sender = data['sender'] ?? 'AI 톡비서';
      final message = data['message'] ?? '';
      final roomName = data['roomName'] ?? '';

      await _localDb.saveNotification(
        packageName: packageName,
        sender: sender,
        message: message,
        roomName: roomName,
        postTime: postTime,
        isAutoSummary: true,
        summaryId: summaryId,
      );
      
      // 읽지 않은 알림 개수 조회 및 배지 업데이트
      _updateNotificationBadge();
      return;
    }

    // 시스템 UI 알림 필터링 (com.android.systemui 등)
    if (packageName == 'com.android.systemui' ||
        packageName.startsWith('com.android.') ||
        packageName == 'android') {
      return;
    }

    // 지원하는 메신저인지 확인
    if (!_localDb.isSupportedMessenger(packageName)) {
      return;
    }

    // Android 파싱 로직과 동일하게 파싱
    final title = data['title'] ?? '';
    final text = data['text'] ?? '';
    final subText = data['subText'] ?? '';
    final isGroupConversation = data['isGroupConversation'] == true;
    final channelId = data['channelId'] ?? '';
    
    String roomName;
    String sender;
    String message;
    
    // 텔레그램 파싱 로직 (Android와 동일)
    // 텔레그램은 3가지 알림 채널 사용:
    // - notification_channels_private_chats: 개인 채팅
    // - notification_channels_groups: 그룹 채팅
    // - notification_channels_channels: 채널
    if (packageName == 'org.telegram.messenger') {
      // channelId로 채널 타입 확인 (더 정확함)
      final isPrivateChannel = channelId.contains('private');
      final isGroupChannel = channelId.contains('groups');
      final isChannelType = channelId.contains('channels');
      final conversationTitle = data['conversationTitle'] ?? '';
      
      // 그룹 채팅 또는 채널 (isGroupConversation 또는 channelId로 판단)
      // 주의: subText.isNotEmpty 조건 제거 - 텔레그램 개인톡에서 subText가 메시지 복사본으로 채워짐
      if (isGroupConversation || isGroupChannel || isChannelType) {
        // 그룹 채팅/채널 형식:
        // - title: "그룹이름: 보낸사람" 또는 "그룹이름"
        // - conversationTitle: 그룹 이름 (있으면 사용)
        // - text: "메시지" 또는 "보낸사람: 메시지"
        // - subText: "보낸사람 @ 메시지" 또는 "메시지"
        roomName = conversationTitle.isNotEmpty ? conversationTitle : title;
        
        // subText에서 보낸사람 추출 시도 (예: "구 여 @ 넵 알겠습니다팀장님")
        final atIdx = subText.indexOf(' @ ');
        if (atIdx > 0) {
          sender = subText.substring(0, atIdx);
          message = text;
        } else {
          // text에서 colon으로 분리 시도
          final colonIdx = text.indexOf(': ');
          if (colonIdx > 0) {
            sender = text.substring(0, colonIdx);
            message = text.substring(colonIdx + 2);
          } else {
            // title에서 colon으로 분리 시도 (예: "SKT PBX 개발검증: 구 여")
            final titleColonIdx = title.indexOf(': ');
            if (titleColonIdx > 0) {
              sender = title.substring(titleColonIdx + 2);
              message = text;
            } else {
              // fallback: title을 sender로 사용
              sender = title;
              message = text;
            }
          }
        }
      } else {
        // 개인 채팅 형식 (isPrivateChannel 또는 isGroupConversation == false):
        // - title: 상대방 이름
        // - text: 메시지 내용
        // - subText: 빈 문자열
        roomName = title;
        sender = title;
        message = text;
      }
    } else if (packageName == 'jp.naver.line.android') {
      // 라인 파싱 로직 (Android와 동일)
      final conversationTitle = data['conversationTitle'] ?? '';
      
      if (isGroupConversation || conversationTitle.isNotEmpty) {
        // 그룹 채팅 형식
        // - conversationTitle: 그룹 이름 (있으면 우선 사용)
        // - subText: 그룹 이름 (conversationTitle 없으면 사용)
        // - title: "그룹이름: 보낸사람" 또는 "그룹이름"
        roomName = conversationTitle.isNotEmpty 
            ? conversationTitle 
            : (subText.isNotEmpty ? subText : title);
        
        // title에서 보낸사람 추출 시도 (예: "내사랑원이❤️, 임기혁: judy Kim")
        if (conversationTitle.isNotEmpty && title.startsWith('$conversationTitle: ')) {
          // conversationTitle prefix로 정확하게 발신자 추출
          sender = title.substring(conversationTitle.length + 2);
          message = text;
        } else {
          final colonIdx = title.indexOf(': ');
          if (colonIdx > 0) {
            sender = title.substring(colonIdx + 2);
            message = text;
          } else {
            // text에서 colon으로 분리 시도
            final textColonIdx = text.indexOf(': ');
            if (textColonIdx > 0) {
              sender = text.substring(0, textColonIdx);
              message = text.substring(textColonIdx + 2);
            } else {
              sender = title;
              message = text;
            }
          }
        }
      } else {
        // 개인 채팅 형식
        roomName = title;
        sender = title;
        message = text;
      }
    } else if (packageName == 'com.microsoft.teams') {
      // Teams 파싱 로직
      final conversationTitle = data['conversationTitle'] ?? '';

      if (conversationTitle.isNotEmpty) {
        // 1:1 채팅 또는 그룹 채팅
        roomName = conversationTitle;
        if (title.startsWith('$conversationTitle: ')) {
          sender = title.substring(conversationTitle.length + 2);
          if (sender.isEmpty) sender = conversationTitle;
        } else {
          sender = conversationTitle;
        }
        message = text;
      } else {
        // 채널 메시지: "XXX 님이 YYY 팀의 채널 ZZZ에서 회신했습니다."
        final channelPattern = RegExp(r'(.+?) 님이 (.+?) 팀의 채널 (.+?)에서');
        final match = channelPattern.firstMatch(title);
        if (match != null) {
          sender = match.group(1)!;
          final teamName = match.group(2)!;
          final channelName = match.group(3)!;
          roomName = '$teamName / $channelName';
          message = text;
        } else {
          // 기타 Teams 알림
          roomName = title;
          sender = title;
          message = text;
        }
      }
    } else if (packageName == 'com.facebook.orca') {
      // Facebook Messenger 파싱 로직
      final conversationTitle = data['conversationTitle'] ?? '';

      if (isGroupConversation || conversationTitle.isNotEmpty) {
        roomName = conversationTitle.isNotEmpty ? conversationTitle : title;
        sender = title;
        message = text;
      } else {
        roomName = title;
        sender = title;
        message = text;
      }
    } else {
      // 기존 로직 (카카오톡 등)
      sender = title;
      message = text;
      roomName = subText.isNotEmpty ? subText : sender;
    }

    // 유효성 검사: sender, message 필수
    if (sender.isEmpty || message.isEmpty) {
      debugPrint('❌ 알림 무시: 필수 필드 누락 (sender=${sender.isEmpty}, message=${message.isEmpty})');
      return;
    }

    // 차단된 채팅방인지 확인
    final existingRoom = await _localDb.findRoom(roomName, packageName);
    if (existingRoom != null && existingRoom.blocked) {
      return;
    }

    // 알림 설정 확인 - 음소거된 채팅방인지
    final notificationService =
        Provider.of<NotificationSettingsService>(context, listen: false);

    // 음소거된 채팅방이면 알림만 삭제
    // 라인인 경우 chatId를 우선 사용 (roomName이 랜덤으로 변할 수 있음)
    final chatId = existingRoom?.chatId;
    if (notificationService.isMuted(roomName, packageName, chatId)) {
      try {
        await methodChannel.invokeMethod(
          'cancelAllNotificationsForRoom',
          {'roomName': roomName},
        );
      } catch (e) {
        debugPrint('❌ 알림 삭제 실패: $e');
      }
    }

    // 푸시 알림 저장
    // postTime은 Android에서 Long 타입으로 전달되므로 안전하게 변환
    int postTime;
    if (data['postTime'] != null) {
      if (data['postTime'] is int) {
        postTime = data['postTime'] as int;
      } else if (data['postTime'] is num) {
        postTime = (data['postTime'] as num).toInt();
      } else {
        postTime = DateTime.now().millisecondsSinceEpoch;
      }
    } else {
      postTime = DateTime.now().millisecondsSinceEpoch;
    }

    final savedId = await _localDb.saveNotification(
      packageName: packageName,
      sender: sender,
      message: message,
      roomName: roomName,
      postTime: postTime,
    );

    if (savedId == null) {
      debugPrint('❌ 알림 저장 실패: roomName=$roomName, sender=$sender');
    }

    // Android 네이티브에서 이미 DB에 저장했으므로 UI만 갱신
    if (mounted && _chatRoomListKey.currentState != null) {
      _chatRoomListKey.currentState!.refreshRooms();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _mainMethodSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 강제 업데이트 필요 시 업데이트 화면 표시
    if (_isForceUpdateRequired) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.system_update,
                  size: 80,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                const Text(
                  '업데이트가 필요합니다',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '앱을 계속 사용하려면\n최신 버전(${_versionCheckResult?.latestVersion ?? ""})으로\n업데이트해 주세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    if (_versionCheckResult != null) {
                      UpdateDialog.show(context, _versionCheckResult!);
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('업데이트하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ⚠️ 수정: 권한이 없으면 PermissionScreen 표시 (로딩 화면 제거로 깜빡임 방지)
    if (!_isPermissionGranted) {
      return PermissionScreen(
        onComplete: () {
          // 권한 확인 후 상태 업데이트 (빠른 체크만)
          _checkPermissionsOnly();
        },
      );
    }

    // 사용 가이드 표시 (최초 진입 시)
    if (_showGuide) {
      return const AppGuideScreen();
    }

    // 권한이 있으면 대화목록 화면 표시
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // 전면 광고 표시 후 앱 종료
        final adService = AdService();
        final adShown = await adService.showExitAd(
          onAdDismissed: () {
            SystemNavigator.pop();
          },
        );
        if (!adShown) {
          SystemNavigator.pop();
        }
      },
      child: ChatRoomListScreen(key: _chatRoomListKey),
    );
  }
}

// 알림 데이터 모델 (기존 호환용)
class NotificationData {
  final String packageName;
  final String title;
  final String text;
  final String subText;
  final String bigText;
  final int postTime;
  final int id;
  final String tag;
  final String key;
  final String groupKey;
  final String category;
  final String channelId;
  final String group;
  final String sortKey;
  final String tickerText;
  final String conversationTitle;
  final bool isGroupConversation;
  final String allExtras;

  NotificationData({
    required this.packageName,
    required this.title,
    required this.text,
    required this.subText,
    required this.bigText,
    required this.postTime,
    required this.id,
    required this.tag,
    required this.key,
    required this.groupKey,
    required this.category,
    required this.channelId,
    required this.group,
    required this.sortKey,
    required this.tickerText,
    required this.conversationTitle,
    required this.isGroupConversation,
    required this.allExtras,
  });

  factory NotificationData.fromMap(Map<String, dynamic> map) {
    return NotificationData(
      packageName: map['packageName'] ?? '',
      title: map['title'] ?? '',
      text: map['text'] ?? '',
      subText: map['subText'] ?? '',
      bigText: map['bigText'] ?? '',
      postTime: map['postTime'] ?? 0,
      id: map['id'] ?? 0,
      tag: map['tag'] ?? '',
      key: map['key'] ?? '',
      groupKey: map['groupKey'] ?? '',
      category: map['category'] ?? '',
      channelId: map['channelId'] ?? '',
      group: map['group'] ?? '',
      sortKey: map['sortKey'] ?? '',
      tickerText: map['tickerText'] ?? '',
      conversationTitle: map['conversationTitle'] ?? '',
      isGroupConversation: map['isGroupConversation'] ?? false,
      allExtras: map['allExtras'] ?? '',
    );
  }

  String get formattedTime {
    if (postTime == 0) return '';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(postTime);
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}
