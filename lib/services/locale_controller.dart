import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dksw_app_core/dksw_app_core.dart';

/// 앱 UI 언어(로케일) 컨트롤러.
/// - 설정 화면에서 선택, SharedPreferences 에 영구 저장.
/// - null = 기기 시스템 언어 따름.
/// - 지원: 한국어(ko) · 영어(en) · 일본어(ja). EU 개별 언어는 ARB 추가 시 supported 만 늘리면 됨.
///
/// NotificationSettingsService 와 동일한 싱글톤 + ChangeNotifier 패턴.
/// main() 에서 initialize() 선행 → 첫 build 부터 선택 언어 보장.
class LocaleController extends ChangeNotifier {
  LocaleController._internal();
  static final LocaleController _instance = LocaleController._internal();
  factory LocaleController() => _instance;

  static const String _prefsKey = 'app_locale';

  /// 지원 언어 (MaterialApp.supportedLocales / ARB 와 일치 유지).
  static const List<Locale> supported = [
    Locale('ko'),
    Locale('en'),
    Locale('ja'),
  ];

  Locale? _locale; // null = 시스템 언어
  bool _initialized = false;

  Locale? get locale => _locale;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null && code.isNotEmpty) {
        _locale = Locale(code);
      }
    } catch (_) {
      // 로드 실패해도 시스템 언어로 폴백 — 앱 동작엔 지장 없음.
    }
    _initialized = true;
    _syncContentLang();
  }

  /// 현재 적용 언어 코드 ('ko'|'en'|'ja'). _locale 미설정 시 시스템 언어를 따른다.
  String get effectiveLanguageCode {
    final code = _locale?.languageCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return (code == 'en' || code == 'ja') ? code : 'ko';
  }

  /// 서버 콘텐츠(FAQ·공지·이벤트·정책) 언어를 코어에 반영.
  /// 'ko' 는 null 로 전달 → 서버 기본(한국어) 서빙 (사이드이펙트 없음).
  void _syncContentLang() {
    final code = effectiveLanguageCode;
    DkswCore.setContentLang(code == 'ko' ? null : code);
  }

  /// 언어 변경. [locale] 이 null 이면 시스템 언어로 되돌림.
  Future<void> setLocale(Locale? locale) async {
    if (_locale?.languageCode == locale?.languageCode) return;
    _locale = locale;
    _syncContentLang();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, locale.languageCode);
      }
    } catch (_) {}
  }

  /// 언어 코드 → 네이티브 표기 이름.
  static String displayName(String code) {
    switch (code) {
      case 'ko':
        return '한국어';
      case 'en':
        return 'English';
      case 'ja':
        return '日本語';
      default:
        return code;
    }
  }
}
