import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adfit_android_view_surface.dart';

/// 채팅 목록 **상단** Kakao AdFit 네이티브 (카드 레이아웃 · Android Surface PlatformView)
class AdFitNativeTopAdWidget extends StatelessWidget {
  final String adCode;

  const AdFitNativeTopAdWidget({
    super.key,
    required this.adCode,
  });

  static const String _viewType = 'com.dksw.app/adfit_native_top';

  /// 플랫폼 뷰 레이아웃용 고정 높이 (스폰서 줄 + 2줄 카피 + 100dp 미디어 기준)
  static const double slotHeight = 150;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) {
      return SizedBox(
        height: slotHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    if (adCode.isEmpty) {
      return SizedBox(
        height: slotHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
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
