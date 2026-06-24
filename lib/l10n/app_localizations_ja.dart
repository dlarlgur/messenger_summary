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

  @override
  String get blocked_loadFailed => 'ブロックしたチャットの読み込みに失敗しました。';

  @override
  String get blocked_unblockFailed => 'ブロック解除に失敗しました。';

  @override
  String get blocked_bulkUnblockTitle => '一括ブロック解除';

  @override
  String get blocked_cancel => 'キャンセル';

  @override
  String get blocked_unblock => '解除';

  @override
  String get blocked_unblockTitle => 'ブロック解除';

  @override
  String get blocked_title => 'ブロックしたチャット';

  @override
  String get blocked_deselectAll => '全て解除';

  @override
  String get blocked_selectAll => '全て選択';

  @override
  String get blocked_unblockSelected => '選択したものを解除';

  @override
  String get blocked_exitSelectionMode => '選択モードを終了';

  @override
  String get blocked_edit => '編集';

  @override
  String get blocked_retry => '再試行';

  @override
  String get blocked_emptyMessage => 'ブロックしたチャットはありません。';

  @override
  String get guideSkip => 'スキップ';

  @override
  String get guideStart => 'はじめる';

  @override
  String get guideNext => '次へ';

  @override
  String get guideNotifTitle => 'メッセンジャー通知設定';

  @override
  String get guideNotifSubtitle => 'メッセージを正確に読み取るため\n以下のように設定してください';

  @override
  String get guideNotifSettingPath =>
      'メッセンジャーの設定 → 通知 → 通知表示 → 通知内容\n「名前＋メッセージ」に設定';

  @override
  String get guideMockSenderBoss => '部長';

  @override
  String get guideMockTimePm559 => '午後5:59';

  @override
  String get guideMockBossMessage => 'キムさん、今日退勤前までに社長へ提出する報告書を作成して送ってください。';

  @override
  String get guideMockNotifHint =>
      'メッセージが届くと、上のスクリーンショットのように\nスマートフォン上部の通知バーに表示されます。';

  @override
  String get guideSummaryTitle => 'AI会話要約';

  @override
  String get guideSummarySubtitle => '長い会話もひと目で把握できます';

  @override
  String get guideSummaryRoomName => 'AIトーク秘書 購読者の集まり';

  @override
  String get guideSummaryBadge => 'AI要約';

  @override
  String get guideSummaryCardTitle => 'AIトーク秘書の使い方ガイド';

  @override
  String get guideStatMessagesValue => '5件';

  @override
  String get guideStatMessagesLabel => 'メッセージ';

  @override
  String get guideStatParticipantsValue => '5人';

  @override
  String get guideStatParticipantsLabel => '参加者';

  @override
  String get guideStatDurationValue => '8分';

  @override
  String get guideStatDurationLabel => '所要時間';

  @override
  String get guideSummaryContent =>
      'AIトーク秘書の使い方を互いに共有し、要約機能がとても便利でストレスがずっと減ったという内容を話し合っています。';

  @override
  String get guideSummaryHint => 'チャットルームで要約ボタンを押してみてください';

  @override
  String get guideDeletedTitle => '削除されたメッセージの復元';

  @override
  String get guideDeletedSubtitle =>
      '削除されたメッセージを見ることができ、\n相手に気づかれずにメッセージを先に確認できます。';

  @override
  String get guideChatBoss => '部長、';

  @override
  String get guideChatDeleted => 'メッセージが削除されました。';

  @override
  String get guideAiAssistantBadge => 'AIトーク秘書';

  @override
  String get guideChatRestored => '本当にイライラする！！！';

  @override
  String get guideDeletedExplain1 => 'これからは削除されたメッセージを見ることができ、';

  @override
  String get guideDeletedExplain2 => '相手に気づかれずにメッセージを先に確認できます。';

  @override
  String get howTo_appBarTitle => 'AIトークアシスタント 使い方ガイド';

  @override
  String get howTo_section1Title => '1. 必須設定';

  @override
  String get howTo_section1Subtitle => '動作のために必須です!';

  @override
  String get howTo_section1Item1 =>
      'メッセンジャーの通知をオンに: 要約や削除メッセージの確認をしたいチャットルームの通知をオンにしてください。';

  @override
  String get howTo_section1Item2 =>
      '通知の形式: メッセンジャーの設定 → 通知 → 「名前+メッセージ」の形式に設定すると内容を認識できます。';

  @override
  String get howTo_section1Item3 =>
      'アプリ権限の許可: アプリ設定で「通知へのアクセスを許可」および**「バッテリー最適化を停止」**を必ず設定してください。';

  @override
  String get howTo_section2Title => '2. 🔒 セキュリティとプライバシー保護';

  @override
  String get howTo_section2Subtitle => '安心してご利用ください!';

  @override
  String get howTo_section2Item1 =>
      'ローカル保存方式: すべての会話内容はサーバーではなくユーザーの端末(ローカル)にのみ保存され安全です。';

  @override
  String get howTo_section2Item2 =>
      '徹底した個人情報マスキング: 要約機能の利用時、会話に含まれる住民登録番号、携帯電話番号、メールなどの主要な個人情報は自動的にマスキング(アスタリスク処理)してから送信されます。';

  @override
  String get howTo_section2Item3 =>
      'データセキュリティ: すべての通信はHTTPS暗号化を経由し、サーバーにはいかなる会話ログも残りません。';

  @override
  String get howTo_section2Item4 =>
      '匿名性の保証: 別途のログインを行わないため、会話内容が誰のものか特定できず、匿名性が徹底的に保証されます。';

  @override
  String get howTo_section3Title => '3. チャットルーム一覧の管理';

  @override
  String get howTo_section3Subtitle => '一覧で長押し';

  @override
  String get howTo_section3Item1 =>
      'AI要約機能のオン/オフ: オンにすると、未読メッセージが5件以上のとき入室時に自動で要約エリアが選択されます。';

  @override
  String get howTo_section3Item2 =>
      'AI自動要約設定 (Basic専用): 設定したメッセージ件数が貯まると自動で要約し、プッシュ通知を送ります。';

  @override
  String get howTo_section3Item3 =>
      '上部に固定 / 通知オフ: よく使うルームは固定し、にぎやかなルームはアプリ内で通知だけオフにできます。';

  @override
  String get howTo_section3Item4 =>
      'チャットルームのブロック / 削除: ブロックするとメッセージの保存を停止し、削除するとすべてのデータ(写真、要約など)が消去されます。';

  @override
  String get howTo_section4Title => '4. チャットルーム内の主な機能';

  @override
  String get howTo_section4Item1 => '会話の要約: 右上の要約アイコンをタップすると、すぐに要約できます。';

  @override
  String get howTo_section4Item2 =>
      '検索 & コピー: ユーザー/時間/キーワード別に検索でき、メッセージを長押ししてコピーできます。';

  @override
  String get howTo_section4Item3 => '削除メッセージの確認: 相手が削除したメッセージもそのまま確認できます。';

  @override
  String get howTo_section4Item4 => '注意事項: 動画および複数枚まとめての写真はアプリ内に保存されません。';

  @override
  String get howTo_section5Title => '5. 詳細な要約の活用法';

  @override
  String get howTo_section5Item1 =>
      '手動要約: 区間を直接選択、数値を入力、または吹き出しをタップしてブロックを指定し要約できます。';

  @override
  String get howTo_section5Item2 =>
      '要約履歴: [アプリ設定 → 要約管理 → 要約履歴]で過去の記録の確認・削除ができます。';

  @override
  String get howTo_section6Title => '6. 料金プランと使用量の確認';

  @override
  String get howTo_section6Subtitle => '[アプリ設定 → 要約管理]でリアルタイムの使用量を確認してください。';

  @override
  String get howTo_freePlanName => '無料プラン';

  @override
  String get howTo_basicPlanName => 'ベーシックプラン';

  @override
  String get howTo_planLabelCount => '要約回数';

  @override
  String get howTo_planLabelLimit => '1回あたりの要約上限';

  @override
  String get howTo_planLabelFeature => '主な特徴';

  @override
  String get howTo_freePlanLimitValue => '5〜50件';

  @override
  String get howTo_freePlanFeatureValue => '基本の要約機能';

  @override
  String get howTo_basicPlanCountValue => '150回 (決済日基準でリセット)';

  @override
  String get howTo_basicPlanLimitValue => '5〜200件';

  @override
  String get howTo_basicPlanFeatureValue =>
      'ユーザーが設定したメッセージ数だけ自動要約。\n自動要約後にプッシュ通知を提供。';

  @override
  String get paywall_upgradeTitle => 'BASICプランにアップグレード';

  @override
  String get paywall_dailyLimitReached =>
      '本日の無料要約の回数をすべて使い切りました。\nBASICプランで続けてご利用ください。';

  @override
  String get paywall_adRechargeNotice => '広告の視聴後、要約1回がすぐにチャージされます';

  @override
  String get paywall_defaultSubtitle => 'より多くのメッセージを分析してスマートに管理しましょう';

  @override
  String get paywall_later => 'あとで';

  @override
  String get subscriptionRetry => '再試行';

  @override
  String get subscriptionIapUnavailable => 'アプリ内課金を利用できません。';

  @override
  String get subscriptionPurchaseInProgress =>
      '購入を処理しています。完了するとプランが自動的に有効になります。';

  @override
  String get subscriptionPurchaseStartFailed => '購入を開始できませんでした。';

  @override
  String get subscriptionPurchaseError => '購入中にエラーが発生しました。しばらくしてからもう一度お試しください。';

  @override
  String get subscriptionRestoreSuccess => '購入を復元しました。';

  @override
  String get subscriptionNoRestorablePurchases => '復元できる購入履歴がありません。';

  @override
  String get subscriptionRestoreError =>
      '購入の復元中にエラーが発生しました。しばらくしてからもう一度お試しください。';

  @override
  String get subscriptionTitle => 'プラン登録';

  @override
  String get subscriptionRestore => '購入を復元';

  @override
  String get subscriptionNoProducts => '登録された商品がありません。';

  @override
  String get subscriptionCurrentPlanBadge => '現在のプラン';

  @override
  String get subscriptionSubscribe => '登録する';

  @override
  String get subscriptionBenefitNoAds => '煩わしい広告を非表示（全面・リワード広告なし）';

  @override
  String get subscriptionBenefitMonthlySummaries => '月150回まで要約可能';

  @override
  String get subscriptionBenefitAutoSummary => '自動要約機能を利用可能';

  @override
  String get summaryLoadFailed => '要約履歴を読み込めませんでした。しばらくしてからもう一度お試しください。';

  @override
  String get summaryDeleteTitle => '要約を削除';

  @override
  String get summaryCancel => 'キャンセル';

  @override
  String get summaryDelete => '削除';

  @override
  String get summaryDeleteFailedRetry => '削除に失敗しました。しばらくしてからもう一度お試しください。';

  @override
  String get summaryDeleteOneConfirm => 'この要約を削除しますか？';

  @override
  String get summaryDeleted => '要約を削除しました。';

  @override
  String get summaryDeleteFailed => '削除に失敗しました。';

  @override
  String get summaryHistoryTitle => 'AI要約履歴';

  @override
  String get summaryDeselectAll => 'すべて解除';

  @override
  String get summarySelectAll => 'すべて選択';

  @override
  String get summaryDeleteSelected => '選択を削除';

  @override
  String get summaryExitSelectionMode => '選択モードを終了';

  @override
  String get summaryEdit => '編集';

  @override
  String get summaryNoHistory => '要約履歴がありません';

  @override
  String get summaryNoSummaryForDate => 'この日付の要約はありません';

  @override
  String get summaryDetailLabel => '詳細内容';

  @override
  String get summaryViewDetail => '詳細を見る';

  @override
  String get summarySelectDate => '日付を選択';

  @override
  String get summaryConfirm => '選択';

  @override
  String get usageTitle => '要約管理';

  @override
  String get usageRefresh => '更新';

  @override
  String get usageRetry => '再試行';

  @override
  String get usageLoadFailed => '使用量情報を読み込めませんでした。';

  @override
  String get usageToggleSummaryFailed => '要約機能の設定変更に失敗しました。';

  @override
  String get usagePlanFree => '無料プラン';

  @override
  String get usagePlanBasic => 'ベーシックプラン';

  @override
  String get usageLimitDaily => '1日の要約制限';

  @override
  String get usageLimitMonthly => '月間の要約制限';

  @override
  String get usageUsage => '使用量';

  @override
  String get usageStatusExceeded => '超過';

  @override
  String get usageStatusNearLimit => 'ほぼ使い切り';

  @override
  String get usageStatusNormal => '正常';

  @override
  String get usageRemainingLabel => '残り回数';

  @override
  String get usageNextReset => '次のリセット';

  @override
  String get usageNextResetMonthly => '翌月のリセット';

  @override
  String get usageSummaryEnabledRooms => '要約機能オンのチャット';

  @override
  String get usageNoSummaryEnabledRooms => '要約機能がオンのチャットはありません';

  @override
  String get usageNoRooms => 'チャットがありません';

  @override
  String get usageUnknown => '不明';

  @override
  String get usageRoom => 'チャット';

  @override
  String get usageSummaryHistory => '要約履歴';

  @override
  String get usageSummaryHistorySubtitle => 'このチャットの要約履歴を見る';

  @override
  String get usageAutoSummaryFeature => '自動要約';

  @override
  String get usageAutoSummary => '自動要約';

  @override
  String get usageAutoSummaryDescription => 'N件のメッセージが溜まると自動でバックグラウンド要約';

  @override
  String get usageAutoSummaryOff => '自動要約はオフです';

  @override
  String get usageMessageCount => 'メッセージ数';

  @override
  String get usageCountUnit => '件';

  @override
  String get usageRangeMin => '5件';

  @override
  String get usageRangeMax => '200件';

  @override
  String get usageConfirm => '確認';

  @override
  String get usageAutoSummaryBasicOnly => '自動要約機能はベーシックプランでのみ利用できます。';

  @override
  String get about_appBarTitle => 'AIトークアシスタントとは';

  @override
  String get about_appTitle => 'AIトークアシスタント';

  @override
  String get about_introDescription =>
      'AIトークアシスタントは、カカオトークやLINEなどのメッセンジャーの会話をAIで要約してくれるスマートなメッセンジャーアシスタントです。';

  @override
  String get about_featuresTitle => '主な機能';

  @override
  String get about_featureCollectTitle => 'メッセンジャー会話の自動収集';

  @override
  String get about_featureCollectDescription =>
      'カカオトークやLINEなど、さまざまなメッセンジャーの会話を自動で収集して保存します。';

  @override
  String get about_featureSummaryTitle => 'AIによる会話の自動要約';

  @override
  String get about_featureSummaryDescription =>
      '強力なAI技術で、長い会話の内容を簡潔かつ明確に要約します。';

  @override
  String get about_featureHistoryTitle => '要約履歴の管理';

  @override
  String get about_featureHistoryDescription => '過去の要約履歴を確認・管理できます。';

  @override
  String get about_featureDeletedTitle => '削除されたメッセージの表示とプレビュー';

  @override
  String get about_featureDeletedDescription =>
      '相手が削除したメッセージも確認でき、プレビュー機能を提供します。';

  @override
  String get events_appBarTitle => 'イベント';

  @override
  String get events_emptyTitle => '進行中のイベントはありません';

  @override
  String get events_emptyDescription => '新しいイベントが始まったらここでお知らせします。';

  @override
  String get faq_appBarTitle => 'よくある質問';

  @override
  String get faq_emptyTitle => '登録された質問はありません';

  @override
  String get faq_emptyDescription => '準備でき次第ここに表示されます。';

  @override
  String get faq_categoryOther => 'その他';

  @override
  String get maintenance_exitApp => 'アプリを終了';

  @override
  String get maintenance_defaultTitle => 'メンテナンス中です';

  @override
  String get maintenance_defaultBody =>
      'より良いサービスのためメンテナンス中です。\nしばらくしてからもう一度ご利用ください。';

  @override
  String get messengerSettings_appBarTitle => 'メッセンジャー管理';

  @override
  String get messengerSettings_guide => '使用するメッセンジャーを選択し、タブに表示される順序を変更できます。';

  @override
  String get messengerSettings_enabledSection => '有効なメッセンジャー（ドラッグして並べ替え）';

  @override
  String get messengerSettings_disabledSection => '無効なメッセンジャー';

  @override
  String get messengerSettings_allEnabled => 'すべてのメッセンジャーが有効です。';

  @override
  String get messengerSettings_basicRequired => 'Basicプランが必要です';

  @override
  String get messengerSettings_upgradeContent =>
      'カカオトーク以外のメッセンジャーを使うには\nBasicプランにアップグレードしてください。';

  @override
  String get messengerSettings_cancel => 'キャンセル';

  @override
  String get messengerSettings_upgrade => 'アップグレード';

  @override
  String get notices_appBarTitle => 'お知らせ';

  @override
  String get notices_emptyTitle => '登録されたお知らせはありません';

  @override
  String get notices_emptyDescription => '新しいお知らせが投稿されるとここで確認できます。';

  @override
  String get notices_typeBanner => 'サービスのお知らせ';

  @override
  String get notices_typeNotice => 'お知らせ';

  @override
  String get policies_appBarTitle => 'ポリシーと規約';

  @override
  String get policies_emptyTitle => '登録された文書はありません';

  @override
  String get policies_externalLink => '外部リンク';

  @override
  String get notifList_deletedOne => '通知を削除しました。';

  @override
  String get notifList_deleteAllTitle => 'すべての通知を削除';

  @override
  String get notifList_deleteAllConfirm => 'すべての通知を削除しますか？';

  @override
  String get notifList_cancel => 'キャンセル';

  @override
  String get notifList_delete => '削除';

  @override
  String get notifList_deletedAll => 'すべての通知を削除しました。';

  @override
  String get notifList_appBarTitle => '自動要約の通知';

  @override
  String get notifList_deleteAllTooltip => 'すべて削除';

  @override
  String get notifList_empty => '保存された自動要約の通知はありません';

  @override
  String get notifList_summaryNotFound => '該当する要約が見つかりませんでした。';

  @override
  String get notifList_unknownRoom => '不明なチャット';

  @override
  String get popupNotice_skipToday => '今日は表示しない';

  @override
  String get popupNotice_skipMonth => '1ヶ月表示しない';

  @override
  String get popupNotice_close => '閉じる';

  @override
  String get ratingDialog_title => 'アプリは気に入っていただけましたか？';

  @override
  String get ratingDialog_message => '評価をひとついただけると\n私たちの大きな励みになります 🙏';

  @override
  String get ratingDialog_later => 'あとで';

  @override
  String get ratingDialog_rate => '評価する';

  @override
  String get updateDialog_storeOpenFailed => 'ストアを開けませんでした。';

  @override
  String get updateDialog_forcedTitle => '必須アップデート';

  @override
  String get updateDialog_optionalTitle => '新しいバージョンがあります';

  @override
  String get updateDialog_changesLabel => '変更点';

  @override
  String get updateDialog_forcedNotice => '快適にご利用いただくため、最新バージョンにアップデートしてください。';

  @override
  String get updateDialog_skip1Day => '1日表示しない';

  @override
  String get updateDialog_skip7Days => '1週間表示しない';

  @override
  String get updateDialog_later => 'あとで';

  @override
  String get updateDialog_updateNow => '今すぐ更新';

  @override
  String get chatList_notifPermGranted => '通知の権限が許可されました。';

  @override
  String get chatList_loadFailed => 'チャット一覧の読み込みに失敗しました。';

  @override
  String get chatList_summaryToggleOn => 'AI要約をオン';

  @override
  String get chatList_summaryToggleOff => 'AI要約をオフ';

  @override
  String get chatList_summaryEnabledSub => '要約機能は有効です';

  @override
  String get chatList_summaryDisabledSub => '要約機能は無効です';

  @override
  String get chatList_autoSummarySetting => '自動要約の設定';

  @override
  String get chatList_autoSummaryOff => '自動要約はオフです';

  @override
  String get chatList_basicOnly => 'BASICプランで利用可能';

  @override
  String get chatList_markRead => '既読にする';

  @override
  String get chatList_pinOff => '固定を解除';

  @override
  String get chatList_pinOn => 'チャットを上部に固定';

  @override
  String get chatList_muteOn => 'チャット通知をオン';

  @override
  String get chatList_muteOff => 'チャット通知をオフ';

  @override
  String get chatList_block => 'チャットをブロック';

  @override
  String get chatList_deleteRoom => 'チャットを削除';

  @override
  String get chatList_markAllRead => 'すべて既読にする';

  @override
  String get chatList_appSettings => 'アプリ設定';

  @override
  String get chatList_markReadFailed => '既読にできませんでした。';

  @override
  String get chatList_allMarkedRead => 'すべてのチャットを既読にしました。';

  @override
  String get chatList_summaryOn => '✨ AI要約をオンにしました。';

  @override
  String get chatList_summaryOff => 'AI要約をオフにしました。';

  @override
  String get chatList_summaryToggleFailed => '要約機能の設定変更に失敗しました。';

  @override
  String get chatList_pinned => '上部に固定しました。';

  @override
  String get chatList_unpinned => '固定を解除しました。';

  @override
  String get chatList_blockConfirm => 'ブロック';

  @override
  String get chatList_blockFailed => 'チャットのブロックに失敗しました。';

  @override
  String get chatList_deleteRoomConfirm => 'メッセージと要約がすべて消えます。\n本当に削除しますか？';

  @override
  String get chatList_delete => '削除';

  @override
  String get chatList_deleteRoomFailed => 'チャットの削除に失敗しました。';

  @override
  String get chatList_sentEmoji => 'スタンプを送信しました';

  @override
  String get chatList_sentPhoto => '写真を送信しました';

  @override
  String get chatList_noEnabledMessengers => '有効なメッセンジャーがありません';

  @override
  String get chatList_retry => '再試行';

  @override
  String get chatList_noRooms => 'チャットがありません';

  @override
  String get chatList_unknownAlias => '不明';

  @override
  String get chatList_deviceInfoFailed => '端末情報を取得できませんでした。アプリを再起動してください。';

  @override
  String get chatList_planSelectTitle => 'プラン選択（テスト用）';

  @override
  String get chatList_planSelectContent =>
      '使用するプランを選択してください。\n\n• Free: 1日3回、メッセージ最大100件\n• Basic: 月150回、メッセージ最大200件';

  @override
  String get chatList_cancel => 'キャンセル';

  @override
  String get chatList_planSetFailed => 'プランの設定に失敗しました。';

  @override
  String get chatList_planSetError => 'プラン設定中にエラーが発生しました。しばらくしてからもう一度お試しください。';

  @override
  String get chatDetail_sendFailed => 'メッセージの送信に失敗しました。';

  @override
  String get chatDetail_sendError => 'メッセージ送信中にエラーが発生しました。しばらくしてからもう一度お試しください。';

  @override
  String get chatDetail_leaveTitle => 'チャットを退出';

  @override
  String get chatDetail_leaveConfirm => 'メッセージと要約がすべて消えます。\n退出しますか？';

  @override
  String get chatDetail_cancel => 'キャンセル';

  @override
  String get chatDetail_leave => '退出';

  @override
  String get chatDetail_selectUser => 'ユーザーを選択';

  @override
  String get chatDetail_all => 'すべて';

  @override
  String get chatDetail_noMessagesToSummarize => '要約するメッセージがありません。';

  @override
  String get chatDetail_messageCountInput => 'メッセージ数を入力';

  @override
  String get chatDetail_countInputHint => '件数を入力';

  @override
  String get chatDetail_countUnit => '件';

  @override
  String get chatDetail_confirm => '確認';

  @override
  String get chatDetail_selectStart => '選択開始';

  @override
  String get chatDetail_selectEnd => '選択終了';

  @override
  String get chatDetail_pinned => '上部に固定しました。';

  @override
  String get chatDetail_unpinned => '固定を解除しました。';

  @override
  String get chatDetail_pinFailed => '固定設定の変更に失敗しました。';

  @override
  String get chatDetail_summaryOn => '✨ AI要約をオンにしました。';

  @override
  String get chatDetail_summaryOff => 'AI要約をオフにしました。';

  @override
  String get chatDetail_summaryToggleFailed => '要約機能の設定変更に失敗しました。';

  @override
  String get chatDetail_leaveFailed => 'チャットの退出に失敗しました。';

  @override
  String get chatDetail_deleteMessage => 'メッセージを削除';

  @override
  String get chatDetail_summaryHistory => 'AI要約履歴';

  @override
  String get chatDetail_messengerFallback => 'メッセンジャー';

  @override
  String get chatDetail_retry => '再試行';

  @override
  String get chatDetail_noConversation => 'まだ会話がありません';

  @override
  String get chatDetail_summaryMode => 'AI要約モード';

  @override
  String get chatDetail_searchHint => '会話を検索';

  @override
  String get chatDetail_summary => '要約';

  @override
  String get chatDetail_zeroCount => '0件';

  @override
  String get chatDetail_noResults => '結果なし';

  @override
  String get chatDetail_datePickerHelp => '移動する日付を選択';

  @override
  String get chatDetail_datePickerMove => '移動';

  @override
  String get chatDetail_messageInputHint => 'メッセージを入力';

  @override
  String get chatDetail_aiSummaryTooltip => 'AI要約';

  @override
  String get chatDetail_autoSummaryBasic => '自動要約 BASIC';

  @override
  String get chatDetail_selectMessagesToSummarize => '要約するメッセージを選択してください。';

  @override
  String get chatDetail_summaryGenFailed => '要約の生成に失敗しました。もう一度お試しください。';

  @override
  String get chatDetail_summaryTimeout => 'リクエストがタイムアウトしました。もう一度お試しください。';

  @override
  String get chatDetail_summaryError =>
      '要約リクエスト中にエラーが発生しました。しばらくしてからもう一度お試しください。';

  @override
  String get chatDetail_resetMidnight => '明日の0時にリセットされます';

  @override
  String get chatDetail_watchAdGetSummary => '広告を視聴して無料要約を1回獲得';

  @override
  String get chatDetail_watchAdToSummarize => '広告を見て要約する';

  @override
  String get chatDetail_close => '閉じる';

  @override
  String get chatDetail_adNotCompleted => '広告の視聴が完了しなかったため、無料要約の回数は追加されませんでした。';

  @override
  String get chatDetail_summaryFallbackTitle => '会話の要約';

  @override
  String get chatDetail_messages => 'メッセージ';

  @override
  String get chatDetail_participants => '参加者';

  @override
  String get chatDetail_duration => '所要時間';

  @override
  String get chatDetail_detailCollapse => '詳細を閉じる';

  @override
  String get chatDetail_detailExpand => '詳細を見る';

  @override
  String get chatDetail_detailContent => '詳細内容';

  @override
  String get chatDetail_timeUnderMin => '1分未満';

  @override
  String get chatDetail_readHere => 'ここまで既読';

  @override
  String get chatDetail_linkOpenFailed => 'リンクを開けませんでした。';

  @override
  String get chatDetail_messageCopied => 'メッセージをコピーしました。';

  @override
  String get chatDetail_copyFailed => 'メッセージのコピーに失敗しました。';

  @override
  String get chatDetail_copyAll => 'すべてコピー';

  @override
  String get chatDetail_copyPartial => '一部だけコピー';

  @override
  String get chatDetail_selectText => 'テキストを選択';

  @override
  String get chatDetail_dragToSelect => 'コピーしたい部分をドラッグして選択してください';

  @override
  String get chatDetail_copySelected => '選択範囲をコピー';

  @override
  String get chatDetail_delete => '削除';

  @override
  String get chatDetail_selectMessages => 'メッセージを選択';

  @override
  String get chatDetail_imageLoadFailed => '画像を読み込めませんでした';

  @override
  String get chatDetail_imageNotFound => '画像が見つかりません';

  @override
  String get chatDetail_imageLoadError => '画像の読み込みに失敗';

  @override
  String get chatDetail_imageFileNotFound => '画像ファイルが見つかりません。';

  @override
  String get chatDetail_imageSaved => '画像をギャラリーに保存しました。';

  @override
  String get chatDetail_imageSaveFailed => '画像の保存に失敗しました。';

  @override
  String get chatDetail_imageSaveError => '画像の保存中にエラーが発生しました。';

  @override
  String get chatDetail_save => '保存';

  @override
  String get chatDetail_msgDeleteFailed => 'メッセージの削除に失敗しました。';
}
