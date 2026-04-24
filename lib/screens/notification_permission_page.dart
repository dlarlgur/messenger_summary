import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 시스템 알림(POST_NOTIFICATIONS) 권한 안내 페이지.
///
/// 진입 시 자동으로 시스템 권한 다이얼로그를 띄워, 사용자는
/// "AI 톡비서에서 알림을 보내도록 허용하시겠습니까?" 시스템 팝업에서
/// 바로 허용/거부 선택 가능합니다.
///
/// 온보딩 마지막 단계 또는 설정 페이지의 알림 토글에서 재사용됩니다.
class NotificationPermissionPage extends StatefulWidget {
  /// 권한 결정 후 호출 (허용/거부 무관). null이면 Navigator.pop으로 닫힘.
  final ValueChanged<bool>? onComplete;

  /// 진행 표시(3/3 등)를 보여줄지 여부. 온보딩에서는 true.
  final bool showProgress;

  const NotificationPermissionPage({
    super.key,
    this.onComplete,
    this.showProgress = false,
  });

  @override
  State<NotificationPermissionPage> createState() =>
      _NotificationPermissionPageState();
}

class _NotificationPermissionPageState extends State<NotificationPermissionPage> {
  static const MethodChannel _methodChannel =
      MethodChannel('com.dksw.app/notification');

  bool _isRequesting = false;
  bool _hasAttempted = false;

  Future<void> _triggerSystemPopup() async {
    if (_isRequesting) return;
    _hasAttempted = true;
    setState(() => _isRequesting = true);

    bool granted = false;
    try {
      // 이미 허용된 경우 즉시 반환
      final already = await _methodChannel
              .invokeMethod<bool>('areNotificationsEnabled') ??
          false;
      if (already) {
        granted = true;
      } else {
        final raw = await _methodChannel
            .invokeMethod<dynamic>('requestNotificationPermission');
        final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
        granted = map['granted'] == true;
      }
    } catch (e) {
      debugPrint('알림 권한 요청 실패: $e');
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }

    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!(granted);
    } else {
      Navigator.of(context).pop(granted);
    }
  }

  Future<void> _skip() async {
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!(false);
    } else {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF2196F3);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _skip,
        ),
        title: widget.showProgress
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 1.0,
                  minHeight: 4,
                  backgroundColor: Color(0xFFE3F2FD),
                  valueColor: AlwaysStoppedAnimation(blue),
                ),
              )
            : null,
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.showProgress)
                      const Text(
                        '3 / 3 · 알림',
                        style: TextStyle(
                          fontSize: 13,
                          color: blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      '메시지 알림을\n받아보세요',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AI 톡비서가 자동 요약 결과를 빠르게 알려드려요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 36),
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active,
                          size: 44,
                          color: blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    _buildBenefitCard(
                      icon: Icons.summarize_outlined,
                      iconColor: const Color(0xFF2196F3),
                      title: '자동 요약 알림',
                      description: '대화방 요약이 끝나면 즉시 알려드려요',
                    ),
                    const SizedBox(height: 12),
                    _buildBenefitCard(
                      icon: Icons.block,
                      iconColor: const Color(0xFFE53935),
                      title: '광고 알림 없음',
                      description: '불필요한 마케팅 알림은 보내지 않아요',
                    ),
                    const SizedBox(height: 12),
                    _buildBenefitCard(
                      icon: Icons.settings_outlined,
                      iconColor: Colors.grey[700]!,
                      title: '언제든 해제 가능',
                      description: '설정에서 알림을 켜고 끌 수 있어요',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isRequesting ? null : _triggerSystemPopup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    disabledBackgroundColor: blue.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _isRequesting
                        ? '권한 요청 중...'
                        : (_hasAttempted ? '다시 요청하기' : '허용하기'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
                const SizedBox(height: 4),
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
        ],
      ),
    );
  }
}
