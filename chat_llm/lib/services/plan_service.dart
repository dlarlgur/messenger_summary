import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../interceptors/auth_interceptor.dart';

/// 플랜 설정 서비스
class PlanService {
  static final PlanService _instance = PlanService._internal();
  factory PlanService() => _instance;

  static const String _baseUrl = 'https://api.dksw4.com';
  
  // 테스트/개발 환경용 (관리자 API)
  static const String _planTestEndpoint = '/api/v1/admin/plan/test';
  static const String _planDeleteEndpoint = '/api/v1/admin/plan/test/delete';
  
  // 상용 환경용 (일반 사용자 API)
  static const String _planSubscribeEndpoint = '/api/v1/plan/subscribe';
  static const String _planCancelEndpoint = '/api/v1/plan/cancel';
  
  static const String _usageEndpoint = '/api/v1/llm/usage';
  
  // 환경 설정: true = 테스트 모드, false = 상용 모드
  static const bool _isTestMode = false; // 상용 모드
  
  /// 테스트 모드 여부 확인
  static bool get isTestMode => _isTestMode;

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

  /// 캐시된 플랜 타입 즉시 반환 (동기 메서드)
  ///
  /// API 호출 없이 캐시된 값을 즉시 반환합니다.
  /// 캐시가 없으면 기본값 'free'를 반환합니다.
  /// UI가 즉시 반응해야 하는 경우 (예: 컨텍스트 메뉴) 이 메서드를 사용하세요.
  String getCachedPlanTypeSync() {
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
  /// 
  /// 테스트 모드: 관리자 API 사용
  /// 상용 모드: 결제 시스템 연동 필요 (인앱 결제 등)
  Future<bool> setBasicPlan(String deviceIdHash) async {
    try {
      if (_isTestMode) {
        // 테스트 모드: 관리자 API 사용
        final response = await _dio.post(
          _planTestEndpoint,
          data: {
            'deviceIdHash': deviceIdHash,
          },
        );

        if (response.statusCode == 200) {
          debugPrint('✅ Basic 플랜 설정 성공 (테스트 모드)');
          invalidateCache(); // 캐시 무효화
          return true;
        } else {
          debugPrint('❌ Basic 플랜 설정 실패: ${response.statusCode}');
          return false;
        }
      } else {
        // 상용 모드: 결제 시스템 연동 필요
        // TODO: 인앱 결제 연동 후 구현
        // 1. Google Play Billing / App Store In-App Purchase 호출
        // 2. 결제 성공 후 /api/v1/plan/subscribe API 호출
        debugPrint('⚠️ 상용 모드: 결제 시스템 연동 필요');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Basic 플랜 설정 에러: $e');
      return false;
    }
  }

  /// 플랜 구독 (상용 모드)
  /// 
  /// 인앱 결제 성공 후 호출하는 메서드
  /// 
  /// [purchaseToken] - Google Play/App Store에서 받은 결제 영수증 토큰
  /// [productId] - 구매한 상품 ID (예: "basic_plan_monthly")
  /// [platform] - 플랫폼 ("android" 또는 "ios")
  /// 
  /// 서버 API 요청 예시:
  /// POST /api/v1/plan/subscribe
  /// {
  ///   "purchaseToken": "...",
  ///   "productId": "basic_plan_monthly",
  ///   "platform": "android"
  /// }
  /// 
  /// 서버 응답 예시:
  /// {
  ///   "success": true,
  ///   "message": "플랜이 Basic으로 설정되었습니다.",
  ///   "planType": "basic",
  ///   "expiresAt": "2024-02-29T23:59:59",
  ///   "limit": 200,
  ///   "period": "monthly"
  /// }
  Future<Map<String, dynamic>?> subscribePlan({
    required String purchaseToken,
    required String productId,
    required String platform, // "android" or "ios"
  }) async {
    try {
      final response = await _dio.post(
        _planSubscribeEndpoint,
        data: {
          'purchaseToken': purchaseToken,
          'productId': productId,
          'platform': platform,
        },
      );

      if (response.statusCode == 200) {
        final result = Map<String, dynamic>.from(response.data);
        debugPrint('✅ 플랜 구독 성공: ${result['planType']}');
        invalidateCache(); // 캐시 무효화
        return result;
      } else {
        debugPrint('❌ 플랜 구독 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ 플랜 구독 에러: $e');
      return null;
    }
  }

  /// Free 플랜으로 설정 (구독 취소)
  /// 
  /// 테스트 모드: 관리자 API 사용
  /// 상용 모드: 구독 취소 API 사용
  Future<bool> setFreePlan(String deviceIdHash) async {
    try {
      if (_isTestMode) {
        // 테스트 모드: 관리자 API 사용
        final response = await _dio.post(
          _planDeleteEndpoint,
          data: {
            'deviceIdHash': deviceIdHash,
          },
        );

        if (response.statusCode == 200) {
          debugPrint('✅ Free 플랜 설정 성공 (테스트 모드)');
          invalidateCache(); // 캐시 무효화
          return true;
        } else {
          debugPrint('❌ Free 플랜 설정 실패: ${response.statusCode}');
          return false;
        }
      } else {
        // 상용 모드: 구독 취소 API 사용
        final response = await _dio.post(
          _planCancelEndpoint,
          data: {
            'deviceIdHash': deviceIdHash,
          },
        );

        if (response.statusCode == 200) {
          debugPrint('✅ 구독 취소 성공');
          invalidateCache(); // 캐시 무효화
          return true;
        } else {
          debugPrint('❌ 구독 취소 실패: ${response.statusCode}');
          return false;
        }
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
