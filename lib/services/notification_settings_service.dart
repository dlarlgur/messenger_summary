import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsService extends ChangeNotifier {
  static const String _mutedRoomsKey = 'muted_rooms';
  static const String _mutedRoomsMigratedKey = 'muted_rooms_migrated_v2';

  // 알림 끄기된 키 목록 (packageName|roomName 형식)
  Set<String> _mutedRooms = {};

  Set<String> get mutedRooms => _mutedRooms;

  /// 음소거 키 생성 (packageName|roomName 또는 packageName|chatId)
  /// 라인인 경우 chatId를 우선 사용 (roomName이 랜덤으로 변할 수 있음)
  static String _makeKey(String roomName, [String? packageName, String? chatId]) {
    final pkg = packageName ?? 'com.kakao.talk';
    // 라인인 경우 chatId를 우선 사용
    if (pkg == 'jp.naver.line.android' && chatId != null && chatId.isNotEmpty) {
      return '$pkg|$chatId';
    }
    return '$pkg|$roomName';
  }

  // 초기화 - 저장된 설정 로드 + 마이그레이션
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 음소거 목록 로드
      final mutedRoomsJson = prefs.getString(_mutedRoomsKey);
      if (mutedRoomsJson != null) {
        final List<dynamic> list = jsonDecode(mutedRoomsJson);
        _mutedRooms = list.cast<String>().toSet();
      }

      // 기존 데이터 마이그레이션 (roomName → com.kakao.talk|roomName)
      final migrated = prefs.getBool(_mutedRoomsMigratedKey) ?? false;
      if (!migrated && _mutedRooms.isNotEmpty) {
        final newSet = <String>{};
        for (final key in _mutedRooms) {
          if (key.contains('|')) {
            newSet.add(key); // 이미 새 형식
          } else {
            newSet.add('com.kakao.talk|$key'); // 기존 형식 → 카카오톡으로 마이그레이션
          }
        }
        _mutedRooms = newSet;
        await _save();
        await prefs.setBool(_mutedRoomsMigratedKey, true);
        debugPrint('음소거 목록 마이그레이션 완료: ${_mutedRooms.length}개');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('알림 설정 로드 오류: $e');
    }
  }

  // 음소거 상태 확인 (packageName 포함, 라인인 경우 chatId 사용)
  bool isMuted(String roomName, [String? packageName, String? chatId]) {
    final pkg = packageName ?? 'com.kakao.talk';
    
    // 라인인 경우 chatId와 roomName 모두 확인 (chatId가 없을 수 있음)
    if (pkg == 'jp.naver.line.android') {
      // 1. chatId로 확인 (우선)
      if (chatId != null && chatId.isNotEmpty) {
        final chatIdKey = '$pkg|$chatId';
        if (_mutedRooms.contains(chatIdKey)) return true;
      }
      // 2. roomName으로 확인 (폴백)
      final roomNameKey = '$pkg|$roomName';
      if (_mutedRooms.contains(roomNameKey)) return true;
      // 3. 저장된 키 중에 이 roomName이나 chatId가 포함된 것 확인 (마이그레이션 대응)
      for (final mutedKey in _mutedRooms) {
        if (mutedKey.startsWith('$pkg|')) {
          final keyValue = mutedKey.substring('$pkg|'.length);
          // chatId나 roomName과 일치하는지 확인
          if (keyValue == chatId || keyValue == roomName) {
            return true;
          }
        }
      }
      return false;
    }
    
    // 다른 메신저는 기존 로직
    final key = _makeKey(roomName, packageName, chatId);
    if (_mutedRooms.contains(key)) return true;
    // 하위 호환: 기존 형식 (roomName만) 확인
    if (packageName == null && _mutedRooms.contains(roomName)) return true;
    return false;
  }

  // 알림 켜기
  Future<void> enableNotification(String roomName, [String? packageName, String? chatId]) async {
    final pkg = packageName ?? 'com.kakao.talk';
    
    // 라인인 경우 chatId와 roomName 키 모두 제거
    if (pkg == 'jp.naver.line.android') {
      if (chatId != null && chatId.isNotEmpty) {
        _mutedRooms.remove('$pkg|$chatId');
      }
      _mutedRooms.remove('$pkg|$roomName');
      // 저장된 키 중에 이 roomName이나 chatId가 포함된 것 모두 제거
      _mutedRooms.removeWhere((key) {
        if (key.startsWith('$pkg|')) {
          final keyValue = key.substring('$pkg|'.length);
          return keyValue == chatId || keyValue == roomName;
        }
        return false;
      });
    } else {
      _mutedRooms.remove(_makeKey(roomName, packageName, chatId));
      // 하위 호환: 기존 형식도 제거
      _mutedRooms.remove(roomName);
    }
    
    await _save();
    notifyListeners();
    debugPrint('알림 켜기: ${_makeKey(roomName, packageName, chatId)}');
  }

  // 알림 끄기
  Future<void> disableNotification(String roomName, [String? packageName, String? chatId]) async {
    _mutedRooms.add(_makeKey(roomName, packageName, chatId));
    await _save();
    notifyListeners();
    debugPrint('알림 끄기: ${_makeKey(roomName, packageName, chatId)}');
  }

  // 알림 토글
  Future<void> toggleNotification(String roomName, [String? packageName, String? chatId]) async {
    if (isMuted(roomName, packageName, chatId)) {
      await enableNotification(roomName, packageName, chatId);
    } else {
      await disableNotification(roomName, packageName, chatId);
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
