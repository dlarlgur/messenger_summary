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
import 'screens/chat_room_list_screen.dart';
import 'screens/permission_screen.dart';
import 'screens/summary_history_screen.dart';
import 'screens/app_guide_screen.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 한국어 날짜 포맷 초기화
  await initializeDateFormatting('ko_KR', null);

  // 로컬 DB 초기화
  await LocalDbService().initialize();

  // 프로필 이미지 서비스 초기화 (앱 시작 시 한 번)
  await ProfileImageService().initialize();

  runApp(const MyApp());
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
  bool _isPermissionGranted = false;
  bool _isCheckingPermissions = true; // ⚠️ 수정: 권한 확인 중인지 여부
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

  /// 빠른 초기화: JWT 토큰이 있으면 즉시 화면 표시
  Future<void> _fastInitialize() async {
    debugPrint('🚀 빠른 초기화 시작');
    
    try {
      // 1. JWT 토큰 확인 (빠르게)
      final authService = AuthService();
      final token = await authService.getJwtToken();
      
      if (token != null) {
        debugPrint('✅ JWT 토큰 있음 - 즉시 화면 표시');
        // JWT 토큰이 있으면 즉시 화면 표시 (권한 체크는 백그라운드에서)
        if (mounted) {
          setState(() {
            _isCheckingPermissions = false; // 화면 표시 허용
            _isPermissionGranted = true; // 일단 권한 있음으로 설정 (백그라운드에서 재확인)
          });
        }
        
        // 백그라운드에서 나머지 작업 처리
        _backgroundInitialize();
      } else {
        debugPrint('⚠️ JWT 토큰 없음 - 전체 초기화 진행');
        // JWT 토큰이 없으면 전체 초기화 진행
        await _fullInitialize();
      }
    } catch (e) {
      debugPrint('❌ 빠른 초기화 실패: $e');
      // 실패 시 전체 초기화 진행
      await _fullInitialize();
    }
  }

  /// 전체 초기화 (JWT 토큰이 없을 때)
  Future<void> _fullInitialize() async {
    debugPrint('🚀 전체 초기화 시작');
    
    // 버전 체크와 JWT 토큰 발급을 비동기로 동시에 실행
    final versionCheckFuture = _checkVersion();
    final jwtTokenFuture = _getJwtToken();
    
    // 두 작업 모두 완료될 때까지 대기
    await Future.wait([versionCheckFuture, jwtTokenFuture]);
    
    // JWT 토큰이 발급된 후 구독 정보 조회
    await _checkSubscription();
    
    // 권한 체크 및 초기화 진행
    _initializeAndCheckPermissions();
  }

  /// 백그라운드 초기화 (JWT 토큰이 있을 때)
  void _backgroundInitialize() {
    debugPrint('🔄 백그라운드 초기화 시작');
    
    // 모든 작업을 백그라운드에서 비동기로 처리
    Future.microtask(() async {
      try {
        // 1. 버전 체크 (강제 업데이트만 체크)
        await _checkVersion();
        
        // 2. 구독 정보 조회 (기기 변경 시 구독 부활 포함)
        await _checkSubscription();
        
        // 3. 권한 체크 (백그라운드에서 처리)
        await _initializeAndCheckPermissions();
      } catch (e) {
        debugPrint('❌ 백그라운드 초기화 오류: $e');
      }
    });
  }
  
  /// 버전 체크 (비동기, 백그라운드에서 실행)
  Future<void> _checkVersion() async {
    try {
      final versionService = AppVersionService();
      debugPrint('🚀 버전 체크 호출 전');
      final result = await versionService.checkVersion();
      debugPrint('🚀 버전 체크 완료: updateRequired=${result.updateRequired}, updateType=${result.updateType}');

      if (result.updateRequired && result.updateType == UpdateType.force) {
        // 강제 업데이트만 앱 시작 시 처리
        _versionCheckResult = result;
        debugPrint('🚨 강제 업데이트 필요: ${result.latestVersion}');
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
      debugPrint('버전 체크 실패: $e');
      // 버전 체크 실패 시 앱 사용 허용
    }
  }
  
  /// JWT 토큰 발급 (비동기)
  Future<void> _getJwtToken() async {
    try {
      final authService = AuthService();
      final token = await authService.getJwtToken();
      if (token != null) {
        debugPrint('✅ JWT 토큰 발급 성공 (자동 요약 준비 완료)');
      } else {
        debugPrint('⚠️ JWT 토큰 발급 실패 - 자동 요약 불가');
      }
    } catch (e) {
      debugPrint('JWT 토큰 발급 오류: $e');
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
          debugPrint('⏭️ 구독 동기화 스킵: ${hoursSinceLastSync}시간 전에 동기화됨 (${syncIntervalHours}시간 간격)');
          return;
        }
      }
      
      debugPrint('🔄 구독 동기화 시작 (마지막 동기화: ${lastSyncTimeMillis != null ? DateTime.fromMillisecondsSinceEpoch(lastSyncTimeMillis) : "없음"})');
      
      final planService = PlanService();
      final purchaseService = InAppPurchaseService();
      
      // 1. 인앱 결제 서비스 초기화 (백그라운드에서)
      final initialized = await purchaseService.initialize();
      if (!initialized) {
        debugPrint('⚠️ 인앱 결제 초기화 실패, 구독 정보만 조회');
        // 인앱 결제 초기화 실패해도 구독 정보는 조회 시도
        final currentPlan = await planService.getCurrentPlan();
        if (currentPlan != null) {
          debugPrint('✅ 구독 정보 조회 성공: planType=${currentPlan['planType']}');
          // 동기화 시간 저장
          await prefs.setInt(lastSyncKey, DateTime.now().millisecondsSinceEpoch);
        }
        return;
      }

      // 2. 과거 구매 내역 조회 (기기 변경 시 구독 부활용)
      // restorePurchases()를 호출하면 purchaseStream을 통해 과거 구매 내역이 전달됨
      purchaseService.queryPastPurchases(); // await 제거 (백그라운드에서 처리)
      
      // 3. 잠시 대기 (purchaseStream에서 purchaseToken 캐시될 시간 확보)
      // 주의: restorePurchases()는 비동기로 purchaseStream을 통해 결과를 전달하므로
      // 실제 purchaseToken은 _handlePurchaseUpdate()에서 캐시됩니다.
      // 따라서 짧은 딜레이 후 캐시된 purchaseToken을 조회합니다.
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 4. 캐시된 purchaseToken 조회
      final purchaseToken = purchaseService.getCachedPurchaseToken();
      
      // 5. 구독 정보 동기화 (purchaseToken이 있으면 함께 전송)
      final currentPlan = await planService.getCurrentPlan(
        purchaseToken: purchaseToken,
      );
      
      if (currentPlan != null) {
        debugPrint('✅ 구독 정보 동기화 성공: planType=${currentPlan['planType']}');
        if (purchaseToken != null) {
          debugPrint('✅ purchaseToken으로 구독 부활 시도 완료');
        }
        
        // 동기화 시간 저장
        await prefs.setInt(lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      } else {
        debugPrint('⚠️ 구독 정보 동기화 실패');
      }
    } catch (e) {
      debugPrint('구독 정보 동기화 오류: $e');
    }
  }

  /// Main MethodChannel 설정 (summaryId 수신용)
  void _setupMainMethodChannel() {
    mainMethodChannel.setMethodCallHandler((call) async {
      if (call.method == 'openSummary') {
        final summaryId = call.arguments as int?;
        if (summaryId != null && summaryId > 0) {
          debugPrint('📱 MainMethodChannel에서 summaryId 수신: $summaryId');
          _openSummaryFromNotification(summaryId);
        }
      }
    });
  }

  /// 대기 중인 summaryId 확인 및 처리
  Future<void> _checkPendingSummaryId() async {
    try {
      // 먼저 MethodChannel에서 확인
      final summaryIdFromChannel = await mainMethodChannel.invokeMethod<int?>('getPendingSummaryId');
      int? summaryId = summaryIdFromChannel;
      
      // MethodChannel에 없으면 SharedPreferences에서 확인
      if (summaryId == null || summaryId <= 0) {
        final prefs = await SharedPreferences.getInstance();
        summaryId = prefs.getInt('flutter.pending_summary_id');
        if (summaryId != null && summaryId > 0) {
          await prefs.remove('flutter.pending_summary_id');
        }
      }
      
      if (summaryId != null && summaryId > 0) {
        debugPrint('📱 대기 중인 summaryId 발견: $summaryId');
        _openSummaryFromNotification(summaryId);
      }
    } catch (e) {
      debugPrint('대기 중인 summaryId 처리 실패: $e');
    }
  }

  /// 알림에서 받은 summaryId로 요약 히스토리 열기
  Future<void> _openSummaryFromNotification(int summaryId) async {
    // 이미 처리한 summaryId는 무시 (중복 방지)
    if (_processedSummaryIds.contains(summaryId)) {
      debugPrint('📱 이미 처리한 summaryId 무시: $summaryId');
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
              debugPrint('📱 요약 히스토리 화면으로 이동: roomId=$roomId, summaryId=$summaryId');
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => SummaryHistoryScreen(
                    roomId: roomId,
                    roomName: room.roomName,
                    initialSummaryId: summaryId,
                  ),
                ),
              );
            } else {
              debugPrint('⚠️ Navigator를 찾을 수 없음');
            }
          });
        } else {
          debugPrint('⚠️ 채팅방을 찾을 수 없음: roomId=$roomId');
        }
      } else {
        debugPrint('⚠️ summaryId로 roomId를 찾을 수 없음: summaryId=$summaryId');
      }
    } catch (e) {
      debugPrint('요약 히스토리 열기 실패: $e');
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
      debugPrint('알림 권한 확인 실패: $e');
    }

    try {
      batteryOptimizationDisabled =
          await methodChannel.invokeMethod<bool>('isBatteryOptimizationDisabled') ?? false;
    } catch (e) {
      debugPrint('배터리 최적화 권한 확인 실패: $e');
    }

    if (mounted) {
      // 필수 권한이 모두 없으면 권한 화면으로 이동하지 않고 대화목록 유지
      // (권한은 사용자가 설정에서 직접 설정하도록 유도)
      if (!notificationPermissionGranted || !batteryOptimizationDisabled) {
        debugPrint('⚠️ 권한 미허용 - 대화목록 유지 (권한은 설정에서 설정 가능)');
        debugPrint('  알림 권한: $notificationPermissionGranted');
        debugPrint('  배터리 최적화 제외: $batteryOptimizationDisabled');
        // 권한이 없어도 대화목록은 유지 (권한 화면으로 강제 이동하지 않음)
        setState(() {
          _isPermissionGranted = true; // 대화목록 유지
          _isCheckingPermissions = false; // 권한 확인 완료
        });
      } else {
        // 모든 필수 권한이 있으면 메인 화면 유지
        debugPrint('✅ 모든 필수 권한 허용됨 - 메인 화면 유지');
        debugPrint('  알림 권한: $notificationPermissionGranted');
        debugPrint('  배터리 최적화 제외: $batteryOptimizationDisabled');
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
      debugPrint('자동요약 알림 팝업 확인 실패: $e');
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
                            debugPrint('설정 화면 열기 실패: $e');
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
      debugPrint('🔄 앱 포그라운드 복귀 - 리스너 재구독 및 대화목록 새로고침');
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
    } else if (state == AppLifecycleState.paused) {
      debugPrint('⏸️ 앱 백그라운드로 이동');
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
            debugPrint('🔄 스트림 에러 후 재구독 시도...');
            _startListening();
          }
        });
      },
      cancelOnError: false, // 에러 발생해도 구독 유지
    );
    debugPrint('✅ 이벤트 리스너 구독 시작');
  }

  /// 채팅방 업데이트 처리
  Future<void> _handleRoomUpdate(Map<String, dynamic> data) async {
    debugPrint('=== ✅ 채팅방 업데이트 수신 ===');
    debugPrint('  roomName: ${data['roomName']}');
    debugPrint('  roomId: ${data['roomId']}');
    debugPrint('  unreadCount: ${data['unreadCount']}');
    debugPrint('  lastMessage: ${data['lastMessage']}');
    debugPrint('  lastMessageTime: ${data['lastMessageTime']}');

    // ⚠️ 보수적 수정: ChatRoomListScreen에 업데이트 전달
    // 즉시 실행하여 빠른 동기화 보장
    if (mounted) {
      if (_chatRoomListKey.currentState != null) {
        debugPrint('🔄 대화방 목록 새로고침 요청 (ChatRoomListScreen 상태: 활성)');
        _chatRoomListKey.currentState!.refreshRooms();
      } else {
        debugPrint('⚠️ ChatRoomListScreen이 아직 초기화되지 않음 - 나중에 다시 시도');
        // 위젯이 아직 초기화되지 않았을 수 있으므로 잠시 후 다시 시도
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _chatRoomListKey.currentState != null) {
            debugPrint('🔄 대화방 목록 새로고침 재시도');
            _chatRoomListKey.currentState!.refreshRooms();
          } else {
            debugPrint('⚠️ 재시도 실패: 위젯이 dispose되었거나 ChatRoomListScreen이 없음');
          }
        });
      }
    } else {
      debugPrint('⚠️ 위젯이 dispose됨 - 새로고침 스킵');
    }
  }

  /// 배지 업데이트
  Future<void> _updateNotificationBadge() async {
    try {
      final unreadCount = await _localDb.getUnreadNotificationCount();
      await methodChannel.invokeMethod('updateNotificationBadge', {'count': unreadCount});
      debugPrint('📊 배지 업데이트: $unreadCount개');
    } catch (e) {
      debugPrint('❌ 배지 업데이트 실패: $e');
    }
  }

  /// 알림 수신 → UI 갱신 (Android 네이티브에서 이미 DB에 저장됨)
  Future<void> _handleNotification(Map<String, dynamic> data) async {
    debugPrint('📩 알림 수신: $data');

    final packageName = data['packageName'] ?? '';
    final type = data['type'] ?? 'notification';
    final isAutoSummary = data['isAutoSummary'] == true || type == 'auto_summary';
    final summaryId = data['summaryId'] as int?;

    // 자동요약 알림인 경우 별도 처리
    if (isAutoSummary) {
      debugPrint('🤖 자동요약 알림 수신: summaryId=$summaryId');
      
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
      debugPrint('🔇 시스템 알림 무시: $packageName');
      return;
    }

    // 지원하는 메신저인지 확인
    if (!_localDb.isSupportedMessenger(packageName)) {
      debugPrint('❌ 지원하지 않는 메신저: $packageName');
      return;
    }

    // 매핑: title -> sender, text -> message, subText -> roomName
    final sender = data['title'] ?? '';
    final message = data['text'] ?? '';
    final subText = data['subText'] ?? '';

    // 개인톡: subText가 비어있으면 sender를 roomName으로 사용
    // 그룹톡: subText가 채팅방 이름
    final roomName = subText.isNotEmpty ? subText : sender;

    debugPrint('📝 파싱 결과: sender=$sender, message=$message, roomName=$roomName');

    // 유효성 검사: sender, message 필수
    if (sender.isEmpty || message.isEmpty) {
      debugPrint('❌ 알림 무시: 필수 필드 누락 (sender=${sender.isEmpty}, message=${message.isEmpty})');
      return;
    }

    // 차단된 채팅방인지 확인
    final existingRoom = await _localDb.findRoom(roomName, packageName);
    if (existingRoom != null && existingRoom.blocked) {
      debugPrint('🚫 차단된 채팅방 알림 무시: $roomName');
      return;
    }

    // 알림 설정 확인 - 음소거된 채팅방인지
    final notificationService =
        Provider.of<NotificationSettingsService>(context, listen: false);

    // 음소거된 채팅방이면 알림만 삭제
    if (notificationService.isMuted(roomName)) {
      debugPrint('🔇 알림 음소거됨: $roomName');
      try {
        await methodChannel.invokeMethod(
          'cancelAllNotificationsForRoom',
          {'roomName': roomName},
        );
      } catch (e) {
        debugPrint('❌ 알림 삭제 실패: $e');
      }
    }

    debugPrint('✅ === 알림 수신 → 푸시 알림 저장 ===');
    debugPrint('  패키지: $packageName');
    debugPrint('  발신자: $sender, 대화방: $roomName');
    debugPrint('  메시지: $message');

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
        debugPrint('⚠️ postTime 타입 변환 실패, 현재 시간 사용');
      }
    } else {
      postTime = DateTime.now().millisecondsSinceEpoch;
      debugPrint('⚠️ postTime이 없음, 현재 시간 사용');
    }

    debugPrint('📝 알림 저장 시도: postTime=$postTime');
    final savedId = await _localDb.saveNotification(
      packageName: packageName,
      sender: sender,
      message: message,
      roomName: roomName,
      postTime: postTime,
    );

    if (savedId != null) {
      debugPrint('✅ 알림 저장 성공: id=$savedId');
    } else {
      debugPrint('❌ 알림 저장 실패: 저장된 ID가 null');
    }

    // Android 네이티브에서 이미 DB에 저장했으므로 UI만 갱신
    // 즉시 실행하여 빠른 동기화 보장
    if (mounted && _chatRoomListKey.currentState != null) {
      debugPrint('🔄 대화방 목록 새로고침 요청');
      _chatRoomListKey.currentState!.refreshRooms();
      debugPrint('✅ UI 갱신 요청 완료');
    } else {
      debugPrint('⚠️ ChatRoomListScreen이 아직 초기화되지 않음 또는 위젯이 dispose됨');
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

    // ⚠️ 수정: 권한 확인 중이면 로딩 표시
    if (_isCheckingPermissions) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ⚠️ 수정: 권한이 없으면 PermissionScreen 표시
    if (!_isPermissionGranted) {
      return PermissionScreen(
        onComplete: () {
          debugPrint('✅ 권한 화면 완료 콜백 호출됨');
          // 권한 확인 후 상태 업데이트
          _initializeAndCheckPermissions();
        },
      );
    }

    // 사용 가이드 표시 (최초 진입 시)
    if (_showGuide) {
      return const AppGuideScreen();
    }

    // 권한이 있으면 대화목록 화면 표시
    return ChatRoomListScreen(key: _chatRoomListKey);
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
