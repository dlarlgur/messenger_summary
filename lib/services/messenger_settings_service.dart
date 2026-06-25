import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'messenger_registry.dart';
import 'plan_service.dart';

/// 메신저 활성화/순서 설정 관리 서비스
class MessengerSettingsService {
  static final MessengerSettingsService _instance = MessengerSettingsService._internal();
  factory MessengerSettingsService() => _instance;
  MessengerSettingsService._internal();

  static const String _enabledMessengersKey = 'enabled_messengers';
  static const String _oldEnabledMessengersKey = 'flutter.enabled_messengers';
  // 이미 "기본 활성"으로 한 번 제안한 메신저 목록. 사용자가 끈 기본 메신저를
  // 다음 로드 때 되살리지 않기 위함 (신규 추가 default 만 자동 활성).
  static const String _seenDefaultsKey = 'seen_default_messengers';

  final PlanService _planService = PlanService();

  // 캐시된 활성 메신저 패키지명 목록 (순서 포함)
  List<String>? _cachedEnabledPackages;

  // 세션당 1회만 로드 (멱등). main 의 unawaited init 과 화면들의 await init 이
  // 같은 future 를 공유해, 로드가 사용자 선택(setEnabledMessengers)을 덮어쓰는 레이스 방지.
  Future<void>? _initFuture;

  /// 초기화 - SharedPreferences에서 설정 로드 (세션당 1회).
  Future<void> initialize() => _initFuture ??= _loadFromPrefs();

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var json = prefs.getString(_enabledMessengersKey);

      // 마이그레이션: 이전 잘못된 키(flutter.enabled_messengers)에서 데이터 이전
      if (json == null) {
        final oldJson = prefs.getString(_oldEnabledMessengersKey);
        if (oldJson != null) {
          json = oldJson;
          await prefs.setString(_enabledMessengersKey, oldJson);
          await prefs.remove(_oldEnabledMessengersKey);
          debugPrint('메신저 설정 키 마이그레이션 완료: $_oldEnabledMessengersKey → $_enabledMessengersKey');
        }
      }

      final allDefaults = MessengerRegistry.allMessengers
          .where((m) => m.enabledByDefault)
          .map((m) => m.packageName)
          .toList();

      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        _cachedEnabledPackages = list.cast<String>();

