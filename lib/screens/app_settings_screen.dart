import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'blocked_rooms_screen.dart';
import 'usage_management_screen.dart';
import '../services/notification_settings_service.dart';
import '../services/auto_summary_settings_service.dart';

/// 앱 설정 화면
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> with WidgetsBindingObserver {
  String _appVersion = '';
  bool _canDrawOverlays = false;
  static const MethodChannel _methodChannel = MethodChannel('com.example.chat_llm/main');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppVersion();
    _checkOverlayPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkOverlayPermission();
    }
  }

  Future<void> _checkOverlayPermission() async {
    try {
      final canDrawOverlays = await _methodChannel.invokeMethod<bool>('canDrawOverlays') ?? false;
      if (mounted) {
        setState(() {
          _canDrawOverlays = canDrawOverlays;
        });
      }
    } catch (e) {
      debugPrint('오버레이 권한 확인 실패: $e');
    }
  }

  Future<void> _openOverlaySettings() async {
    try {
      await _methodChannel.invokeMethod('openOverlaySettings');
      // 설정에서 돌아왔을 때 권한 상태 다시 확인
      await Future.delayed(const Duration(milliseconds: 500));
      _checkOverlayPermission();
    } catch (e) {
      debugPrint('오버레이 설정 열기 실패: $e');
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('앱 버전 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '앱 설정',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // AI 톡비서 알림 섹션 (맨 위)
          _buildSectionHeader('AI 톡비서 알림'),
          _buildAutoSummaryNotificationMenuItem(context),
          _buildSoundMenuItem(context),
          _buildVibrationMenuItem(context),
          const SizedBox(height: 8),

          // 채팅방 설정 섹션
          _buildSectionHeader('채팅방 설정'),
          _buildMenuItem(
            icon: Icons.block,
            title: '차단된 채팅방 관리',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BlockedRoomsScreen(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.auto_awesome,
            title: '요약 관리',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UsageManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // 일반 섹션
          _buildSectionHeader('일반'),
          _buildMenuItem(
            icon: Icons.star,
            title: '리뷰를 남겨주세요.',
            onTap: () {
              _openStoreReview();
            },
          ),
          _buildMenuItem(
            icon: Icons.thumb_up,
            title: '추천 부탁드립니다.',
            onTap: () {
              _openStoreShare();
            },
          ),
          _buildMenuItem(
            icon: Icons.help_outline,
            title: 'AI 톡비서 사용방법',
            onTap: () {
              _showHowToUse();
            },
          ),
          _buildMenuItem(
            icon: Icons.info_outline,
            title: 'AI 톡비서 란',
            onTap: () {
              _showAbout();
            },
          ),
          const SizedBox(height: 24),
          
          // 앱 버전
          if (_appVersion.isNotEmpty)
            Center(
              child: Text(
                'App version: $_appVersion',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOverlayPermissionMenuItem(BuildContext context) {
    return InkWell(
      onTap: _openOverlaySettings,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.layers,
              size: 24,
              color: _canDrawOverlays ? Colors.green : Colors.grey[700],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '다른 앱 위에 표시',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _canDrawOverlays ? '권한 허용됨' : '권한 필요',
                    style: TextStyle(
                      fontSize: 13,
                      color: _canDrawOverlays ? Colors.green : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.grey[700],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStoreReview() async {
    // TODO: 실제 스토어 URL로 변경
    const url = 'https://play.google.com/store/apps/details?id=com.example.chat_llm';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('스토어 열기 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('스토어를 열 수 없습니다.'),
          ),
        );
      }
    }
  }

  /// 소리 메뉴 아이템
  Widget _buildSoundMenuItem(BuildContext context) {
    return Consumer<AutoSummarySettingsService>(
      builder: (context, autoSummarySettings, _) {
        final isNotificationEnabled = autoSummarySettings.autoSummaryNotificationEnabled;
        final isSoundEnabled = autoSummarySettings.soundEnabled;
        // 알림이 꺼져있으면 소리도 비활성화 표시
        final isEnabled = isNotificationEnabled && isSoundEnabled;
        final canToggle = isNotificationEnabled;

        return InkWell(
          onTap: canToggle
              ? () async {
                  await autoSummarySettings.setSoundEnabled(!isSoundEnabled);
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEnabled ? Icons.volume_up : Icons.volume_off,
                  size: 24,
                  color: isEnabled
                      ? const Color(0xFF2196F3)
                      : (canToggle ? Colors.grey[700] : Colors.grey[400]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '소리',
                        style: TextStyle(
                          fontSize: 16,
                          color: canToggle ? const Color(0xFF1A1A1A) : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !canToggle
                            ? '알림이 꺼져 있습니다'
                            : (isSoundEnabled ? '소리가 켜져 있습니다' : '소리가 꺼져 있습니다'),
                        style: TextStyle(
                          fontSize: 13,
                          color: canToggle ? Colors.grey[600] : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: canToggle
                      ? (value) async {
                          await autoSummarySettings.setSoundEnabled(value);
                        }
                      : null,
                  activeColor: const Color(0xFF2196F3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 진동 메뉴 아이템
  Widget _buildVibrationMenuItem(BuildContext context) {
    return Consumer<AutoSummarySettingsService>(
      builder: (context, autoSummarySettings, _) {
        final isNotificationEnabled = autoSummarySettings.autoSummaryNotificationEnabled;
        final isVibrationEnabled = autoSummarySettings.vibrationEnabled;
        // 알림이 꺼져있으면 진동도 비활성화 표시
        final isEnabled = isNotificationEnabled && isVibrationEnabled;
        final canToggle = isNotificationEnabled;

        return InkWell(
          onTap: canToggle
              ? () async {
                  await autoSummarySettings.setVibrationEnabled(!isVibrationEnabled);
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEnabled ? Icons.vibration : Icons.smartphone,
                  size: 24,
                  color: isEnabled
                      ? const Color(0xFF2196F3)
                      : (canToggle ? Colors.grey[700] : Colors.grey[400]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '진동',
                        style: TextStyle(
                          fontSize: 16,
                          color: canToggle ? const Color(0xFF1A1A1A) : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !canToggle
                            ? '알림이 꺼져 있습니다'
                            : (isVibrationEnabled ? '진동이 켜져 있습니다' : '진동이 꺼져 있습니다'),
                        style: TextStyle(
                          fontSize: 13,
                          color: canToggle ? Colors.grey[600] : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: canToggle
                      ? (value) async {
                          await autoSummarySettings.setVibrationEnabled(value);
                        }
                      : null,
                  activeColor: const Color(0xFF2196F3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 자동 요약 알림 메뉴 아이템
  Widget _buildAutoSummaryNotificationMenuItem(BuildContext context) {
    return Consumer<AutoSummarySettingsService>(
      builder: (context, autoSummarySettings, _) {
        final isEnabled = autoSummarySettings.autoSummaryNotificationEnabled;

        return InkWell(
          onTap: () async {
            await autoSummarySettings.setAutoSummaryNotificationEnabled(!isEnabled);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                  size: 24,
                  color: isEnabled ? const Color(0xFF2196F3) : Colors.grey[700],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '자동 요약 알림',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEnabled
                            ? '자동 요약 완료 시 푸시 알림을 받습니다'
                            : '자동 요약 알림이 꺼져 있습니다',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: (value) async {
                    await autoSummarySettings.setAutoSummaryNotificationEnabled(value);
                  },
                  activeColor: const Color(0xFF2196F3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStoreShare() async {
    // TODO: 실제 스토어 URL로 변경
    const url = 'https://play.google.com/store/apps/details?id=com.example.chat_llm';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('스토어 열기 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('스토어를 열 수 없습니다.'),
          ),
        );
      }
    }
  }

  void _showHowToUse() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI 톡비서 사용방법'),
        content: const SingleChildScrollView(
          child: Text(
            'AI 톡비서는 카카오톡 대화를 자동으로 수집하고 AI로 요약해주는 앱입니다.\n\n'
            '1. 알림 접근 권한을 허용해주세요.\n'
            '2. 카카오톡에서 대화가 오면 자동으로 수집됩니다.\n'
            '3. 대화방에서 요약 버튼을 눌러 요약을 생성할 수 있습니다.\n'
            '4. 요약 히스토리에서 이전 요약을 확인할 수 있습니다.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI 톡비서 란'),
        content: const SingleChildScrollView(
          child: Text(
            'AI 톡비서는 카카오톡 대화를 AI로 요약해주는 스마트한 메신저 어시스턴트입니다.\n\n'
            '주요 기능:\n'
            '• 카카오톡 대화 자동 수집\n'
            '• AI 기반 대화 요약\n'
            '• 요약 히스토리 관리\n'
            '• 채팅방별 요약 기능\n\n'
            '더 효율적인 메신저 사용을 경험해보세요!',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
