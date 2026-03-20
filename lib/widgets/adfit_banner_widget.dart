import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adfit_android_view_surface.dart';

/// Kakao AdFit 배너 (Android: 공식 SDK BannerAdView / 그 외: 빈 슬롯)
class AdFitBannerWidget extends StatelessWidget {
  final String adCode;
  final double height;

  const AdFitBannerWidget({
    super.key,
    required this.adCode,
    this.height = 100,
  });

  static const String _viewType = 'com.dksw.app/adfit_banner';

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !Platform.isAndroid) {
      return SizedBox(
        height: height,
        child: Container(color: Colors.grey[100]),
      );
    }
    if (adCode.isEmpty) {
      return SizedBox(height: height, child: Container(color: Colors.grey[100]));
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: buildAdFitSurfaceAndroidView(
        viewType: _viewType,
        creationParams: <String, dynamic>{
          'clientId': adCode,
          'heightDp': height,
        },
      ),
    );
  }
}
