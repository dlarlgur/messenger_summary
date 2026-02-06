// API 서버 설정
class ApiConstants {
  // 개발 환경: 에뮬레이터에서 호스트 PC 접근 시 10.0.2.2 사용
  // 실기기: PC의 로컬 IP 사용 (예: 192.168.x.x)
  // 배포 환경: 실제 서버 URL로 변경
  static const String baseUrl = 'https://223.130.151.39';

  // 인증 API 엔드포인트
  static const String socialLogin = '/api/v1/auth/social-login';
  static const String refreshToken = '/api/v1/auth/refresh';
  static const String logout = '/api/v1/auth/logout';

  // 사용자 API 엔드포인트
  static const String userMe = '/user/me';
  static const String userNickname = '/user/nickname';

  // 메신저 API 엔드포인트
  static const String messengerAlarm = '/api/v1/messenger/alarm';
  static const String messengerMessengers = '/api/v1/messenger/messengers';
  static const String messengerRooms = '/api/v1/messenger/rooms';
  static const String messengerBlockedRooms = '/api/v1/messenger/rooms/blocked';
  static String messengerRoomDetail(String roomId) => '/api/v1/messenger/rooms/$roomId';
  static String messengerRoomSettings(String roomId) => '/api/v1/messenger/rooms/$roomId/settings';
  static String messengerRoomMessages(String roomId) => '/api/v1/messenger/rooms/$roomId/messages';
  static String messengerRoomSummary(String roomId) => '/api/v1/messenger/rooms/$roomId/summary';
  static String messengerRoomDelete(String roomId) => '/api/v1/messenger/rooms/$roomId';
}

// 카카오 SDK 설정
class KakaoConstants {
  // TODO: 카카오 개발자 콘솔에서 발급받은 네이티브 앱 키로 변경
  static const String nativeAppKey = 'ec8e28e373ce458e3e6707717d400ee9';
}

// 앱 테마 색상
class AppColors {
  // Primary Blue Theme (카카오 노랑 대신 파랑)
  static const int primaryValue = 0xFF2196F3;
  static const int primaryDarkValue = 0xFF1976D2;
  static const int primaryLightValue = 0xFF64B5F6;
  static const int accentValue = 0xFF03A9F4;
  
  // Summary Theme (하늘색 계열 - 카카오톡 스타일)
  static const int summaryPrimary = 0xFF4A9EFF; // 밝은 하늘색
  static const int summaryLight = 0xFF7BB3FF; // 더 밝은 하늘색
  static const int summaryDark = 0xFF3A7ECC; // 어두운 하늘색
}
