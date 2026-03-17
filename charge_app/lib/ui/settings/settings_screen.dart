import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionHeader(context, '차량 설정'),
          _settingTile(context, isDark,
            icon: Icons.directions_car_rounded,
            title: '차량 타입',
            value: settings.vehicleType.label,
            onTap: () => _showVehicleTypePicker(context, ref),
          ),
          if (settings.vehicleType != VehicleType.ev)
            _settingTile(context, isDark,
              icon: Icons.local_gas_station_rounded,
              title: '유종',
              value: settings.fuelType.label,
              onTap: () => _showFuelTypePicker(context, ref),
            ),
          if (settings.vehicleType != VehicleType.gas)
            _settingTile(context, isDark,
              icon: Icons.ev_station_rounded,
              title: '충전기 타입',
              value: settings.chargerTypes.isEmpty
                  ? '미선택'
                  : '${settings.chargerTypes.length}개 선택',
              onTap: () => _showChargerTypePicker(context, ref),
            ),
          _settingTile(context, isDark,
            icon: Icons.radar_rounded,
            title: '검색 반경',
            value: '${(settings.radius / 1000).toInt()}Km',
            onTap: () => _showRadiusPicker(context, ref),
          ),

          const SizedBox(height: 16),
          _sectionHeader(context, '앱 설정'),
          _settingTile(context, isDark,
            icon: Icons.dark_mode_rounded,
            title: '테마',
            value: themeMode == ThemeMode.dark ? '다크' : '라이트',
            onTap: () => _showThemePicker(context, ref),
          ),

          const SizedBox(height: 16),
          _sectionHeader(context, '정보'),
          _settingTile(context, isDark, icon: Icons.info_outline_rounded, title: '앱 버전', value: '1.0.0'),
          _settingTile(context, isDark, icon: Icons.description_outlined, title: '이용약관', onTap: () {}),
          _settingTile(context, isDark, icon: Icons.shield_outlined, title: '개인정보 처리방침', onTap: () {}),

          const SizedBox(height: 24),
          Center(
            child: Text('${AppConstants.appName} · ${AppConstants.packageName}',
              style: Theme.of(context).textTheme.labelSmall),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('데이터 제공: 오피넷(한국석유공사) · 한국환경공단',
              style: Theme.of(context).textTheme.labelSmall),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.gasBlue, letterSpacing: 0.3)),
    );
  }

  Widget _settingTile(BuildContext context, bool isDark, {
    required IconData icon, required String title, String? value, VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, size: 22, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value, style: Theme.of(context).textTheme.bodyMedium),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  void _showVehicleTypePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        Text('차량 타입', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...VehicleType.values.map((t) => ListTile(
          title: Text(t.label),
          trailing: ref.read(settingsProvider).vehicleType == t ? const Icon(Icons.check, color: AppColors.gasBlue) : null,
          onTap: () { ref.read(settingsProvider.notifier).setVehicleType(t); Navigator.pop(context); },
        )),
        const SizedBox(height: 16),
      ]),
    ));
  }

  void _showFuelTypePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        Text('유종 선택', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...FuelType.values.map((t) => ListTile(
          title: Text(t.label),
          trailing: ref.read(settingsProvider).fuelType == t ? const Icon(Icons.check, color: AppColors.gasBlue) : null,
          onTap: () { ref.read(settingsProvider.notifier).setFuelType(t); Navigator.pop(context); },
        )),
        const SizedBox(height: 16),
      ]),
    ));
  }

  void _showChargerTypePicker(BuildContext context, WidgetRef ref) {
    final types = [
      ('01', 'DC콤보'),
      ('02', 'DC차데모'),
      ('06', 'AC3상'),
      ('04', '완속'),
      ('07', '수퍼차저'),
      ('08', '데스티네이션'),
      ('09', 'NACS'),
    ];
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          final selected = List<String>.from(ref.read(settingsProvider).chargerTypes);
          return SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 16),
              Text('충전기 타입', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...types.map((t) {
                final isSelected = selected.contains(t.$1);
                return ListTile(
                  title: Text(t.$2),
                  trailing: isSelected
                      ? const Icon(Icons.check_box_rounded, color: AppColors.evGreen)
                      : const Icon(Icons.check_box_outline_blank_rounded),
                  onTap: () {
                    setState(() {
                      if (isSelected) selected.remove(t.$1);
                      else selected.add(t.$1);
                    });
                    ref.read(settingsProvider.notifier).setChargerTypes(List.from(selected));
                  },
                );
              }),
              const SizedBox(height: 16),
            ]),
          );
        },
      ),
    );
  }

  void _showRadiusPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        Text('검색 반경', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...AppConstants.radiusOptions.map((r) => ListTile(
          title: Text('${(r / 1000).toInt()}Km'),
          trailing: ref.read(settingsProvider).radius == r ? const Icon(Icons.check, color: AppColors.gasBlue) : null,
          onTap: () { ref.read(settingsProvider.notifier).setRadius(r); Navigator.pop(context); },
        )),
        const SizedBox(height: 16),
      ]),
    ));
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        Text('테마', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...[ThemeMode.light, ThemeMode.dark].map((m) => ListTile(
          title: Text(m == ThemeMode.dark ? '다크 모드' : '라이트 모드'),
          trailing: ref.read(themeModeProvider) == m ? const Icon(Icons.check, color: AppColors.gasBlue) : null,
          onTap: () { ref.read(themeModeProvider.notifier).setTheme(m); Navigator.pop(context); },
        )),
        const SizedBox(height: 16),
      ]),
    ));
  }
}
