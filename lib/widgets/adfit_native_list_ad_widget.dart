import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adfit_android_view_surface.dart';

/// Kakao AdFit **네이티브** 광고 — 채팅 목록 중간 슬롯 전용 (Android 커스텀 레이아웃)
///
/// 세로 고정 높이 + Surface PlatformView.
class AdFitNativeListAdWidget extends StatelessWidget {
  final String adCode;

  const AdFitNativeListAdWidget({
    super.key,
    required this.adCode,
  });

  static const String _viewType = 'com.dksw.app/adfit_native_chat_list';
  /// 채팅 행(48 아바타 + 제목/본문 2줄)과 비슷한 높이 — 과도한 회색 빈 슬롯 방지
  static const double listSlotHeight = 76;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) {
      return SizedBox(
        height: listSlotHeight,
        child: Container(color: Colors.grey[100]),
      );
    }
    if (adCode.isEmpty) {
      return SizedBox(
        height: listSlotHeight,
        child: Container(color: Colors.grey[100]),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: listSlotHeight,
      child: buildAdFitSurfaceAndroidView(
        viewType: _viewType,
        creationParams: <String, dynamic>{'clientId': adCode},
      ),
    );
  }
}
