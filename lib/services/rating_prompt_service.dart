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
    final canShow = await shouldShowToday();
    if (!canShow) {
      final prefs = await SharedPreferences.getInstance();
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

  /// Google 인앱 리뷰 시트 → 안 되면 Play Store 페이지.
  static Future<void> _openPlayReviewOrStore() async {
    try {
      final available = await _review.isAvailable();
      debugPrint('⭐ InAppReview.isAvailable()=$available');
      if (available) {
        await _review.requestReview();
        debugPrint('⭐ requestReview() 호출 완료 (실제 표시 여부는 Play 쿼터 결정)');
      } else {
        debugPrint('⭐ isAvailable=false → Play Store 페이지 오픈');
        await _review.openStoreListing(appStoreId: _androidPackageId);
      }
    } catch (e) {
      debugPrint('⚠️ 인앱 평점 요청 실패: $e');
    }
  }

  /// 디버그용: 평점 노출 기록 초기화 (다음 호출 시 다시 시도)
  static Future<void> debugReset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRated);
    await prefs.remove(_keyLastShownDate);
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
