import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'services/local_db_service.dart';
import 'services/notification_settings_service.dart';
import 'services/profile_image_service.dart';
import 'screens/chat_room_list_screen.dart';
import 'screens/permission_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationSettingsService()),
      ],
      child: MaterialApp(
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
      MethodChannel('com.example.chat_llm/notification');
  static const eventChannel =
      EventChannel('com.example.chat_llm/notification_stream');

  StreamSubscription? _subscription;
  bool _isPermissionGranted = false;
  final GlobalKey<ChatRoomListScreenState> _chatRoomListKey = GlobalKey();
  final LocalDbService _localDb = LocalDbService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAndCheckPermissions();
    _startListening();
  }
  
  Future<void> _initializeAndCheckPermissions() async {
    final notificationService =
        Provider.of<NotificationSettingsService>(context, listen: false);

    // 알림 설정 초기화
    await notificationService.initialize();

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
      // 알림 권한 또는 배터리 최적화 제외 권한이 없으면 권한 화면으로
      if (!notificationPermissionGranted || !batteryOptimizationDisabled) {
        debugPrint('⚠️ 권한 미허용 - 권한 화면으로 이동');
        debugPrint('  알림 권한: $notificationPermissionGranted');
        debugPrint('  배터리 최적화 제외: $batteryOptimizationDisabled');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PermissionScreen(
              onComplete: () {
                debugPrint('✅ 권한 화면 완료 콜백 호출됨');
                Future.microtask(() {
                  if (mounted) {
                    debugPrint('✅ 메인 화면으로 네비게이션 시작');
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                    );
                  }
                });
              },
            ),
          ),
        );
      } else {
        // 모든 권한이 있으면 메인 화면 유지
        debugPrint('✅ 모든 권한 허용됨 - 메인 화면 유지');
        _checkPermission(); // 기존 권한 확인 로직도 실행
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      debugPrint('🔄 앱 포그라운드 복귀 - 리스너 재구독 및 대화목록 새로고침');
      // 이벤트 리스너 재구독 (백그라운드에서 끊어졌을 수 있음)
      _subscription?.cancel();
      _startListening();
      // 대화목록 즉시 새로고침
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _chatRoomListKey.currentState?.refreshRooms();
        }
      });
    } else if (state == AppLifecycleState.paused) {
      debugPrint('⏸️ 앱 백그라운드로 이동');
    }
  }

  Future<void> _checkPermission() async {
    try {
      final bool isEnabled =
          await methodChannel.invokeMethod('isNotificationListenerEnabled');
      if (mounted) {
        setState(() {
          _isPermissionGranted = isEnabled;
        });
      }

      if (!isEnabled && mounted) {
        _showPermissionDialog();
      }
    } on PlatformException catch (e) {
      debugPrint('권한 확인 실패: ${e.message}');
    }
  }

  void _showPermissionDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('알림 접근 권한 필요'),
          content: const Text(
            '카카오톡 메시지를 수신하려면 알림 접근 권한이 필요합니다.\n\n설정에서 AI 톡비서의 알림 접근을 허용해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('나중에'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openSettings();
              },
              child: const Text('설정 열기'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _openSettings() async {
    try {
      await methodChannel.invokeMethod('openNotificationSettings');
    } on PlatformException catch (e) {
      debugPrint('설정 열기 실패: ${e.message}');
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

    // ChatRoomListScreen에 업데이트 전달
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
          }
        });
      }
    } else {
      debugPrint('⚠️ 위젯이 dispose됨 - 새로고침 스킵');
    }
  }

  /// 알림 수신 → UI 갱신 (Android 네이티브에서 이미 DB에 저장됨)
  Future<void> _handleNotification(Map<String, dynamic> data) async {
    debugPrint('📩 알림 수신: $data');

    final packageName = data['packageName'] ?? '';

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

    debugPrint('✅ === 알림 수신 → UI 갱신 (Android 네이티브에서 이미 저장됨) ===');
    debugPrint('  패키지: $packageName');
    debugPrint('  발신자: $sender, 대화방: $roomName');
    debugPrint('  메시지: $message');

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
