import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../config/constants.dart';
import '../models/user.dart' as app_user;

class AuthService extends ChangeNotifier {
  static const String _accessTokenKey = 'kakao_access_token';
  static const String _refreshTokenKey = 'kakao_refresh_token';
  static const String _userKey = 'cached_user';
  // AIPF 서버 토큰 키
  static const String _serverAccessTokenKey = 'server_access_token';
  static const String _serverRefreshTokenKey = 'server_refresh_token';

  late final Dio _dio;

  AuthService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ));
    _configureSslBypass();
  }

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

  app_user.User? _currentUser;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  app_user.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  // 초기화 - 저장된 토큰으로 자동 로그인 시도
  Future<bool> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_accessTokenKey);
      final refreshToken = prefs.getString(_refreshTokenKey);
      final serverAccessToken = prefs.getString(_serverAccessTokenKey);

      if (accessToken != null && refreshToken != null) {
        // 토큰이 있으면 유효성 검사
        try {
          // 카카오 토큰 정보 확인
          final tokenInfo = await UserApi.instance.accessTokenInfo();
          debugPrint('카카오 토큰 유효: ${tokenInfo.id}');

          // AIPF 서버 토큰 확인
          if (serverAccessToken == null) {
            debugPrint('AIPF 서버 토큰 없음: 서버 로그인 시도');
            final serverLoginSuccess = await _loginToServer(accessToken);
            if (!serverLoginSuccess) {
              debugPrint('AIPF 서버 로그인 실패');
              await _clearTokens();
              _isLoading = false;
              notifyListeners();
              return false;
            }
          }

          // 캐시된 유저 정보 로드
          final cachedUserJson = prefs.getString(_userKey);
          if (cachedUserJson != null) {
            _currentUser = app_user.User.fromJson(jsonDecode(cachedUserJson));
          } else {
            // 유저 정보 다시 가져오기
            await _fetchAndSaveUser();
          }

          _isLoggedIn = true;
          _isLoading = false;
          notifyListeners();
          return true;
        } catch (e) {
          debugPrint('카카오 토큰 만료: $e');
          // 토큰 삭제
          await _clearTokens();
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('초기화 실패: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 사용자 정보 조회
  Future<Map<String, dynamic>?> _getCurrentUser(String accessToken) async {
    try {
      _dio.options.headers['Authorization'] = 'Bearer $accessToken';
      final response = await _dio.get(ApiConstants.userMe);

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('사용자 정보 조회 실패: $e');
      return null;
    }
  }

  // 토큰 갱신
  Future<bool> _refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessTokenKey, data['accessToken']);
        if (data['refreshToken'] != null) {
          await prefs.setString(_refreshTokenKey, data['refreshToken']);
        }
        debugPrint('토큰 갱신 성공');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('토큰 갱신 오류: $e');
      return false;
    }
  }

  // AIPF 서버 로그인 (카카오 토큰으로)
  Future<bool> _loginToServer(String kakaoAccessToken) async {
    try {
      debugPrint('AIPF 서버 로그인 시도...');
      final response = await _dio.post(
        ApiConstants.socialLogin,
        data: {
          'provider': 'KAKAO',
          'providerAccessToken': kakaoAccessToken,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final prefs = await SharedPreferences.getInstance();

        // AIPF 서버 토큰 저장
        await prefs.setString(_serverAccessTokenKey, data['accessToken']);
        await prefs.setString(_serverRefreshTokenKey, data['refreshToken']);

        debugPrint('AIPF 서버 로그인 성공: userId=${data['userId']}');
        return true;
      }
      debugPrint('AIPF 서버 로그인 실패: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('AIPF 서버 로그인 오류: $e');
      return false;
    }
  }

  // 카카오 로그인
  Future<bool> loginWithKakao() async {
    _isLoading = true;
    notifyListeners();

    try {
      OAuthToken token;
      try {
        // 카카오톡으로 로그인 시도
        token = await UserApi.instance.loginWithKakaoTalk();
      } catch (e) {
        // 카카오톡이 없으면 카카오 계정으로 로그인
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      debugPrint('카카오 로그인 성공: ${token.accessToken}');

      // 카카오 토큰 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, token.accessToken);
      await prefs.setString(_refreshTokenKey, token.refreshToken ?? '');

      // AIPF 서버 로그인
      final serverLoginSuccess = await _loginToServer(token.accessToken);
      if (!serverLoginSuccess) {
        debugPrint('AIPF 서버 로그인 실패');
        await _clearTokens();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 사용자 정보 가져오기
      await _fetchAndSaveUser();

      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('카카오 로그인 실패: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 사용자 정보 가져오기 및 저장
  Future<void> _fetchAndSaveUser() async {
    try {
      User user = await UserApi.instance.me();
      debugPrint('카카오 사용자 정보: ${user.id}, ${user.kakaoAccount?.profile?.nickname}');

      _currentUser = app_user.User(
        id: user.id,
        kakaoId: user.id.toString(),
        nickName: user.kakaoAccount?.profile?.nickname ?? 'User${Random().nextInt(100000)}',
        createdAt: DateTime.now(),
      );

      // SharedPreferences에 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
    } catch (e) {
      debugPrint('사용자 정보 가져오기 실패: $e');
      throw Exception('사용자 정보를 가져올 수 없습니다.');
    }
  }



  // 토큰 삭제
  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
    // AIPF 서버 토큰도 삭제
    await prefs.remove(_serverAccessTokenKey);
    await prefs.remove(_serverRefreshTokenKey);
  }

  // 로그아웃
  Future<void> logout() async {
    try {
      await UserApi.instance.logout();
      debugPrint('카카오 로그아웃 성공');
    } catch (e) {
      debugPrint('카카오 로그아웃 실패: $e');
    }

    await _clearTokens();
    _currentUser = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
