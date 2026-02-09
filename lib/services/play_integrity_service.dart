import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Google Play Integrity 토큰 요청 서비스
/// 플랫폼 채널을 통해 Android 네이티브 코드 호출
class PlayIntegrityService {
  static const MethodChannel _channel = MethodChannel('com.dksw.chat_llm/play_integrity');
  static const String _cloudProjectNumber = '138022204590';

  /// Play Integrity 토큰 요청
  /// Android에서만 동작하며, iOS에서는 null 반환
  static Future<String?> requestIntegrityToken() async {
    try {
      // Android에서만 실행
      final result = await _channel.invokeMethod<String>(
        'requestIntegrityToken',
        {'cloudProjectNumber': _cloudProjectNumber},
      );
      return result;
    } on PlatformException catch (e) {
      print('Play Integrity 토큰 요청 실패: ${e.message}');
      return null;
    } catch (e) {
      print('Play Integrity 토큰 요청 실패: $e');
      return null;
    }
  }

  /// Android ID 가져오기 (기기 고유 식별자)
  static Future<String?> getDeviceId() async {
    try {
      final result = await _channel.invokeMethod<String>('getDeviceId');
      return result;
    } on PlatformException catch (e) {
      print('Device ID 조회 실패: ${e.message}');
      return null;
    } catch (e) {
      print('Device ID 조회 실패: $e');
      return null;
    }
  }
}
