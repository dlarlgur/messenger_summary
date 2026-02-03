import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 자동 요약 설정 서비스
class AutoSummarySettingsService extends ChangeNotifier {
  static const String _autoSummaryNotificationEnabledKey = 'auto_summary_notification_enabled';
  static const String _vibrationEnabledKey = 'notification_vibration_enabled';
  static const String _soundEnabledKey = 'notification_sound_enabled';

  // 자동 요약 알림 활성화 여부 (전역 설정)
  bool _autoSummaryNotificationEnabled = true;
  // 진동 활성화 여부
  bool _vibrationEnabled = true;
  // 소리 활성화 여부
  bool _soundEnabled = true;

  bool get autoSummaryNotificationEnabled => _autoSummaryNotificationEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get soundEnabled => _soundEnabled;

  /// 초기화 - 저장된 설정 로드
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSummaryNotificationEnabled = prefs.getBool(_autoSummaryNotificationEnabledKey) ?? true;
      _vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      notifyListeners();
    } catch (e) {
      debugPrint('자동 요약 설정 로드 오류: $e');
    }
  }

  /// 자동 요약 알림 활성화/비활성화
  Future<void> setAutoSummaryNotificationEnabled(bool enabled) async {
    _autoSummaryNotificationEnabled = enabled;
    await _save();
    notifyListeners();
    debugPrint('자동 요약 알림 설정 변경: $enabled');
  }

  /// 진동 활성화/비활성화
  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    await _save();
    notifyListeners();
    debugPrint('진동 설정 변경: $enabled');
  }

  /// 소리 활성화/비활성화
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _save();
    notifyListeners();
    debugPrint('소리 설정 변경: $enabled');
  }

  /// 설정 저장
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoSummaryNotificationEnabledKey, _autoSummaryNotificationEnabled);
      await prefs.setBool(_vibrationEnabledKey, _vibrationEnabled);
      await prefs.setBool(_soundEnabledKey, _soundEnabled);
    } catch (e) {
      debugPrint('자동 요약 설정 저장 오류: $e');
    }
  }
}
