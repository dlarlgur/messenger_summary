import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  final PlanService _planService = PlanService();

  // 캐시된 활성 메신저 패키지명 목록 (순서 포함)
  List<String>? _cachedEnabledPackages;

  /// 초기화 - SharedPreferences에서 설정 로드
  Future<void> initialize() async {
    await _loadFromPrefs();
  }

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

      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        _cachedEnabledPackages = list.cast<String>();
      } else {
        // 기본값: 카카오톡만
        _cachedEnabledPackages = ['com.kakao.talk'];
        await _saveToPrefs();
      }
    } catch (e) {
      debugPrint('메신저 설정 로드 오류: $e');
      _cachedEnabledPackages = ['com.kakao.talk'];
    }
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
    final packages = _cachedEnabledPackages ?? ['com.kakao.talk'];

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
    return List.from(_cachedEnabledPackages ?? ['com.kakao.talk']);
  }

  /// 메신저 활성화
  Future<void> enableMessenger(String packageName) async {
    _cachedEnabledPackages ??= ['com.kakao.talk'];
    if (!_cachedEnabledPackages!.contains(packageName)) {
      _cachedEnabledPackages!.add(packageName);
      await _saveToPrefs();
    }
  }

  /// 메신저 비활성화 (카카오톡은 비활성화 불가)
  Future<void> disableMessenger(String packageName) async {
    if (packageName == 'com.kakao.talk') return;
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
    // 카카오톡이 반드시 포함되어야 함
    if (!packageNames.contains('com.kakao.talk')) {
      packageNames.insert(0, 'com.kakao.talk');
    }
    _cachedEnabledPackages = packageNames;
    await _saveToPrefs();
  }

  /// 특정 메신저가 활성화되어 있는지 확인
  bool isEnabled(String packageName) {
    return _cachedEnabledPackages?.contains(packageName) ??
           (packageName == 'com.kakao.talk');
  }
}
