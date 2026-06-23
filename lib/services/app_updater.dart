import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

/// 인앱 업데이트 결과.
enum InAppUpdateResult { started, notAvailable, unsupported, error }

/// 구글 플레이 인앱 업데이트 래퍼 (Android 전용).
/// 비안드로이드/실패 시 [InAppUpdateResult.unsupported] 등을 반환해
/// 호출부가 커스텀 다이얼로그로 폴백할 수 있게 한다.
class AppUpdater {
  AppUpdater._();

  static Future<InAppUpdateResult> tryImmediateUpdate() async {
    if (!Platform.isAndroid) return InAppUpdateResult.unsupported;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return InAppUpdateResult.notAvailable;
      }
      if (info.immediateUpdateAllowed != true) {
        return InAppUpdateResult.notAvailable;
      }
      await InAppUpdate.performImmediateUpdate();
      return InAppUpdateResult.started;
    } catch (e) {
      debugPrint('[AppUpdater] immediate 실패: $e');
      return InAppUpdateResult.error;
    }
  }

  static Future<InAppUpdateResult> tryFlexibleUpdate() async {
    if (!Platform.isAndroid) return InAppUpdateResult.unsupported;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return InAppUpdateResult.notAvailable;
      }
      if (info.flexibleUpdateAllowed != true) {
        return InAppUpdateResult.notAvailable;
      }
      await InAppUpdate.startFlexibleUpdate();
      InAppUpdate.completeFlexibleUpdate();
      return InAppUpdateResult.started;
    } catch (e) {
      debugPrint('[AppUpdater] flexible 실패: $e');
      return InAppUpdateResult.error;
    }
  }
}
