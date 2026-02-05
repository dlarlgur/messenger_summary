import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_version_service.dart';

/// 앱 업데이트 다이얼로그
class UpdateDialog extends StatelessWidget {
  final VersionCheckResult versionResult;
  final VoidCallback? onLater;

  const UpdateDialog({
    super.key,
    required this.versionResult,
    this.onLater,
  });

  /// 업데이트 다이얼로그 표시
  static Future<void> show(
    BuildContext context,
    VersionCheckResult versionResult, {
    VoidCallback? onLater,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: versionResult.updateType != UpdateType.force,
      builder: (context) => UpdateDialog(
        versionResult: versionResult,
        onLater: onLater,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isForceUpdate = versionResult.updateType == UpdateType.force;

    return PopScope(
      canPop: !isForceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              isForceUpdate ? Icons.warning_amber_rounded : Icons.system_update,
              color: isForceUpdate ? Colors.orange : Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              isForceUpdate ? '업데이트 필요' : '새 버전 출시',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isForceUpdate
                  ? '앱을 계속 사용하려면 최신 버전으로 업데이트해 주세요.'
                  : '더 나은 서비스를 위해 새 버전이 출시되었습니다.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildVersionInfo(),
            if (versionResult.releaseNote != null &&
                versionResult.releaseNote!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '업데이트 내용',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(
                    versionResult.releaseNote!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!isForceUpdate)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onLater?.call();
              },
              child: Text(
                '나중에',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ElevatedButton(
            onPressed: () => _openStore(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('업데이트'),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '최신 버전',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                versionResult.latestVersion ?? '-',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          if (versionResult.updateType == UpdateType.force)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '최소 버전',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  versionResult.minVersion ?? '-',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _openStore(BuildContext context) async {
    final storeUrl = versionResult.storeUrl;
    if (storeUrl == null || storeUrl.isEmpty) {
      // 스토어 URL이 없으면 기본 URL 사용
      final defaultUrl = Platform.isAndroid
          ? 'https://play.google.com/store/apps/details?id=com.dksw.app'
          : 'https://apps.apple.com/app/id0000000000';

      final uri = Uri.parse(defaultUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('스토어를 열 수 없습니다.')),
        );
      }
    }
  }
}
