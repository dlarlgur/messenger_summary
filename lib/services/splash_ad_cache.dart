import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 스플래시 광고 디스크 캐시 (stale-while-revalidate).
///
/// 매 실행 시 이전 세션에서 prefetch한 광고 메타+이미지를 즉시 노출 →
/// 흰 갭 없이 native splash 직후 광고가 그려진다. 동시에 부트스트랩 결과로
/// 캐시를 갱신해 다음 실행에 반영. max age 7일.
///
/// charge_app은 Hive를 쓰지만, chat_llm은 Hive 미사용 → 메타는
/// SharedPreferences, 이미지 바이트는 application support 디렉토리 파일에 저장.
class SplashAdCache {
  static const String _kAdJson = 'splash_ad_cache_json';
  static const String _kAdSavedAt = 'splash_ad_cache_saved_at';
  static const String _imageFileName = 'splash_ad_cache.bin';
  static const int _maxAgeMs = 7 * 24 * 60 * 60 * 1000; // 7일

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
      debugPrint('[SplashAdCache] read 실패: $e');
      return null;
    }
  }

  /// 이미지 바이트를 Flutter image cache에 NetworkImage(resolvedUrl) 키로 미리 꽂기.
  /// 이후 [Image.network](resolvedUrl)가 디스크 다운로드 없이 즉시 첫 프레임을 그림.
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

  /// 서버 응답 광고를 캐시에 저장. 이미지 다운로드 실패하면 메타도 저장 안 함.
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
      await prefs.setInt(
          _kAdSavedAt, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[SplashAdCache] save 실패: $e');
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
