// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get settingsTitle => '앱 설정';

  @override
  String get sectionGeneral => '일반';

  @override
  String get language => '언어';

  @override
  String get languageSelectTitle => '언어 선택';

  @override
  String get languageSystemDefault => '시스템 기본값';
}
