import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko')
  ];

  /// 앱 설정 화면 타이틀
  ///
  /// In ko, this message translates to:
  /// **'앱 설정'**
  String get settingsTitle;

  /// No description provided for @sectionGeneral.
  ///
  /// In ko, this message translates to:
  /// **'일반'**
  String get sectionGeneral;

  /// No description provided for @language.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get language;

  /// No description provided for @languageSelectTitle.
  ///
  /// In ko, this message translates to:
  /// **'언어 선택'**
  String get languageSelectTitle;

  /// No description provided for @languageSystemDefault.
  ///
  /// In ko, this message translates to:
  /// **'시스템 기본값'**
  String get languageSystemDefault;

  /// No description provided for @permHeaderTitle.
  ///
  /// In ko, this message translates to:
  /// **'원활한 앱 서비스 이용을 위해\n아래 권한을 확인해 주세요'**
  String get permHeaderTitle;

  /// No description provided for @permRequiredSectionLabel.
  ///
  /// In ko, this message translates to:
  /// **'필수 권한'**
  String get permRequiredSectionLabel;

  /// No description provided for @permNotificationTitle.
  ///
  /// In ko, this message translates to:
  /// **'알림 접근'**
  String get permNotificationTitle;

  /// No description provided for @permNotificationDesc.
  ///
  /// In ko, this message translates to:
  /// **'AI 톡비서가 메신저 메시지를 수신하고 표시하기 위해 필요한 권한입니다'**
  String get permNotificationDesc;

  /// No description provided for @permBatteryTitle.
  ///
  /// In ko, this message translates to:
  /// **'배터리 사용량 최적화 중지'**
  String get permBatteryTitle;

  /// No description provided for @permBatteryDesc.
  ///
  /// In ko, this message translates to:
  /// **'AI 톡비서가 원활하게 메시지를 수신할 수 있도록 배터리 사용 최적화 목록에서 제외해 주세요'**
  String get permBatteryDesc;

  /// No description provided for @permRequiredNote.
  ///
  /// In ko, this message translates to:
  /// **'* 필수 권한은 모두 허용 후에 앱을 이용할 수 있습니다.'**
  String get permRequiredNote;

  /// No description provided for @permStart.
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get permStart;

  /// No description provided for @permGrantAllPrompt.
  ///
  /// In ko, this message translates to:
  /// **'위 권한을 모두 허용해주세요'**
  String get permGrantAllPrompt;

  /// No description provided for @permGranted.
  ///
  /// In ko, this message translates to:
  /// **'허용됨'**
  String get permGranted;

  /// No description provided for @permRequiredBadge.
  ///
  /// In ko, this message translates to:
  /// **'필수'**
  String get permRequiredBadge;

  /// No description provided for @blocked_loadFailed.
  ///
  /// In ko, this message translates to:
  /// **'차단된 채팅방을 불러오는데 실패했습니다.'**
  String get blocked_loadFailed;

  /// No description provided for @blocked_unblockFailed.
  ///
  /// In ko, this message translates to:
  /// **'차단 해제에 실패했습니다.'**
  String get blocked_unblockFailed;

  /// No description provided for @blocked_bulkUnblockTitle.
  ///
  /// In ko, this message translates to:
  /// **'차단 일괄 해제'**
  String get blocked_bulkUnblockTitle;

  /// No description provided for @blocked_cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get blocked_cancel;

  /// No description provided for @blocked_unblock.
  ///
  /// In ko, this message translates to:
  /// **'해제'**
  String get blocked_unblock;

  /// No description provided for @blocked_unblockTitle.
  ///
  /// In ko, this message translates to:
  /// **'차단 해제'**
  String get blocked_unblockTitle;

  /// No description provided for @blocked_title.
  ///
  /// In ko, this message translates to:
  /// **'차단방 관리'**
  String get blocked_title;

  /// No description provided for @blocked_deselectAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 해제'**
  String get blocked_deselectAll;

  /// No description provided for @blocked_selectAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 선택'**
  String get blocked_selectAll;

  /// No description provided for @blocked_unblockSelected.
  ///
  /// In ko, this message translates to:
  /// **'선택 해제'**
  String get blocked_unblockSelected;

  /// No description provided for @blocked_exitSelectionMode.
  ///
  /// In ko, this message translates to:
  /// **'선택 모드 종료'**
  String get blocked_exitSelectionMode;

  /// No description provided for @blocked_edit.
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get blocked_edit;

  /// No description provided for @blocked_retry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get blocked_retry;

  /// No description provided for @blocked_emptyMessage.
  ///
  /// In ko, this message translates to:
  /// **'차단된 채팅방이 없습니다.'**
  String get blocked_emptyMessage;

  /// No description provided for @guideSkip.
  ///
  /// In ko, this message translates to:
  /// **'건너뛰기'**
  String get guideSkip;

  /// No description provided for @guideStart.
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get guideStart;

  /// No description provided for @guideNext.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get guideNext;

  /// No description provided for @guideNotifTitle.
  ///
  /// In ko, this message translates to:
  /// **'카카오톡 알림 설정'**
  String get guideNotifTitle;

  /// No description provided for @guideNotifSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'메시지를 정확히 읽으려면\n아래와 같이 설정해 주세요'**
  String get guideNotifSubtitle;

  /// No description provided for @guideNotifSettingPath.
  ///
  /// In ko, this message translates to:
  /// **'카카오톡 설정 → 알림 → 알림 표시 → 알림 내용\n\"이름 + 메시지\"로 설정'**
  String get guideNotifSettingPath;

  /// No description provided for @guideMockSenderBoss.
  ///
  /// In ko, this message translates to:
  /// **'부장님'**
  String get guideMockSenderBoss;

  /// No description provided for @guideMockTimePm559.
  ///
  /// In ko, this message translates to:
  /// **'오후 5:59'**
  String get guideMockTimePm559;

  /// No description provided for @guideMockBossMessage.
  ///
  /// In ko, this message translates to:
  /// **'김대리 오늘 퇴근 전 까지 사장님께 드릴 보고서 작성해서 보내.'**
  String get guideMockBossMessage;

  /// No description provided for @guideMockNotifHint.
  ///
  /// In ko, this message translates to:
  /// **'톡이 오면 위 스크린샷처럼\n스마트폰 상단 알림창에 보여야 합니다.'**
  String get guideMockNotifHint;

  /// No description provided for @guideSummaryTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 대화 요약'**
  String get guideSummaryTitle;

  /// No description provided for @guideSummarySubtitle.
  ///
  /// In ko, this message translates to:
  /// **'긴 대화도 한눈에 파악하세요'**
  String get guideSummarySubtitle;

  /// No description provided for @guideSummaryRoomName.
  ///
  /// In ko, this message translates to:
  /// **'AI 톡비서 구독자 모임'**
  String get guideSummaryRoomName;

  /// No description provided for @guideSummaryBadge.
  ///
  /// In ko, this message translates to:
  /// **'AI 요약'**
  String get guideSummaryBadge;

  /// No description provided for @guideSummaryCardTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 톡비서 사용 방법 안내'**
  String get guideSummaryCardTitle;

  /// No description provided for @guideStatMessagesValue.
  ///
  /// In ko, this message translates to:
  /// **'5개'**
  String get guideStatMessagesValue;

  /// No description provided for @guideStatMessagesLabel.
  ///
  /// In ko, this message translates to:
  /// **'메시지'**
  String get guideStatMessagesLabel;

  /// No description provided for @guideStatParticipantsValue.
  ///
  /// In ko, this message translates to:
  /// **'5명'**
  String get guideStatParticipantsValue;

  /// No description provided for @guideStatParticipantsLabel.
  ///
  /// In ko, this message translates to:
  /// **'참여자'**
  String get guideStatParticipantsLabel;

  /// No description provided for @guideStatDurationValue.
  ///
  /// In ko, this message translates to:
  /// **'8분'**
  String get guideStatDurationValue;

  /// No description provided for @guideStatDurationLabel.
  ///
  /// In ko, this message translates to:
  /// **'소요시간'**
  String get guideStatDurationLabel;

  /// No description provided for @guideSummaryContent.
  ///
  /// In ko, this message translates to:
  /// **'AI 톡비서 사용 방법에 대해 서로 공유하며, 요약 기능이 너무 편해서 스트레스가 훨씬 줄었다는 내용을 공유하고 있습니다.'**
  String get guideSummaryContent;

  /// No description provided for @guideSummaryHint.
  ///
  /// In ko, this message translates to:
  /// **'채팅방에서 요약 버튼을 눌러보세요'**
  String get guideSummaryHint;

  /// No description provided for @guideDeletedTitle.
  ///
  /// In ko, this message translates to:
  /// **'삭제된 메시지 복원'**
  String get guideDeletedTitle;

  /// No description provided for @guideDeletedSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'삭제된 메시지를 볼 수 있고,\n상대 몰래 메시지를 미리 볼 수 있어요.'**
  String get guideDeletedSubtitle;

  /// No description provided for @guideChatBoss.
  ///
  /// In ko, this message translates to:
  /// **'부장님,'**
  String get guideChatBoss;

  /// No description provided for @guideChatDeleted.
  ///
  /// In ko, this message translates to:
  /// **'메시지가 삭제되었습니다.'**
  String get guideChatDeleted;

  /// No description provided for @guideAiAssistantBadge.
  ///
  /// In ko, this message translates to:
  /// **'AI 톡비서'**
  String get guideAiAssistantBadge;

  /// No description provided for @guideChatRestored.
  ///
  /// In ko, this message translates to:
  /// **'완전 짜증나!!!'**
  String get guideChatRestored;

  /// No description provided for @guideDeletedExplain1.
  ///
  /// In ko, this message translates to:
  /// **'이제부터 삭제된 메시지를 볼 수 있고,'**
  String get guideDeletedExplain1;

  /// No description provided for @guideDeletedExplain2.
  ///
  /// In ko, this message translates to:
  /// **'상대 몰래 메시지를 미리 볼 수 있어요.'**
  String get guideDeletedExplain2;

  /// No description provided for @howTo_appBarTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 톡비서 사용 가이드'**
  String get howTo_appBarTitle;

  /// No description provided for @howTo_section1Title.
  ///
  /// In ko, this message translates to:
  /// **'1. 필수 설정'**
  String get howTo_section1Title;

  /// No description provided for @howTo_section1Subtitle.
  ///
  /// In ko, this message translates to:
  /// **'작동을 위해 필수!'**
  String get howTo_section1Subtitle;

  /// No description provided for @howTo_section1Item1.
  ///
  /// In ko, this message translates to:
  /// **'카카오톡 알림 켜기: 요약이나 삭제된 메시지 확인을 원하는 채팅방의 알림을 켜주세요.'**
  String get howTo_section1Item1;

  /// No description provided for @howTo_section1Item2.
  ///
  /// In ko, this message translates to:
  /// **'카톡 알림 형식: 카카오톡 설정 → 알림 → \'이름+메시지\' 형식으로 설정해야 내용을 인식합니다.'**
  String get howTo_section1Item2;

  /// No description provided for @howTo_section1Item3.
  ///
  /// In ko, this message translates to:
  /// **'앱 권한 허용: 앱 설정에서 \'알림 접근 허용\' 및 **\'배터리 사용량 최적화 중지\'**를 반드시 설정해 주세요.'**
  String get howTo_section1Item3;

  /// No description provided for @howTo_section2Title.
  ///
  /// In ko, this message translates to:
  /// **'2. 🔒 보안 및 개인정보 보호'**
  String get howTo_section2Title;

  /// No description provided for @howTo_section2Subtitle.
  ///
  /// In ko, this message translates to:
  /// **'안심하고 사용하세요!'**
  String get howTo_section2Subtitle;

  /// No description provided for @howTo_section2Item1.
  ///
  /// In ko, this message translates to:
  /// **'로컬 저장 방식: 모든 대화 내용은 서버가 아닌 사용자의 휴대폰(로컬)에만 저장되어 안전합니다.'**
  String get howTo_section2Item1;

  /// No description provided for @howTo_section2Item2.
  ///
  /// In ko, this message translates to:
  /// **'철저한 개인정보 마스킹: 요약 기능 사용 시, 대화에 포함된 주민등록번호, 핸드폰 번호, 이메일 등 주요 개인정보는 자동으로 마스킹(별표 처리) 후 전송됩니다.'**
  String get howTo_section2Item2;

  /// No description provided for @howTo_section2Item3.
  ///
  /// In ko, this message translates to:
  /// **'데이터 보안: 모든 통신은 HTTPS 암호화를 거치며, 서버에는 어떠한 대화 로그도 남지 않습니다.'**
  String get howTo_section2Item3;

  /// No description provided for @howTo_section2Item4.
  ///
  /// In ko, this message translates to:
  /// **'익명성 보장: 별도의 로그인을 하지 않으므로 대화 내용이 누구의 것인지 특정할 수 없어 익명성이 철저히 보장됩니다.'**
  String get howTo_section2Item4;

  /// No description provided for @howTo_section3Title.
  ///
  /// In ko, this message translates to:
  /// **'3. 채팅방 목록 관리'**
  String get howTo_section3Title;

  /// No description provided for @howTo_section3Subtitle.
  ///
  /// In ko, this message translates to:
  /// **'목록에서 길게 누르기'**
  String get howTo_section3Subtitle;

  /// No description provided for @howTo_section3Item1.
  ///
  /// In ko, this message translates to:
  /// **'AI 요약 기능 켜기/끄기: 켜두면 안 읽은 메시지가 5개 이상일 때 입장 시 자동으로 요약 영역이 선택됩니다.'**
  String get howTo_section3Item1;

  /// No description provided for @howTo_section3Item2.
  ///
  /// In ko, this message translates to:
  /// **'AI 자동 요약 설정 (Basic 전용): 설정한 메시지 개수가 쌓이면 자동으로 요약하고 푸시 알림을 보냅니다.'**
  String get howTo_section3Item2;

  /// No description provided for @howTo_section3Item3.
  ///
  /// In ko, this message translates to:
  /// **'상단 고정 / 알림 끄기: 자주 쓰는 방은 고정하고, 시끄러운 방은 앱 내에서 알림만 끌 수 있습니다.'**
  String get howTo_section3Item3;

  /// No description provided for @howTo_section3Item4.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 차단 / 삭제: 차단 시 메시지 저장을 중단하며, 삭제 시 모든 데이터(사진, 요약 등)가 소멸됩니다.'**
  String get howTo_section3Item4;

  /// No description provided for @howTo_section4Title.
  ///
  /// In ko, this message translates to:
  /// **'4. 대화방 내부 주요 기능'**
  String get howTo_section4Title;

  /// No description provided for @howTo_section4Item1.
  ///
  /// In ko, this message translates to:
  /// **'대화 요약: 오른쪽 상단의 요약하기 아이콘을 클릭하여 즉시 요약할 수 있습니다.'**
  String get howTo_section4Item1;

  /// No description provided for @howTo_section4Item2.
  ///
  /// In ko, this message translates to:
  /// **'검색 & 복사: 사용자/시간/키워드별 검색이 가능하며, 메시지를 꾹 눌러 복사할 수 있습니다.'**
  String get howTo_section4Item2;

  /// No description provided for @howTo_section4Item3.
  ///
  /// In ko, this message translates to:
  /// **'삭제된 메시지 확인: 상대방이 삭제한 메시지도 그대로 확인할 수 있습니다.'**
  String get howTo_section4Item3;

  /// No description provided for @howTo_section4Item4.
  ///
  /// In ko, this message translates to:
  /// **'주의사항: 동영상 및 여러 장 묶음 사진은 앱 내에 저장되지 않습니다.'**
  String get howTo_section4Item4;

  /// No description provided for @howTo_section5Title.
  ///
  /// In ko, this message translates to:
  /// **'5. 상세 요약 활용법'**
  String get howTo_section5Title;

  /// No description provided for @howTo_section5Item1.
  ///
  /// In ko, this message translates to:
  /// **'수동 요약: 구간 직접 선택, 숫자 입력, 혹은 말풍선 터치로 블록을 잡아 요약할 수 있습니다.'**
  String get howTo_section5Item1;

  /// No description provided for @howTo_section5Item2.
  ///
  /// In ko, this message translates to:
  /// **'요약 히스토리: [앱 설정 → 요약 관리 → 요약 히스토리]에서 과거 기록 확인 및 삭제가 가능합니다.'**
  String get howTo_section5Item2;

  /// No description provided for @howTo_section6Title.
  ///
  /// In ko, this message translates to:
  /// **'6. 요금제 및 사용량 확인'**
  String get howTo_section6Title;

  /// No description provided for @howTo_section6Subtitle.
  ///
  /// In ko, this message translates to:
  /// **'[앱 설정 → 요약 관리]에서 실시간 사용량을 확인하세요.'**
  String get howTo_section6Subtitle;

  /// No description provided for @howTo_freePlanName.
  ///
  /// In ko, this message translates to:
  /// **'무료 플랜'**
  String get howTo_freePlanName;

  /// No description provided for @howTo_basicPlanName.
  ///
  /// In ko, this message translates to:
  /// **'베이직 플랜'**
  String get howTo_basicPlanName;

  /// No description provided for @howTo_planLabelCount.
  ///
  /// In ko, this message translates to:
  /// **'요약 횟수'**
  String get howTo_planLabelCount;

  /// No description provided for @howTo_planLabelLimit.
  ///
  /// In ko, this message translates to:
  /// **'1회 요약 한도'**
  String get howTo_planLabelLimit;

  /// No description provided for @howTo_planLabelFeature.
  ///
  /// In ko, this message translates to:
  /// **'주요 특징'**
  String get howTo_planLabelFeature;

  /// No description provided for @howTo_freePlanLimitValue.
  ///
  /// In ko, this message translates to:
  /// **'5~50개'**
  String get howTo_freePlanLimitValue;

  /// No description provided for @howTo_freePlanFeatureValue.
  ///
  /// In ko, this message translates to:
  /// **'기본 요약 기능'**
  String get howTo_freePlanFeatureValue;

  /// No description provided for @howTo_basicPlanCountValue.
  ///
  /// In ko, this message translates to:
  /// **'150회 (결제일 기준 초기화)'**
  String get howTo_basicPlanCountValue;

  /// No description provided for @howTo_basicPlanLimitValue.
  ///
  /// In ko, this message translates to:
  /// **'5~200개'**
  String get howTo_basicPlanLimitValue;

  /// No description provided for @howTo_basicPlanFeatureValue.
  ///
  /// In ko, this message translates to:
  /// **'사용자가 설정한 메시지 수만큼 자동요약.\n자동요약 후 푸시 알림 제공'**
  String get howTo_basicPlanFeatureValue;

  /// No description provided for @paywall_upgradeTitle.
  ///
  /// In ko, this message translates to:
  /// **'BASIC 플랜으로 업그레이드'**
  String get paywall_upgradeTitle;

  /// No description provided for @paywall_dailyLimitReached.
  ///
  /// In ko, this message translates to:
  /// **'오늘 무료 요약 횟수를 모두 사용했어요.\nBASIC 플랜으로 계속 이용하세요.'**
  String get paywall_dailyLimitReached;

  /// No description provided for @paywall_adRechargeNotice.
  ///
  /// In ko, this message translates to:
  /// **'광고 시청 후 요약 1회가 즉시 충전됩니다'**
  String get paywall_adRechargeNotice;

  /// No description provided for @paywall_defaultSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'더 많은 메시지를 분석하고 스마트하게 관리하세요'**
  String get paywall_defaultSubtitle;

  /// No description provided for @paywall_later.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get paywall_later;

  /// No description provided for @subscriptionRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get subscriptionRetry;

  /// No description provided for @subscriptionIapUnavailable.
  ///
  /// In ko, this message translates to:
  /// **'인앱 결제를 사용할 수 없습니다.'**
  String get subscriptionIapUnavailable;

  /// No description provided for @subscriptionPurchaseInProgress.
  ///
  /// In ko, this message translates to:
  /// **'구매가 진행 중입니다. 완료되면 플랜이 자동으로 활성화됩니다.'**
  String get subscriptionPurchaseInProgress;

  /// No description provided for @subscriptionPurchaseStartFailed.
  ///
  /// In ko, this message translates to:
  /// **'구매 시작에 실패했습니다.'**
  String get subscriptionPurchaseStartFailed;

  /// No description provided for @subscriptionPurchaseError.
  ///
  /// In ko, this message translates to:
  /// **'구매 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'**
  String get subscriptionPurchaseError;

  /// No description provided for @subscriptionRestoreSuccess.
  ///
  /// In ko, this message translates to:
  /// **'구매가 복원되었습니다.'**
  String get subscriptionRestoreSuccess;

  /// No description provided for @subscriptionNoRestorablePurchases.
  ///
  /// In ko, this message translates to:
  /// **'복원할 구매 내역이 없습니다.'**
  String get subscriptionNoRestorablePurchases;

  /// No description provided for @subscriptionRestoreError.
  ///
  /// In ko, this message translates to:
  /// **'구매 복원 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'**
  String get subscriptionRestoreError;

  /// No description provided for @subscriptionTitle.
  ///
  /// In ko, this message translates to:
  /// **'플랜 구독'**
  String get subscriptionTitle;

  /// No description provided for @subscriptionRestore.
  ///
  /// In ko, this message translates to:
  /// **'구매 복원'**
  String get subscriptionRestore;

  /// No description provided for @subscriptionNoProducts.
  ///
  /// In ko, this message translates to:
  /// **'등록된 상품이 없습니다.'**
  String get subscriptionNoProducts;

  /// No description provided for @subscriptionCurrentPlanBadge.
  ///
  /// In ko, this message translates to:
  /// **'현재 플랜'**
  String get subscriptionCurrentPlanBadge;

  /// No description provided for @subscriptionSubscribe.
  ///
  /// In ko, this message translates to:
  /// **'구독하기'**
  String get subscriptionSubscribe;

  /// No description provided for @subscriptionBenefitNoAds.
  ///
  /// In ko, this message translates to:
  /// **'방해 광고 제거 (전면·리워드 X)'**
  String get subscriptionBenefitNoAds;

  /// No description provided for @subscriptionBenefitMonthlySummaries.
  ///
  /// In ko, this message translates to:
  /// **'월 150회 요약 가능'**
  String get subscriptionBenefitMonthlySummaries;

  /// No description provided for @subscriptionBenefitAutoSummary.
  ///
  /// In ko, this message translates to:
  /// **'자동 요약 기능 사용 가능'**
  String get subscriptionBenefitAutoSummary;

  /// No description provided for @summaryLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'요약 히스토리를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.'**
  String get summaryLoadFailed;

  /// No description provided for @summaryDeleteTitle.
  ///
  /// In ko, this message translates to:
  /// **'요약 삭제'**
  String get summaryDeleteTitle;

  /// No description provided for @summaryCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get summaryCancel;

  /// No description provided for @summaryDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get summaryDelete;

  /// No description provided for @summaryDeleteFailedRetry.
  ///
  /// In ko, this message translates to:
  /// **'삭제에 실패했습니다. 잠시 후 다시 시도해주세요.'**
  String get summaryDeleteFailedRetry;

  /// No description provided for @summaryDeleteOneConfirm.
  ///
  /// In ko, this message translates to:
  /// **'이 요약을 삭제하시겠습니까?'**
  String get summaryDeleteOneConfirm;

  /// No description provided for @summaryDeleted.
  ///
  /// In ko, this message translates to:
  /// **'요약이 삭제되었습니다.'**
  String get summaryDeleted;

  /// No description provided for @summaryDeleteFailed.
  ///
  /// In ko, this message translates to:
  /// **'삭제에 실패했습니다.'**
  String get summaryDeleteFailed;

  /// No description provided for @summaryHistoryTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 요약 히스토리'**
  String get summaryHistoryTitle;

  /// No description provided for @summaryDeselectAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 해제'**
  String get summaryDeselectAll;

  /// No description provided for @summarySelectAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 선택'**
  String get summarySelectAll;

  /// No description provided for @summaryDeleteSelected.
  ///
  /// In ko, this message translates to:
  /// **'선택 삭제'**
  String get summaryDeleteSelected;

  /// No description provided for @summaryExitSelectionMode.
  ///
  /// In ko, this message translates to:
  /// **'선택 모드 종료'**
  String get summaryExitSelectionMode;

  /// No description provided for @summaryEdit.
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get summaryEdit;

  /// No description provided for @summaryNoHistory.
  ///
  /// In ko, this message translates to:
  /// **'요약 히스토리가 없습니다'**
  String get summaryNoHistory;

  /// No description provided for @summaryNoSummaryForDate.
  ///
  /// In ko, this message translates to:
  /// **'이 날짜의 요약이 없습니다'**
  String get summaryNoSummaryForDate;

  /// No description provided for @summaryDetailLabel.
  ///
  /// In ko, this message translates to:
  /// **'상세 내용'**
  String get summaryDetailLabel;

  /// No description provided for @summaryViewDetail.
  ///
  /// In ko, this message translates to:
  /// **'상세보기'**
  String get summaryViewDetail;

  /// No description provided for @summarySelectDate.
  ///
  /// In ko, this message translates to:
  /// **'날짜 선택'**
  String get summarySelectDate;

  /// No description provided for @summaryConfirm.
  ///
  /// In ko, this message translates to:
  /// **'선택'**
  String get summaryConfirm;

  /// No description provided for @usageTitle.
  ///
  /// In ko, this message translates to:
  /// **'요약 관리'**
  String get usageTitle;

  /// No description provided for @usageRefresh.
  ///
  /// In ko, this message translates to:
  /// **'새로고침'**
  String get usageRefresh;

  /// No description provided for @usageRetry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get usageRetry;

  /// No description provided for @usageLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'사용량 정보를 불러올 수 없습니다.'**
  String get usageLoadFailed;

  /// No description provided for @usageToggleSummaryFailed.
  ///
  /// In ko, this message translates to:
  /// **'요약 기능 설정 변경에 실패했습니다.'**
  String get usageToggleSummaryFailed;

  /// No description provided for @usagePlanFree.
  ///
  /// In ko, this message translates to:
  /// **'무료 플랜'**
  String get usagePlanFree;

  /// No description provided for @usagePlanBasic.
  ///
  /// In ko, this message translates to:
  /// **'베이직 플랜'**
  String get usagePlanBasic;

  /// No description provided for @usageLimitDaily.
  ///
  /// In ko, this message translates to:
  /// **'일일 요약 제한'**
  String get usageLimitDaily;

  /// No description provided for @usageLimitMonthly.
  ///
  /// In ko, this message translates to:
  /// **'월간 요약 제한'**
  String get usageLimitMonthly;

  /// No description provided for @usageUsage.
  ///
  /// In ko, this message translates to:
  /// **'사용량'**
  String get usageUsage;

  /// No description provided for @usageStatusExceeded.
  ///
  /// In ko, this message translates to:
  /// **'초과'**
  String get usageStatusExceeded;

  /// No description provided for @usageStatusNearLimit.
  ///
  /// In ko, this message translates to:
  /// **'거의 다 사용'**
  String get usageStatusNearLimit;

  /// No description provided for @usageStatusNormal.
  ///
  /// In ko, this message translates to:
  /// **'정상'**
  String get usageStatusNormal;

  /// No description provided for @usageRemainingLabel.
  ///
  /// In ko, this message translates to:
  /// **'남은 횟수'**
  String get usageRemainingLabel;

  /// No description provided for @usageNextReset.
  ///
  /// In ko, this message translates to:
  /// **'다음 리셋'**
  String get usageNextReset;

  /// No description provided for @usageNextResetMonthly.
  ///
  /// In ko, this message translates to:
  /// **'다음 달 리셋'**
  String get usageNextResetMonthly;

  /// No description provided for @usageSummaryEnabledRooms.
  ///
  /// In ko, this message translates to:
  /// **'요약 기능 켜진 채팅방'**
  String get usageSummaryEnabledRooms;

  /// No description provided for @usageNoSummaryEnabledRooms.
  ///
  /// In ko, this message translates to:
  /// **'요약 기능이 켜진 채팅방이 없습니다'**
  String get usageNoSummaryEnabledRooms;

  /// No description provided for @usageNoRooms.
  ///
  /// In ko, this message translates to:
  /// **'채팅방이 없습니다'**
  String get usageNoRooms;

  /// No description provided for @usageUnknown.
  ///
  /// In ko, this message translates to:
  /// **'알 수 없음'**
  String get usageUnknown;

  /// No description provided for @usageRoom.
  ///
  /// In ko, this message translates to:
  /// **'채팅방'**
  String get usageRoom;

  /// No description provided for @usageSummaryHistory.
  ///
  /// In ko, this message translates to:
  /// **'요약 히스토리'**
  String get usageSummaryHistory;

  /// No description provided for @usageSummaryHistorySubtitle.
  ///
  /// In ko, this message translates to:
  /// **'이 채팅방의 요약 기록 보기'**
  String get usageSummaryHistorySubtitle;

  /// No description provided for @usageAutoSummaryFeature.
  ///
  /// In ko, this message translates to:
  /// **'자동요약'**
  String get usageAutoSummaryFeature;

  /// No description provided for @usageAutoSummary.
  ///
  /// In ko, this message translates to:
  /// **'자동 요약'**
  String get usageAutoSummary;

  /// No description provided for @usageAutoSummaryDescription.
  ///
  /// In ko, this message translates to:
  /// **'N개 메시지 쌓이면 자동으로 백그라운드 요약'**
  String get usageAutoSummaryDescription;

  /// No description provided for @usageAutoSummaryOff.
  ///
  /// In ko, this message translates to:
  /// **'자동 요약이 꺼져 있습니다'**
  String get usageAutoSummaryOff;

  /// No description provided for @usageMessageCount.
  ///
  /// In ko, this message translates to:
  /// **'메시지 개수'**
  String get usageMessageCount;

  /// No description provided for @usageCountUnit.
  ///
  /// In ko, this message translates to:
  /// **'개'**
  String get usageCountUnit;

  /// No description provided for @usageRangeMin.
  ///
  /// In ko, this message translates to:
  /// **'5개'**
  String get usageRangeMin;

  /// No description provided for @usageRangeMax.
  ///
  /// In ko, this message translates to:
  /// **'200개'**
  String get usageRangeMax;

  /// No description provided for @usageConfirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get usageConfirm;

  /// No description provided for @usageAutoSummaryBasicOnly.
  ///
  /// In ko, this message translates to:
  /// **'자동 요약 기능은 베이직 플랜에서만 사용 가능합니다.'**
  String get usageAutoSummaryBasicOnly;

  /// No description provided for @about_appBarTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 톡비서 란'**
  String get about_appBarTitle;

  /// No description provided for @about_appTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 톡비서'**
  String get about_appTitle;

  /// No description provided for @about_introDescription.
  ///
  /// In ko, this message translates to:
  /// **'AI 톡비서는 카카오톡, 라인 등의 메신저 대화를 AI로 요약해주는 스마트한 메신저 어시스턴트입니다.'**
  String get about_introDescription;

  /// No description provided for @about_featuresTitle.
  ///
  /// In ko, this message translates to:
  /// **'주요 기능'**
  String get about_featuresTitle;

  /// No description provided for @about_featureCollectTitle.
  ///
  /// In ko, this message translates to:
  /// **'메신저 대화 자동 수집'**
  String get about_featureCollectTitle;

  /// No description provided for @about_featureCollectDescription.
  ///
  /// In ko, this message translates to:
  /// **'카카오톡, 라인 등 다양한 메신저의 대화를 자동으로 수집하여 저장합니다.'**
  String get about_featureCollectDescription;

  /// No description provided for @about_featureSummaryTitle.
  ///
  /// In ko, this message translates to:
  /// **'AI 기반 대화 자동 요약'**
  String get about_featureSummaryTitle;

  /// No description provided for @about_featureSummaryDescription.
  ///
  /// In ko, this message translates to:
  /// **'강력한 AI 기술로 긴 대화 내용을 간결하고 명확하게 요약해드립니다.'**
  String get about_featureSummaryDescription;

  /// No description provided for @about_featureHistoryTitle.
  ///
  /// In ko, this message translates to:
  /// **'요약 히스토리 관리'**
  String get about_featureHistoryTitle;

  /// No description provided for @about_featureHistoryDescription.
  ///
  /// In ko, this message translates to:
  /// **'과거 요약 내역을 확인하고 관리할 수 있습니다.'**
  String get about_featureHistoryDescription;

  /// No description provided for @about_featureDeletedTitle.
  ///
  /// In ko, this message translates to:
  /// **'삭제된 메시지 보기 및 미리보기'**
  String get about_featureDeletedTitle;

  /// No description provided for @about_featureDeletedDescription.
  ///
  /// In ko, this message translates to:
  /// **'상대방이 삭제한 메시지도 확인할 수 있으며, 미리보기 기능을 제공합니다.'**
  String get about_featureDeletedDescription;

  /// No description provided for @events_appBarTitle.
  ///
  /// In ko, this message translates to:
  /// **'이벤트'**
  String get events_appBarTitle;

  /// No description provided for @events_emptyTitle.
  ///
  /// In ko, this message translates to:
  /// **'진행 중인 이벤트가 없습니다'**
  String get events_emptyTitle;

  /// No description provided for @events_emptyDescription.
  ///
  /// In ko, this message translates to:
  /// **'새 이벤트가 시작되면 여기서 알려드릴게요.'**
  String get events_emptyDescription;

  /// No description provided for @faq_appBarTitle.
  ///
  /// In ko, this message translates to:
  /// **'자주 묻는 질문'**
  String get faq_appBarTitle;

  /// No description provided for @faq_emptyTitle.
  ///
  /// In ko, this message translates to:
  /// **'등록된 질문이 없습니다'**
  String get faq_emptyTitle;

  /// No description provided for @faq_emptyDescription.
  ///
  /// In ko, this message translates to:
  /// **'준비되는 대로 여기에 표시됩니다.'**
  String get faq_emptyDescription;

  /// No description provided for @faq_categoryOther.
  ///
  /// In ko, this message translates to:
  /// **'기타'**
  String get faq_categoryOther;

  /// No description provided for @maintenance_exitApp.
  ///
  /// In ko, this message translates to:
  /// **'앱 종료'**
  String get maintenance_exitApp;

  /// No description provided for @maintenance_defaultTitle.
  ///
  /// In ko, this message translates to:
  /// **'점검 중입니다'**
  String get maintenance_defaultTitle;

  /// No description provided for @maintenance_defaultBody.
  ///
  /// In ko, this message translates to:
  /// **'더 나은 서비스를 위해 점검 중입니다.\n잠시 후 다시 이용해주세요.'**
  String get maintenance_defaultBody;

  /// No description provided for @messengerSettings_appBarTitle.
  ///
  /// In ko, this message translates to:
  /// **'메신저 관리'**
  String get messengerSettings_appBarTitle;

  /// No description provided for @messengerSettings_guide.
  ///
  /// In ko, this message translates to:
  /// **'사용할 메신저를 선택하고, 탭에 표시되는 순서를 변경할 수 있습니다.'**
  String get messengerSettings_guide;

  /// No description provided for @messengerSettings_enabledSection.
  ///
  /// In ko, this message translates to:
  /// **'활성 메신저 (드래그하여 순서 변경)'**
  String get messengerSettings_enabledSection;

  /// No description provided for @messengerSettings_disabledSection.
  ///
  /// In ko, this message translates to:
  /// **'비활성 메신저'**
  String get messengerSettings_disabledSection;

  /// No description provided for @messengerSettings_allEnabled.
  ///
  /// In ko, this message translates to:
  /// **'모든 메신저가 활성화되어 있습니다.'**
  String get messengerSettings_allEnabled;

  /// No description provided for @messengerSettings_basicRequired.
  ///
  /// In ko, this message translates to:
  /// **'Basic 플랜 필요'**
  String get messengerSettings_basicRequired;

  /// No description provided for @messengerSettings_upgradeContent.
  ///
  /// In ko, this message translates to:
  /// **'카카오톡 외 다른 메신저를 사용하려면\nBasic 플랜으로 업그레이드하세요.'**
  String get messengerSettings_upgradeContent;

  /// No description provided for @messengerSettings_cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get messengerSettings_cancel;

  /// No description provided for @messengerSettings_upgrade.
  ///
  /// In ko, this message translates to:
  /// **'업그레이드'**
  String get messengerSettings_upgrade;

  /// No description provided for @notices_appBarTitle.
  ///
  /// In ko, this message translates to:
  /// **'공지사항'**
  String get notices_appBarTitle;

  /// No description provided for @notices_emptyTitle.
  ///
  /// In ko, this message translates to:
  /// **'등록된 공지가 없습니다'**
  String get notices_emptyTitle;

  /// No description provided for @notices_emptyDescription.
  ///
  /// In ko, this message translates to:
  /// **'새 공지가 올라오면 여기서 확인할 수 있어요.'**
  String get notices_emptyDescription;

  /// No description provided for @notices_typeBanner.
  ///
  /// In ko, this message translates to:
  /// **'서비스 공지'**
  String get notices_typeBanner;

  /// No description provided for @notices_typeNotice.
  ///
  /// In ko, this message translates to:
  /// **'공지'**
  String get notices_typeNotice;

  /// No description provided for @policies_appBarTitle.
  ///
  /// In ko, this message translates to:
  /// **'정책 및 약관'**
  String get policies_appBarTitle;

  /// No description provided for @policies_emptyTitle.
  ///
  /// In ko, this message translates to:
  /// **'등록된 문서가 없습니다'**
  String get policies_emptyTitle;

  /// No description provided for @policies_externalLink.
  ///
  /// In ko, this message translates to:
  /// **'외부 링크'**
  String get policies_externalLink;

  /// No description provided for @notifList_deletedOne.
  ///
  /// In ko, this message translates to:
  /// **'알림이 삭제되었습니다.'**
  String get notifList_deletedOne;

  /// No description provided for @notifList_deleteAllTitle.
  ///
  /// In ko, this message translates to:
  /// **'모든 알림 삭제'**
  String get notifList_deleteAllTitle;

  /// No description provided for @notifList_deleteAllConfirm.
  ///
  /// In ko, this message translates to:
  /// **'모든 알림을 삭제하시겠습니까?'**
  String get notifList_deleteAllConfirm;

  /// No description provided for @notifList_cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get notifList_cancel;

  /// No description provided for @notifList_delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get notifList_delete;

  /// No description provided for @notifList_deletedAll.
  ///
  /// In ko, this message translates to:
  /// **'모든 알림이 삭제되었습니다.'**
  String get notifList_deletedAll;

  /// No description provided for @notifList_appBarTitle.
  ///
  /// In ko, this message translates to:
  /// **'자동 요약 알림'**
  String get notifList_appBarTitle;

  /// No description provided for @notifList_deleteAllTooltip.
  ///
  /// In ko, this message translates to:
  /// **'모두 삭제'**
  String get notifList_deleteAllTooltip;

  /// No description provided for @notifList_empty.
  ///
  /// In ko, this message translates to:
  /// **'저장된 자동 요약 알림이 없습니다'**
  String get notifList_empty;

  /// No description provided for @notifList_summaryNotFound.
  ///
  /// In ko, this message translates to:
  /// **'해당 요약을 찾을 수 없습니다.'**
  String get notifList_summaryNotFound;

  /// No description provided for @notifList_unknownRoom.
  ///
  /// In ko, this message translates to:
  /// **'알 수 없는 채팅방'**
  String get notifList_unknownRoom;

  /// No description provided for @popupNotice_skipToday.
  ///
  /// In ko, this message translates to:
  /// **'오늘 하루 안 보기'**
  String get popupNotice_skipToday;

  /// No description provided for @popupNotice_skipMonth.
  ///
  /// In ko, this message translates to:
  /// **'한 달 안 보기'**
  String get popupNotice_skipMonth;

  /// No description provided for @popupNotice_close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get popupNotice_close;

  /// No description provided for @ratingDialog_title.
  ///
  /// In ko, this message translates to:
  /// **'톡비서가 마음에 드시나요?'**
  String get ratingDialog_title;

  /// No description provided for @ratingDialog_message.
  ///
  /// In ko, this message translates to:
  /// **'평점 한 번이면 저희에게\n정말 큰 힘이 됩니다 🙏'**
  String get ratingDialog_message;

  /// No description provided for @ratingDialog_later.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get ratingDialog_later;

  /// No description provided for @ratingDialog_rate.
  ///
  /// In ko, this message translates to:
  /// **'평점 남기기'**
  String get ratingDialog_rate;

  /// No description provided for @updateDialog_storeOpenFailed.
  ///
  /// In ko, this message translates to:
  /// **'스토어를 열 수 없습니다.'**
  String get updateDialog_storeOpenFailed;

  /// No description provided for @updateDialog_forcedTitle.
  ///
  /// In ko, this message translates to:
  /// **'필수 업데이트'**
  String get updateDialog_forcedTitle;

  /// No description provided for @updateDialog_optionalTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 버전이 나왔어요'**
  String get updateDialog_optionalTitle;

  /// No description provided for @updateDialog_changesLabel.
  ///
  /// In ko, this message translates to:
  /// **'변경 사항'**
  String get updateDialog_changesLabel;

  /// No description provided for @updateDialog_forcedNotice.
  ///
  /// In ko, this message translates to:
  /// **'원활한 이용을 위해 최신 버전으로 업데이트해 주세요.'**
  String get updateDialog_forcedNotice;

  /// No description provided for @updateDialog_skip1Day.
  ///
  /// In ko, this message translates to:
  /// **'하루 동안 보지 않기'**
  String get updateDialog_skip1Day;

  /// No description provided for @updateDialog_skip7Days.
  ///
  /// In ko, this message translates to:
  /// **'일주일 동안 보지 않기'**
  String get updateDialog_skip7Days;

  /// No description provided for @updateDialog_later.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get updateDialog_later;

  /// No description provided for @updateDialog_updateNow.
  ///
  /// In ko, this message translates to:
  /// **'지금 업데이트'**
  String get updateDialog_updateNow;

  /// No description provided for @chatList_notifPermGranted.
  ///
  /// In ko, this message translates to:
  /// **'알림 권한이 허용되었습니다.'**
  String get chatList_notifPermGranted;

  /// No description provided for @chatList_loadFailed.
  ///
  /// In ko, this message translates to:
  /// **'대화방 목록을 불러오는데 실패했습니다.'**
  String get chatList_loadFailed;

  /// No description provided for @chatList_summaryToggleOn.
  ///
  /// In ko, this message translates to:
  /// **'AI 요약 기능 켜기'**
  String get chatList_summaryToggleOn;

  /// No description provided for @chatList_summaryToggleOff.
  ///
  /// In ko, this message translates to:
  /// **'AI 요약 기능 끄기'**
  String get chatList_summaryToggleOff;

  /// No description provided for @chatList_summaryEnabledSub.
  ///
  /// In ko, this message translates to:
  /// **'요약 기능이 활성화되어 있습니다'**
  String get chatList_summaryEnabledSub;

  /// No description provided for @chatList_summaryDisabledSub.
  ///
  /// In ko, this message translates to:
  /// **'요약 기능이 비활성화되어 있습니다'**
  String get chatList_summaryDisabledSub;

  /// No description provided for @chatList_autoSummarySetting.
  ///
  /// In ko, this message translates to:
  /// **'자동요약기능설정'**
  String get chatList_autoSummarySetting;

  /// No description provided for @chatList_autoSummaryOff.
  ///
  /// In ko, this message translates to:
  /// **'자동 요약이 꺼져 있습니다'**
  String get chatList_autoSummaryOff;

  /// No description provided for @chatList_basicOnly.
  ///
  /// In ko, this message translates to:
  /// **'BASIC 플랜에서 사용 가능'**
  String get chatList_basicOnly;

  /// No description provided for @chatList_markRead.
  ///
  /// In ko, this message translates to:
  /// **'읽음 처리'**
  String get chatList_markRead;

  /// No description provided for @chatList_pinOff.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 고정 해제'**
  String get chatList_pinOff;

  /// No description provided for @chatList_pinOn.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 상단 고정'**
  String get chatList_pinOn;

  /// No description provided for @chatList_muteOn.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 알림 켜기'**
  String get chatList_muteOn;

  /// No description provided for @chatList_muteOff.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 알림 끄기'**
  String get chatList_muteOff;

  /// No description provided for @chatList_block.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 차단'**
  String get chatList_block;

  /// No description provided for @chatList_deleteRoom.
  ///
  /// In ko, this message translates to:
  /// **'대화방 삭제'**
  String get chatList_deleteRoom;

  /// No description provided for @chatList_markAllRead.
  ///
  /// In ko, this message translates to:
  /// **'모두 읽음 처리'**
  String get chatList_markAllRead;

  /// No description provided for @chatList_appSettings.
  ///
  /// In ko, this message translates to:
  /// **'앱 설정'**
  String get chatList_appSettings;

  /// No description provided for @chatList_markReadFailed.
  ///
  /// In ko, this message translates to:
  /// **'읽음 처리에 실패했습니다.'**
  String get chatList_markReadFailed;

  /// No description provided for @chatList_allMarkedRead.
  ///
  /// In ko, this message translates to:
  /// **'모든 채팅방이 읽음 처리되었습니다.'**
  String get chatList_allMarkedRead;

  /// No description provided for @chatList_summaryOn.
  ///
  /// In ko, this message translates to:
  /// **'✨ AI 요약 기능이 켜졌습니다.'**
  String get chatList_summaryOn;

  /// No description provided for @chatList_summaryOff.
  ///
  /// In ko, this message translates to:
  /// **'AI 요약 기능이 꺼졌습니다.'**
  String get chatList_summaryOff;

  /// No description provided for @chatList_summaryToggleFailed.
  ///
  /// In ko, this message translates to:
  /// **'요약 기능 설정 변경에 실패했습니다.'**
  String get chatList_summaryToggleFailed;

  /// No description provided for @chatList_pinned.
  ///
  /// In ko, this message translates to:
  /// **'상단에 고정되었습니다.'**
  String get chatList_pinned;

  /// No description provided for @chatList_unpinned.
  ///
  /// In ko, this message translates to:
  /// **'고정이 해제되었습니다.'**
  String get chatList_unpinned;

  /// No description provided for @chatList_blockConfirm.
  ///
  /// In ko, this message translates to:
  /// **'차단'**
  String get chatList_blockConfirm;

  /// No description provided for @chatList_blockFailed.
  ///
  /// In ko, this message translates to:
  /// **'채팅방 차단에 실패했습니다.'**
  String get chatList_blockFailed;

  /// No description provided for @chatList_deleteRoomConfirm.
  ///
  /// In ko, this message translates to:
  /// **'메시지, 요약 전부 사라집니다.\n정말 삭제하시겠습니까?'**
  String get chatList_deleteRoomConfirm;

  /// No description provided for @chatList_delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get chatList_delete;

  /// No description provided for @chatList_deleteRoomFailed.
  ///
  /// In ko, this message translates to:
  /// **'대화방 삭제에 실패했습니다.'**
  String get chatList_deleteRoomFailed;

  /// No description provided for @chatList_sentEmoji.
  ///
  /// In ko, this message translates to:
  /// **'이모티콘을 보냈습니다'**
  String get chatList_sentEmoji;

  /// No description provided for @chatList_sentPhoto.
  ///
  /// In ko, this message translates to:
  /// **'사진을 보냈습니다'**
  String get chatList_sentPhoto;

  /// No description provided for @chatList_noEnabledMessengers.
  ///
  /// In ko, this message translates to:
  /// **'활성화된 메신저가 없습니다'**
  String get chatList_noEnabledMessengers;

  /// No description provided for @chatList_retry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get chatList_retry;

  /// No description provided for @chatList_noRooms.
  ///
  /// In ko, this message translates to:
  /// **'대화방이 없습니다'**
  String get chatList_noRooms;

  /// No description provided for @chatList_unknownAlias.
  ///
  /// In ko, this message translates to:
  /// **'알 수 없음'**
  String get chatList_unknownAlias;

  /// No description provided for @chatList_deviceInfoFailed.
  ///
  /// In ko, this message translates to:
  /// **'기기 정보를 가져올 수 없습니다. 앱을 재시작해주세요.'**
  String get chatList_deviceInfoFailed;

  /// No description provided for @chatList_planSelectTitle.
  ///
  /// In ko, this message translates to:
  /// **'플랜 선택 (테스트용)'**
  String get chatList_planSelectTitle;

  /// No description provided for @chatList_planSelectContent.
  ///
  /// In ko, this message translates to:
  /// **'사용할 플랜을 선택하세요.\n\n• Free: 일 3회, 메시지 최대 100개\n• Basic: 월 150회, 메시지 최대 200개'**
  String get chatList_planSelectContent;

  /// No description provided for @chatList_cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get chatList_cancel;

  /// No description provided for @chatList_planSetFailed.
  ///
  /// In ko, this message translates to:
  /// **'플랜 설정에 실패했습니다.'**
  String get chatList_planSetFailed;

  /// No description provided for @chatList_planSetError.
  ///
  /// In ko, this message translates to:
  /// **'플랜 설정 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'**
  String get chatList_planSetError;

  /// No description provided for @chatDetail_sendFailed.
  ///
  /// In ko, this message translates to:
  /// **'메시지 전송에 실패했습니다.'**
  String get chatDetail_sendFailed;

  /// No description provided for @chatDetail_sendError.
  ///
  /// In ko, this message translates to:
  /// **'메시지 전송 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'**
  String get chatDetail_sendError;

  /// No description provided for @chatDetail_leaveTitle.
  ///
  /// In ko, this message translates to:
  /// **'대화방 나가기'**
  String get chatDetail_leaveTitle;

  /// No description provided for @chatDetail_leaveConfirm.
  ///
  /// In ko, this message translates to:
  /// **'메시지, 요약 전부 사라집니다.\n나가시겠습니까?'**
  String get chatDetail_leaveConfirm;

  /// No description provided for @chatDetail_cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get chatDetail_cancel;

  /// No description provided for @chatDetail_leave.
  ///
  /// In ko, this message translates to:
  /// **'나가기'**
  String get chatDetail_leave;

  /// No description provided for @chatDetail_selectUser.
  ///
  /// In ko, this message translates to:
  /// **'사용자 선택'**
  String get chatDetail_selectUser;

  /// No description provided for @chatDetail_all.
  ///
  /// In ko, this message translates to:
  /// **'전체'**
  String get chatDetail_all;

  /// No description provided for @chatDetail_noMessagesToSummarize.
  ///
  /// In ko, this message translates to:
  /// **'요약할 메시지가 없습니다.'**
  String get chatDetail_noMessagesToSummarize;

  /// No description provided for @chatDetail_messageCountInput.
  ///
  /// In ko, this message translates to:
  /// **'메시지 개수 입력'**
  String get chatDetail_messageCountInput;

  /// No description provided for @chatDetail_countInputHint.
  ///
  /// In ko, this message translates to:
  /// **'개수 입력'**
  String get chatDetail_countInputHint;

  /// No description provided for @chatDetail_countUnit.
  ///
  /// In ko, this message translates to:
  /// **'개'**
  String get chatDetail_countUnit;

  /// No description provided for @chatDetail_confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get chatDetail_confirm;

  /// No description provided for @chatDetail_selectStart.
  ///
  /// In ko, this message translates to:
  /// **'선택 시작'**
  String get chatDetail_selectStart;

  /// No description provided for @chatDetail_selectEnd.
  ///
  /// In ko, this message translates to:
  /// **'선택 끝'**
  String get chatDetail_selectEnd;

  /// No description provided for @chatDetail_pinned.
  ///
  /// In ko, this message translates to:
  /// **'상단에 고정되었습니다.'**
  String get chatDetail_pinned;

  /// No description provided for @chatDetail_unpinned.
  ///
  /// In ko, this message translates to:
  /// **'고정이 해제되었습니다.'**
  String get chatDetail_unpinned;

  /// No description provided for @chatDetail_pinFailed.
  ///
  /// In ko, this message translates to:
  /// **'고정 설정 변경에 실패했습니다.'**
  String get chatDetail_pinFailed;

  /// No description provided for @chatDetail_summaryOn.
  ///
  /// In ko, this message translates to:
  /// **'✨ AI 요약 기능이 켜졌습니다.'**
  String get chatDetail_summaryOn;

  /// No description provided for @chatDetail_summaryOff.
  ///
  /// In ko, this message translates to:
  /// **'AI 요약 기능이 꺼졌습니다.'**
  String get chatDetail_summaryOff;

  /// No description provided for @chatDetail_summaryToggleFailed.
  ///
  /// In ko, this message translates to:
  /// **'요약 기능 설정 변경에 실패했습니다.'**
  String get chatDetail_summaryToggleFailed;

  /// No description provided for @chatDetail_leaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'대화방 나가기에 실패했습니다.'**
  String get chatDetail_leaveFailed;

  /// No description provided for @chatDetail_deleteMessage.
  ///
  /// In ko, this message translates to:
  /// **'메시지 삭제'**
  String get chatDetail_deleteMessage;

  /// No description provided for @chatDetail_summaryHistory.
  ///
  /// In ko, this message translates to:
  /// **'AI 요약 히스토리'**
  String get chatDetail_summaryHistory;

  /// No description provided for @chatDetail_messengerFallback.
  ///
  /// In ko, this message translates to:
  /// **'메신저'**
  String get chatDetail_messengerFallback;

  /// No description provided for @chatDetail_retry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get chatDetail_retry;

  /// No description provided for @chatDetail_noConversation.
  ///
  /// In ko, this message translates to:
  /// **'아직 대화가 없습니다'**
  String get chatDetail_noConversation;

  /// No description provided for @chatDetail_summaryMode.
  ///
  /// In ko, this message translates to:
  /// **'AI 요약 모드'**
  String get chatDetail_summaryMode;

  /// No description provided for @chatDetail_searchHint.
  ///
  /// In ko, this message translates to:
  /// **'대화 검색'**
  String get chatDetail_searchHint;

  /// No description provided for @chatDetail_summary.
  ///
  /// In ko, this message translates to:
  /// **'요약'**
  String get chatDetail_summary;

  /// No description provided for @chatDetail_zeroCount.
  ///
  /// In ko, this message translates to:
  /// **'0개'**
  String get chatDetail_zeroCount;

  /// No description provided for @chatDetail_noResults.
  ///
  /// In ko, this message translates to:
  /// **'결과 없음'**
  String get chatDetail_noResults;

  /// No description provided for @chatDetail_datePickerHelp.
  ///
  /// In ko, this message translates to:
  /// **'이동할 날짜 선택'**
  String get chatDetail_datePickerHelp;

  /// No description provided for @chatDetail_datePickerMove.
  ///
  /// In ko, this message translates to:
  /// **'이동'**
  String get chatDetail_datePickerMove;

  /// No description provided for @chatDetail_messageInputHint.
  ///
  /// In ko, this message translates to:
  /// **'메시지 입력'**
  String get chatDetail_messageInputHint;

  /// No description provided for @chatDetail_aiSummaryTooltip.
  ///
  /// In ko, this message translates to:
  /// **'AI 요약'**
  String get chatDetail_aiSummaryTooltip;

  /// No description provided for @chatDetail_autoSummaryBasic.
  ///
  /// In ko, this message translates to:
  /// **'자동요약 BASIC'**
  String get chatDetail_autoSummaryBasic;

  /// No description provided for @chatDetail_selectMessagesToSummarize.
  ///
  /// In ko, this message translates to:
  /// **'요약할 메시지를 선택해주세요.'**
  String get chatDetail_selectMessagesToSummarize;

  /// No description provided for @chatDetail_summaryGenFailed.
  ///
  /// In ko, this message translates to:
  /// **'요약 생성에 실패했습니다. 다시 시도해주세요.'**
  String get chatDetail_summaryGenFailed;

  /// No description provided for @chatDetail_summaryTimeout.
  ///
  /// In ko, this message translates to:
  /// **'요청 시간이 초과되었습니다. 다시 시도해주세요.'**
  String get chatDetail_summaryTimeout;

  /// No description provided for @chatDetail_summaryError.
  ///
  /// In ko, this message translates to:
  /// **'요약 요청 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'**
  String get chatDetail_summaryError;

  /// No description provided for @chatDetail_resetMidnight.
  ///
  /// In ko, this message translates to:
  /// **'내일 자정에 초기화됩니다'**
  String get chatDetail_resetMidnight;

  /// No description provided for @chatDetail_watchAdGetSummary.
  ///
  /// In ko, this message translates to:
  /// **'광고를 시청하고 무료 요약 1회 획득'**
  String get chatDetail_watchAdGetSummary;

  /// No description provided for @chatDetail_watchAdToSummarize.
  ///
  /// In ko, this message translates to:
  /// **'광고 보고 요약하기'**
  String get chatDetail_watchAdToSummarize;

  /// No description provided for @chatDetail_close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get chatDetail_close;

  /// No description provided for @chatDetail_adNotCompleted.
  ///
  /// In ko, this message translates to:
  /// **'광고 시청이 완료되지 않아 무료 요약 횟수가 추가되지 않았습니다.'**
  String get chatDetail_adNotCompleted;

  /// No description provided for @chatDetail_summaryFallbackTitle.
  ///
  /// In ko, this message translates to:
  /// **'대화 요약'**
  String get chatDetail_summaryFallbackTitle;

  /// No description provided for @chatDetail_messages.
  ///
  /// In ko, this message translates to:
  /// **'메시지'**
  String get chatDetail_messages;

  /// No description provided for @chatDetail_participants.
  ///
  /// In ko, this message translates to:
  /// **'참여자'**
  String get chatDetail_participants;

  /// No description provided for @chatDetail_duration.
  ///
  /// In ko, this message translates to:
  /// **'시간'**
  String get chatDetail_duration;

  /// No description provided for @chatDetail_detailCollapse.
  ///
  /// In ko, this message translates to:
  /// **'상세보기 접기'**
  String get chatDetail_detailCollapse;

  /// No description provided for @chatDetail_detailExpand.
  ///
  /// In ko, this message translates to:
  /// **'상세보기'**
  String get chatDetail_detailExpand;

  /// No description provided for @chatDetail_detailContent.
  ///
  /// In ko, this message translates to:
  /// **'상세 내용'**
  String get chatDetail_detailContent;

  /// No description provided for @chatDetail_timeUnderMin.
  ///
  /// In ko, this message translates to:
  /// **'1분 미만'**
  String get chatDetail_timeUnderMin;

  /// No description provided for @chatDetail_readHere.
  ///
  /// In ko, this message translates to:
  /// **'여기까지 읽었습니다'**
  String get chatDetail_readHere;

  /// No description provided for @chatDetail_linkOpenFailed.
  ///
  /// In ko, this message translates to:
  /// **'링크를 열 수 없습니다.'**
  String get chatDetail_linkOpenFailed;

  /// No description provided for @chatDetail_messageCopied.
  ///
  /// In ko, this message translates to:
  /// **'메시지가 복사되었습니다.'**
  String get chatDetail_messageCopied;

  /// No description provided for @chatDetail_copyFailed.
  ///
  /// In ko, this message translates to:
  /// **'메시지 복사에 실패했습니다.'**
  String get chatDetail_copyFailed;

  /// No description provided for @chatDetail_copyAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 복사'**
  String get chatDetail_copyAll;

  /// No description provided for @chatDetail_copyPartial.
  ///
  /// In ko, this message translates to:
  /// **'일부만 복사'**
  String get chatDetail_copyPartial;

  /// No description provided for @chatDetail_selectText.
  ///
  /// In ko, this message translates to:
  /// **'텍스트 선택'**
  String get chatDetail_selectText;

  /// No description provided for @chatDetail_dragToSelect.
  ///
  /// In ko, this message translates to:
  /// **'복사할 부분을 드래그하여 선택하세요'**
  String get chatDetail_dragToSelect;

  /// No description provided for @chatDetail_copySelected.
  ///
  /// In ko, this message translates to:
  /// **'선택 복사'**
  String get chatDetail_copySelected;

  /// No description provided for @chatDetail_delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get chatDetail_delete;

  /// No description provided for @chatDetail_selectMessages.
  ///
  /// In ko, this message translates to:
  /// **'메시지 선택'**
  String get chatDetail_selectMessages;

  /// No description provided for @chatDetail_imageLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'이미지를 불러올 수 없습니다'**
  String get chatDetail_imageLoadFailed;

  /// No description provided for @chatDetail_imageNotFound.
  ///
  /// In ko, this message translates to:
  /// **'이미지를 찾을 수 없습니다'**
  String get chatDetail_imageNotFound;

  /// No description provided for @chatDetail_imageLoadError.
  ///
  /// In ko, this message translates to:
  /// **'이미지 로드 실패'**
  String get chatDetail_imageLoadError;

  /// No description provided for @chatDetail_imageFileNotFound.
  ///
  /// In ko, this message translates to:
  /// **'이미지 파일을 찾을 수 없습니다.'**
  String get chatDetail_imageFileNotFound;

  /// No description provided for @chatDetail_imageSaved.
  ///
  /// In ko, this message translates to:
  /// **'이미지가 갤러리에 저장되었습니다.'**
  String get chatDetail_imageSaved;

  /// No description provided for @chatDetail_imageSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'이미지 저장에 실패했습니다.'**
  String get chatDetail_imageSaveFailed;

  /// No description provided for @chatDetail_imageSaveError.
  ///
  /// In ko, this message translates to:
  /// **'이미지 저장 중 오류가 발생했습니다.'**
  String get chatDetail_imageSaveError;

  /// No description provided for @chatDetail_save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get chatDetail_save;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
