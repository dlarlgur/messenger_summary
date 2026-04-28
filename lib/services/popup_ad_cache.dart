import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 홈 팝업 광고 디스크 캐시 — stale-while-revalidate.
///
/// 같은 패턴을 [SplashAdCache] 가 쓰고 있고, 이 클래스는 placement = 'popup'
/// 광고용 사본이다. chat_llm 은 Hive 미사용이라 메타는 SharedPreferences,
/// 이미지 바이트는 application support 디렉토리 파일에 저장.
///
/// 동작:
///  - 진입 시 캐시된 광고를 즉시 노출 → 네트워크 fetch 대기 없음 (광고 0ms)
///  - 동시에 서버 /api/popup 로 새 광고 fetch → 디스크 갱신 → 다음 진입 반영
///  - 캐시 max age 7일.
///  - 콘솔에서 광고 비활성화/삭제 시 다음 fetch 가 null 받아 [clear] 호출.
///    한 번의 노출 지연(이미 캐시된 옛 광고 한 번 더 보임) 은 의도된 트레이드오프.
class PopupAdCache {
  static const String _kAdJson = 'popup_ad_cache_json';
  static const String _kAdSavedAt = 'popup_ad_cache_saved_at';
  static const String _imageFileName = 'popup_ad_cache.bin';
  static const int _maxAgeMs = 7 * 24 * 60 * 60 * 1000;

  /// 디스크에 저장된 광고가 유효하면 (SplashAd, bytes) 반환.
  /// max age 초과·이미지 누락 등은 모두 null.
  static Future<(SplashAd, Uint8List)?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAt = prefs.getInt(_kAdSavedAt);
      if (savedAt == null) return null;
      if (DateTime.now().millisecondsSinceEpoch - savedAt > _maxAgeMs) {
        return null;
      }

      final json = prefs.getString(_kAdJson);
      if (json == null || json.isEmpty) return null;

      final file = await _imageFile();
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      final ad = SplashAd.fromJson(
          Map<String, dynamic>.from(jsonDecode(json) as Map));
      if (ad.imageUrl.isEmpty) return null;
      return (ad, bytes);
    } catch (e) {
      debugPrint('[PopupAdCache] read 실패: $e');
      return null;
    }
  }

  /// 이미지 바이트를 Flutter image cache 에 NetworkImage(url) 키로 미리 꽂기.
  /// 이후 [Image.network](url) 가 디스크 다운로드 없이 즉시 첫 프레임을 그림.
  static Future<bool> installInImageCache(
      String url, Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final completer = OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: frame.image, scale: 1.0)),
      );
      PaintingBinding.instance.imageCache.putIfAbsent(
        NetworkImage(url),
        () => completer,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 서버 응답 광고를 캐시에 저장. 이미지 다운로드 실패 시 메타도 저장 안 함.
  static Future<void> save(SplashAd ad) async {
    try {
      final url = DkswCore.resolveAssetUrl(ad.imageUrl);
      final res = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final body = res.data;
      if (res.statusCode != 200 || body == null || body.isEmpty) return;
      final bytes = Uint8List.fromList(body);

      final file = await _imageFile();
      await file.writeAsBytes(bytes, flush: true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAdJson, jsonEncode(ad.toJson()));
      await prefs.setInt(_kAdSavedAt, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[PopupAdCache] save 실패: $e');
    }
  }

  /// 서버에 광고가 없거나 비활성화된 경우 — 캐시 비움.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAdJson);
      await prefs.remove(_kAdSavedAt);
      final file = await _imageFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// 캐시된 광고와 새 광고가 동일한지 (id 기준).
  static Future<bool> isSameAsCached(SplashAd fresh) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kAdJson);
      if (raw == null || raw.isEmpty) return false;
      final cached = jsonDecode(raw) as Map<String, dynamic>;
      final cachedId = (cached['id'] as num?)?.toInt();
      return cachedId == fresh.id;
    } catch (_) {
      return false;
    }
  }

  static Future<File> _imageFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_imageFileName');
  }
}
