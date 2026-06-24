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

  @override
  String get permHeaderTitle => '원활한 앱 서비스 이용을 위해\n아래 권한을 확인해 주세요';

  @override
  String get permRequiredSectionLabel => '필수 권한';

  @override
  String get permNotificationTitle => '알림 접근';

  @override
  String get permNotificationDesc => 'AI 톡비서가 메신저 메시지를 수신하고 표시하기 위해 필요한 권한입니다';

  @override
  String get permBatteryTitle => '배터리 사용량 최적화 중지';

  @override
  String get permBatteryDesc =>
      'AI 톡비서가 원활하게 메시지를 수신할 수 있도록 배터리 사용 최적화 목록에서 제외해 주세요';

  @override
  String get permRequiredNote => '* 필수 권한은 모두 허용 후에 앱을 이용할 수 있습니다.';

  @override
  String get permStart => '시작하기';

  @override
  String get permGrantAllPrompt => '위 권한을 모두 허용해주세요';

  @override
  String get permGranted => '허용됨';

  @override
  String get permRequiredBadge => '필수';
}
