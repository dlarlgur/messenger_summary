import 'dart:async';
import 'dart:convert';

import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../screens/events_screen.dart';
import '../screens/notices_screen.dart';
import '../widgets/inquiry_native_ad_banner.dart';

/// 백그라운드/종료 상태 메시지 핸들러.
/// notification 페이로드는 시스템이 자동으로 트레이에 표시하므로 여기선 데이터 처리만.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 필요 시 데이터 메시지 처리. 현재는 시스템 표시에 위임.
}

/// 포그라운드로 띄운 로컬 알림을 **알림창에서** 탭하면 앱이 잠깐 paused 상태라
/// onDidReceiveNotificationResponse(포그라운드 콜백) 대신 이 백그라운드 핸들러로 올 수 있다.
/// 별도 isolate라 네비게이션 불가 → payload 를 저장해두고, 앱 resume 시
/// [PushService.checkPendingDeepLink] 가 읽어 라우팅한다.
const String _kPendingDeepLink = 'pending_push_deeplink';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final p = response.payload;
  if (p == null || p.isEmpty) return;
  SharedPreferences.getInstance().then((sp) => sp.setString(_kPendingDeepLink, p));
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
  static bool _tapHandlersRegistered = false;

  // 딥링크 push 가 SplashScreen→MainScreen 전환에 덮어써지지 않도록, MainScreen 이
  // 올라온 뒤에만 라우팅한다. MainScreen.initState 에서 signalAppReady() 호출.
  static final Completer<void> _appReady = Completer<void>();
  static void signalAppReady() {
    if (!_appReady.isCompleted) _appReady.complete();
  }

  static Future<void> initialize() async {
    try {
      debugPrint('[PUSH] initialize 시작');
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;

      // 로컬 알림 init — 포그라운드(앱 실행 중)에서 FCM 을 직접 표시하기 위함.
      // 백그라운드/종료 상태에선 시스템이 notification 페이로드를 자동 표시.
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        // 포그라운드에서 띄운 로컬 알림 탭 → 딥링크 라우팅
        onDidReceiveNotificationResponse: _handleLocalTap,
        // 알림창에서 탭(앱 paused) → 백그라운드 isolate 로 올 수 있어 별도 등록
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_generalChannel);

      // 포그라운드 수신 — 시스템이 자동 표시 안 하므로 직접 띄움.
      FirebaseMessaging.onMessage.listen(_showForeground);

      // 알림 탭 → 딥링크 라우팅 (중복 등록 방지)
      if (!_tapHandlersRegistered) {
        _tapHandlersRegistered = true;
        // 백그라운드(앱 실행 중) 상태에서 알림 탭
        FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteTap);
        // 종료 상태에서 알림 탭으로 앱이 켜진 경우 (런치 메시지)
        FirebaseMessaging.instance.getInitialMessage().then((m) {
          debugPrint('[PUSH] getInitialMessage = ${m?.data}');
          if (m != null) _handleRemoteTap(m);
        });
        debugPrint('[PUSH] tap handlers 등록 완료');
      }

      // 백그라운드 탭으로 저장된 대기 딥링크가 있으면 처리 (콜드 스타트 케이스)
      checkPendingDeepLink();

      // Android 는 POST_NOTIFICATIONS 권한 없어도 토큰 발급됨 — 권한 요청은 분리.
      final token = await messaging.getToken();
      if (token != null) await DkswCore.registerInquiryFcmToken(token);
      messaging.onTokenRefresh.listen(DkswCore.registerInquiryFcmToken);
      debugPrint('[PUSH] initialize 완료 (token=${token != null})');
    } catch (e, st) {
      // 푸시 셋업 실패가 앱 부팅을 막지 않도록 무시 — 단 원인은 로그로 남긴다.
      debugPrint('[PUSH] initialize 실패: $e\n$st');
    }
  }

  /// 포그라운드에서 받은 FCM 메시지를 로컬 알림으로 표시.
  static void _showForeground(RemoteMessage message) {
    debugPrint('[PUSH] onMessage(foreground 수신) data=${message.data} hasNotif=${message.notification != null}');
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
      // 탭 시 딥링크 라우팅용 — FCM data 를 그대로 실어 보냄.
      payload: jsonEncode(message.data),
    );
  }

  /// 포그라운드 로컬 알림 탭 핸들러 — payload(JSON) 를 파싱해 라우팅.
  static void _handleLocalTap(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('[PUSH] _handleLocalTap payload=$payload');
    if (payload == null || payload.isEmpty) return;
    try {
      final data = (jsonDecode(payload) as Map).cast<String, dynamic>();
      _route(data);
    } catch (e) {
      debugPrint('[PUSH] _handleLocalTap parse 실패: $e');
    }
  }

  /// 백그라운드/종료 상태 알림 탭 핸들러.
  static void _handleRemoteTap(RemoteMessage message) {
    debugPrint('[PUSH] _handleRemoteTap data=${message.data}');
    _route(message.data);
  }

  /// 백그라운드 isolate(알림창 탭)에서 저장해둔 대기 딥링크를 읽어 라우팅.
  /// 앱 시작(initialize) 및 resume(생명주기) 시 호출.
  static Future<void> checkPendingDeepLink() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.reload(); // 다른 isolate 가 쓴 값을 보기 위해 갱신
      final p = sp.getString(_kPendingDeepLink);
      if (p == null || p.isEmpty) return;
      await sp.remove(_kPendingDeepLink);
      debugPrint('[PUSH] pending deeplink 처리: $p');
      final data = (jsonDecode(p) as Map).cast<String, dynamic>();
      _route(data);
    } catch (e) {
      debugPrint('[PUSH] pending deeplink 실패: $e');
    }
  }

  /// FCM data 기반 라우팅 — 1:1 문의 답변 / 이벤트 / 공지 딥링크.
  /// 종료 상태에서 켜질 땐 navigator 가 아직 준비 전일 수 있어 준비될 때까지 재시도.
  static Future<void> _route(Map<String, dynamic> data, {int attempt = 0}) async {
    final type = data['type']?.toString();
    if (type != 'inquiry_reply' && type != 'event' && type != 'notice') return;

    // MainScreen 이 올라온 뒤에만 push — 안 그러면 SplashScreen→MainScreen 전환이
    // 딥링크로 push 한 화면을 덮어써 메인으로 돌아간다(종료상태 진입 레이스).
    if (attempt == 0) {
      debugPrint('[PUSH] _route type=$type, appReady 대기...');
      await _appReady.future.timeout(const Duration(seconds: 12), onTimeout: () {});
    }

    final nav = MyApp.navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[PUSH] _route nav=null attempt=$attempt');
      if (attempt >= 12) return; // 최대 ~6초 대기 후 포기
      await Future.delayed(const Duration(milliseconds: 500));
      return _route(data, attempt: attempt + 1);
    }
    debugPrint('[PUSH] _route nav 준비됨 → type=$type 라우팅');

    if (type == 'inquiry_reply') {
      final id = int.tryParse(data['inquiryId']?.toString() ?? '');
      nav.push(MaterialPageRoute(
        builder: (_) => InquiryScreen(
          topBanner: const InquiryNativeAdBanner(),
          bannerAboveHeader: true,
          initialInquiryId: id,
        ),
      ));
      return;
    }

    // 이벤트 / 공지 — id 로 항목을 받아 상세로 직행. 푸시 탭 직후엔 네트워크가 덜 준비돼
    // 첫 fetch 가 비거나 늦을 수 있으므로, 못 찾으면 잠깐 뒤 재시도한 뒤 폴백한다.
    final id = int.tryParse(data['id']?.toString() ?? '');
    if (type == 'event') {
      _routeToEventDetail(nav, id);
    } else if (type == 'notice') {
      _routeToNoticeDetail(nav, id);
    }
  }

  static Future<void> _routeToEventDetail(NavigatorState nav, int? id,
      {int attempt = 0}) async {
    EventItem? item;
    try {
      final list = await DkswCore.fetchEvents();
      for (final e in list) {
        if (e.id == id) { item = e; break; }
      }
    } catch (_) {}
    if (item == null && id != null && attempt < 4) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _routeToEventDetail(nav, id, attempt: attempt + 1);
    }
    final found = item;
    nav.push(MaterialPageRoute(
      builder: (_) =>
          found != null ? EventDetailScreen(event: found) : const EventsScreen(),
    ));
  }

  static Future<void> _routeToNoticeDetail(NavigatorState nav, int? id,
      {int attempt = 0}) async {
    NoticeItem? item;
    try {
      final list = await DkswCore.fetchNotices();
      for (final n in list) {
        if (n.id == id) { item = n; break; }
      }
    } catch (_) {}
    if (item == null && id != null && attempt < 4) {
      await Future.delayed(const Duration(milliseconds: 600));
      return _routeToNoticeDetail(nav, id, attempt: attempt + 1);
    }
    final found = item;
    nav.push(MaterialPageRoute(
      builder: (_) =>
          found != null ? NoticeDetailScreen(notice: found) : const NoticesScreen(),
    ));
  }

  /// OS 알림 권한(POST_NOTIFICATIONS / iOS notification) 요청.
  /// 채팅방 목록 첫 진입 시점에 호출 — 권한 화면이나 온보딩 위에 겹쳐 뜨지 않도록.
  static Future<void> requestNotificationPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
  }
}
