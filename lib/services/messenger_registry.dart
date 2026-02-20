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
