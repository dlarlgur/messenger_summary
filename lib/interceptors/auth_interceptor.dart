import 'package:dio/dio.dart';
import '../config/constants.dart';
import '../services/auth_service.dart';

/// JWT 토큰 및 X-Timestamp 헤더를 자동 추가하는 Dio 인터셉터
class AuthInterceptor extends Interceptor {
  final AuthService _authService = AuthService();
  
  // 재시도 플래그 키
  static const String _retryCountKey = 'auth_retry_count';
  static const int _maxRetryCount = 1; // 최대 재시도 횟수

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // 재시도 횟수 초기화 (새 요청인 경우)
    if (options.extra[_retryCountKey] == null) {
      options.extra[_retryCountKey] = 0;
    }

    // JWT 토큰 가져오기
    final token = await _authService.getJwtToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      // JWT 토큰이 없으면 에러를 던지지 않고 요청 진행
      // 서버에서 401 응답을 받으면 onError에서 처리
      print('⚠️ JWT 토큰이 없습니다. Play Integrity 토큰 요청이 필요합니다.');
    }

    // X-Timestamp 헤더 추가 (밀리초 단위)
    options.headers['X-Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // 401 Unauthorized: 토큰 만료 또는 유효하지 않음
    if (err.response?.statusCode == 401) {
      final requestOptions = err.requestOptions;
      final retryCount = (requestOptions.extra[_retryCountKey] as int?) ?? 0;
      
      // 토큰 발급 API 경로는 재시도하지 않음
      if (requestOptions.path.contains('/auth/token')) {
        print('❌ JWT 토큰 발급 API가 401을 반환했습니다. Play Integrity 토큰이 유효하지 않을 수 있습니다.');
        handler.next(err);
        return;
      }
      
      // 최대 재시도 횟수 초과 시 에러 전달
      if (retryCount >= _maxRetryCount) {
        print('❌ 최대 재시도 횟수(${_maxRetryCount})를 초과했습니다. 인증 실패로 처리합니다.');
        handler.next(err);
        return;
      }
      
      final errorMessage = err.response?.data?['message'] as String?;
      
      print('⚠️ 401 에러 발생. 토큰 재발급 시도... (재시도 횟수: $retryCount/$_maxRetryCount)');
      
      // 토큰 삭제 및 재요청
      await _authService.clearToken();
      final newToken = await _authService.getJwtToken();

      if (newToken != null && newToken.isNotEmpty) {
        // 원래 요청 재시도
        final opts = requestOptions.copyWith(
          extra: {
            ...requestOptions.extra,
            _retryCountKey: retryCount + 1,
          },
        );
        opts.headers['Authorization'] = 'Bearer $newToken';
        opts.headers['X-Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();

        try {
          final response = await Dio().fetch(opts);
          handler.resolve(response);
          return;
        } catch (e) {
          // 재시도 실패
          print('❌ JWT 토큰 재요청 후 요청 재시도 실패: $e');
          handler.next(err);
          return;
        }
      } else {
        print('❌ JWT 토큰 발급 실패. Play Integrity 토큰 요청이 실패했을 수 있습니다.');
        // JWT 토큰 발급 실패 시 원래 에러 전달
        handler.next(err);
        return;
      }
    }

    // 429 Too Many Requests: 사용량 한도(도달/초과)
    if (err.response?.statusCode == 429) {
      final responseData = err.response?.data;
      if (responseData is Map<String, dynamic>) {
        // nextResetDate는 문자열 또는 배열일 수 있으므로 안전하게 처리
        dynamic nextResetDateValue = responseData['nextResetDate'];
        String? nextResetDate;
        if (nextResetDateValue is String) {
          nextResetDate = nextResetDateValue;
        } else if (nextResetDateValue != null) {
          // 배열 형태로 오는 경우 문자열로 변환
          nextResetDate = nextResetDateValue.toString();
        }
        
        final currentUsage = responseData['currentUsage'] as int?;
        final limit = responseData['limit'] as int?;
        final maxLimit = responseData['maxLimit'] as int?;
        final planType = responseData['planType'] as String?;
        final message = responseData['message'] as String?;

        // 로그: limit=현재 최대(2+받은 리워드). maxLimit 미제공 시 5 디폴트 적용
        final freeHint = (planType == 'free' && limit != null)
            ? ' [limit=$limit, maxLimit=${maxLimit ?? "${UsageConstants.freePlanMaxLimitFallback}(디폴트)"}]'
            : '';
        print('⚠️ 사용량 한도: $currentUsage/$limit (플랜: $planType)$freeHint');
        print('📅 다음 갱신일: $nextResetDate');
        if (message != null) {
          print('💬 메시지: $message');
        }
      
      }
    }

    handler.next(err);
  }
}
