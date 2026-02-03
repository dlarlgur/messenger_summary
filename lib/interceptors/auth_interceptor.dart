import 'package:dio/dio.dart';
import '../services/auth_service.dart';

/// JWT 토큰 및 X-Timestamp 헤더를 자동 추가하는 Dio 인터셉터
class AuthInterceptor extends Interceptor {
  final AuthService _authService = AuthService();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
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
      final errorMessage = err.response?.data?['message'] as String?;
      
      // "Missing required authentication headers" 에러는 JWT 토큰이 없는 경우
      if (errorMessage?.contains('Missing required authentication headers') == true) {
        print('⚠️ JWT 토큰이 없습니다. Play Integrity 토큰을 요청합니다...');
        
        // 토큰 삭제 및 재요청
        await _authService.clearToken();
        final newToken = await _authService.getJwtToken();

        if (newToken != null && newToken.isNotEmpty) {
          // 원래 요청 재시도
          final opts = err.requestOptions;
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
      } else {
        // 다른 401 에러 (토큰 만료 등)
        await _authService.clearToken();
        final newToken = await _authService.getJwtToken();

        if (newToken != null && newToken.isNotEmpty) {
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          opts.headers['X-Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();

          try {
            final response = await Dio().fetch(opts);
            handler.resolve(response);
            return;
          } catch (e) {
            handler.next(err);
            return;
          }
        }
      }
    }

    // 429 Too Many Requests: 사용량 초과
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
        final planType = responseData['planType'] as String?;
        final message = responseData['message'] as String?;

        // 사용자에게 알림 표시
        print('⚠️ 사용량 초과: $currentUsage/$limit (플랜: $planType)');
        print('📅 다음 갱신일: $nextResetDate');
        if (message != null) {
          print('💬 메시지: $message');
        }
      
      }
    }

    handler.next(err);
  }
}
