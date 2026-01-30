import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'services/auth_service.dart';
import 'services/notification_settings_service.dart';
import 'services/profile_image_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_room_list_screen.dart';
import 'screens/permission_screen.dart';
import 'config/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: KakaoConstants.nativeAppKey);

  // 한국어 날짜 포맷 초기화
  await initializeDateFormatting('ko_KR', null);
  
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
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => NotificationSettingsService()),
      ],
      child: MaterialApp(
        title: 'Chat LLM',
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
        home: const SplashScreen(),
      ),
    );
  }
}

// 스플래시 화면 - 초기화 및 자동 로그인 처리
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const MethodChannel _methodChannel = MethodChannel('com.example.chat_llm/notification');
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final notificationService =
        Provider.of<NotificationSettingsService>(context, listen: false);

    // 알림 설정 초기화
    await notificationService.initialize();

    // 자동 로그인 시도
    final isLoggedIn = await authService.initialize();

    // 필수 권한 확인 (알림 접근 권한)
    bool notificationPermissionGranted = false;
    try {
      notificationPermissionGranted = await _methodChannel.invokeMethod<bool>('isNotificationListenerEnabled') ?? false;
    } catch (e) {
      debugPrint('권한 확인 실패: $e');
    }

    if (mounted) {
      if (isLoggedIn && !notificationPermissionGranted) {
        // 로그인은 되어있지만 권한이 없으면 권한 화면으로
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PermissionScreen(
              onComplete: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                );
              },
            ),
          ),
        );
      } else {
        // 권한이 있거나 로그인이 안 되어있으면 기존 플로우
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => isLoggedIn ? const MainScreen() : const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앱 로고
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                size: 50,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chat LLM',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
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

class _MainScreenState extends State<MainScreen> {
  static const methodChannel =
      MethodChannel('com.example.chat_llm/notification');
  static const eventChannel =
      EventChannel('com.example.chat_llm/notification_stream');

  StreamSubscription? _subscription;
  bool _isPermissionGranted = false;
  final GlobalKey<ChatRoomListScreenState> _chatRoomListKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _startListening();
  }

  Future<void> _checkPermission() async {
    try {
      final bool isEnabled =
          await methodChannel.invokeMethod('isNotificationListenerEnabled');
      setState(() {
        _isPermissionGranted = isEnabled;
      });

      if (!isEnabled) {
        _showPermissionDialog();
      }
    } on PlatformException catch (e) {
      debugPrint('권한 확인 실패: ${e.message}');
    }
  }

  void _showPermissionDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('알림 접근 권한 필요'),
          content: const Text(
            '카카오톡 메시지를 수신하려면 알림 접근 권한이 필요합니다.\n\n설정에서 Chat LLM의 알림 접근을 허용해주세요.',
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
    _subscription = eventChannel.receiveBroadcastStream().listen(
      (event) async {
        if (event is Map) {
          final data = Map<String, dynamic>.from(event);
          final eventType = data['type'] ?? 'notification';

          if (eventType == 'room_updated') {
            // 채팅방 업데이트 이벤트 처리
            await _handleRoomUpdate(data);
          } else {
            // 기존 알림 이벤트 처리
            await _handleNotification(data);
          }
        }
      },
      onError: (error) {
        debugPrint('스트림 에러: $error');
      },
    );
  }

  /// 채팅방 업데이트 처리 (서버에서 응답이 왔을 때)
  Future<void> _handleRoomUpdate(Map<String, dynamic> data) async {
    debugPrint('=== 채팅방 업데이트 수신 ===');
    debugPrint('  roomId: ${data['roomId']}');
    debugPrint('  roomName: ${data['roomName']}');
    debugPrint('  unreadCount: ${data['unreadCount']}');
    debugPrint('  lastMessage: ${data['lastMessage']}');

    // ChatRoomListScreen에 업데이트 전달
    _chatRoomListKey.currentState?.updateRoom(data);
  }

  Future<void> _handleNotification(Map<String, dynamic> data) async {
    final packageName = data['packageName'] ?? '';

    // 지원하는 패키지인지 확인은 서버에서 처리
    // 클라이언트는 모든 알림을 서버로 전달하고, 서버에서 지원 여부를 확인
    if (packageName.isEmpty) {
      debugPrint('패키지명이 없는 알림 무시');
      return;
    }

    // 매핑: title -> sender, text -> message, subText -> roomName
    final sender = data['title'] ?? '';
    final message = data['text'] ?? '';
    final roomName = data['subText'] ?? '';

    // 유효성 검사: sender, message, roomName 모두 필수
    if (sender.isEmpty || message.isEmpty || roomName.isEmpty) {
      debugPrint('알림 무시: 필수 필드 누락');
      return;
    }

    // 알림 설정 확인 - 음소거된 채팅방인지
    final notificationService =
        Provider.of<NotificationSettingsService>(context, listen: false);

    if (notificationService.isMuted(roomName)) {
      debugPrint('알림 음소거됨: $roomName');
      // 음소거된 채팅방의 알림 자동 삭제
      try {
        await methodChannel.invokeMethod(
          'cancelAllNotificationsForRoom',
          {'roomName': roomName},
        );
        debugPrint('음소거 채팅방 알림 삭제 요청됨: $roomName');
      } catch (e) {
        debugPrint('알림 삭제 실패: $e');
      }
      return;
    }

    // API 호출은 Native(NotificationListener)에서 처리
    // Flutter는 UI 알림/갱신만 담당
    // 지원 여부는 서버에서 확인하므로 클라이언트는 모든 알림을 전달
    debugPrint('=== 알림 수신 (Native에서 API 호출) ===');
    debugPrint('  패키지: $packageName');
    debugPrint('  발신자: $sender, 대화방: $roomName');
  }

  @override
  void dispose() {
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
