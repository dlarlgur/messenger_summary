import 'package:dio/dio.dart';
import 'package:dksw_app_core/dksw_app_core.dart';

/// charge_server 의 멀티앱 문의/푸시 등록 API 클라이언트.
/// (chat_llm 메인 백엔드와 별개 — 문의/FCM 등록만 charge_server 경유)
class SupportService {
  static const String appId = 'com.dksw.app';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://charge.dksw4.com/api',
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
  ));

  /// FCM 토큰을 push_devices 에 등록 (app_id = com.dksw.app)
  static Future<void> registerFcm(String token) async {
    try {
      await _dio.post('/alerts/device', data: {
        'appId': appId,
        'deviceId': DkswCore.deviceId,
        'fcmToken': token,
      });
    } catch (_) {}
  }

  static Future<bool> createInquiry({
    required String title,
    required String content,
  }) async {
    final res = await _dio.post('/inquiries', data: {
      'app_id': appId,
      'device_id': DkswCore.deviceId,
      'title': title,
      'content': content,
    });
    return res.data?['success'] == true;
  }

  static Future<List<Map<String, dynamic>>> getMyInquiries() async {
    final res = await _dio.get('/inquiries', queryParameters: {
      'app_id': appId,
      'device_id': DkswCore.deviceId,
    });
    final list = res.data?['inquiries'];
    if (list is List) {
      return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
}
