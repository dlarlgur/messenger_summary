import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

/// 업데이트 타입
enum UpdateType {
  none,     // 업데이트 필요 없음
  optional, // 선택 업데이트
  force,    // 강제 업데이트
}

/// 버전 체크 결과
class VersionCheckResult {
  final bool updateRequired;
  final UpdateType updateType;
  final String? latestVersion;
  final int? latestVersionCode;
  final String? minVersion;
  final String? storeUrl;
  final String? releaseNote;
  final String? errorMessage;

  VersionCheckResult({
    required this.updateRequired,
    required this.updateType,
    this.latestVersion,
    this.latestVersionCode,
    this.minVersion,
    this.storeUrl,
    this.releaseNote,
    this.errorMessage,
  });

  factory VersionCheckResult.fromJson(Map<String, dynamic> json) {
    return VersionCheckResult(
      updateRequired: json['updateRequired'] ?? false,
      updateType: _parseUpdateType(json['updateType']),
      latestVersion: json['latestVersion'],
      latestVersionCode: json['latestVersionCode'],
      minVersion: json['minVersion'],
      storeUrl: json['storeUrl'],
      releaseNote: json['releaseNote'],
      errorMessage: json['message'],
    );
  }

  static UpdateType _parseUpdateType(String? type) {
    switch (type?.toUpperCase()) {
      case 'FORCE':
        return UpdateType.force;
      case 'OPTIONAL':
        return UpdateType.optional;
      default:
        return UpdateType.none;
    }
  }

  /// 에러 응답 생성
  factory VersionCheckResult.error(String message) {
    return VersionCheckResult(
      updateRequired: false,
      updateType: UpdateType.none,
      errorMessage: message,
    );
  }

  /// 업데이트 불필요 응답 생성
  factory VersionCheckResult.noUpdate() {
    return VersionCheckResult(
      updateRequired: false,
      updateType: UpdateType.none,
    );
  }
}

/// 앱 버전 관리 서비스
class AppVersionService {
  static final AppVersionService _instance = AppVersionService._internal();
  factory AppVersionService() => _instance;
  AppVersionService._internal();

  static const String _skipUpdateDateKey = 'skip_update_dialog_date';

  /// 버전 체크
  /// 서버에서 최신 버전 정보를 조회하고 현재 앱 버전과 비교
  Future<VersionCheckResult> checkVersion() async {
    try {
      // 현재 앱 정보 가져오기
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 플랫폼 확인
      final platform = Platform.isAndroid ? 'android' : 'ios';

      debugPrint('📱 버전 체크 시작: platform=$platform, currentVersionCode=$currentVersionCode');

      // API 호출
      final url = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.versionCheck}?platform=$platform&versionCode=$currentVersionCode'
      );

      debugPrint('📱 버전 체크 URL: $url');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('{"message": "Timeout"}', 408),
      );

      debugPrint('📱 버전 체크 응답: statusCode=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = VersionCheckResult.fromJson(json);
        debugPrint('📱 버전 체크 결과: updateRequired=${result.updateRequired}, updateType=${result.updateType}');
        return result;
      } else {
        // 서버 오류 시 업데이트 체크 스킵 (앱 사용 가능)
        debugPrint('📱 버전 체크 실패: statusCode=${response.statusCode}');
        return VersionCheckResult.noUpdate();
      }
    } catch (e) {
      // 네트워크 오류 시 업데이트 체크 스킵 (앱 사용 가능)
      debugPrint('📱 버전 체크 예외: $e');
      return VersionCheckResult.noUpdate();
    }
  }

  /// 현재 앱 버전 정보 가져오기
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// 현재 앱 빌드 번호 가져오기
  Future<int> getCurrentBuildNumber() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return int.tryParse(packageInfo.buildNumber) ?? 0;
  }

  /// 오늘 하루 다이얼로그 보지 않기 설정
  Future<void> skipUpdateDialogToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await prefs.setString(_skipUpdateDateKey, todayString);
      debugPrint('📱 오늘 하루 업데이트 다이얼로그 숨김 설정: $todayString');
    } catch (e) {
      debugPrint('📱 오늘 하루 보지 않기 설정 실패: $e');
    }
  }

  /// 오늘 다이얼로그를 보지 않기로 설정했는지 확인
  Future<bool> shouldSkipUpdateDialogToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skipDateString = prefs.getString(_skipUpdateDateKey);
      
      if (skipDateString == null) {
        return false;
      }

      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // 오늘 날짜와 저장된 날짜가 같으면 스킵
      final shouldSkip = skipDateString == todayString;
      debugPrint('📱 업데이트 다이얼로그 스킵 확인: skipDate=$skipDateString, today=$todayString, shouldSkip=$shouldSkip');
      
      return shouldSkip;
    } catch (e) {
      debugPrint('📱 오늘 하루 보지 않기 확인 실패: $e');
      return false;
    }
  }
}
