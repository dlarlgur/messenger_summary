import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/chat_room.dart';
import '../models/chat_message.dart';

// 인증 관련 예외
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

// 동의 필요 예외
class ConsentRequiredException implements Exception {
  final String message;
  ConsentRequiredException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  final Dio _dio = Dio();

  static const String _serverAccessTokenKey = 'server_access_token';
  static const String _serverRefreshTokenKey = 'server_refresh_token';

  // 자체 서명 인증서 허용 설정
  void _configureSslBypass() {
    if (_dio.httpClientAdapter is IOHttpClientAdapter) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        return client;
      };
    }
  }

  ApiService() {
    _configureSslBypass(); // 자체 서명 인증서 허용
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.headers['Content-Type'] = 'application/json';

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  // 서버 액세스 토큰 가져오기
  Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverAccessTokenKey);
  }

  // 인증 헤더 설정
  Future<void> _setAuthHeader() async {
    final token = await _getAccessToken();
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // 토큰 갱신
  Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_serverRefreshTokenKey);

      if (refreshToken == null) {
        debugPrint('리프레시 토큰이 없습니다');
        return false;
      }

      final response = await _dio.post(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await prefs.setString(_serverAccessTokenKey, data['accessToken']);
        if (data['refreshToken'] != null) {
          await prefs.setString(_serverRefreshTokenKey, data['refreshToken']);
        }
        debugPrint('토큰 갱신 성공');
        return true;
      } else {
        debugPrint('토큰 갱신 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('토큰 갱신 오류: $e');
      return false;
    }
  }

  // 알림 수신 API 호출
  // sender, message, roomName이 모두 null이 아니고 빈값이 아닐 때만 호출
  Future<bool> sendKakaoAlarm({
    required String packageName,
    required String sender,
    required String message,
    required String roomName,
    required String createTime,
  }) async {
    // 유효성 검사: sender, message, roomName 모두 null/빈값이 아니어야 함
    if (sender.isEmpty || message.isEmpty || roomName.isEmpty) {
      debugPrint('알림 API 호출 스킵: sender, message, roomName 중 빈값 존재');
      debugPrint('  sender: "$sender", message: "$message", roomName: "$roomName"');
      return false;
    }

    try {
      await _setAuthHeader();

      Response response;
      try {
        response = await _dio.post(
          ApiConstants.messengerAlarm,
          data: {
            'packageName': packageName,
            'sender': sender,
            'message': message,
            'roomName': roomName,
            'createTime': createTime,
          },
        );
      } on DioException catch (e) {
        // 토큰 만료 시 갱신 후 재시도
        if (e.response?.statusCode == 401) {
          if (await _refreshToken()) {
            await _setAuthHeader();
            response = await _dio.post(
              ApiConstants.messengerAlarm,
              data: {
                'packageName': packageName,
                'sender': sender,
                'message': message,
                'roomName': roomName,
                'createTime': createTime,
              },
            );
          } else {
            return false;
          }
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('알림 API 호출 성공');
        return true;
      } else {
        debugPrint('알림 API 호출 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('알림 API 호출 오류: $e');
      return false;
    }
  }

  // 지원 메신저 목록 조회
  Future<List<Map<String, dynamic>>> getSupportedMessengers() async {
    try {
      await _setAuthHeader();

      Response response;
      try {
        response = await _dio.get(ApiConstants.messengerMessengers);
      } on DioException catch (e) {
        // 토큰 만료 시 갱신 후 재시도
        if (e.response?.statusCode == 401) {
          if (await _refreshToken()) {
            await _setAuthHeader();
            response = await _dio.get(ApiConstants.messengerMessengers);
          } else {
            return [];
          }
        } else {
          debugPrint('지원 메신저 목록 조회 실패: ${e.response?.statusCode}');
          return [];
        }
      }

      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
        return [];
      } else {
        debugPrint('지원 메신저 목록 조회 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('지원 메신저 목록 조회 오류: $e');
      return [];
    }
  }

  // 대화방 목록 조회
  Future<List<ChatRoom>> getChatRooms() async {
    final token = await _getAccessToken();
    debugPrint('=== 대화방 목록 조회 ===');
    debugPrint('URL: ${ApiConstants.baseUrl}${ApiConstants.messengerRooms}');
    debugPrint('토큰: ${token != null ? '있음 (${token.substring(0, 20.clamp(0, token.length))}...)' : '없음!'}');

    await _setAuthHeader();

    Response response;
    try {
      response = await _dio.get(ApiConstants.messengerRooms);
    } on DioException catch (e) {
      debugPrint('응답 코드: ${e.response?.statusCode}');

      // 토큰 만료 시 갱신 후 재시도
      if (e.response?.statusCode == 401) {
        if (await _refreshToken()) {
          await _setAuthHeader();
          response = await _dio.get(ApiConstants.messengerRooms);
        } else {
          // 토큰 갱신 실패 - 재로그인 필요
          throw AuthException('세션이 만료되었습니다. 다시 로그인해주세요.');
        }
      } else if (e.response?.statusCode == 403) {
        // 동의 필요 여부 확인
        final body = e.response?.data;
        if (body != null && body['code'] == 'MESSAGE_SUMMARY_NOT_AGREED') {
          throw ConsentRequiredException('메시지 요약 서비스 동의가 필요합니다.');
        }
        throw Exception('접근 권한이 없습니다.');
      } else {
        debugPrint('대화방 목록 조회 실패: ${e.response?.statusCode}');
        throw Exception('대화방 목록을 불러오는데 실패했습니다.');
      }
    }

    debugPrint('응답 코드: ${response.statusCode}');
    final responseData = response.data;
    debugPrint('응답 본문: ${responseData.toString().length > 200 ? responseData.toString().substring(0, 200) : responseData}');

    if (response.statusCode == 200) {
      try {
        final List<dynamic> jsonList = responseData is String ? jsonDecode(responseData) : responseData;
        return jsonList.map((json) => ChatRoom.fromJson(json)).toList();
      } catch (e) {
        debugPrint('대화방 목록 파싱 실패: $e');
        rethrow;
      }
    } else {
      throw Exception('대화방 목록을 불러오는데 실패했습니다.');
    }
  }

  // 대화방 상세 조회 (LLM 요약 포함, 페이지네이션 지원)
  Future<RoomDetailResponse?> getChatRoomDetail(int roomId, {int page = 0, int size = 50}) async {
    try {
      await _setAuthHeader();

      Response response;
      final url = '${ApiConstants.messengerRoomDetail(roomId.toString())}?page=$page&size=$size';
      try {
        response = await _dio.get(url);
      } on DioException catch (e) {
        // 토큰 만료 시 갱신 후 재시도
        if (e.response?.statusCode == 401) {
          if (await _refreshToken()) {
            await _setAuthHeader();
            response = await _dio.get(url);
          } else {
            return null;
          }
        } else {
          debugPrint('대화방 상세 조회 실패: ${e.response?.statusCode}');
          return null;
        }
      }

      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return RoomDetailResponse.fromJson(data);
      } else {
        debugPrint('대화방 상세 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('대화방 상세 조회 오류: $e');
      return null;
    }
  }

  // 대화방 메시지 목록 조회 (페이지네이션 지원)
  Future<RoomMessagesResponse?> getRoomMessages(int roomId, {int page = 0, int size = 50}) async {
    try {
      await _setAuthHeader();

      Response response;
      final url = '${ApiConstants.messengerRoomMessages(roomId.toString())}?page=$page&size=$size';
      try {
        response = await _dio.get(url);
      } on DioException catch (e) {
        // 토큰 만료 시 갱신 후 재시도
        if (e.response?.statusCode == 401) {
          if (await _refreshToken()) {
            await _setAuthHeader();
            response = await _dio.get(url);
          } else {
            return null;
          }
        } else {
          debugPrint('메시지 목록 조회 실패: ${e.response?.statusCode}');
          return null;
        }
      }

      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return RoomMessagesResponse.fromJson(data);
      } else {
        debugPrint('메시지 목록 조회 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('메시지 목록 조회 오류: $e');
      return null;
    }
  }

  // 약관 동의 상태 조회
  Future<Map<String, dynamic>> getConsent() async {
    try {
      await _setAuthHeader();

      Response response;
      try {
        response = await _dio.get('/api/v1/user/consent');
      } on DioException catch (e) {
        // 토큰 만료 시 갱신 후 재시도
        if (e.response?.statusCode == 401) {
          if (await _refreshToken()) {
            await _setAuthHeader();
            response = await _dio.get('/api/v1/user/consent');
          } else {
            throw AuthException('세션이 만료되었습니다.');
          }
        } else {
          debugPrint('동의 상태 조회 실패: ${e.response?.statusCode}');
          return {'agreed': false};
        }
      }

      if (response.statusCode == 200) {
        return response.data is String ? jsonDecode(response.data) : Map<String, dynamic>.from(response.data);
      } else {
        debugPrint('동의 상태 조회 실패: ${response.statusCode}');
        return {'agreed': false};
      }
    } catch (e) {
      debugPrint('동의 상태 조회 오류: $e');
      rethrow;
    }
  }

  // 채팅방 설정 업데이트 (pinned, category, summaryEnabled, blocked)
  Future<ChatRoom?> updateRoomSettings(int roomId, {bool? pinned, String? category, bool? summaryEnabled, bool? blocked}) async {
    try {
      await _setAuthHeader();

      final data = <String, dynamic>{};
      if (pinned != null) data['pinned'] = pinned;
      if (category != null) data['category'] = category;
      if (summaryEnabled != null) data['summaryEnabled'] = summaryEnabled;
      if (blocked != null) data['blocked'] = blocked;

      Response response;
      try {
        response = await _dio.patch(
          ApiConstants.messengerRoomSettings(roomId.toString()),
          data: data,
        );
      } on DioException catch (e) {
        // 토큰 만료 시 갱신 후 재시도
        if (e.response?.statusCode == 401) {
          if (await _refreshToken()) {
            await _setAuthHeader();
            response = await _dio.patch(
              ApiConstants.messengerRoomSettings(roomId.toString()),
              data: data,
            );
          } else {
            return null;
          }
        } else {
          debugPrint('채팅방 설정 업데이트 실패: ${e.response?.statusCode}');
          return null;
        }
      }

      if (response.statusCode == 200) {
        final responseData = response.data is String ? jsonDecode(response.data) : response.data;
        return ChatRoom.fromJson(responseData);
      } else {
        debugPrint('채팅방 설정 업데이트 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('채팅방 설정 업데이트 오류: $e');
      return null;
    }
  }

  // 선택한 메시지들을 요약
  Future<Map<String, dynamic>?> createSummary(int roomId, List<int> messageIds) async {
    try {
      await _setAuthHeader();

      final data = {
        'roomId': roomId,
        'messageIds': messageIds,
      };

      Response response;
      try {
        response = await _dio.post(
          ApiConstants.messengerRoomSummary(roomId.toString()),
          data: data,
        );
      } on DioException catch (e) {
        // 토큰 만료 시 갱신 후 재시도
        if (e.response?.statusCode == 401) {
          if (await _refreshToken()) {
            await _setAuthHeader();
            response = await _dio.post(
              ApiConstants.messengerRoomSummary(roomId.toString()),
              data: data,
            );
          } else {
            return null;
          }
        } else {
          debugPrint('요약 요청 실패: ${e.response?.statusCode}');
          return null;
        }
      }

      if (response.statusCode == 200) {
        final responseData = response.data is String ? jsonDecode(response.data) : response.data;
        return Map<String, dynamic>.from(responseData);
      } else {
        debugPrint('요약 요청 실패: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('요약 요청 오류: $e');
      return null;
    }
  }

  // 차단된 대화방 목록 조회
  Future<List<ChatRoom>> getBlockedRooms() async {
    try {
      await _setAuthHeader();

      Response response;
      try {
        response = await _dio.get(ApiConstants.messengerBlockedRooms);
      } on DioException catch (e) {
        // 토큰 만료 시 갱신 후 재시도
        if (e.response?.statusCode == 401) {
          if (await _refreshToken()) {
            await _setAuthHeader();
            response = await _dio.get(ApiConstants.messengerBlockedRooms);
          } else {
            return [];
          }
        } else {
          debugPrint('차단된 대화방 목록 조회 실패: ${e.response?.statusCode}');
          return [];
        }
      }

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        return jsonList.map((json) => ChatRoom.fromJson(json)).toList();
      } else {
        debugPrint('차단된 대화방 목록 조회 실패: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('차단된 대화방 목록 조회 오류: $e');
      return [];
    }
  }

  // 대화방 삭제
  Future<bool> deleteRoom(int roomId) async {
    try {
      await _setAuthHeader();

      Response response;
      try {
        response = await _dio.delete(
          ApiConstants.messengerRoomDelete(roomId.toString()),
        );
      } on DioException catch (e) {
        // 토큰 만료 시 갱신 후 재시도
        if (e.response?.statusCode == 401) {
          if (await _refreshToken()) {
            await _setAuthHeader();
            response = await _dio.delete(
              ApiConstants.messengerRoomDelete(roomId.toString()),
            );
          } else {
            return false;
          }
        } else {
          debugPrint('대화방 삭제 실패: ${e.response?.statusCode}');
          return false;
        }
      }

      if (response.statusCode == 204) {
        return true;
      } else {
        debugPrint('대화방 삭제 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('대화방 삭제 오류: $e');
      return false;
    }
  }

  // 약관 동의 저장
  Future<Map<String, dynamic>> saveConsent({
    required bool serviceTerms,
    required bool privacyTerms,
    required bool messageSummaryTerms,
  }) async {
    try {
      await _setAuthHeader();

      Response response;
      try {
        response = await _dio.post(
          '/api/v1/user/consent',
          data: {
            'serviceTerms': serviceTerms,
            'privacyTerms': privacyTerms,
            'messageSummaryTerms': messageSummaryTerms,
          },
        );
      } on DioException catch (e) {
        // 토큰 만료 시 갱신 후 재시도
        if (e.response?.statusCode == 401) {
          if (await _refreshToken()) {
            await _setAuthHeader();
            response = await _dio.post(
              '/api/v1/user/consent',
              data: {
                'serviceTerms': serviceTerms,
                'privacyTerms': privacyTerms,
                'messageSummaryTerms': messageSummaryTerms,
              },
            );
          } else {
            throw AuthException('세션이 만료되었습니다.');
          }
        } else {
          debugPrint('동의 저장 실패: ${e.response?.statusCode}');
          throw Exception('동의 저장에 실패했습니다.');
        }
      }

      if (response.statusCode == 200) {
        return response.data is String ? jsonDecode(response.data) : Map<String, dynamic>.from(response.data);
      } else {
        debugPrint('동의 저장 실패: ${response.statusCode}');
        throw Exception('동의 저장에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('동의 저장 오류: $e');
      rethrow;
    }
  }

  void dispose() {
    _dio.close();
  }
}
