import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'blocked_rooms_screen.dart';
import 'usage_management_screen.dart';
import 'subscription_screen.dart';
import '../services/auto_summary_settings_service.dart';
import '../services/plan_service.dart';

/// 앱 설정 화면
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> with WidgetsBindingObserver {
  String _appVersion = '';
  bool _wasWaitingForPermission = false;
  String? _currentPlanType;
  final PlanService _planService = PlanService();

  // 파란색 테마 컬러
  static const Color _primaryBlue = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAppVersion();
    _loadCurrentPlan();
  }

  Future<void> _loadCurrentPlan() async {
    try {
      // 설정 화면 진입 시 항상 서버에서 최신 플랜 정보 조회
      _planService.invalidateCache();
      final planType = await _planService.getCurrentPlanType();
      if (mounted) {
        setState(() {
          _currentPlanType = planType;
        });
      }
    } catch (e) {
      debugPrint('플랜 정보 로드 실패: $e');
    }
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
      _checkAndEnableNotification();
    }
  }

  /// 알림 권한 확인 후 자동으로 알림 켜기
  Future<void> _checkAndEnableNotification() async {
    final autoSummarySettingsService =
        Provider.of<AutoSummarySettingsService>(context, listen: false);

    final wasPermissionDisabled = !autoSummarySettingsService.systemNotificationPermissionEnabled;

    // 시스템 알림 권한 상태 새로고침
    await autoSummarySettingsService.refreshSystemNotificationPermission();

    // 권한이 없었다가 새로 허용된 경우, 자동으로 알림 켜기
    if (_wasWaitingForPermission &&
        autoSummarySettingsService.systemNotificationPermissionEnabled &&
        !autoSummarySettingsService.appNotificationEnabled) {
      await autoSummarySettingsService.setAutoSummaryNotificationEnabled(true);
      _wasWaitingForPermission = false;
    }
  }

  /// 설정 화면으로 이동할 때 권한 대기 상태로 설정
  void _markWaitingForPermission() {
    _wasWaitingForPermission = true;
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
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          '앱 설정',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Premium 배너
          _buildPremiumBanner(),

          // AI 톡비서 알림 섹션 (맨 위)
          _buildSectionHeaderStyled('AI 톡비서 알림', Icons.notifications_active),
          _buildAutoSummaryNotificationMenuItem(context),
          _buildSoundMenuItem(context),
          _buildVibrationMenuItem(context),
          const SizedBox(height: 16),

          // 채팅방 설정 섹션
          _buildSectionHeaderStyled('채팅방 설정', Icons.chat_bubble_outline),
          _buildStyledMenuItem(
            icon: Icons.block,
            title: '차단된 채팅방 관리',
            subtitle: '요약에서 제외할 채팅방',
            isFirst: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BlockedRoomsScreen(),
                ),
              );
            },
          ),
          _buildStyledMenuItem(
            icon: Icons.auto_awesome,
            title: '요약 관리',
            subtitle: '요약 사용량 및 설정',
            isLast: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UsageManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 일반 섹션
          _buildSectionHeaderStyled('일반', Icons.settings),
          _buildStyledMenuItem(
            icon: Icons.star,
            title: '리뷰를 남겨주세요',
            subtitle: '소중한 리뷰가 큰 힘이 됩니다',
            iconColor: Colors.amber,
            isFirst: true,
            onTap: () {
              _openStoreReview();
            },
          ),
          _buildStyledMenuItem(
            icon: Icons.share,
            title: '친구에게 추천하기',
            subtitle: '앱을 친구와 공유해보세요',
            iconColor: Colors.green,
            onTap: () {
              _openStoreShare();
            },
          ),
          _buildStyledMenuItem(
            icon: Icons.help_outline,
            title: 'AI 톡비서 사용방법',
            subtitle: '앱 사용 가이드',
            iconColor: _primaryBlue,
            onTap: () {
              _showHowToUse();
            },
          ),
          _buildStyledMenuItem(
            icon: Icons.info_outline,
            title: 'AI 톡비서 란',
            subtitle: '앱 소개 및 기능 안내',
            iconColor: _primaryBlue,
            onTap: () {
              _showAbout();
            },
            isLast: true,
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

  /// Premium 배너 위젯
  Widget _buildPremiumBanner() {
    // 현재 플랜에 따른 표시 텍스트
    String planDisplayName;
    String planDescription;

    switch (_currentPlanType) {
      case 'basic':
        planDisplayName = 'Basic 플랜';
        planDescription = '더 많은 혜택을 원하시면 탭하세요';
        break;
      case 'premium':
        planDisplayName = 'Premium 플랜';
        planDescription = '모든 기능을 사용 중입니다';
        break;
      default:
        planDisplayName = '무료 플랜';
        planDescription = '프리미엄으로 업그레이드하세요';
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SubscriptionScreen(),
          ),
        ).then((_) {
          // 구독 화면에서 돌아오면 플랜 정보 갱신
          _loadCurrentPlan();
        });
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9C27B0),  // 보라색
              Color(0xFF7B1FA2),  // 진한 보라
              Color(0xFFE91E63),  // 핑크
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
        children: [
          // 배경 장식
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // 반짝이 효과
          Positioned(
            right: 30,
            top: 20,
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white.withValues(alpha: 0.6),
              size: 16,
            ),
          ),
          Positioned(
            right: 80,
            bottom: 30,
            child: Icon(
              Icons.auto_awesome,
              color: Colors.white.withValues(alpha: 0.4),
              size: 12,
            ),
          ),
          // 메인 콘텐츠
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              planDisplayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        planDescription,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem('메시지 자동 요약'),
                      const SizedBox(height: 8),
                      _buildFeatureItem('메시지 최대 300개 요약'),
                    ],
                  ),
                ),
                // AI 아이콘
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.psychology,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 스타일된 섹션 헤더
  Widget _buildSectionHeaderStyled(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: _primaryBlue,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E),
            ),
          ),
        ],
      ),
    );
  }

  /// 스타일된 메뉴 아이템
  Widget _buildStyledMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool isFirst = false,
    bool isLast = false,
  }) {
    BorderRadius? borderRadius;
    if (isFirst && isLast) {
      borderRadius = BorderRadius.circular(16);
    } else if (isFirst) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      );
    } else if (isLast) {
      borderRadius = const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: !isLast
            ? const Border(
                bottom: BorderSide(
                  color: Color(0xFFE8EDF3),
                  width: 1,
                ),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (iconColor ?? _primaryBlue).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: iconColor ?? _primaryBlue,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPlayStoreSubscription() async {
    // 플레이스토어 구독/결제 페이지로 이동
    const url = 'https://play.google.com/store/apps/details?id=com.dksw.app';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('플레이스토어 열기 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('플레이스토어를 열 수 없습니다.'),
          ),
        );
      }
    }
  }

  Future<void> _openStoreReview() async {
    // TODO: 실제 스토어 URL로 변경
    const url = 'https://play.google.com/store/apps/details?id=com.dksw.app';
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
        final isEnabled = isNotificationEnabled && isSoundEnabled;
        final canToggle = isNotificationEnabled;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE8EDF3),
                width: 1,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canToggle
                  ? () async {
                      await autoSummarySettings.setSoundEnabled(!isSoundEnabled);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (isEnabled ? _primaryBlue : Colors.grey).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEnabled ? Icons.volume_up : Icons.volume_off,
                        size: 22,
                        color: isEnabled
                            ? _primaryBlue
                            : (canToggle ? Colors.grey[600] : Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '소리',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: canToggle ? const Color(0xFF1A1A1A) : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            !canToggle
                                ? '알림이 꺼져 있습니다'
                                : (isSoundEnabled ? '소리가 켜져 있습니다' : '소리가 꺼져 있습니다'),
                            style: TextStyle(
                              fontSize: 12,
                              color: canToggle ? Colors.grey[500] : Colors.grey[400],
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
                      activeTrackColor: _primaryBlue.withValues(alpha: 0.5),
                      activeThumbColor: _primaryBlue,
                    ),
                  ],
                ),
              ),
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
        final isEnabled = isNotificationEnabled && isVibrationEnabled;
        final canToggle = isNotificationEnabled;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canToggle
                  ? () async {
                      await autoSummarySettings.setVibrationEnabled(!isVibrationEnabled);
                    }
                  : null,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (isEnabled ? _primaryBlue : Colors.grey).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEnabled ? Icons.vibration : Icons.smartphone,
                        size: 22,
                        color: isEnabled
                            ? _primaryBlue
                            : (canToggle ? Colors.grey[600] : Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '진동',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: canToggle ? const Color(0xFF1A1A1A) : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            !canToggle
                                ? '알림이 꺼져 있습니다'
                                : (isVibrationEnabled ? '진동이 켜져 있습니다' : '진동이 꺼져 있습니다'),
                            style: TextStyle(
                              fontSize: 12,
                              color: canToggle ? Colors.grey[500] : Colors.grey[400],
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
                      activeTrackColor: _primaryBlue.withValues(alpha: 0.5),
                      activeThumbColor: _primaryBlue,
                    ),
                  ],
                ),
              ),
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
        final systemPermissionEnabled = autoSummarySettings.systemNotificationPermissionEnabled;
        final appEnabled = autoSummarySettings.appNotificationEnabled;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFE8EDF3),
                width: 1,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (!systemPermissionEnabled) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('알림 권한이 필요합니다. 설정에서 알림을 허용해주세요.'),
                        action: SnackBarAction(
                          label: '설정',
                          onPressed: () async {
                            _markWaitingForPermission();
                            try {
                              const methodChannel = MethodChannel('com.dksw.app/main');
                              await methodChannel.invokeMethod('openAppSettings');
                            } catch (e) {
                              debugPrint('설정 화면 열기 실패: $e');
                            }
                          },
                        ),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                  return;
                }
                final success = await autoSummarySettings.setAutoSummaryNotificationEnabled(!appEnabled);
                if (!success && mounted) {
                  await autoSummarySettings.refreshSystemNotificationPermission();
                }
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (isEnabled ? _primaryBlue : Colors.grey).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                        size: 22,
                        color: isEnabled ? _primaryBlue : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '자동 요약 알림',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            !systemPermissionEnabled
                                ? '알림 권한이 필요합니다'
                                : isEnabled
                                    ? '자동 요약 완료 시 푸시 알림을 받습니다'
                                    : '자동 요약 알림이 꺼져 있습니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: !systemPermissionEnabled ? Colors.orange[700] : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isEnabled,
                      onChanged: systemPermissionEnabled
                          ? (value) async {
                              final success = await autoSummarySettings.setAutoSummaryNotificationEnabled(value);
                              if (!success && mounted) {
                                await autoSummarySettings.refreshSystemNotificationPermission();
                              }
                            }
                          : null,
                      activeTrackColor: _primaryBlue.withValues(alpha: 0.5),
                      activeThumbColor: _primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openStoreShare() async {
    // TODO: 실제 스토어 URL로 변경
    const url = 'https://play.google.com/store/apps/details?id=com.dksw.app';
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
