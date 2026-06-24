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

  @override
  String get permHeaderTitle => 'アプリを快適にご利用いただくため\n以下の権限をご確認ください';

  @override
  String get permRequiredSectionLabel => '必須の権限';

  @override
  String get permNotificationTitle => '通知へのアクセス';

  @override
  String get permNotificationDesc => 'メッセンジャーのメッセージを受信・表示するために必要な権限です';

  @override
  String get permBatteryTitle => 'バッテリー最適化を無効にする';

  @override
  String get permBatteryDesc => 'メッセージを確実に受信できるよう、バッテリー最適化の対象から除外してください';

  @override
  String get permRequiredNote => '※ 必須の権限をすべて許可するとアプリをご利用いただけます。';

  @override
  String get permStart => 'はじめる';

  @override
  String get permGrantAllPrompt => '上記の権限をすべて許可してください';

  @override
  String get permGranted => '許可済み';

  @override
  String get permRequiredBadge => '必須';
}
