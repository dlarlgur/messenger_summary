import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// 백그라운드/종료 상태 메시지 핸들러.
/// notification 페이로드는 시스템이 자동으로 트레이에 표시하므로 여기선 데이터 처리만.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 필요 시 데이터 메시지 처리. 현재는 시스템 표시에 위임.
}

/// FCM 초기화 + 토큰 등록. DkswCore 초기화 이후(deviceId 확정) 호출해야 함.
///
/// 알림 권한 요청은 [requestNotificationPermission] 로 분리됨 —
/// 권한 화면 / 온보딩이 끝나고 채팅방 목록 첫 진입 시점에서 호출해야 사용자
/// 동선이 자연스러움 (그 전에 호출하면 권한 화면 위에 OS 다이얼로그 겹침).
class PushService {
  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      // Android 는 POST_NOTIFICATIONS 권한 없어도 토큰 발급됨 — 권한 요청은 분리.
      final token = await messaging.getToken();
      if (token != null) await DkswCore.registerInquiryFcmToken(token);
      messaging.onTokenRefresh.listen(DkswCore.registerInquiryFcmToken);
    } catch (_) {
      // 푸시 셋업 실패가 앱 부팅을 막지 않도록 무시
    }
  }

  /// OS 알림 권한(POST_NOTIFICATIONS / iOS notification) 요청.
  /// 채팅방 목록 첫 진입 시점에 호출 — 권한 화면이나 온보딩 위에 겹쳐 뜨지 않도록.
  static Future<void> requestNotificationPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
  }
}
