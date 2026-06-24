// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get settingsTitle => 'アプリ設定';

  @override
  String get sectionGeneral => '一般';

  @override
  String get language => '言語';

  @override
  String get languageSelectTitle => '言語を選択';

  @override
  String get languageSystemDefault => 'システムの既定';
}
