import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 백그라운드/종료 상태 메시지 핸들러.
/// notification 페이로드는 시스템이 자동으로 트레이에 표시하므로 여기선 데이터 처리만.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 필요 시 데이터 메시지 처리. 현재는 시스템 표시에 위임.
}

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// 포그라운드 표시용 범용 채널 — 문의 답변·공지·이벤트 모두 이 채널로.
const AndroidNotificationChannel _generalChannel = AndroidNotificationChannel(
  'general',
  '알림',
  description: '문의 답변, 공지, 이벤트 알림',
  importance: Importance.high,
);

/// FCM 초기화 + 토큰 등록. DkswCore 초기화 이후(deviceId 확정) 호출해야 함.
///
/// 알림 권한 요청은 [requestNotificationPermission] 로 분리됨 —
/// 권한 화면 / 온보딩이 끝나고 채팅방 목록 첫 진입 시점에서 호출해야 사용자
/// 동선이 자연스러움 (그 전에 호출하면 권한 화면 위에 OS 다이얼로그 겹침).
class PushService {
  static int _notifId = 2000;

  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;

      // 로컬 알림 init — 포그라운드(앱 실행 중)에서 FCM 을 직접 표시하기 위함.
      // 백그라운드/종료 상태에선 시스템이 notification 페이로드를 자동 표시.
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_generalChannel);

      // 포그라운드 수신 — 시스템이 자동 표시 안 하므로 직접 띄움.
      FirebaseMessaging.onMessage.listen(_showForeground);

      // Android 는 POST_NOTIFICATIONS 권한 없어도 토큰 발급됨 — 권한 요청은 분리.
      final token = await messaging.getToken();
      if (token != null) await DkswCore.registerInquiryFcmToken(token);
      messaging.onTokenRefresh.listen(DkswCore.registerInquiryFcmToken);
    } catch (_) {
      // 푸시 셋업 실패가 앱 부팅을 막지 않도록 무시
    }
  }

  /// 포그라운드에서 받은 FCM 메시지를 로컬 알림으로 표시.
  static void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return; // data-only 메시지는 표시 대상 아님
    final body = n.body ?? '';
    _localNotifications.show(
      _notifId++,
      n.title ?? '알림',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _generalChannel.id,
          _generalChannel.name,
          channelDescription: _generalChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  /// OS 알림 권한(POST_NOTIFICATIONS / iOS notification) 요청.
  /// 채팅방 목록 첫 진입 시점에 호출 — 권한 화면이나 온보딩 위에 겹쳐 뜨지 않도록.
  static Future<void> requestNotificationPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
  }
}
