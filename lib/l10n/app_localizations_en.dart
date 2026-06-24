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

  @override
  String get blocked_loadFailed => 'Failed to load blocked chats.';

  @override
  String get blocked_unblockFailed => 'Failed to unblock.';

  @override
  String get blocked_bulkUnblockTitle => 'Unblock All Selected';

  @override
  String get blocked_cancel => 'Cancel';

  @override
  String get blocked_unblock => 'Unblock';

  @override
  String get blocked_unblockTitle => 'Unblock';

  @override
  String get blocked_title => 'Blocked Chats';

  @override
  String get blocked_deselectAll => 'Deselect All';

  @override
  String get blocked_selectAll => 'Select All';

  @override
  String get blocked_unblockSelected => 'Unblock selected';

  @override
  String get blocked_exitSelectionMode => 'Exit selection mode';

  @override
  String get blocked_edit => 'Edit';

  @override
  String get blocked_retry => 'Retry';

  @override
  String get blocked_emptyMessage => 'No blocked chats.';

  @override
  String get guideSkip => 'Skip';

  @override
  String get guideStart => 'Get started';

  @override
  String get guideNext => 'Next';

  @override
  String get guideNotifTitle => 'Messenger notification setup';

  @override
  String get guideNotifSubtitle =>
      'To read messages accurately,\nplease set it up as shown below';

  @override
  String get guideNotifSettingPath =>
      'Messenger Settings → Notifications → Notification display → Notification content\nSet to \"Name + Message\"';

  @override
  String get guideMockSenderBoss => 'Manager';

  @override
  String get guideMockTimePm559 => '5:59 PM';

  @override
  String get guideMockBossMessage =>
      'Kim, write up the report for the CEO and send it before you leave today.';

  @override
  String get guideMockNotifHint =>
      'When a message arrives, it should appear\nin the notification bar at the top of your phone, as in the screenshot above.';

  @override
  String get guideSummaryTitle => 'AI conversation summary';

  @override
  String get guideSummarySubtitle =>
      'Grasp even long conversations at a glance';

  @override
  String get guideSummaryRoomName => 'AI Chat Assistant Subscribers Group';

  @override
  String get guideSummaryBadge => 'AI summary';

  @override
  String get guideSummaryCardTitle => 'How to use the AI Chat Assistant';

  @override
  String get guideStatMessagesValue => '5';

  @override
  String get guideStatMessagesLabel => 'Messages';

  @override
  String get guideStatParticipantsValue => '5';

  @override
  String get guideStatParticipantsLabel => 'Participants';

  @override
  String get guideStatDurationValue => '8 min';

  @override
  String get guideStatDurationLabel => 'Duration';

  @override
  String get guideSummaryContent =>
      'Members are sharing how to use the AI Chat Assistant, and talking about how the summary feature is so convenient that it has greatly reduced their stress.';

  @override
  String get guideSummaryHint => 'Tap the summary button in a chat room';

  @override
  String get guideDeletedTitle => 'Restore deleted messages';

  @override
  String get guideDeletedSubtitle =>
      'You can view deleted messages\nand preview messages without the other person knowing.';

  @override
  String get guideChatBoss => 'Manager,';

  @override
  String get guideChatDeleted => 'This message was deleted.';

  @override
  String get guideAiAssistantBadge => 'AI Chat Assistant';

  @override
  String get guideChatRestored => 'This is so annoying!!!';

  @override
  String get guideDeletedExplain1 =>
      'From now on you can view deleted messages,';

  @override
  String get guideDeletedExplain2 =>
      'and preview messages without the other person knowing.';

  @override
  String get howTo_appBarTitle => 'AI Talk Assistant Guide';

  @override
  String get howTo_section1Title => '1. Required Settings';

  @override
  String get howTo_section1Subtitle => 'Essential for it to work!';

  @override
  String get howTo_section1Item1 =>
      'Turn on messenger notifications: Enable notifications for the chat rooms where you want summaries or to check deleted messages.';

  @override
  String get howTo_section1Item2 =>
      'Notification format: In your messenger settings, set Notifications to the \'name + message\' format so the content can be recognized.';

  @override
  String get howTo_section1Item3 =>
      'Allow app permissions: In the app settings, be sure to enable \'Notification access\' and **\'Disable battery optimization\'**.';

  @override
  String get howTo_section2Title => '2. 🔒 Security & Privacy';

  @override
  String get howTo_section2Subtitle => 'Use it with peace of mind!';

  @override
  String get howTo_section2Item1 =>
      'Local storage: All conversations are stored only on your phone (locally), not on a server, keeping them safe.';

  @override
  String get howTo_section2Item2 =>
      'Thorough personal data masking: When using the summary feature, key personal information in the conversation such as ID numbers, phone numbers, and emails is automatically masked (with asterisks) before being sent.';

  @override
  String get howTo_section2Item3 =>
      'Data security: All communication is HTTPS-encrypted, and no conversation logs remain on the server.';

  @override
  String get howTo_section2Item4 =>
      'Anonymity guaranteed: Since no separate login is required, conversations cannot be tied to anyone, so your anonymity is thoroughly protected.';

  @override
  String get howTo_section3Title => '3. Managing the Chat List';

  @override
  String get howTo_section3Subtitle => 'Long-press in the list';

  @override
  String get howTo_section3Item1 =>
      'Turn AI summary on/off: When on, the summary area is automatically selected on entry if there are 5 or more unread messages.';

  @override
  String get howTo_section3Item2 =>
      'AI auto-summary settings (Basic only): Once the set number of messages accumulates, it summarizes automatically and sends a push notification.';

  @override
  String get howTo_section3Item3 =>
      'Pin to top / mute: Pin the rooms you use often, and mute notifications within the app for noisy rooms.';

  @override
  String get howTo_section3Item4 =>
      'Block / delete chat rooms: Blocking stops message storage, and deleting removes all data (photos, summaries, etc.).';

  @override
  String get howTo_section4Title => '4. Key Features Inside a Chat Room';

  @override
  String get howTo_section4Item1 =>
      'Summarize conversation: Tap the Summarize icon at the top right to summarize instantly.';

  @override
  String get howTo_section4Item2 =>
      'Search & copy: Search by user, time, or keyword, and long-press a message to copy it.';

  @override
  String get howTo_section4Item3 =>
      'Check deleted messages: You can still see messages the other person deleted, just as they were.';

  @override
  String get howTo_section4Item4 =>
      'Note: Videos and multi-photo bundles are not saved within the app.';

  @override
  String get howTo_section5Title => '5. Advanced Summary Tips';

  @override
  String get howTo_section5Item1 =>
      'Manual summary: Summarize by selecting a range directly, entering a number, or tapping a speech bubble to grab a block.';

  @override
  String get howTo_section5Item2 =>
      'Summary history: From [App Settings → Summary Management → Summary History] you can view and delete past records.';

  @override
  String get howTo_section6Title => '6. Plans & Usage';

  @override
  String get howTo_section6Subtitle =>
      'Check real-time usage in [App Settings → Summary Management].';

  @override
  String get howTo_freePlanName => 'Free Plan';

  @override
  String get howTo_basicPlanName => 'Basic Plan';

  @override
  String get howTo_planLabelCount => 'Summary count';

  @override
  String get howTo_planLabelLimit => 'Per-summary limit';

  @override
  String get howTo_planLabelFeature => 'Key features';

  @override
  String get howTo_freePlanLimitValue => '5–50 messages';

  @override
  String get howTo_freePlanFeatureValue => 'Basic summary feature';

  @override
  String get howTo_basicPlanCountValue => '150 times (resets on billing date)';

  @override
  String get howTo_basicPlanLimitValue => '5–200 messages';

  @override
  String get howTo_basicPlanFeatureValue =>
      'Auto-summarizes as many messages as you set.\nSends a push notification after auto-summary.';

  @override
  String get paywall_upgradeTitle => 'Upgrade to BASIC';

  @override
  String get paywall_dailyLimitReached =>
      'You\'ve used all of today\'s free summaries.\nContinue with the BASIC plan.';

  @override
  String get paywall_adRechargeNotice =>
      'One summary is recharged instantly after watching the ad';

  @override
  String get paywall_defaultSubtitle =>
      'Analyze more messages and manage them smartly';

  @override
  String get paywall_later => 'Later';

  @override
  String get subscriptionRetry => 'Try again';

  @override
  String get subscriptionIapUnavailable =>
      'In-app purchases are not available.';

  @override
  String get subscriptionPurchaseInProgress =>
      'Your purchase is in progress. Your plan will be activated automatically once it completes.';

  @override
  String get subscriptionPurchaseStartFailed => 'Failed to start the purchase.';

  @override
  String get subscriptionPurchaseError =>
      'Something went wrong during the purchase. Please try again in a moment.';

  @override
  String get subscriptionRestoreSuccess => 'Your purchase has been restored.';

  @override
  String get subscriptionNoRestorablePurchases =>
      'There are no purchases to restore.';

  @override
  String get subscriptionRestoreError =>
      'Something went wrong while restoring your purchase. Please try again in a moment.';

  @override
  String get subscriptionTitle => 'Subscribe to a Plan';

  @override
  String get subscriptionRestore => 'Restore purchases';

  @override
  String get subscriptionNoProducts => 'There are no products available.';

  @override
  String get subscriptionCurrentPlanBadge => 'Current plan';

  @override
  String get subscriptionSubscribe => 'Subscribe';

  @override
  String get subscriptionBenefitNoAds =>
      'No intrusive ads (no interstitial or rewarded ads)';

  @override
  String get subscriptionBenefitMonthlySummaries =>
      'Up to 150 summaries per month';

  @override
  String get subscriptionBenefitAutoSummary => 'Auto-summary feature available';

  @override
  String get summaryLoadFailed =>
      'Couldn\'t load the summary history. Please try again in a moment.';

  @override
  String get summaryDeleteTitle => 'Delete summary';

  @override
  String get summaryCancel => 'Cancel';

  @override
  String get summaryDelete => 'Delete';

  @override
  String get summaryDeleteFailedRetry =>
      'Deletion failed. Please try again in a moment.';

  @override
  String get summaryDeleteOneConfirm => 'Delete this summary?';

  @override
  String get summaryDeleted => 'Summary deleted.';

  @override
  String get summaryDeleteFailed => 'Deletion failed.';

  @override
  String get summaryHistoryTitle => 'AI Summary History';

  @override
  String get summaryDeselectAll => 'Deselect all';

  @override
  String get summarySelectAll => 'Select all';

  @override
  String get summaryDeleteSelected => 'Delete selected';

  @override
  String get summaryExitSelectionMode => 'Exit selection mode';

  @override
  String get summaryEdit => 'Edit';

  @override
  String get summaryNoHistory => 'No summary history';

  @override
  String get summaryNoSummaryForDate => 'No summaries for this date';

  @override
  String get summaryDetailLabel => 'Details';

  @override
  String get summaryViewDetail => 'View details';

  @override
  String get summarySelectDate => 'Select date';

  @override
  String get summaryConfirm => 'Confirm';

  @override
  String get usageTitle => 'Summary Management';

  @override
  String get usageRefresh => 'Refresh';

  @override
  String get usageRetry => 'Try Again';

  @override
  String get usageLoadFailed => 'Unable to load usage information.';

  @override
  String get usageToggleSummaryFailed =>
      'Failed to change the summary setting.';

  @override
  String get usagePlanFree => 'Free Plan';

  @override
  String get usagePlanBasic => 'Basic Plan';

  @override
  String get usageLimitDaily => 'Daily summary limit';

  @override
  String get usageLimitMonthly => 'Monthly summary limit';

  @override
  String get usageUsage => 'Usage';

  @override
  String get usageStatusExceeded => 'Exceeded';

  @override
  String get usageStatusNearLimit => 'Almost used up';

  @override
  String get usageStatusNormal => 'Normal';

  @override
  String get usageRemainingLabel => 'Remaining';

  @override
  String get usageNextReset => 'Next reset';

  @override
  String get usageNextResetMonthly => 'Next month\'s reset';

  @override
  String get usageSummaryEnabledRooms => 'Chats with summary enabled';

  @override
  String get usageNoSummaryEnabledRooms => 'No chats have summary enabled';

  @override
  String get usageNoRooms => 'No chats';

  @override
  String get usageUnknown => 'Unknown';

  @override
  String get usageRoom => 'Chat';

  @override
  String get usageSummaryHistory => 'Summary History';

  @override
  String get usageSummaryHistorySubtitle => 'View this chat\'s summary history';

  @override
  String get usageAutoSummaryFeature => 'Auto Summary';

  @override
  String get usageAutoSummary => 'Auto Summary';

  @override
  String get usageAutoSummaryDescription =>
      'Automatically summarizes in the background once N messages accumulate';

  @override
  String get usageAutoSummaryOff => 'Auto summary is off';

  @override
  String get usageMessageCount => 'Message count';

  @override
  String get usageCountUnit => '';

  @override
  String get usageRangeMin => '5';

  @override
  String get usageRangeMax => '200';

  @override
  String get usageConfirm => 'Confirm';

  @override
  String get usageAutoSummaryBasicOnly =>
      'Auto summary is available only on the Basic plan.';

  @override
  String get about_appBarTitle => 'About AI Talk Assistant';

  @override
  String get about_appTitle => 'AI Talk Assistant';

  @override
  String get about_introDescription =>
      'AI Talk Assistant is a smart messenger assistant that uses AI to summarize your messenger conversations, such as those on KakaoTalk and LINE.';

  @override
  String get about_featuresTitle => 'Key Features';

  @override
  String get about_featureCollectTitle =>
      'Automatic Messenger Conversation Collection';

  @override
  String get about_featureCollectDescription =>
      'Automatically collects and saves conversations from various messengers such as KakaoTalk and LINE.';

  @override
  String get about_featureSummaryTitle =>
      'AI-Powered Automatic Conversation Summary';

  @override
  String get about_featureSummaryDescription =>
      'Powerful AI technology summarizes long conversations concisely and clearly.';

  @override
  String get about_featureHistoryTitle => 'Summary History Management';

  @override
  String get about_featureHistoryDescription =>
      'View and manage your past summary history.';

  @override
  String get about_featureDeletedTitle => 'View Deleted Messages and Preview';

  @override
  String get about_featureDeletedDescription =>
      'View messages that the other party has deleted, with a preview feature provided.';

  @override
  String get events_appBarTitle => 'Events';

  @override
  String get events_emptyTitle => 'No events in progress';

  @override
  String get events_emptyDescription =>
      'We\'ll let you know here when a new event starts.';

  @override
  String get faq_appBarTitle => 'FAQ';

  @override
  String get faq_emptyTitle => 'No questions yet';

  @override
  String get faq_emptyDescription =>
      'They\'ll appear here as soon as they\'re ready.';

  @override
  String get faq_categoryOther => 'Other';

  @override
  String get maintenance_exitApp => 'Exit app';

  @override
  String get maintenance_defaultTitle => 'Under maintenance';

  @override
  String get maintenance_defaultBody =>
      'We\'re performing maintenance to improve our service.\nPlease try again shortly.';

  @override
  String get messengerSettings_appBarTitle => 'Manage Messengers';

  @override
  String get messengerSettings_guide =>
      'Choose the messengers to use and change the order they appear in the tabs.';

  @override
  String get messengerSettings_enabledSection =>
      'Active messengers (drag to reorder)';

  @override
  String get messengerSettings_disabledSection => 'Inactive messengers';

  @override
  String get messengerSettings_allEnabled => 'All messengers are active.';

  @override
  String get messengerSettings_basicRequired => 'Basic plan required';

  @override
  String get messengerSettings_upgradeContent =>
      'To use messengers other than KakaoTalk,\nupgrade to the Basic plan.';

  @override
  String get messengerSettings_cancel => 'Cancel';

  @override
  String get messengerSettings_upgrade => 'Upgrade';

  @override
  String get notices_appBarTitle => 'Notices';

  @override
  String get notices_emptyTitle => 'No notices yet';

  @override
  String get notices_emptyDescription =>
      'New notices will appear here when they\'re posted.';

  @override
  String get notices_typeBanner => 'Service notice';

  @override
  String get notices_typeNotice => 'Notice';

  @override
  String get policies_appBarTitle => 'Policies & Terms';

  @override
  String get policies_emptyTitle => 'No documents yet';

  @override
  String get policies_externalLink => 'External link';

  @override
  String get notifList_deletedOne => 'Notification deleted.';

  @override
  String get notifList_deleteAllTitle => 'Delete all notifications';

  @override
  String get notifList_deleteAllConfirm => 'Delete all notifications?';

  @override
  String get notifList_cancel => 'Cancel';

  @override
  String get notifList_delete => 'Delete';

  @override
  String get notifList_deletedAll => 'All notifications deleted.';

  @override
  String get notifList_appBarTitle => 'Auto-summary notifications';

  @override
  String get notifList_deleteAllTooltip => 'Delete all';

  @override
  String get notifList_empty => 'No saved auto-summary notifications';

  @override
  String get notifList_summaryNotFound => 'That summary couldn\'t be found.';

  @override
  String get notifList_unknownRoom => 'Unknown chat';

  @override
  String get popupNotice_skipToday => 'Don\'t show today';

  @override
  String get popupNotice_skipMonth => 'Don\'t show for a month';

  @override
  String get popupNotice_close => 'Close';

  @override
  String get ratingDialog_title => 'Enjoying the app?';

  @override
  String get ratingDialog_message => 'A quick rating means\nso much to us 🙏';

  @override
  String get ratingDialog_later => 'Later';

  @override
  String get ratingDialog_rate => 'Leave a rating';

  @override
  String get updateDialog_storeOpenFailed => 'Couldn\'t open the store.';

  @override
  String get updateDialog_forcedTitle => 'Required update';

  @override
  String get updateDialog_optionalTitle => 'A new version is available';

  @override
  String get updateDialog_changesLabel => 'What\'s new';

  @override
  String get updateDialog_forcedNotice =>
      'Please update to the latest version for the best experience.';

  @override
  String get updateDialog_skip1Day => 'Hide for a day';

  @override
  String get updateDialog_skip7Days => 'Hide for a week';

  @override
  String get updateDialog_later => 'Later';

  @override
  String get updateDialog_updateNow => 'Update now';
}
