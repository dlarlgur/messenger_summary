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

  @override
  String get blocked_loadFailed => '차단된 채팅방을 불러오는데 실패했습니다.';

  @override
  String get blocked_unblockFailed => '차단 해제에 실패했습니다.';

  @override
  String get blocked_bulkUnblockTitle => '차단 일괄 해제';

  @override
  String get blocked_cancel => '취소';

  @override
  String get blocked_unblock => '해제';

  @override
  String get blocked_unblockTitle => '차단 해제';

  @override
  String get blocked_title => '차단방 관리';

  @override
  String get blocked_deselectAll => '전체 해제';

  @override
  String get blocked_selectAll => '전체 선택';

  @override
  String get blocked_unblockSelected => '선택 해제';

  @override
  String get blocked_exitSelectionMode => '선택 모드 종료';

  @override
  String get blocked_edit => '편집';

  @override
  String get blocked_retry => '다시 시도';

  @override
  String get blocked_emptyMessage => '차단된 채팅방이 없습니다.';

  @override
  String get guideSkip => '건너뛰기';

  @override
  String get guideStart => '시작하기';

  @override
  String get guideNext => '다음';

  @override
  String get guideNotifTitle => '카카오톡 알림 설정';

  @override
  String get guideNotifSubtitle => '메시지를 정확히 읽으려면\n아래와 같이 설정해 주세요';

  @override
  String get guideNotifSettingPath =>
      '카카오톡 설정 → 알림 → 알림 표시 → 알림 내용\n\"이름 + 메시지\"로 설정';

  @override
  String get guideMockSenderBoss => '부장님';

  @override
  String get guideMockTimePm559 => '오후 5:59';

  @override
  String get guideMockBossMessage => '김대리 오늘 퇴근 전 까지 사장님께 드릴 보고서 작성해서 보내.';

  @override
  String get guideMockNotifHint => '톡이 오면 위 스크린샷처럼\n스마트폰 상단 알림창에 보여야 합니다.';

  @override
  String get guideSummaryTitle => 'AI 대화 요약';

  @override
  String get guideSummarySubtitle => '긴 대화도 한눈에 파악하세요';

  @override
  String get guideSummaryRoomName => 'AI 톡비서 구독자 모임';

  @override
  String get guideSummaryBadge => 'AI 요약';

  @override
  String get guideSummaryCardTitle => 'AI 톡비서 사용 방법 안내';

  @override
  String get guideStatMessagesValue => '5개';

  @override
  String get guideStatMessagesLabel => '메시지';

  @override
  String get guideStatParticipantsValue => '5명';

  @override
  String get guideStatParticipantsLabel => '참여자';

  @override
  String get guideStatDurationValue => '8분';

  @override
  String get guideStatDurationLabel => '소요시간';

  @override
  String get guideSummaryContent =>
      'AI 톡비서 사용 방법에 대해 서로 공유하며, 요약 기능이 너무 편해서 스트레스가 훨씬 줄었다는 내용을 공유하고 있습니다.';

  @override
  String get guideSummaryHint => '채팅방에서 요약 버튼을 눌러보세요';

  @override
  String get guideDeletedTitle => '삭제된 메시지 복원';

  @override
  String get guideDeletedSubtitle => '삭제된 메시지를 볼 수 있고,\n상대 몰래 메시지를 미리 볼 수 있어요.';

  @override
  String get guideChatBoss => '부장님,';

  @override
  String get guideChatDeleted => '메시지가 삭제되었습니다.';

  @override
  String get guideAiAssistantBadge => 'AI 톡비서';

  @override
  String get guideChatRestored => '완전 짜증나!!!';

  @override
  String get guideDeletedExplain1 => '이제부터 삭제된 메시지를 볼 수 있고,';

  @override
  String get guideDeletedExplain2 => '상대 몰래 메시지를 미리 볼 수 있어요.';

  @override
  String get howTo_appBarTitle => 'AI 톡비서 사용 가이드';

  @override
  String get howTo_section1Title => '1. 필수 설정';

  @override
  String get howTo_section1Subtitle => '작동을 위해 필수!';

  @override
  String get howTo_section1Item1 =>
      '카카오톡 알림 켜기: 요약이나 삭제된 메시지 확인을 원하는 채팅방의 알림을 켜주세요.';

  @override
  String get howTo_section1Item2 =>
      '카톡 알림 형식: 카카오톡 설정 → 알림 → \'이름+메시지\' 형식으로 설정해야 내용을 인식합니다.';

  @override
  String get howTo_section1Item3 =>
      '앱 권한 허용: 앱 설정에서 \'알림 접근 허용\' 및 **\'배터리 사용량 최적화 중지\'**를 반드시 설정해 주세요.';

  @override
  String get howTo_section2Title => '2. 🔒 보안 및 개인정보 보호';

  @override
  String get howTo_section2Subtitle => '안심하고 사용하세요!';

  @override
  String get howTo_section2Item1 =>
      '로컬 저장 방식: 모든 대화 내용은 서버가 아닌 사용자의 휴대폰(로컬)에만 저장되어 안전합니다.';

  @override
  String get howTo_section2Item2 =>
      '철저한 개인정보 마스킹: 요약 기능 사용 시, 대화에 포함된 주민등록번호, 핸드폰 번호, 이메일 등 주요 개인정보는 자동으로 마스킹(별표 처리) 후 전송됩니다.';

  @override
  String get howTo_section2Item3 =>
      '데이터 보안: 모든 통신은 HTTPS 암호화를 거치며, 서버에는 어떠한 대화 로그도 남지 않습니다.';

  @override
  String get howTo_section2Item4 =>
      '익명성 보장: 별도의 로그인을 하지 않으므로 대화 내용이 누구의 것인지 특정할 수 없어 익명성이 철저히 보장됩니다.';

  @override
  String get howTo_section3Title => '3. 채팅방 목록 관리';

  @override
  String get howTo_section3Subtitle => '목록에서 길게 누르기';

  @override
  String get howTo_section3Item1 =>
      'AI 요약 기능 켜기/끄기: 켜두면 안 읽은 메시지가 5개 이상일 때 입장 시 자동으로 요약 영역이 선택됩니다.';

  @override
  String get howTo_section3Item2 =>
      'AI 자동 요약 설정 (Basic 전용): 설정한 메시지 개수가 쌓이면 자동으로 요약하고 푸시 알림을 보냅니다.';

  @override
  String get howTo_section3Item3 =>
      '상단 고정 / 알림 끄기: 자주 쓰는 방은 고정하고, 시끄러운 방은 앱 내에서 알림만 끌 수 있습니다.';

  @override
  String get howTo_section3Item4 =>
      '채팅방 차단 / 삭제: 차단 시 메시지 저장을 중단하며, 삭제 시 모든 데이터(사진, 요약 등)가 소멸됩니다.';

  @override
  String get howTo_section4Title => '4. 대화방 내부 주요 기능';

  @override
  String get howTo_section4Item1 =>
      '대화 요약: 오른쪽 상단의 요약하기 아이콘을 클릭하여 즉시 요약할 수 있습니다.';

  @override
  String get howTo_section4Item2 =>
      '검색 & 복사: 사용자/시간/키워드별 검색이 가능하며, 메시지를 꾹 눌러 복사할 수 있습니다.';

  @override
  String get howTo_section4Item3 => '삭제된 메시지 확인: 상대방이 삭제한 메시지도 그대로 확인할 수 있습니다.';

  @override
  String get howTo_section4Item4 => '주의사항: 동영상 및 여러 장 묶음 사진은 앱 내에 저장되지 않습니다.';

  @override
  String get howTo_section5Title => '5. 상세 요약 활용법';

  @override
  String get howTo_section5Item1 =>
      '수동 요약: 구간 직접 선택, 숫자 입력, 혹은 말풍선 터치로 블록을 잡아 요약할 수 있습니다.';

  @override
  String get howTo_section5Item2 =>
      '요약 히스토리: [앱 설정 → 요약 관리 → 요약 히스토리]에서 과거 기록 확인 및 삭제가 가능합니다.';

  @override
  String get howTo_section6Title => '6. 요금제 및 사용량 확인';

  @override
  String get howTo_section6Subtitle => '[앱 설정 → 요약 관리]에서 실시간 사용량을 확인하세요.';

  @override
  String get howTo_freePlanName => '무료 플랜';

  @override
  String get howTo_basicPlanName => '베이직 플랜';

  @override
  String get howTo_planLabelCount => '요약 횟수';

  @override
  String get howTo_planLabelLimit => '1회 요약 한도';

  @override
  String get howTo_planLabelFeature => '주요 특징';

  @override
  String get howTo_freePlanLimitValue => '5~50개';

  @override
  String get howTo_freePlanFeatureValue => '기본 요약 기능';

  @override
  String get howTo_basicPlanCountValue => '150회 (결제일 기준 초기화)';

  @override
  String get howTo_basicPlanLimitValue => '5~200개';

  @override
  String get howTo_basicPlanFeatureValue =>
      '사용자가 설정한 메시지 수만큼 자동요약.\n자동요약 후 푸시 알림 제공';

  @override
  String get paywall_upgradeTitle => 'BASIC 플랜으로 업그레이드';

  @override
  String get paywall_dailyLimitReached =>
      '오늘 무료 요약 횟수를 모두 사용했어요.\nBASIC 플랜으로 계속 이용하세요.';

  @override
  String get paywall_adRechargeNotice => '광고 시청 후 요약 1회가 즉시 충전됩니다';

  @override
  String get paywall_defaultSubtitle => '더 많은 메시지를 분석하고 스마트하게 관리하세요';

  @override
  String get paywall_later => '나중에';

  @override
  String get subscriptionRetry => '다시 시도';

  @override
  String get subscriptionIapUnavailable => '인앱 결제를 사용할 수 없습니다.';

  @override
  String get subscriptionPurchaseInProgress =>
      '구매가 진행 중입니다. 완료되면 플랜이 자동으로 활성화됩니다.';

  @override
  String get subscriptionPurchaseStartFailed => '구매 시작에 실패했습니다.';

  @override
  String get subscriptionPurchaseError => '구매 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get subscriptionRestoreSuccess => '구매가 복원되었습니다.';

  @override
  String get subscriptionNoRestorablePurchases => '복원할 구매 내역이 없습니다.';

  @override
  String get subscriptionRestoreError => '구매 복원 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get subscriptionTitle => '플랜 구독';

  @override
  String get subscriptionRestore => '구매 복원';

  @override
  String get subscriptionNoProducts => '등록된 상품이 없습니다.';

  @override
  String get subscriptionCurrentPlanBadge => '현재 플랜';

  @override
  String get subscriptionSubscribe => '구독하기';

  @override
  String get subscriptionBenefitNoAds => '방해 광고 제거 (전면·리워드 X)';

  @override
  String get subscriptionBenefitMonthlySummaries => '월 150회 요약 가능';

  @override
  String get subscriptionBenefitAutoSummary => '자동 요약 기능 사용 가능';

  @override
  String get summaryLoadFailed => '요약 히스토리를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get summaryDeleteTitle => '요약 삭제';

  @override
  String get summaryCancel => '취소';

  @override
  String get summaryDelete => '삭제';

  @override
  String get summaryDeleteFailedRetry => '삭제에 실패했습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get summaryDeleteOneConfirm => '이 요약을 삭제하시겠습니까?';

  @override
  String get summaryDeleted => '요약이 삭제되었습니다.';

  @override
  String get summaryDeleteFailed => '삭제에 실패했습니다.';

  @override
  String get summaryHistoryTitle => 'AI 요약 히스토리';

  @override
  String get summaryDeselectAll => '전체 해제';

  @override
  String get summarySelectAll => '전체 선택';

  @override
  String get summaryDeleteSelected => '선택 삭제';

  @override
  String get summaryExitSelectionMode => '선택 모드 종료';

  @override
  String get summaryEdit => '편집';

  @override
  String get summaryNoHistory => '요약 히스토리가 없습니다';

  @override
  String get summaryNoSummaryForDate => '이 날짜의 요약이 없습니다';

  @override
  String get summaryDetailLabel => '상세 내용';

  @override
  String get summaryViewDetail => '상세보기';

  @override
  String get summarySelectDate => '날짜 선택';

  @override
  String get summaryConfirm => '선택';

  @override
  String get usageTitle => '요약 관리';

  @override
  String get usageRefresh => '새로고침';

  @override
  String get usageRetry => '다시 시도';

  @override
  String get usageLoadFailed => '사용량 정보를 불러올 수 없습니다.';

  @override
  String get usageToggleSummaryFailed => '요약 기능 설정 변경에 실패했습니다.';

  @override
  String get usagePlanFree => '무료 플랜';

  @override
  String get usagePlanBasic => '베이직 플랜';

  @override
  String get usageLimitDaily => '일일 요약 제한';

  @override
  String get usageLimitMonthly => '월간 요약 제한';

  @override
  String get usageUsage => '사용량';

  @override
  String get usageStatusExceeded => '초과';

  @override
  String get usageStatusNearLimit => '거의 다 사용';

  @override
  String get usageStatusNormal => '정상';

  @override
  String get usageRemainingLabel => '남은 횟수';

  @override
  String get usageNextReset => '다음 리셋';

  @override
  String get usageNextResetMonthly => '다음 달 리셋';

  @override
  String get usageSummaryEnabledRooms => '요약 기능 켜진 채팅방';

  @override
  String get usageNoSummaryEnabledRooms => '요약 기능이 켜진 채팅방이 없습니다';

  @override
  String get usageNoRooms => '채팅방이 없습니다';

  @override
  String get usageUnknown => '알 수 없음';

  @override
  String get usageRoom => '채팅방';

  @override
  String get usageSummaryHistory => '요약 히스토리';

  @override
  String get usageSummaryHistorySubtitle => '이 채팅방의 요약 기록 보기';

  @override
  String get usageAutoSummaryFeature => '자동요약';

  @override
  String get usageAutoSummary => '자동 요약';

  @override
  String get usageAutoSummaryDescription => 'N개 메시지 쌓이면 자동으로 백그라운드 요약';

  @override
  String get usageAutoSummaryOff => '자동 요약이 꺼져 있습니다';

  @override
  String get usageMessageCount => '메시지 개수';

  @override
  String get usageCountUnit => '개';

  @override
  String get usageRangeMin => '5개';

  @override
  String get usageRangeMax => '200개';

  @override
  String get usageConfirm => '확인';

  @override
  String get usageAutoSummaryBasicOnly => '자동 요약 기능은 베이직 플랜에서만 사용 가능합니다.';
}
