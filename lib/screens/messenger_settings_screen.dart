import 'package:flutter/material.dart';
import '../services/messenger_registry.dart';
import '../services/messenger_settings_service.dart';
import '../services/plan_service.dart';
import 'subscription_screen.dart';

/// 메신저 관리 설정 화면
class MessengerSettingsScreen extends StatefulWidget {
  const MessengerSettingsScreen({super.key});

  @override
  State<MessengerSettingsScreen> createState() => _MessengerSettingsScreenState();
}

class _MessengerSettingsScreenState extends State<MessengerSettingsScreen> {
  final MessengerSettingsService _settingsService = MessengerSettingsService();
  final PlanService _planService = PlanService();

  // 현재 활성화된 패키지 목록 (순서 유지, 플랜 무관)
  List<String> _enabledPackages = [];
  bool _isBasicPlan = false;
  bool _isLoading = true;

  static const Color _primaryBlue = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isBasic = await _planService.isBasicPlan();
    setState(() {
      _enabledPackages = _settingsService.getSavedEnabledPackages();
      _isBasicPlan = isBasic;
      _isLoading = false;
    });
  }

  Future<void> _toggleMessenger(String packageName, bool enabled) async {
    if (enabled) {
      await _settingsService.enableMessenger(packageName);
    } else {
      await _settingsService.disableMessenger(packageName);
    }
    setState(() {
      _enabledPackages = _settingsService.getSavedEnabledPackages();
    });
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) newIndex--;
      final item = _enabledPackages.removeAt(oldIndex);
      _enabledPackages.insert(newIndex, item);
    });
    await _settingsService.setEnabledMessengers(_enabledPackages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '메신저 관리',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 안내 텍스트
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Text(
            '사용할 메신저를 선택하고, 탭에 표시되는 순서를 변경할 수 있습니다.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 활성화된 메신저 (순서 변경 가능)
        if (_enabledPackages.isNotEmpty) ...[
          _buildSectionHeader('활성 메신저 (드래그하여 순서 변경)'),
          _buildEnabledMessengersList(),
          const SizedBox(height: 8),
        ],

        // 비활성화된 메신저
        _buildSectionHeader('비활성 메신저'),
        _buildDisabledMessengersList(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildEnabledMessengersList() {
    return Container(
      color: Colors.white,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _enabledPackages.length,
        onReorder: _onReorder,
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final packageName = _enabledPackages[index];
          final info = MessengerRegistry.getByPackageName(packageName);
          if (info == null) return const SizedBox.shrink(key: ValueKey('unknown'));

          final isKakao = packageName == 'com.kakao.talk';

          return Container(
            key: ValueKey(packageName),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[100]!, width: 0.5),
              ),
            ),
            child: ListTile(
              leading: _buildMessengerIcon(info),
              title: Text(
                info.alias,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: isKakao
                  ? Text(
                      '기본 메신저 (비활성화 불가)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 토글 스위치
                  Switch(
                    value: true,
                    onChanged: isKakao
                        ? null
                        : (value) => _toggleMessenger(packageName, value),
                    activeColor: _primaryBlue,
                  ),
                  // 드래그 핸들
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDisabledMessengersList() {
    final disabledMessengers = MessengerRegistry.allMessengers
        .where((m) => !_enabledPackages.contains(m.packageName))
        .toList();

    if (disabledMessengers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: Center(
          child: Text(
            '모든 메신저가 활성화되어 있습니다.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: disabledMessengers.map((info) {
          // 테스트를 위해 Free 플랜도 모든 메신저 사용 가능
          // TODO: 테스트 완료 후 플랜 제한 복구
          // final needsUpgrade = !_isBasicPlan && info.packageName != 'com.kakao.talk';
          final needsUpgrade = false; // 테스트용: 모든 메신저 활성화 가능

          return Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[100]!, width: 0.5),
              ),
            ),
            child: ListTile(
              leading: _buildMessengerIcon(info, disabled: true),
              title: Text(
                info.alias,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: needsUpgrade ? Colors.grey[400] : Colors.black87,
                ),
              ),
              subtitle: needsUpgrade
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 12, color: Colors.orange[400]),
                        const SizedBox(width: 4),
                        Text(
                          'Basic 플랜 필요',
                          style: TextStyle(fontSize: 12, color: Colors.orange[400]),
                        ),
                      ],
                    )
                  : null,
              trailing: Switch(
                value: false,
                onChanged: needsUpgrade
                    ? (_) => _showUpgradeDialog()
                    : (value) {
                        if (value) _toggleMessenger(info.packageName, true);
                      },
                activeColor: _primaryBlue,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessengerIcon(MessengerInfo info, {bool disabled = false}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: disabled ? Colors.grey[300] : info.brandColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        info.icon,
        color: disabled
            ? Colors.grey[500]
            : (info.packageName == 'com.kakao.talk' ? Colors.black87 : Colors.white),
        size: 22,
      ),
    );
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Basic 플랜 필요'),
        content: const Text('카카오톡 외 다른 메신저를 사용하려면\nBasic 플랜으로 업그레이드하세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: const Text('업그레이드'),
          ),
        ],
      ),
    );
  }
}
