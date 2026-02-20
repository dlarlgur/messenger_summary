import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../interceptors/auth_interceptor.dart';
import '../services/privacy_masking_service.dart';

/// LLM 요약 서비스 (JWT 기반 인증)
class LlmService {
  static final LlmService _instance = LlmService._internal();
  factory LlmService() => _instance;
  LlmService._internal() {
    _initDio();
  }

  // API 설정
  static const String _baseUrl = 'https://api.dksw4.com';
  static const String _summaryEndpoint = '/api/v1/llm/summary';

  // Dio 인스턴스
  late final Dio _dio;

  /// Dio 초기화 (JWT 인터셉터 추가)
  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // JWT 인증 인터셉터 추가
    _dio.interceptors.add(AuthInterceptor());
  }


  /// 서버에서 현재 사용량 조회
  ///
  /// GET /api/v1/llm/usage 호출
  /// Returns: 남은 횟수 (limit - currentUsage), 오류 시 null
  Future<int?> getServerRemainingCount() async {
    try {
      final response = await _dio.get('/api/v1/llm/usage');
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final limit = data['limit'] as int? ?? 0;
        final currentUsage = data['currentUsage'] as int? ?? 0;
        final remaining = (limit - currentUsage).clamp(0, 99);
        debugPrint('📊 서버 사용량 조회: currentUsage=$currentUsage, limit=$limit, remaining=$remaining');
        return remaining;
      }
      return null;
    } catch (e) {
      debugPrint('❌ 서버 사용량 조회 실패: $e');
      return null;
    }
  }

  /// 광고 시청 리워드 서버 등록
  ///
  /// Flutter SDK는 onUserEarnedReward에서 transactionId를 노출하지 않으므로
  /// SSV 대신 JWT 인증으로 서버에 직접 리워드를 등록합니다.
  ///
  /// Returns: true = 등록 성공, false = 실패 (한도 초과 포함)
  Future<bool> registerAdReward() async {
    try {
      final response = await _dio.post('/api/v1/reward/direct');
      debugPrint('✅ 리워드 서버 등록 성공: ${response.data}');
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        debugPrint('⚠️ 리워드 한도 초과: ${e.response?.data}');
      } else {
        debugPrint('❌ 리워드 서버 등록 실패: ${e.response?.statusCode} ${e.message}');
      }
      return false;
    } catch (e) {
      debugPrint('❌ 리워드 서버 등록 오류: $e');
      return false;
    }
  }

  /// 메시지 요약 요청
  ///
  /// [messages] - 요약할 메시지 목록 (시간순 정렬 권장, 최대 200개)
  /// [roomName] - 채팅방 이름
  ///
  /// Returns: 요약 결과 Map 또는 에러 시 null
  /// Throws: [RateLimitException] 사용량 초과 시
  Future<Map<String, dynamic>?> summarizeMessages({
    required List<Map<String, dynamic>> messages,
    required String roomName,
  }) async {
    try {
      // 민감 정보 마스킹 처리
      final maskedMessages = messages.map((msg) {
        final maskedMsg = Map<String, dynamic>.from(msg);
        if (maskedMsg['message'] != null) {
          maskedMsg['message'] = PrivacyMaskingService.maskSensitiveInfo(
            maskedMsg['message'] as String,
          );
        }
        return maskedMsg;
      }).toList();

      debugPrint('========== LLM 요약 요청 시작 ==========');
      debugPrint('📌 요청 URL: $_baseUrl$_summaryEndpoint');
      debugPrint('📌 대화방: $roomName');
      debugPrint('📌 메시지 개수: ${maskedMessages.length}');
      
      // 요청 데이터 (JWT는 인터셉터에서 자동 추가)
      final requestData = <String, dynamic>{
        'roomName': roomName,
        'messages': maskedMessages,
        'messageCount': maskedMessages.length,
      };

      final response = await _dio.post(
        _summaryEndpoint,
        data: requestData,
      );

      debugPrint('📌 LLM 응답 코드: ${response.statusCode}');
      debugPrint('📌 LLM 응답 데이터 타입: ${response.data.runtimeType}');
      debugPrint('📌 LLM 응답 데이터: ${response.data}');
      
      debugPrint('========== LLM 요약 요청 완료 ==========');

      if (response.statusCode == 200) {
        // 응답 데이터 타입에 따라 처리
        Map<String, dynamic>? responseData;
        
        if (response.data is Map) {
          responseData = Map<String, dynamic>.from(response.data);
        } else if (response.data is String) {
          final dataString = response.data as String;
          if (dataString.isEmpty) {
            debugPrint('⚠️ 응답 데이터가 비어있습니다.');
            return null;
          }
          try {
            // String을 JSON으로 파싱 시도
            final decoded = jsonDecode(dataString);
            if (decoded is Map) {
              responseData = Map<String, dynamic>.from(decoded);
            } else {
              debugPrint('⚠️ 파싱된 데이터가 Map이 아닙니다: ${decoded.runtimeType}');
              return null;
            }
          } catch (e) {
            debugPrint('⚠️ 응답 데이터를 JSON으로 파싱 실패: $e');
            debugPrint('   원본 데이터: $dataString');
            return null;
          }
        } else if (response.data == null) {
          debugPrint('⚠️ 응답 데이터가 null입니다.');
          return null;
        } else {
          debugPrint('⚠️ 알 수 없는 응답 데이터 타입: ${response.data.runtimeType}');
          return null;
        }
        
        // 응답 데이터 상세 로깅
        if (responseData != null) {
          debugPrint('📌 요약 전문 리스폰스:');
          debugPrint('   summarySubject: ${responseData['summarySubject'] ?? 'N/A'}');
          debugPrint('   summaryMessage: ${responseData['summaryMessage'] ?? responseData['summary'] ?? 'N/A'}');
          debugPrint('   summaryDetailMessage: ${responseData['summaryDetailMessage'] ?? 'N/A'}');
          if (responseData['summaryDetailMessage'] != null) {
            debugPrint('   summaryDetailMessage 길이: ${(responseData['summaryDetailMessage'] as String?)?.length ?? 0}');
          }
        }
        
        return responseData;
      } else {
        debugPrint('LLM 요약 실패: ${response.statusCode}, ${response.data}');
        return null;
      }
    } on DioException catch (e) {
      debugPrint('========== LLM 요약 요청 에러 ==========');
      debugPrint('❌ DioException 발생');
      debugPrint('   상태 코드: ${e.response?.statusCode}');
      debugPrint('   에러 타입: ${e.type}');
      debugPrint('   에러 메시지: ${e.message}');
      debugPrint('   응답 데이터: ${e.response?.data}');
      debugPrint('   요청 URL: ${e.requestOptions.uri}');
      debugPrint('   요청 헤더: ${e.requestOptions.headers}');
      debugPrint('   요청 데이터: ${e.requestOptions.data}');
      
      // 400 에러인 경우 상세 정보 출력
      if (e.response?.statusCode == 400) {
        debugPrint('   ⚠️ 400 Bad Request - 요청 데이터 검증 실패');
        try {
          final errorData = e.response?.data;
          if (errorData is Map) {
            debugPrint('   에러 상세: $errorData');
            if (errorData.containsKey('message')) {
              debugPrint('   서버 메시지: ${errorData['message']}');
            }
            if (errorData.containsKey('errors')) {
              debugPrint('   검증 에러: ${errorData['errors']}');
            }
          } else if (errorData is String) {
            debugPrint('   서버 응답: $errorData');
          }
        } catch (_) {}
      }
      
      debugPrint('==========================================');
      
      if (e.response?.statusCode == 429) {
        // 429 응답에서 플랜 정보 추출
        final responseData = e.response?.data;
        String planType = 'free';
        int currentUsage = 0;
        int limit = 0;
        String? nextResetDate;
        
        if (responseData is Map<String, dynamic>) {
          planType = responseData['planType'] as String? ?? 'free';
          currentUsage = responseData['currentUsage'] as int? ?? 0;
          limit = responseData['limit'] as int? ?? 0;
          dynamic nextResetDateValue = responseData['nextResetDate'];
          if (nextResetDateValue is String) {
            nextResetDate = nextResetDateValue;
          } else if (nextResetDateValue != null) {
            nextResetDate = nextResetDateValue.toString();
          }
        }
        
        // 플랜별 에러 메시지 생성
        // Free: 분모를 항상 4(기본1 + 광고3)로 고정 → 사용자에게 처음부터 "4회 가능" 인식
        final displayUsage = currentUsage > limit ? limit : currentUsage;
        const int freeMaxTotal = 4; // FREE_DAILY_LIMIT(1) + MAX_DAILY_REWARDS(3)
        String message;
        if (planType == 'free') {
          message = '오늘 무료 요약 $displayUsage/${freeMaxTotal}회 사용 완료';
        } else {
          message = '이번 달 요약 $displayUsage/$limit회 사용 완료';
        }
        
        final retryAfter = e.response?.headers.value('retry-after');
        throw RateLimitException(
          message,
          retryAfterSeconds: int.tryParse(retryAfter ?? '60') ?? 60,
        );
      } else if (e.response?.statusCode == 401) {
        throw AuthException('인증에 실패했습니다. 앱을 다시 설치해주세요.');
      } else if (e.response?.statusCode == 403) {
        throw AuthException('접근이 거부되었습니다.');
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout) {
        throw TimeoutException('요약 요청 시간이 초과되었습니다.');
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('========== LLM 요약 요청 에러 ==========');
      debugPrint('❌ 일반 예외 발생: $e');
      debugPrint('   스택 트레이스: $stackTrace');
      debugPrint('==========================================');
      return null;
    }
  }
}

/// Rate Limit 초과 예외
class RateLimitException implements Exception {
  final String message;
  final int retryAfterSeconds;

  RateLimitException(this.message, {this.retryAfterSeconds = 60});

  @override
  String toString() => message;
}

/// 인증 예외
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

/// 타임아웃 예외
class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => message;
}
