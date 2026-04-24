import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 하루 1회 첫 접속 시 Google Play 인앱 평점 UI 표시.
/// 인앱 확인 다이얼로그 없이 Google 네이티브 리뷰 시트를 바로 띄운다.
class RatingPromptService {
  static const String _keyRated = 'rating_rated';
  static const String _keyLastShownDate = 'rating_last_shown_date';
  static const String _androidPackageId = 'com.dksw.app';

  static final InAppReview _review = InAppReview.instance;

  /// 평점 UI를 띄워야 하는지 여부 (이미 평가했으면 false, 아니면 매 진입마다 시도)
  static Future<bool> shouldShowToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_keyRated) ?? false) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 인앱 리뷰 시트를 바로 띄움. 장치·스토어에서 지원하지 않으면 Play Store 페이지 오픈.
  static Future<void> maybeShow() async {
    debugPrint('⭐ RatingPromptService.maybeShow() 진입');
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('⭐ 스킵 - 안드로이드 아님 (kIsWeb=$kIsWeb, isAndroid=${!kIsWeb && Platform.isAndroid})');
      return;
    }
    final canShow = await shouldShowToday();
    if (!canShow) {
      final prefs = await SharedPreferences.getInstance();
      debugPrint('⭐ 스킵 - shouldShowToday=false (rated=${prefs.getBool(_keyRated)}, lastShown=${prefs.getString(_keyLastShownDate)}, today=${_todayString()})');
      return;
    }

    await _markShownToday();
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

  /// 사용자가 평점을 완료했을 가능성이 높을 때 호출 (외부에서 필요 시)
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
