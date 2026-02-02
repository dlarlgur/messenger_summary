import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// LLM 요약 서비스 (JWT 없이 Device ID + App Signature 기반 인증)
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

  // 캐싱된 디바이스 정보
  String? _deviceId;
  String? _appSignature;
  
  // Rate limiting: 1분당 5회 제한
  static const int _maxRequestsPerMinute = 5;
  final List<DateTime> _requestHistory = [];

  /// Dio 초기화 (SSL 인증서 검증 활성화)
  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // SSL 인증서 검증 활성화 (기본값 사용)
    // 도메인(api.dksw4.com)을 사용하므로 정상적인 SSL 인증서 검증 수행
  }

  /// 디바이스 ID 가져오기
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _deviceId = androidInfo.id; // Android ID
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor ?? 'unknown';
    } else {
      _deviceId = 'unknown';
    }

    return _deviceId!;
  }

  /// 앱 서명 생성 (패키지명 + 버전 + 디바이스ID의 해시)
  Future<String> _getAppSignature() async {
    if (_appSignature != null) return _appSignature!;

    final packageInfo = await PackageInfo.fromPlatform();
    final deviceId = await _getDeviceId();

    // 패키지명 + 버전 + 디바이스ID를 조합하여 SHA256 해시 생성
    final signatureData = '${packageInfo.packageName}:${packageInfo.version}:$deviceId';
    final bytes = utf8.encode(signatureData);
    final hash = sha256.convert(bytes);

    _appSignature = hash.toString();
    return _appSignature!;
  }

  /// Rate limiting 체크 (1분당 5회 제한)
  void _checkRateLimit() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    
    // 1분 이전의 요청 기록 제거
    _requestHistory.removeWhere((timestamp) => timestamp.isBefore(oneMinuteAgo));
    
    // 1분 내 요청 횟수 확인
    if (_requestHistory.length >= _maxRequestsPerMinute) {
      final oldestRequest = _requestHistory.first;
      final waitSeconds = 60 - now.difference(oldestRequest).inSeconds;
      throw RateLimitException(
        '1분당 요청 횟수를 초과했습니다. ${waitSeconds}초 후 다시 시도해주세요.',
        retryAfterSeconds: waitSeconds,
      );
    }
    
    // 현재 요청 시간 기록
    _requestHistory.add(now);
  }

  /// 메시지 요약 요청
  ///
  /// [messages] - 요약할 메시지 목록 (시간순 정렬 권장)
  /// [roomName] - 채팅방 이름
  ///
  /// Returns: 요약 결과 Map 또는 에러 시 null
  /// Throws: [RateLimitException] 분당 요청 초과 시
  Future<Map<String, dynamic>?> summarizeMessages({
    required List<Map<String, dynamic>> messages,
    required String roomName,
  }) async {
    // 클라이언트 측 rate limiting 체크
    _checkRateLimit();
    
    try {
      final deviceId = await _getDeviceId();
      final appSignature = await _getAppSignature();
      final packageInfo = await PackageInfo.fromPlatform();

      debugPrint('========== LLM 요약 요청 시작 ==========');
      debugPrint('📌 요청 URL: $_baseUrl$_summaryEndpoint');
      debugPrint('📌 대화방: $roomName');
      debugPrint('📌 메시지 개수: ${messages.length}');
      debugPrint('📌 인증 헤더:');
      debugPrint('   X-Device-Id: $deviceId');
      debugPrint('   X-App-Signature: $appSignature');
      debugPrint('   X-Package-Name: ${packageInfo.packageName}');
      debugPrint('   X-App-Version: ${packageInfo.version}');
      
      // 요청 데이터 상세 로깅
      final requestData = <String, dynamic>{
        'roomName': roomName,
        'messages': messages,
        'messageCount': messages.length,
        // 카테고리는 제거되었지만, 서버가 요구할 경우를 대비해 주석 처리
        // 'category': 'DAILY', // 서버가 카테고리를 필수로 요구한다면 이 줄의 주석을 해제
      };
      debugPrint('📌 요청 데이터 (JSON):');
      debugPrint('   roomName: $roomName');
      debugPrint('   messageCount: ${messages.length}');
      debugPrint('   category: (제거됨)');
      debugPrint('📌 메시지 목록:');
      for (int i = 0; i < messages.length; i++) {
        final msg = messages[i];
        debugPrint('   [$i] sender: ${msg['sender']}, message: ${msg['message']?.toString().substring(0, (msg['message']?.toString().length ?? 0) > 50 ? 50 : msg['message']?.toString().length ?? 0)}...');
        debugPrint('       createTime: ${msg['createTime']}');
      }

      final response = await _dio.post(
        _summaryEndpoint,
        data: requestData,
        options: Options(
          headers: {
            'X-Device-Id': deviceId,
            'X-App-Signature': appSignature,
            'X-Package-Name': packageInfo.packageName,
            'X-App-Version': packageInfo.version,
          },
        ),
      );

      debugPrint('📌 LLM 응답 코드: ${response.statusCode}');
      debugPrint('📌 LLM 응답 데이터: ${response.data}');
      
      // 응답 데이터 상세 로깅
      if (response.statusCode == 200 && response.data is Map) {
        final responseData = Map<String, dynamic>.from(response.data);
        debugPrint('📌 요약 전문 리스폰스:');
        debugPrint('   summarySubject: ${responseData['summarySubject'] ?? 'N/A'}');
        debugPrint('   summaryMessage: ${responseData['summaryMessage'] ?? responseData['summary'] ?? 'N/A'}');
        debugPrint('   summaryDetailMessage: ${responseData['summaryDetailMessage'] ?? 'N/A'}');
        if (responseData['summaryDetailMessage'] != null) {
          debugPrint('   summaryDetailMessage 길이: ${(responseData['summaryDetailMessage'] as String?)?.length ?? 0}');
        }
      }
      
      debugPrint('========== LLM 요약 요청 완료 ==========');

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
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
        final retryAfter = e.response?.headers.value('retry-after');
        throw RateLimitException(
          '요청 횟수를 초과했습니다. 잠시 후 다시 시도해주세요.',
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
