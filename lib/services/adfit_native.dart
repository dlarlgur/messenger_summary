import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android 네이티브 Kakao AdFit SDK 연동 (팝업: 앱 종료 / 앱 전환)
class AdFitNative {
  static const MethodChannel _channel = MethodChannel('com.dksw.app/adfit');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// 앱 종료형 팝업 광고. [Map] keys: ok, type, reason, errorCode
  static Future<Map<String, dynamic>?> showExitPopupAd(String clientId) async {
    if (!_supported) return {'ok': false, 'reason': 'unsupported_platform'};
    try {
      final raw = await _channel.invokeMethod<dynamic>('showExitPopupAd', {
        'clientId': clientId,
      });
      return _asStringKeyMap(raw);
    } on PlatformException catch (e) {
      debugPrint('AdFit showExitPopupAd: ${e.message}');
      return {'ok': false, 'reason': 'platform_exception', 'message': e.message};
    }
  }

  /// 앱 전환형 팝업 광고 (채팅방 나가기 등)
  static Future<Map<String, dynamic>?> showTransitionPopupAd(String clientId) async {
    if (!_supported) return {'ok': false, 'reason': 'unsupported_platform'};
    try {
      final raw = await _channel.invokeMethod<dynamic>('showTransitionPopupAd', {
        'clientId': clientId,
      });
      return _asStringKeyMap(raw);
    } on PlatformException catch (e) {
      debugPrint('AdFit showTransitionPopupAd: ${e.message}');
      return {'ok': false, 'reason': 'platform_exception', 'message': e.message};
    }
  }

  static Map<String, dynamic>? _asStringKeyMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), _unwrap(v)));
    }
    return null;
  }

  static dynamic _unwrap(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _unwrap(val)));
    }
    if (v is List) {
      return v.map(_unwrap).toList();
    }
    return v;
  }
}
