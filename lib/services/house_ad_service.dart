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

/// 콘솔에서 등록한 직접(house) 광고.
///
/// imageUrl 은 상대 경로일 수 있어 사용 시 [DkswCore.resolveAssetUrl] 로 해석.
///
/// [displayStyle]:
///   - 'card'   : AdMob 카드 톤 [아이콘 | 헤드라인 + 본문 | CTA]
///   - 'banner' : 풀폭 그래픽 배너 (이미지만, 카톡 채팅 상단 스타일)
/// 콘솔 등록 시 명시적으로 선택. 미지정/구버전 응답은 'card' 폴백.
class HouseAd {
  final int id;
  final int listPosition;
  final bool bypassAdmob;
  final String displayStyle; // 'card' | 'banner'
  final String imageUrl;
  final String? headline;
  final String? bodyText;
  final String? ctaLabel;
  final String? ctaUrl;
  final String ctaType;
  final int weight;

  const HouseAd({
    required this.id,
    required this.listPosition,
    required this.bypassAdmob,
    required this.displayStyle,
    required this.imageUrl,
    this.headline,
    this.bodyText,
    this.ctaLabel,
    this.ctaUrl,
    required this.ctaType,
    required this.weight,
  });

  /// 풀폭 배너 모드 (이미지만 노출).
  bool get isBanner => displayStyle == 'banner';

  /// 카드 모드 (텍스트 + 아이콘 + CTA).
  bool get isCard => displayStyle != 'banner';

  factory HouseAd.fromJson(Map<String, dynamic> j) => HouseAd(
        id: (j['id'] as num).toInt(),
        listPosition: (j['listPosition'] as num?)?.toInt() ?? 0,
        bypassAdmob: j['bypassAdmob'] == true,
        displayStyle:
            j['displayStyle']?.toString() == 'banner' ? 'banner' : 'card',
        imageUrl: j['imageUrl']?.toString() ?? '',
        headline: j['headline']?.toString(),
        bodyText: j['bodyText']?.toString(),
        ctaLabel: j['ctaLabel']?.toString(),
        ctaUrl: j['ctaUrl']?.toString(),
        ctaType: j['ctaType']?.toString() ?? 'none',
        weight: (j['weight'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'listPosition': listPosition,
        'bypassAdmob': bypassAdmob,
        'displayStyle': displayStyle,
        'imageUrl': imageUrl,
        'headline': headline,
        'bodyText': bodyText,
        'ctaLabel': ctaLabel,
        'ctaUrl': ctaUrl,
        'ctaType': ctaType,
        'weight': weight,
      };
}

/// 콘솔에서 받은 house ad 캐시 (stale-while-revalidate).
///
/// chat_llm 은 Hive 미사용 → 메타는 SharedPreferences, 이미지 바이트는
/// applicationSupport 디렉토리 파일.
///
/// 노출 규칙(charge_app과 동일):
///   - 슬롯 4·8 = 기본 AdMob. 같은 위치에 bypass=true house ad 가 있으면 대체.
///   - 슬롯 12+ = 등록된 house ad 항상 노출 (AdMob 자리 아님).
class HouseAdCache {
  HouseAdCache._();

  static const String _packageName = 'com.dksw.app';
  static const String _serverBaseUrl = 'https://dksw4.com/console';
  static const String _kAdsJson = 'house_ads_meta';
  static const String _kAdsSavedAt = 'house_ads_meta_saved_at';
  static const String _imageDirName = 'house_ads';
  static const int _maxAgeMs = 7 * 24 * 60 * 60 * 1000;

  static List<HouseAd> _ads = const [];
  static bool _fetched = false;

  static List<HouseAd> get ads => _ads;
  static bool get fetched => _fetched;

  /// 위치별 house ad lookup. 같은 위치에 여러 개면 서버에서 1건만 픽해서 내려줌.
  static HouseAd? at(int position) {
    for (final a in _ads) {
      if (a.listPosition == position) return a;
    }
    return null;
  }

  /// 디스크에 저장된 이전 광고 + 이미지 즉시 로드.
  /// 첫 프레임에 광고가 보이게 — 네트워크 fetch 기다리지 않음.
  /// 메인 isolate에서 `await` 가능 (UI 블로킹 거의 없음, 메타+이미지 N개 로드).
  static Future<void> readFromDiskAndInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAt = prefs.getInt(_kAdsSavedAt);
      if (savedAt == null) return;
      if (DateTime.now().millisecondsSinceEpoch - savedAt > _maxAgeMs) {
        return;
      }

      final raw = prefs.getString(_kAdsJson);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw);
      if (list is! List) return;

      _ads = list
          .whereType<Map>()
          .map((m) => HouseAd.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      _fetched = true;

      final dir = await _imageDir();
      for (final ad in _ads) {
        final file = File('${dir.path}/${ad.id}.bin');
        if (!await file.exists()) continue;
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) continue;
          await _installInImageCache(
            DkswCore.resolveAssetUrl(ad.imageUrl),
            bytes,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[HouseAdCache] readFromDisk 실패: $e');
    }
  }

  /// 디스크에서 읽은 광고를 Flutter image cache에 NetworkImage(url) 키로 등록
  /// → Image.network(url) 즉시 그림.
  static Future<void> _installInImageCache(
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
    } catch (_) {}
  }

