// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionGeneral => 'General';

  @override
  String get language => 'Language';

  @override
  String get languageSelectTitle => 'Select language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get permHeaderTitle =>
      'Please grant the permissions below\nso the app can work properly';

  @override
  String get permRequiredSectionLabel => 'Required permissions';

  @override
  String get permNotificationTitle => 'Notification access';

  @override
  String get permNotificationDesc =>
      'Required to receive and display your messenger messages';

  @override
  String get permBatteryTitle => 'Disable battery optimization';

  @override
  String get permBatteryDesc =>
      'Please exclude this app from battery optimization so it can receive messages reliably';

  @override
  String get permRequiredNote =>
      '* You can use the app once all required permissions are granted.';

  @override
  String get permStart => 'Get started';

  @override
  String get permGrantAllPrompt => 'Please grant all permissions above';

  @override
  String get permGranted => 'Granted';

  @override
  String get permRequiredBadge => 'Required';
}
