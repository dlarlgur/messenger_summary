import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'play_integrity_service.dart';

/// 인증 서비스 (Play Integrity + JWT)
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _baseUrl = 'https://api.dksw4.com';
  static const String _tokenEndpoint = '/api/v1/auth/token';
  static const String _jwtStorageKey = 'jwt_token';
  static const String _deviceIdHashKey = 'device_id_hash';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  String? _cachedJwtToken;
  String? _cachedDeviceIdHash;

  /// Play Integrity 토큰 요청 및 JWT 발급
  Future<String?> getJwtToken() async {
    // 캐시된 토큰이 있으면 반환
    if (_cachedJwtToken != null) {
      return _cachedJwtToken;
    }

    // Secure Storage에서 토큰 확인
    final storedToken = await _secureStorage.read(key: _jwtStorageKey);
    if (storedToken != null && storedToken.isNotEmpty) {
      _cachedJwtToken = storedToken;
      return storedToken;
    }

    // Play Integrity 토큰 요청
    try {
      final integrityToken = await _requestPlayIntegrityToken();
      if (integrityToken == null) {
        print('❌ Play Integrity 토큰 요청 실패');
        return null;
      }

      // Android ID 가져오기 (기기 고유 식별자)
      final deviceId = await PlayIntegrityService.getDeviceId();
      if (deviceId == null) {
        print('❌ Device ID 조회 실패');
        return null;
      }
      print('📱 Device ID: ${deviceId.substring(0, deviceId.length > 8 ? 8 : deviceId.length)}... (전체 길이: ${deviceId.length})');

      // 서버에 토큰 전송하여 JWT 발급
      // 주의: 이 요청은 AuthInterceptor를 거치지 않도록 별도의 Dio 인스턴스 사용
      final response = await _dio.post(
        _tokenEndpoint,
        data: {
          'integrityToken': integrityToken,
          'deviceId': deviceId,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final accessToken = response.data['accessToken'] as String?;
        final deviceIdHash = response.data['deviceIdHash'] as String?;
        print('🔐 Device ID Hash: ${deviceIdHash?.substring(0, deviceIdHash != null && deviceIdHash.length > 8 ? 8 : deviceIdHash?.length ?? 0)}... (전체 길이: ${deviceIdHash?.length ?? 0})');

          if (accessToken != null) {
          // Secure Storage에 저장
          await _secureStorage.write(key: _jwtStorageKey, value: accessToken);
          if (deviceIdHash != null) {
            await _secureStorage.write(key: _deviceIdHashKey, value: deviceIdHash);
          }

          // Android에서 자동 요약 API 호출을 위해 SharedPreferences에도 저장
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', accessToken);

          _cachedJwtToken = accessToken;
          _cachedDeviceIdHash = deviceIdHash;
          print('✅ JWT 토큰 발급 성공');
          return accessToken;
        } else {
          print('❌ JWT 토큰 발급 실패: 응답에 accessToken이 없습니다.');
        }
      } else {
        print('❌ JWT 토큰 발급 실패: 상태 코드 ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        print('❌ JWT 토큰 발급 실패: Play Integrity 토큰이 유효하지 않습니다 (401)');
      } else {
        print('❌ JWT 토큰 발급 실패: ${e.message}');
        if (e.response != null) {
          print('   상태 코드: ${e.response?.statusCode}');
          print('   응답 데이터: ${e.response?.data}');
        }
      }
    } catch (e) {
      print('❌ JWT 토큰 발급 실패: $e');
    }

    return null;
  }

  /// Play Integrity 토큰 요청
  Future<String?> _requestPlayIntegrityToken() async {
    return await PlayIntegrityService.requestIntegrityToken();
  }

  /// JWT 토큰 삭제 (로그아웃)
  Future<void> clearToken() async {
    _cachedJwtToken = null;
    _cachedDeviceIdHash = null;
    await _secureStorage.delete(key: _jwtStorageKey);
    await _secureStorage.delete(key: _deviceIdHashKey);
    
    // Android 자동 요약을 위해 SharedPreferences에서도 삭제
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  /// 현재 저장된 JWT 토큰 반환 (재발급 없이)
  Future<String?> getStoredToken() async {
    if (_cachedJwtToken != null) {
      // Android 자동 요약을 위해 SharedPreferences에도 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _cachedJwtToken!);
      return _cachedJwtToken;
    }
    final token = await _secureStorage.read(key: _jwtStorageKey);
    
    // Android 자동 요약을 위해 SharedPreferences에도 저장
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
    }
    
    return token;
  }

  /// Device ID Hash 반환
  Future<String?> getDeviceIdHash() async {
    if (_cachedDeviceIdHash != null) {
      return _cachedDeviceIdHash;
    }
    return await _secureStorage.read(key: _deviceIdHashKey);
  }
}