  /// 콘솔 /api/house-ads 호출 + 이미지 다운로드 + 디스크 저장.
  /// 실패해도 조용히 무시 (광고 없음 상태).
  static Future<void> fetch() async {
    try {
      final res = await Dio().get(
        '$_serverBaseUrl/api/house-ads',
        queryParameters: {'package': _packageName},
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      final data = res.data;
      if (data is! Map || data['ok'] != true) {
        _fetched = true;
        return;
      }
      final adsRaw = data['ads'];
      if (adsRaw is! List) {
        _fetched = true;
        return;
      }
      final fresh = adsRaw
          .whereType<Map>()
          .map((m) => HouseAd.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      _ads = fresh;
      _fetched = true;

      // 이미지 다운로드 + 파일 저장 + image cache 등록
      final dir = await _imageDir();
      final dio = Dio();
      final keepIds = <int>{};
      for (final ad in fresh) {
        keepIds.add(ad.id);
        final url = DkswCore.resolveAssetUrl(ad.imageUrl);
        try {
          final r = await dio.get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              receiveTimeout: const Duration(seconds: 10),
            ),
          );
          final body = r.data;
          if (r.statusCode == 200 && body != null && body.isNotEmpty) {
            final bytes = Uint8List.fromList(body);
            final file = File('${dir.path}/${ad.id}.bin');
            await file.writeAsBytes(bytes, flush: true);
            await _installInImageCache(url, bytes);
          }
        } catch (_) {}
      }
      // 더 이상 등록 안 된 광고 이미지는 정리
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          if (!name.endsWith('.bin')) continue;
          final id = int.tryParse(name.substring(0, name.length - 4));
          if (id != null && !keepIds.contains(id)) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }

      // 메타 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kAdsJson, jsonEncode(fresh.map((a) => a.toJson()).toList()));
      await prefs.setInt(
          _kAdsSavedAt, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[HouseAdCache] fetch 실패: $e');
      _fetched = true;
    }
  }