        // enabledByDefault 자동 활성화는 "아직 제안한 적 없는 default" 에만 적용한다.
        // 사용자가 명시적으로 끈 기본 메신저(온보딩/설정)를 매 로드마다 되살리던 버그 수정.
        var seen = prefs.getStringList(_seenDefaultsKey);
        if (seen == null) {
          // 마이그레이션: 기존 유저는 현재 default 를 모두 이미 제안받은 것으로 간주
          // → 끈 항목이 다시 켜지지 않음.
          seen = List<String>.from(allDefaults);
          await prefs.setStringList(_seenDefaultsKey, seen);
        }
        final seenSet = seen.toSet();
        final newDefaults = allDefaults
            .where((p) => !seenSet.contains(p) && !_cachedEnabledPackages!.contains(p))
            .toList();
        if (newDefaults.isNotEmpty) {
          _cachedEnabledPackages!.addAll(newDefaults);
          await _saveToPrefs();
        }
        // 이번 릴리즈의 모든 default 를 "제안함" 으로 기록 (다음부터 재활성 안 함).
        final merged = {...seenSet, ...allDefaults};
        if (merged.length != seenSet.length) {
          await prefs.setStringList(_seenDefaultsKey, merged.toList());
        }
      } else {
        // 기본값: 전체 메신저, 단 지역(기기 언어) 주력 메신저를 맨 앞으로 → 첫 탭이 그 메신저.
        // 일본→LINE, 한국→KakaoTalk, 그 외→WhatsApp.
        _cachedEnabledPackages = _localeOrderedPackages();
        await _saveToPrefs();
        await prefs.setStringList(_seenDefaultsKey, allDefaults);
      }
    } catch (e) {
      debugPrint('메신저 설정 로드 오류: $e');
      _cachedEnabledPackages = MessengerRegistry.allMessengers.map((m) => m.packageName).toList();
    }
  }

  /// 기기 언어에 따라 주력 메신저를 맨 앞에 둔 전체 패키지 순서 (첫 실행 기본순서).
  /// 일본→LINE, 한국→KakaoTalk, 그 외→WhatsApp. 첫 탭이 이 메신저가 된다.
  List<String> _localeOrderedPackages() {
    final list = MessengerRegistry.allMessengers.map((m) => m.packageName).toList();
    final lang = WidgetsBinding.instance.platformDispatcher.locale.languageCode.toLowerCase();
    final primary = lang == 'ja'
        ? 'jp.naver.line.android' // LINE
        : lang == 'ko'
            ? 'com.kakao.talk' // KakaoTalk
            : 'com.whatsapp'; // WhatsApp
    if (list.remove(primary)) list.insert(0, primary);
    return list;
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_enabledMessengersKey, jsonEncode(_cachedEnabledPackages));
    } catch (e) {
      debugPrint('메신저 설정 저장 오류: $e');
    }
  }

  /// 활성 메신저 목록 반환 (플랜 제한 적용, 순서 유지)
  List<MessengerInfo> getEnabledMessengers() {
    final planType = _planService.getCachedPlanTypeSync();
    final packages = _cachedEnabledPackages ?? const <String>[];

    // 테스트를 위해 Free 플랜도 모든 메신저 사용 가능
    // TODO: 테스트 완료 후 Free 플랜 제한 복구
    // if (planType == 'free') {
    //   // Free 플랜: 카카오톡만
    //   final kakao = MessengerRegistry.getByPackageName('com.kakao.talk');
    //   return kakao != null ? [kakao] : [];
    // }

    // 모든 플랜: 저장된 순서대로 반환 (Slack 포함)
    return packages
        .map((pkg) => MessengerRegistry.getByPackageName(pkg))
        .whereType<MessengerInfo>()
        .toList();
  }

  /// 동기적으로 활성 메신저 목록을 Map 형태로 반환 (기존 코드 호환)
  List<Map<String, String>> getEnabledMessengersAsMap() {
    return getEnabledMessengers().map((m) => m.toMap()).toList();
  }

  /// 저장된 전체 패키지 목록 (플랜 무관) - 설정 화면용
  List<String> getSavedEnabledPackages() {
    return List.from(_cachedEnabledPackages ?? MessengerRegistry.allMessengers.map((m) => m.packageName).toList());
  }

  /// 메신저 활성화
  Future<void> enableMessenger(String packageName) async {
    _cachedEnabledPackages ??= MessengerRegistry.allMessengers.map((m) => m.packageName).toList();
    if (!_cachedEnabledPackages!.contains(packageName)) {
      _cachedEnabledPackages!.add(packageName);
      await _saveToPrefs();
    }
  }

  /// 메신저 비활성화 — 카톡 포함 어떤 메신저든 사용자가 끌 수 있음.
  Future<void> disableMessenger(String packageName) async {
    _cachedEnabledPackages?.remove(packageName);
    await _saveToPrefs();
  }

  /// 순서 변경
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (_cachedEnabledPackages == null) return;
    if (oldIndex < newIndex) newIndex--;
    final item = _cachedEnabledPackages!.removeAt(oldIndex);
    _cachedEnabledPackages!.insert(newIndex, item);
    await _saveToPrefs();
  }

  /// 전체 목록 설정 (순서 포함)
  Future<void> setEnabledMessengers(List<String> packageNames) async {
    _cachedEnabledPackages = packageNames;
    await _saveToPrefs();
  }

  /// 특정 메신저가 활성화되어 있는지 확인
  bool isEnabled(String packageName) {
    return _cachedEnabledPackages?.contains(packageName) ?? false;
  }
}
