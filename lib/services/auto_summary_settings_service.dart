import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 자동 요약 설정 서비스
class AutoSummarySettingsService extends ChangeNotifier {
  static const String _autoSummaryNotificationEnabledKey = 'auto_summary_notification_enabled';
  static const String _vibrationEnabledKey = 'notification_vibration_enabled';
  static const String _soundEnabledKey = 'notification_sound_enabled';
  static const String _hasShownNotificationDialogKey = 'has_shown_auto_summary_notification_dialog';

  static const MethodChannel _methodChannel = MethodChannel('com.example.chat_llm/main');

  // 자동 요약 알림 활성화 여부 (전역 설정)
  bool _autoSummaryNotificationEnabled = false;
  // 진동 활성화 여부
  bool _vibrationEnabled = true;
  // 소리 활성화 여부
  bool _soundEnabled = true;
  // 시스템 알림 권한 상태
  bool _systemNotificationPermissionEnabled = false;

  bool get autoSummaryNotificationEnabled => _autoSummaryNotificationEnabled && _systemNotificationPermissionEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get systemNotificationPermissionEnabled => _systemNotificationPermissionEnabled;
  bool get appNotificationEnabled => _autoSummaryNotificationEnabled; // 앱 내 설정만 반환

  /// 초기화 - 저장된 설정 로드
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoSummaryNotificationEnabled = prefs.getBool(_autoSummaryNotificationEnabledKey) ?? false;
      _vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      
      // 시스템 알림 권한 확인
      await _checkSystemNotificationPermission();
      
      notifyListeners();
    } catch (e) {
      debugPrint('자동 요약 설정 로드 오류: $e');
    }
  }

  /// 시스템 알림 권한 확인
  Future<void> _checkSystemNotificationPermission() async {
    try {
      final enabled = await _methodChannel.invokeMethod<bool>('areNotificationsEnabled') ?? false;
      _systemNotificationPermissionEnabled = enabled;
    } catch (e) {
      debugPrint('시스템 알림 권한 확인 실패: $e');
      _systemNotificationPermissionEnabled = false;
    }
  }

  /// 시스템 알림 권한 상태 새로고침
  Future<void> refreshSystemNotificationPermission() async {
    await _checkSystemNotificationPermission();
    notifyListeners();
  }

  /// 최초 진입 시 팝업 표시 여부 확인
  Future<bool> shouldShowNotificationDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_hasShownNotificationDialogKey) ?? false);
    } catch (e) {
      debugPrint('팝업 표시 여부 확인 실패: $e');
      return true;
    }
  }

  /// 팝업 표시 완료 표시
  Future<void> markNotificationDialogShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasShownNotificationDialogKey, true);
    } catch (e) {
      debugPrint('팝업 표시 완료 저장 실패: $e');
    }
  }

  /// 자동 요약 알림 활성화/비활성화
  Future<bool> setAutoSummaryNotificationEnabled(bool enabled) async {
    if (enabled) {
      // 시스템 알림 권한 확인
      await _checkSystemNotificationPermission();
      if (!_systemNotificationPermissionEnabled) {
        debugPrint('시스템 알림 권한이 없어 자동 요약 알림을 켤 수 없습니다');
        return false; // 시스템 권한이 없으면 false 반환
      }
    }
    
    _autoSummaryNotificationEnabled = enabled;
    await _save();
    notifyListeners();
    debugPrint('자동 요약 알림 설정 변경: $enabled');
    return true;
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
