import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsService extends ChangeNotifier {
  static const String _mutedRoomsKey = 'muted_rooms';

  // 알림 끄기된 roomName 목록
  Set<String> _mutedRooms = {};

  Set<String> get mutedRooms => _mutedRooms;

  // 초기화 - 저장된 설정 로드
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mutedRoomsJson = prefs.getString(_mutedRoomsKey);
      if (mutedRoomsJson != null) {
        final List<dynamic> list = jsonDecode(mutedRoomsJson);
        _mutedRooms = list.cast<String>().toSet();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('알림 설정 로드 오류: $e');
    }
  }

  // roomName이 알림 음소거 상태인지 확인
  bool isMuted(String roomName) {
    return _mutedRooms.contains(roomName);
  }

  // 알림 켜기
  Future<void> enableNotification(String roomName) async {
    _mutedRooms.remove(roomName);
    await _save();
    notifyListeners();
    debugPrint('알림 켜기: $roomName');
  }

  // 알림 끄기
  Future<void> disableNotification(String roomName) async {
    _mutedRooms.add(roomName);
    await _save();
    notifyListeners();
    debugPrint('알림 끄기: $roomName');
  }

  // 알림 토글
  Future<void> toggleNotification(String roomName) async {
    if (isMuted(roomName)) {
      await enableNotification(roomName);
    } else {
      await disableNotification(roomName);
    }
  }

  // 설정 저장
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mutedRoomsKey, jsonEncode(_mutedRooms.toList()));
    } catch (e) {
      debugPrint('알림 설정 저장 오류: $e');
    }
  }

  // 모든 음소거 해제
  Future<void> clearAllMuted() async {
    _mutedRooms.clear();
    await _save();
    notifyListeners();
  }
}
