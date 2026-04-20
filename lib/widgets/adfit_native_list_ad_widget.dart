import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adfit_android_view_surface.dart';

/// Kakao AdFit 네이티브 — 채팅 목록 중간 슬롯.
///
/// SurfaceAndroidView(Hybrid Composition)는 Flutter가 준 높이 제약 안에서만
/// Android가 렌더링한다. 따라서 레이아웃 구조를 계산한 충분한 고정 높이를 사용한다.
///
/// 본문 1줄 말줄임 기준: 패딩 + max(44 아바타, 제목·광고줄·본문) + 약간 여유.
class AdFitNativeListAdWidget extends StatelessWidget {
  final String adCode;

  const AdFitNativeListAdWidget({
    super.key,
    required this.adCode,
  });

  static const String _viewType = 'com.dksw.app/adfit_native_chat_list';

  /// 1줄 본문 기준 타이트 높이 (아래 빈 여백 최소화)
  static const double slotHeight = 84;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) {
      return SizedBox(height: slotHeight, child: Container(color: Colors.grey[100]));
    }
    if (adCode.isEmpty) {
      return SizedBox(height: slotHeight, child: Container(color: Colors.grey[100]));
    }

    return SizedBox(
      width: double.infinity,
      height: slotHeight,
      child: buildAdFitSurfaceAndroidView(
        viewType: _viewType,
        creationParams: <String, dynamic>{'clientId': adCode},
      ),
    );
  }
}
