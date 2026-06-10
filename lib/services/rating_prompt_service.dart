import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/rating_dialog.dart';

/// 하루 1회 진입 시 평점 안내 다이얼로그 노출.
///
/// 흐름:
///  1. shouldShowToday() — 이미 평점 처리됐거나 오늘 이미 띄웠으면 false
///  2. 커스텀 RatingDialog ("앱이 마음에 드시나요?") 표시
///  3. 평점 남기기 → Google In-App Review 시트 시도 → 없으면 Play Store 페이지
///  4. 나중에 / X → 오늘은 미노출 (내일 다시)
class RatingPromptService {
  static const String _keyRated = 'rating_rated';
  static const String _keyLastShownDate = 'rating_last_shown_date';
  static const String _keyEntryCount = 'rating_entry_count';
  /// 평점 노출 후보가 되기 위한 최소 진입 횟수.
  /// 첫 설치 직후엔 거부감 크니까 2번째 진입부터 후보.
  static const int _minEntryCount = 2;
  static const String _androidPackageId = 'com.dksw.app';

  static final InAppReview _review = InAppReview.instance;

  /// 오늘 다이얼로그를 띄울지 결정.
  /// - 이미 평점 완료 → 영구 false
  /// - 오늘 이미 띄움 → false
  /// - 그 외 → true
  static Future<bool> shouldShowToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_keyRated) ?? false) return false;
      final lastShown = prefs.getString(_keyLastShownDate);
      if (lastShown == _todayString()) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 평점 안내 다이얼로그를 띄움. 안드로이드 외에는 no-op.
  static Future<void> maybeShow(BuildContext context) async {
    debugPrint('⭐ RatingPromptService.maybeShow() 진입');
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('⭐ 스킵 - 안드로이드 아님');
      return;
    }

    // 진입 카운터 증가 (첫 설치 직후 거부감 방지)
    final prefs = await SharedPreferences.getInstance();
    final entryCount = (prefs.getInt(_keyEntryCount) ?? 0) + 1;
    await prefs.setInt(_keyEntryCount, entryCount);
    if (entryCount < _minEntryCount) {
      debugPrint('⭐ 스킵 - 진입 횟수 부족 ($entryCount/$_minEntryCount)');
      return;
    }

    final canShow = await shouldShowToday();
    if (!canShow) {
      debugPrint(
          '⭐ 스킵 - shouldShowToday=false (rated=${prefs.getBool(_keyRated)}, lastShown=${prefs.getString(_keyLastShownDate)}, today=${_todayString()})');
      return;
    }

    await _markShownToday();
    if (!context.mounted) return;

    await RatingDialog.show(
      context: context,
      onConfirm: () async {
        debugPrint('⭐ 평점 남기기 클릭 → Play 인앱 리뷰/스토어 이동');
        await _openPlayReviewOrStore();
        await markRated();
      },
      onLater: () {
        debugPrint('⭐ 나중에 / 닫기 — 오늘은 미노출, 내일 재시도');
      },
    );
  }

  /// Google In-App Review 시트 우선 → 무반응이면 Play Store 페이지로 자동 fallback.
  ///
  /// requestReview() 는 Play Store 정식 배포본(internal/closed/open/production
  /// 트랙) + Play Services + Google 쿼터 OK 일 때 인앱 시트가 뜸. 디버그 빌드 /
  /// sideload / 쿼터 차단 시엔 무반응 + 에러도 안 남김.
  ///
  /// 무반응을 감지하기 위해 lifecycle observer 등록 후 1.5초 안에 paused/inactive
  /// 가 안 잡히면 시트가 안 뜬 것으로 간주하고 openStoreListing 으로 자동 빠짐.
  static Future<void> _openPlayReviewOrStore() async {
    // 1) lifecycle 감시 시작
    final shown = Completer<bool>();
    final observer = _SheetShownObserver(() {
      if (!shown.isCompleted) shown.complete(true);
    });
    WidgetsBinding.instance.addObserver(observer);

    try {
      // 2) 인앱 시트 시도
      try {
        await _review.requestReview();
      } catch (e) {
        debugPrint('⚠️ requestReview 호출 실패: $e');
      }

      // 3) 1.5초 안에 paused/inactive 잡히면 시트 떴거나 Play 앱 열린 것
      final wasShown = await Future.any<bool>([
        shown.future,
        Future<bool>.delayed(const Duration(milliseconds: 1500), () => false),
      ]);

      if (wasShown) {
        debugPrint('⭐ 인앱 리뷰 시트 표시됨');
        return;
      }

      // 4) 무반응 → Play Store 페이지로 fallback
      debugPrint('⭐ 인앱 시트 무반응 → Play Store 페이지 fallback');
      try {
        await _review.openStoreListing(appStoreId: _androidPackageId);
      } catch (e) {
        debugPrint('⚠️ Play Store 오픈 실패: $e');
      }
    } finally {
      WidgetsBinding.instance.removeObserver(observer);
    }
  }

  /// 디버그용: 평점 노출 기록 초기화 (다음 호출 시 다시 시도)
  static Future<void> debugReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRated);
    await prefs.remove(_keyLastShownDate);
    await prefs.remove(_keyEntryCount);
    debugPrint('⭐ debugReset 완료');
  }

  /// 사용자가 평점을 완료했을 가능성이 높을 때 호출 (영구 미노출).
  static Future<void> markRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRated, true);
  }

  static Future<void> _markShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastShownDate, _todayString());
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

/// 인앱 리뷰 시트가 떴는지(앱이 paused/inactive 됐는지) 감지하는 짧은 수명 옵저버.
class _SheetShownObserver with WidgetsBindingObserver {
  final VoidCallback onShown;
  _SheetShownObserver(this.onShown);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      onShown();
    }
  }
}
