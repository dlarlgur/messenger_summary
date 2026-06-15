import 'package:flutter/material.dart';

/// 메신저 메타데이터
class MessengerInfo {
  final String packageName;
  final String alias;
  final Color brandColor;
  final IconData icon;
  final bool enabledByDefault;

  const MessengerInfo({
    required this.packageName,
    required this.alias,
    required this.brandColor,
    required this.icon,
    this.enabledByDefault = false,
  });

  Map<String, String> toMap() => {
    'packageName': packageName,
    'alias': alias,
  };

  /// 메신저 로고 위젯. 대부분은 [icon] 을 그대로 렌더하지만,
  /// 네이버 밴드처럼 적합한 머티리얼 아이콘이 없는 메신저는 글리프 텍스트로 표시.
  Widget buildGlyph({required Color color, required double size}) {
    if (packageName == 'com.nhn.android.band') {
      // 실제 BAND 로고 — 작은 사이즈는 'B' 한 글자, 큰 사이즈는 'BAND' 풀 텍스트.
      final isCompact = size < 20;
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          isCompact ? 'B' : 'BAND',
          style: TextStyle(
            color: color,
            fontSize: size * (isCompact ? 0.85 : 0.5),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      );
    }
    return Icon(icon, color: color, size: size);
  }
}

/// 모든 메신저 정보의 중앙 레지스트리
class MessengerRegistry {
  static const List<MessengerInfo> allMessengers = [
    MessengerInfo(
      packageName: 'com.kakao.talk',
      alias: '카카오톡',
      brandColor: Color(0xFFFEE500),
      icon: Icons.chat_bubble,
      enabledByDefault: true,
    ),
    MessengerInfo(
      packageName: 'jp.naver.line.android',
      alias: 'LINE',
      brandColor: Color(0xFF00B900),
      icon: Icons.message,
    ),
    MessengerInfo(
      packageName: 'org.telegram.messenger',
      alias: 'Telegram',
      brandColor: Color(0xFF0088CC),
      icon: Icons.send,
    ),
    MessengerInfo(
      packageName: 'com.instagram.android',
      alias: 'Instagram',
      brandColor: Color(0xFFE4405F),
      icon: Icons.camera_alt,
    ),
    MessengerInfo(
      packageName: 'com.Slack',
      alias: 'Slack',
      brandColor: Color(0xFF4A154B),
      icon: Icons.tag,
    ),
    MessengerInfo(
      packageName: 'com.microsoft.teams',
      alias: 'Teams',
      brandColor: Color(0xFF6264A7),
      icon: Icons.groups,
    ),
    MessengerInfo(
      packageName: 'com.facebook.orca',
      alias: 'Messenger',
      brandColor: Color(0xFF0084FF),
      icon: Icons.messenger,
    ),
    MessengerInfo(
      packageName: 'com.nhn.android.band',
      alias: '네이버 밴드',
      brandColor: Color(0xFF2EC36C),
      icon: Icons.group_work_rounded,
      enabledByDefault: true,
    ),
    // 문자(SMS) — 가상 패키지. 네이티브가 기기 기본 문자앱 알림을 "sms" 로 정규화해 캡처.
    // 기본 ON: 신규 유저는 첫 실행 시 전체 활성, 기존 유저는 enabledByDefault 머지로 자동 추가.
    // 설정 화면(messenger_settings)에서 다른 메신저처럼 On/Off 토글 가능.
    MessengerInfo(
      packageName: 'sms',
      alias: '문자메시지',
      brandColor: Color(0xFF1E88E5),
      icon: Icons.sms,
      enabledByDefault: true,
    ),
  ];

  static MessengerInfo? getByPackageName(String packageName) {
    try {
      return allMessengers.firstWhere((m) => m.packageName == packageName);
    } catch (_) {
      return null;
    }
  }

  static String getAlias(String packageName) {
    return getByPackageName(packageName)?.alias ?? '알 수 없음';
  }
}
