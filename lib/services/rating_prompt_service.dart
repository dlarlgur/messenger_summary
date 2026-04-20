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

  /// 오늘 평점 UI를 띄워야 하는지 여부
  static Future<bool> shouldShowToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_keyRated) ?? false) return false;
      final last = prefs.getString(_keyLastShownDate) ?? '';
      return last != _todayString();
    } catch (_) {
      return false;
    }
  }

  /// 인앱 리뷰 시트를 바로 띄움. 장치·스토어에서 지원하지 않으면 Play Store 페이지 오픈.
  static Future<void> maybeShow() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (!await shouldShowToday()) return;

    await _markShownToday();
    try {
      if (await _review.isAvailable()) {
        await _review.requestReview();
      } else {
        // 구글 플레이 서비스 쿼터 초과·미지원 단말 대응: 스토어 리스팅 직접 오픈
        await _review.openStoreListing(appStoreId: _androidPackageId);
      }
      // 요청이 실제로 노출되었는지 API가 알려주지 않으므로,
      // 일단 오늘은 다시 띄우지 않는다. 사용자가 평점을 실제로 남겼는지는
      // isAvailable()가 false로 전환되는 시점에서 마킹됨.
    } catch (e) {
      debugPrint('⚠️ 인앱 평점 요청 실패: $e');
    }
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
