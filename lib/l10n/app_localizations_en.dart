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

  @override
  String get chatList_notifPermGranted => 'Notification permission granted.';

  @override
  String get chatList_loadFailed => 'Failed to load the chat list.';

  @override
  String get chatList_summaryToggleOn => 'Turn on AI summary';

  @override
  String get chatList_summaryToggleOff => 'Turn off AI summary';

  @override
  String get chatList_summaryEnabledSub => 'Summary is enabled';

  @override
  String get chatList_summaryDisabledSub => 'Summary is disabled';

  @override
  String get chatList_autoSummarySetting => 'Auto-summary settings';

  @override
  String get chatList_autoSummaryOff => 'Auto-summary is off';

  @override
  String get chatList_basicOnly => 'Available on the BASIC plan';

  @override
  String get chatList_markRead => 'Mark as read';

  @override
  String get chatList_pinOff => 'Unpin chat';

  @override
  String get chatList_pinOn => 'Pin chat to top';

  @override
  String get chatList_muteOn => 'Turn on chat notifications';

  @override
  String get chatList_muteOff => 'Turn off chat notifications';

  @override
  String get chatList_block => 'Block chat';

  @override
  String get chatList_deleteRoom => 'Delete chat';

  @override
  String get chatList_markAllRead => 'Mark all as read';

  @override
  String get chatList_appSettings => 'App settings';

  @override
  String get chatList_markReadFailed => 'Failed to mark as read.';

  @override
  String get chatList_allMarkedRead => 'All chats marked as read.';

  @override
  String get chatList_summaryOn => '✨ AI summary turned on.';

  @override
  String get chatList_summaryOff => 'AI summary turned off.';

  @override
  String get chatList_summaryToggleFailed =>
      'Failed to change the summary setting.';

  @override
  String get chatList_pinned => 'Pinned to top.';

  @override
  String get chatList_unpinned => 'Unpinned.';

  @override
  String get chatList_blockConfirm => 'Block';

  @override
  String get chatList_blockFailed => 'Failed to block the chat.';

  @override
  String get chatList_deleteRoomConfirm =>
      'All messages and summaries will be lost.\nAre you sure you want to delete?';

  @override
  String get chatList_delete => 'Delete';

  @override
  String get chatList_deleteRoomFailed => 'Failed to delete the chat.';

  @override
  String get chatList_sentEmoji => 'Sent an emoticon';

  @override
  String get chatList_sentPhoto => 'Sent a photo';

  @override
  String get chatList_noEnabledMessengers => 'No active messengers';

  @override
  String get chatList_retry => 'Retry';

  @override
  String get chatList_noRooms => 'No chats';

  @override
  String get chatList_unknownAlias => 'Unknown';

  @override
  String get chatList_deviceInfoFailed =>
      'Couldn\'t get device info. Please restart the app.';

  @override
  String get chatList_planSelectTitle => 'Select plan (test)';

  @override
  String get chatList_planSelectContent =>
      'Choose a plan to use.\n\n• Free: 3/day, up to 100 messages\n• Basic: 150/month, up to 200 messages';

  @override
  String get chatList_cancel => 'Cancel';

  @override
  String get chatList_planSetFailed => 'Failed to set the plan.';

  @override
  String get chatList_planSetError =>
      'An error occurred while setting the plan. Please try again shortly.';

  @override
  String get chatDetail_sendFailed => 'Failed to send the message.';

  @override
  String get chatDetail_sendError =>
      'An error occurred while sending. Please try again shortly.';

  @override
  String get chatDetail_leaveTitle => 'Leave chat';

  @override
  String get chatDetail_leaveConfirm =>
      'All messages and summaries will be lost.\nAre you sure you want to leave?';

  @override
  String get chatDetail_cancel => 'Cancel';

  @override
  String get chatDetail_leave => 'Leave';

  @override
  String get chatDetail_selectUser => 'Select user';

  @override
  String get chatDetail_all => 'All';

  @override
  String get chatDetail_noMessagesToSummarize => 'No messages to summarize.';

  @override
  String get chatDetail_messageCountInput => 'Enter message count';

  @override
  String get chatDetail_countInputHint => 'Enter a number';

  @override
  String get chatDetail_countUnit => '';

  @override
  String get chatDetail_confirm => 'OK';

  @override
  String get chatDetail_selectStart => 'Start of selection';

  @override
  String get chatDetail_selectEnd => 'End of selection';

  @override
  String get chatDetail_pinned => 'Pinned to top.';

  @override
  String get chatDetail_unpinned => 'Unpinned.';

  @override
  String get chatDetail_pinFailed => 'Failed to change the pin setting.';

  @override
  String get chatDetail_summaryOn => '✨ AI summary turned on.';

  @override
  String get chatDetail_summaryOff => 'AI summary turned off.';

  @override
  String get chatDetail_summaryToggleFailed =>
      'Failed to change the summary setting.';

  @override
  String get chatDetail_leaveFailed => 'Failed to leave the chat.';

  @override
  String get chatDetail_deleteMessage => 'Delete messages';

  @override
  String get chatDetail_summaryHistory => 'AI summary history';

  @override
  String get chatDetail_messengerFallback => 'Messenger';

  @override
  String get chatDetail_retry => 'Retry';

  @override
  String get chatDetail_noConversation => 'No conversation yet';

  @override
  String get chatDetail_summaryMode => 'AI summary mode';

  @override
  String get chatDetail_searchHint => 'Search conversation';

  @override
  String get chatDetail_summary => 'Summarize';

  @override
  String get chatDetail_zeroCount => '0';

  @override
  String get chatDetail_noResults => 'No results';

  @override
  String get chatDetail_datePickerHelp => 'Select a date to jump to';

  @override
  String get chatDetail_datePickerMove => 'Go';

  @override
  String get chatDetail_messageInputHint => 'Type a message';

  @override
  String get chatDetail_aiSummaryTooltip => 'AI summary';

  @override
  String get chatDetail_autoSummaryBasic => 'Auto-summary BASIC';

  @override
  String get chatDetail_selectMessagesToSummarize =>
      'Please select messages to summarize.';

  @override
  String get chatDetail_summaryGenFailed =>
      'Failed to generate the summary. Please try again.';

  @override
  String get chatDetail_summaryTimeout =>
      'The request timed out. Please try again.';

  @override
  String get chatDetail_summaryError =>
      'An error occurred during the summary request. Please try again shortly.';

  @override
  String get chatDetail_resetMidnight => 'Resets at midnight tonight';

  @override
  String get chatDetail_watchAdGetSummary =>
      'Watch an ad to get 1 free summary';

  @override
  String get chatDetail_watchAdToSummarize => 'Watch ad to summarize';

  @override
  String get chatDetail_close => 'Close';

  @override
  String get chatDetail_adNotCompleted =>
      'The ad wasn\'t finished, so no free summary was added.';

  @override
  String get chatDetail_summaryFallbackTitle => 'Conversation summary';

  @override
  String get chatDetail_messages => 'Messages';

  @override
  String get chatDetail_participants => 'Participants';

  @override
  String get chatDetail_duration => 'Duration';

  @override
  String get chatDetail_detailCollapse => 'Collapse details';

  @override
  String get chatDetail_detailExpand => 'View details';

  @override
  String get chatDetail_detailContent => 'Details';

  @override
  String get chatDetail_timeUnderMin => 'Under 1 min';

  @override
  String get chatDetail_readHere => 'Read up to here';

  @override
  String get chatDetail_linkOpenFailed => 'Couldn\'t open the link.';

  @override
  String get chatDetail_messageCopied => 'Message copied.';

  @override
  String get chatDetail_copyFailed => 'Failed to copy the message.';

  @override
  String get chatDetail_copyAll => 'Copy all';

  @override
  String get chatDetail_copyPartial => 'Copy part';

  @override
  String get chatDetail_selectText => 'Select text';

  @override
  String get chatDetail_dragToSelect =>
      'Drag to select the part you want to copy';

  @override
  String get chatDetail_copySelected => 'Copy selection';

  @override
  String get chatDetail_delete => 'Delete';

  @override
  String get chatDetail_selectMessages => 'Select messages';

  @override
  String get chatDetail_imageLoadFailed => 'Couldn\'t load the image';

  @override
  String get chatDetail_imageNotFound => 'Image not found';

  @override
  String get chatDetail_imageLoadError => 'Image load failed';

  @override
  String get chatDetail_imageFileNotFound => 'Image file not found.';

  @override
  String get chatDetail_imageSaved => 'Image saved to your gallery.';

  @override
  String get chatDetail_imageSaveFailed => 'Failed to save the image.';

  @override
  String get chatDetail_imageSaveError =>
      'An error occurred while saving the image.';

  @override
  String get chatDetail_save => 'Save';

  @override
  String get chatDetail_msgDeleteFailed => 'Failed to delete the message.';

  @override
  String get settings_sectionAppNotif => 'App notifications';

  @override
  String get settings_sectionChat => 'Chat settings';

  @override
  String get settings_messengerManage => 'Manage messengers';

  @override
  String get settings_messengerManageSub =>
      'Choose messengers and change their order';

  @override
  String get settings_blockedRooms => 'Manage blocked chats';

  @override
  String get settings_blockedRoomsSub => 'Chats to exclude from summaries';

  @override
  String get settings_summaryManage => 'Summary management';

  @override
  String get settings_summaryManageSub => 'Summary usage and settings';

  @override
  String get settings_sectionSupport => 'News & Help';

  @override
  String get settings_notices => 'Notices';

  @override
  String get settings_noticesFallback => 'Check out the latest notices';

  @override
  String get settings_events => 'Events';

  @override
  String get settings_eventsFallback => 'There may be events going on';

  @override
  String get settings_faq => 'FAQ';

  @override
  String get settings_faqFallback => 'Find answers to your questions';

  @override
  String get settings_inquiry => 'Contact us';

  @override
  String get settings_inquirySub => 'Leave a question and we\'ll reply';

  @override
  String get settings_sectionNotif => 'Notifications';

  @override
  String get settings_review => 'Leave a review';

  @override
  String get settings_reviewSub => 'Your review means a lot to us';

  @override
  String get settings_share => 'Recommend to a friend';

  @override
  String get settings_shareSub => 'Share the app with friends';

  @override
  String get settings_howToUse => 'How to use the app';

  @override
  String get settings_howToUseSub => 'App usage guide';

  @override
  String get settings_about => 'About the app';

  @override
  String get settings_aboutSub => 'App intro and features';

  @override
  String get settings_policies => 'Policies & Terms';

  @override
  String get settings_policiesSub => 'Privacy policy, terms of service, etc.';

  @override
  String get settings_planBasicActive => 'On the Basic plan';

  @override
  String get settings_planBasicActiveSub =>
      'Manage subscription and view benefits';

  @override
  String get settings_planFree => 'Free plan';

  @override
  String get settings_planFreeSub => 'Upgrade to Basic to summarize more';

  @override
  String get settings_featureAutoManual =>
      '150 summaries/month (auto + manual)';

  @override
  String get settings_featureAutoPush => 'Auto-summary + push notifications';

  @override
  String get settings_featureNoAds =>
      'No intrusive ads (no interstitial/rewarded)';

  @override
  String get settings_marketingTitle => 'Receive marketing info';

  @override
  String get settings_marketingToggle => 'Get event and benefit alerts';

  @override
  String get settings_marketingToggleSub =>
      'Receive promotional info such as events (optional)';

  @override
  String get settings_playStoreOpenFailed => 'Couldn\'t open the Play Store.';

  @override
  String get settings_storeOpenFailed => 'Couldn\'t open the store.';

  @override
  String get settings_sound => 'Sound';

  @override
  String get settings_vibration => 'Vibration';

  @override
  String get settings_notifOff => 'Notifications are off';

  @override
  String get settings_soundOn => 'Sound is on';

  @override
  String get settings_soundOff => 'Sound is off';

  @override
  String get settings_vibrationOn => 'Vibration is on';

  @override
  String get settings_vibrationOff => 'Vibration is off';

  @override
  String get settings_notifPermTitle => 'Notification permission needed';

  @override
  String get settings_notifPermContent =>
      'To receive auto-summary notifications,\nnotification permission is required.\n\nPlease allow notifications in Settings.';

  @override
  String get settings_cancel => 'Cancel';

  @override
  String get settings_goToSettings => 'Go to Settings';

  @override
  String get settings_autoSummaryNotif => 'Auto-summary notifications';

  @override
  String get settings_autoSummaryNotifNeedPerm =>
      'Notification permission required';

  @override
  String get settings_autoSummaryNotifOn =>
      'Get a push when auto-summary completes';

  @override
  String get settings_autoSummaryNotifOff =>
      'Auto-summary notifications are off';

  @override
  String get main_autoSummaryNotifTitle => 'Auto-summary notifications';

  @override
  String get main_autoSummaryNotifContent =>
      'Get a push notification when auto-summary completes?\n\nNotification permission is required.';

  @override
  String get main_later => 'Later';

  @override
  String get main_notifPermSnack =>
      'Notification permission is required. Please allow notifications in Settings.';

  @override
  String get main_settings => 'Settings';

  @override
  String get main_getNotif => 'Get notifications';

  @override
  String get main_updateNeeded => 'Update required';

  @override
  String get main_update => 'Update';

  @override
  String chatList_autoSummaryReach(int count) {
    return 'Auto-summarize when $count messages pile up';
  }

  @override
  String chatList_markReadCount(int count) {
    return 'Mark $count unread messages as read';
  }

  @override
  String chatList_roomNotifOn(String room) {
    return 'Notifications for $room are on.';
  }

  @override
  String chatList_roomNotifOff(String room) {
    return 'Notifications for $room are off.';
  }

  @override
  String chatList_blockConfirmMsg(String room) {
    return 'Block $room?\n\nBlocked chats are hidden from the list,\nand new messages won\'t be saved.\n\nYou can unblock from Settings > Manage blocked chats.';
  }

  @override
  String chatList_roomBlocked(String room) {
    return '$room has been blocked.';
  }

  @override
  String chatList_roomDeleted(String room) {
    return '$room has been deleted.';
  }

  @override
  String chatList_noRoomsForPkg(String name) {
    return 'No $name chats';
  }

  @override
  String chatList_planSet(String plan) {
    return 'Plan set to $plan.';
  }

  @override
  String chatDetail_msgCountNeed5(int count) {
    return 'There are $count messages. Summaries need at least 5.';
  }

  @override
  String chatDetail_countRangeHint(int max, int current) {
    return 'Up to $max (currently $current selected)';
  }

  @override
  String chatDetail_countRangeError(int max) {
    return 'Enter a number between 5 and $max.';
  }

  @override
  String chatDetail_roomNotifOff(String room) {
    return 'Notifications for $room are off.';
  }

  @override
  String chatDetail_roomNotifOn(String room) {
    return 'Notifications for $room are on.';
  }

  @override
  String chatDetail_leftRoom(String room) {
    return 'You left $room.';
  }

  @override
  String chatDetail_participantCount(int count) {
    return '$count';
  }

  @override
  String chatDetail_openMessenger(String name) {
    return 'Open $name';
  }

  @override
  String chatDetail_newMessages(int count) {
    return '$count new messages';
  }

  @override
  String chatDetail_noMsgForDate(String date) {
    return 'No messages for $date';
  }

  @override
  String chatDetail_messagesSelected(int count) {
    return '$count messages selected';
  }

  @override
  String chatDetail_summaryCount(int count) {
    return '$count summaries';
  }

  @override
  String chatDetail_totalBasic(int count) {
    return '$count total · BASIC 200';
  }

  @override
  String chatDetail_freePlanMax(int max) {
    return 'On the free plan you can summarize up to $max.';
  }

  @override
  String chatDetail_todayRemaining(int remaining) {
    return 'Remaining today: $remaining/3';
  }

  @override
  String chatDetail_msgCountValue(int count) {
    return '$count';
  }

  @override
  String chatDetail_deleteSelectedCount(int count) {
    return 'Delete $count';
  }

  @override
  String chatDetail_deletedCount(int count) {
    return '$count messages deleted.';
  }

  @override
  String chatDetail_deleteConfirmCount(int count) {
    return 'Delete the $count selected messages?';
  }

  @override
  String chatDetail_summarySubjectFallback(int count) {
    return 'Summary of $count messages';
  }

  @override
  String chatDetail_durationHm(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String chatDetail_durationH(int hours) {
    return '${hours}h';
  }

  @override
  String chatDetail_durationM(int minutes) {
    return '${minutes}m';
  }

  @override
  String settings_featureBasicMsgCap(int count) {
    return 'Summarize up to $count messages';
  }

  @override
  String settings_featureFreeLimit(int count) {
    return 'Up to $count free summaries per day';
  }

  @override
  String settings_featureFreeMsgCap(int count) {
    return 'Summarize up to $count messages';
  }

  @override
  String settings_featureAdRewards(int count) {
    return '$count provided by watching ads';
  }

  @override
  String settings_countRegistered(int count) {
    return '$count registered';
  }

  @override
  String main_updateVersionMsg(String version) {
    return 'To keep using the app,\nplease update to the latest version ($version).';
  }

  @override
  String get chatList_yesterday => 'Yesterday';

  @override
  String get chatDetail_loadFailed => 'Failed to load the conversation.';

  @override
  String get chatDetail_msgSelectedSuffix => ' messages selected';

  @override
  String chatDetail_selectedChars(int count) {
    return 'Selected: $count chars';
  }

  @override
  String chatDetail_totalChars(int count) {
    return 'Total: $count chars';
  }

  @override
  String get brand_appName => 'AI Talk Assistant';

  @override
  String get onboardMessenger_title => 'Which messengers to monitor?';

  @override
  String get onboardMessenger_subtitle =>
      'We save notifications from the messengers you pick to power summaries and deleted-message viewing. You can change this later in settings.';

  @override
  String get onboardMessenger_start => 'Get started';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String paywall_limitWithAd(int count) {
    return 'You\'ve used all your free summaries.\nWatch an ad to use it $count more times today.';
  }

  @override
  String paywall_watchAdButton(int count) {
    return 'Watch ad for a free summary ($count left today)';
  }

  @override
  String paywall_featureUnlock(String feature) {
    return '🔒  Unlock $feature';
  }

  @override
  String get paywall_benefit1Title => '150 summaries per month';

  @override
  String get paywall_benefit1Sub => 'Auto + manual, 150/month total';

  @override
  String get paywall_benefit2Title => 'Summarize up to 200 messages';

  @override
  String get paywall_benefit2Sub => 'FREE 50, BASIC 200';

  @override
  String get paywall_benefit3Title => 'Auto-summary & push alerts';

  @override
  String get paywall_benefit3Sub =>
      'Auto-analyze & notify when N messages arrive';

  @override
  String get paywall_benefit4Title => 'Remove all ads';

  @override
  String get paywall_benefit4Sub => 'No banner or interstitial ads';

  @override
  String paywall_subscribeCta(String price) {
    return 'Subscribe to BASIC';
  }

  @override
  String subscriptionCurrentPlan(String plan) {
    return 'Current plan: $plan';
  }

  @override
  String subscriptionBenefitMsgCap(int count) {
    return 'Summarize up to $count messages';
  }

  @override
  String get subscriptionLoadError => 'Failed to load product info';

  @override
  String get subscriptionRestoreFailed => 'Restore failed';
}