  static Future<void> reportImpression(int adId) async {
    try {
      await Dio()
          .post('$_serverBaseUrl/api/ads/$adId/impression')
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  static Future<void> reportClick(int adId) async {
    try {
      await Dio()
          .post('$_serverBaseUrl/api/ads/$adId/click')
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  static Future<Directory> _imageDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_imageDirName');
    if (!await dir.exists()) {
      try {
        await dir.create(recursive: true);
      } catch (_) {}
    }
    return dir;
  }
}

/// 리스트 슬롯 결정 — 앱이 호출.
///
/// AdMob 기본 슬롯: 4, 8.
/// 같은 위치 house ad 가 있고 bypass_admob=true 면 house 가 대체.
/// 슬롯 12+ 는 house ad 만.
class AdSlotResolver {
  AdSlotResolver._();

  static const Set<int> admobSlots = {4, 8};

  /// 슬롯이 광고 위치인지 (AdMob 또는 house ad).
  /// 광고 자체가 없으면 false → 다음 일반 아이템이 그 자리에 채워짐.
  static bool isAdSlot(int position) {
    if (admobSlots.contains(position)) return true;
    return HouseAdCache.at(position) != null;
  }

  /// 슬롯의 광고 종류 반환. SlotKind.none = 광고 없음(아이템 자리).
  static SlotKind kindAt(int position) {
    final house = HouseAdCache.at(position);
    if (admobSlots.contains(position)) {
      // AdMob 슬롯 — house+bypass 면 대체, 아니면 AdMob.
      if (house != null && house.bypassAdmob) return SlotKind.house;
      return SlotKind.admob;
    }
    // 비-AdMob 슬롯 — house ad 있으면 노출, 없으면 일반 아이템.
    if (house != null) return SlotKind.house;
    return SlotKind.none;
  }

  /// 화면에 등장할 가장 먼 광고 슬롯 (스크롤 끝까지 그릴 필요 X 한정용).
  static int get maxAdSlot {
    int m = 8; // AdMob 기본 두 자리
    for (final a in HouseAdCache.ads) {
      if (a.listPosition > m) m = a.listPosition;
    }
    return m;
  }
}

enum SlotKind { admob, house, none }

/// 홈 상단 배너 광고 캐시 (chat_llm 전용 단일 슬롯).
///
/// /api/top-banner 응답을 stale-while-revalidate 패턴으로 디스크 캐시.
/// HouseAdCache와 동일한 SharedPreferences + path_provider 저장 방식.
///
/// 노출 규칙:
///  - bypassAdmob=true 인 활성 광고가 있으면 chat_room_list_screen 의 상단
///    AdMob 자리를 가로채 노출.
///  - 없거나 bypassAdmob=false 면 기존 AdMob → AdFit 폴백 그대로.
class TopBannerCache {
  TopBannerCache._();

  static const String _packageName = 'com.dksw.app';
  static const String _serverBaseUrl = 'https://dksw4.com/console';
  static const String _kAdJson = 'top_banner_meta';
  static const String _kAdSavedAt = 'top_banner_meta_saved_at';
  static const String _imageFileName = 'top_banner_cache.bin';
  static const int _maxAgeMs = 7 * 24 * 60 * 60 * 1000;

  static HouseAd? _ad;
  static bool _fetched = false;

  static HouseAd? get current => _ad;
  static bool get fetched => _fetched;

  /// 디스크 캐시 즉시 로드 + image cache에 미리 등록 → 첫 프레임에 광고 표시.
  static Future<void> readFromDiskAndInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAt = prefs.getInt(_kAdSavedAt);
      if (savedAt == null) return;
      if (DateTime.now().millisecondsSinceEpoch - savedAt > _maxAgeMs) return;

      final raw = prefs.getString(_kAdJson);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw);
      if (json is! Map) return;
      final ad = HouseAd.fromJson(Map<String, dynamic>.from(json));
      if (ad.imageUrl.isEmpty) return;
      _ad = ad;
      _fetched = true;

      final file = await _imageFile();
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            await _installInImageCache(
              DkswCore.resolveAssetUrl(ad.imageUrl),
              bytes,
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[TopBannerCache] readFromDisk 실패: $e');
    }
  }

  static Future<void> _installInImageCache(
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
    } catch (_) {}
  }

  /// 콘솔 /api/top-banner 호출 + 이미지 다운로드 + 디스크 저장.
  static Future<void> fetch() async {
    try {
      final res = await Dio().get(
        '$_serverBaseUrl/api/top-banner',
        queryParameters: {'package': _packageName},
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      final data = res.data;
      if (data is! Map || data['ok'] != true) {
        _fetched = true;
        return;
      }
      final adRaw = data['ad'];
      if (adRaw is! Map) {
        // 활성 광고 없음 → 캐시 비움
        _ad = null;
        _fetched = true;
        await _clearDisk();
        return;
      }
      final ad = HouseAd.fromJson(Map<String, dynamic>.from(adRaw));
      _ad = ad;
      _fetched = true;

      // 이미지 다운로드 + 디스크 저장 + image cache 등록
      final url = DkswCore.resolveAssetUrl(ad.imageUrl);
      try {
        final r = await Dio().get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        final body = r.data;
        if (r.statusCode == 200 && body != null && body.isNotEmpty) {
          final bytes = Uint8List.fromList(body);
          final file = await _imageFile();
          await file.writeAsBytes(bytes, flush: true);
          await _installInImageCache(url, bytes);
        }
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAdJson, jsonEncode(ad.toJson()));
      await prefs.setInt(
          _kAdSavedAt, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[TopBannerCache] fetch 실패: $e');
      _fetched = true;
    }
  }

  static Future<void> _clearDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAdJson);
      await prefs.remove(_kAdSavedAt);
      final file = await _imageFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// HouseAdCache와 동일 엔드포인트 사용. 호출 위임.
  static Future<void> reportImpression(int adId) =>
      HouseAdCache.reportImpression(adId);
  static Future<void> reportClick(int adId) =>
      HouseAdCache.reportClick(adId);

  static Future<File> _imageFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_imageFileName');
  }
}
