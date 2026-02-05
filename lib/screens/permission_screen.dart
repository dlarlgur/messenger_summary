import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';

/// 권한 설정 화면
class PermissionScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const PermissionScreen({super.key, required this.onComplete});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with WidgetsBindingObserver {
  static const MethodChannel _methodChannel = MethodChannel('com.dksw.app/notification');
  
  bool _notificationPermissionGranted = false;
  bool _batteryOptimizationDisabled = false;
  bool _canDrawOverlays = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 포그라운드로 돌아오면 권한 상태 재확인
    if (state == AppLifecycleState.resumed) {
      // 약간의 지연을 주어 설정 화면에서 돌아온 후 권한 상태가 반영되도록 함
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkPermissions();
        }
      });
    }
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    setState(() => _isChecking = true);
    
    try {
      // 알림 접근 권한 확인
      final notificationEnabled = await _methodChannel.invokeMethod<bool>('isNotificationListenerEnabled') ?? false;

      // 배터리 최적화 제외 확인
      final batteryOptimizationDisabled = await _methodChannel.invokeMethod<bool>('isBatteryOptimizationDisabled') ?? false;

      // 다른 앱 위에 표시 권한 확인
      final canDrawOverlays = await _methodChannel.invokeMethod<bool>('canDrawOverlays') ?? false;

      debugPrint('📋 권한 상태 확인:');
      debugPrint('  알림 권한: $notificationEnabled');
      debugPrint('  배터리 최적화 제외: $batteryOptimizationDisabled');
      debugPrint('  다른 앱 위에 표시: $canDrawOverlays');
      final allGranted = notificationEnabled && batteryOptimizationDisabled && canDrawOverlays;
      debugPrint('  필수 권한 모두 허용됨: $allGranted');

      if (mounted) {
        setState(() {
          _notificationPermissionGranted = notificationEnabled;
          _batteryOptimizationDisabled = batteryOptimizationDisabled;
          _canDrawOverlays = canDrawOverlays;
          _isChecking = false;
        });
      }
    } catch (e) {
      debugPrint('권한 확인 실패: $e');
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _openNotificationSettings() async {
    try {
      await _methodChannel.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('알림 설정 열기 실패: $e');
    }
  }

  Future<void> _openBatteryOptimizationSettings() async {
    try {
      await _methodChannel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('배터리 최적화 설정 열기 실패: $e');
    }
  }

  Future<void> _openOverlaySettings() async {
    try {
      await _methodChannel.invokeMethod('openOverlaySettings');
    } catch (e) {
      debugPrint('오버레이 설정 열기 실패: $e');
    }
  }

  bool get _allRequiredPermissionsGranted => 
      _notificationPermissionGranted && 
      _batteryOptimizationDisabled && 
      _canDrawOverlays;
  
  bool get _allPermissionsGranted => _notificationPermissionGranted && _batteryOptimizationDisabled;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              
              // 헤더
              const Text(
                '원활한 앱 서비스 이용을 위해\n아래 권한을 확인해 주세요',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                '필수 권한',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 권한 목록
              Expanded(
                child: _isChecking
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          // 알림 접근 권한 (필수)
                          _buildPermissionItem(
                            icon: Icons.notifications_active,
                            iconColor: const Color(0xFFFF9800),
                            title: '알림 접근',
                            description: 'AI 톡비서가 카카오톡 메시지를 수신하고 표시하기 위해 필요한 권한입니다',
                            isRequired: true,
                            isGranted: _notificationPermissionGranted,
                            onTap: _openNotificationSettings,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // 배터리 최적화 제외 (권장)
                          _buildPermissionItem(
                            icon: Icons.battery_saver,
                            iconColor: const Color(0xFF4CAF50),
                            title: '배터리 사용량 최적화 중지',
                            description: 'AI 톡비서가 원활하게 메시지를 수신할 수 있도록 배터리 사용 최적화 목록에서 제외해 주세요',
                            isRequired: false,
                            isGranted: _batteryOptimizationDisabled,
                            onTap: _openBatteryOptimizationSettings,
                          ),

                          const SizedBox(height: 16),

                          // 다른 앱 위에 표시 (필수)
                          _buildPermissionItem(
                            icon: Icons.layers,
                            iconColor: const Color(0xFF2196F3),
                            title: '다른 앱 위에 표시',
                            description: '다른 앱 위에 표시되도록 허용하여 더욱 편리한 사용자 경험을 제공합니다.',
                            isRequired: true,
                            isGranted: _canDrawOverlays,
                            onTap: _openOverlaySettings,
                          ),
                        ],
                      ),
              ),
              
              // 안내 문구
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '* 필수 권한은 모두 허용 후에 앱을 이용할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
              
              // 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _allRequiredPermissionsGranted
                      ? () async {
                          debugPrint('✅ 시작하기 버튼 클릭 - 메인 화면으로 이동');
                          if (!mounted) return;
                          
                          // 권한 상태 재확인 (설정에서 돌아왔을 수 있으므로)
                          await _checkPermissions();
                          
                          if (!mounted) return;
                          
                          // 권한이 모두 허용되었는지 최종 확인
                          // 약간의 지연을 주어 상태 업데이트가 완료되도록 함
                          await Future.delayed(const Duration(milliseconds: 300));
                          
                          if (!mounted) return;
                          
                          if (_allRequiredPermissionsGranted) {
                            debugPrint('✅ 모든 권한 허용 확인됨 - 메인 화면으로 이동');
                            // PermissionScreen 내부에서 직접 메인 화면으로 이동
                            if (mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const MainScreen()),
                                (route) => false, // 모든 이전 라우트 제거
                              );
                              debugPrint('✅ 메인 화면으로 네비게이션 완료');
                            }
                            // onComplete 콜백도 호출 (호환성을 위해)
                            widget.onComplete();
                          } else {
                            debugPrint('⚠️ 권한이 아직 허용되지 않음');
                            debugPrint('  알림 권한: $_notificationPermissionGranted');
                            debugPrint('  배터리 최적화 제외: $_batteryOptimizationDisabled');
                            debugPrint('  다른 앱 위에 표시: $_canDrawOverlays');
                            // 권한이 없으면 다시 확인하도록 안내
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('필수 권한을 모두 허용해주세요.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _allRequiredPermissionsGranted ? '시작하기' : '권한 모두 허용하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _allRequiredPermissionsGranted ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isRequired,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isGranted ? const Color(0xFFE3F2FD) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGranted ? const Color(0xFF64B5F6) : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 14),
            
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isRequired 
                              ? (isGranted ? Colors.green : const Color(0xFFFF9800))
                              : (isGranted ? Colors.green : Colors.grey[400]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isGranted ? '허용됨' : (isRequired ? '필수' : '권장'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            // 체크 또는 화살표
            if (isGranted)
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              )
            else
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
