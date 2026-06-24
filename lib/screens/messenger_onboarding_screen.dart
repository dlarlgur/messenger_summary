import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/messenger_registry.dart';
import '../services/messenger_settings_service.dart';

/// 온보딩 메신저 선택 화면 — 권한 허용 직후 1회 노출.
/// 어떤 메신저의 알림을 저장(요약·삭제 메시지 보기)할지 고른다.
/// 기본 체크 = MessengerInfo.enabledByDefault. 나중에 설정에서 변경 가능.
class MessengerOnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const MessengerOnboardingScreen({super.key, required this.onDone});

  static const String _seenKey = 'messenger_onboarding_seen';

  static Future<bool> hasSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {}
  }

  @override
  State<MessengerOnboardingScreen> createState() => _MessengerOnboardingScreenState();
}

class _MessengerOnboardingScreenState extends State<MessengerOnboardingScreen> {
  late final Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 이미 저장된 설정이 있으면 그걸, 없으면 enabledByDefault 로 초기화.
    final saved = MessengerSettingsService().getSavedEnabledPackages();
    _selected = saved.isNotEmpty
        ? saved.toSet()
        : MessengerRegistry.allMessengers
            .where((m) => m.enabledByDefault)
            .map((m) => m.packageName)
            .toSet();
  }

  Future<void> _start() async {
    if (_saving) return;
    setState(() => _saving = true);
    await MessengerSettingsService().setEnabledMessengers(_selected.toList());
    await MessengerOnboardingScreen.markSeen();
    if (!mounted) return;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final messengers = MessengerRegistry.allMessengers;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
              child: Text(
                l.onboardMessenger_title,
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, height: 1.35),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                l.onboardMessenger_subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.45),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: messengers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final m = messengers[i];
                  final on = _selected.contains(m.packageName);
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() {
                      if (on) {
                        _selected.remove(m.packageName);
                      } else {
                        _selected.add(m.packageName);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: on ? accent.withValues(alpha: 0.06) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: on ? accent.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: m.brandColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: m.buildGlyph(color: m.brandColor, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              m.alias,
                              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Icon(
                            on ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: on ? accent : Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _start,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          l.onboardMessenger_start,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
