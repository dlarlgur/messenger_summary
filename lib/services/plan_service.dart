import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../interceptors/auth_interceptor.dart';

/// 플랜 설정 서비스 (테스트용)
class PlanService {
  static final PlanService _instance = PlanService._internal();
  factory PlanService() => _instance;

  static const String _baseUrl = 'https://api.dksw4.com';
  static const String _planTestEndpoint = '/api/v1/admin/plan/test';
  static const String _planDeleteEndpoint = '/api/v1/admin/plan/test/delete';
  static const String _usageEndpoint = '/api/v1/llm/usage';

  late final Dio _dio;

  // 캐시된 플랜 정보
  String? _cachedPlanType;
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  PlanService._internal() {
    _initDio();
  }

  /// 현재 플랜이 베이직인지 확인 (캐시 사용)
  Future<bool> isBasicPlan() async {
    final planType = await getCurrentPlanType();
    return planType == 'basic';
  }

  /// 현재 플랜 타입 조회 (캐시 사용)
  Future<String> getCurrentPlanType() async {
    // 캐시가 유효하면 캐시 반환
    if (_cachedPlanType != null && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < _cacheExpiry) {
        return _cachedPlanType!;
      }
    }

    // API 호출하여 플랜 정보 갱신
    final usage = await getUsage();
    if (usage != null) {
      _cachedPlanType = usage['planType'] as String? ?? 'free';
      _lastFetchTime = DateTime.now();
      return _cachedPlanType!;
    }

    return _cachedPlanType ?? 'free';
  }

  /// 캐시 무효화
  void invalidateCache() {
    _cachedPlanType = null;
    _lastFetchTime = null;
  }

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ));
    // JWT 인증 인터셉터 추가
    _dio.interceptors.add(AuthInterceptor());
  }

  /// Basic 플랜으로 설정
  Future<bool> setBasicPlan(String deviceIdHash) async {
    try {
      final response = await _dio.post(
        _planTestEndpoint,
        data: {
          'deviceIdHash': deviceIdHash,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Basic 플랜 설정 성공');
        return true;
      } else {
        debugPrint('❌ Basic 플랜 설정 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Basic 플랜 설정 에러: $e');
      return false;
    }
  }

  /// Free 플랜으로 설정 (Redis에서 삭제)
  Future<bool> setFreePlan(String deviceIdHash) async {
    try {
      final response = await _dio.post(
        _planDeleteEndpoint,
        data: {
          'deviceIdHash': deviceIdHash,
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Free 플랜 설정 성공 (Redis에서 삭제)');
        return true;
      } else {
        debugPrint('❌ Free 플랜 설정 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Free 플랜 설정 에러: $e');
      return false;
    }
  }

  /// 사용량 조회
  Future<Map<String, dynamic>?> getUsage() async {
    try {
      final response = await _dio.get(_usageEndpoint);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      } else {
        debugPrint('❌ 사용량 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 사용량 조회 에러: $e');
      return null;
    }
  }
}
