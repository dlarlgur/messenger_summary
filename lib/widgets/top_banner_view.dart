import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/house_ad_service.dart';

const Color _accent = Color(0xFF2563EB);

/// 톡비서 채팅방 목록 상단 배너 광고 (chat_llm 전용 단일 슬롯).
///
/// 두 가지 표시 모드 (콘솔 등록 시 [HouseAd.displayStyle] 로 명시 선택):
///   - 'banner' → **풀폭 그래픽 배너** (이미지 자연 비율 그대로, 카드 보더 없음)
///   - 'card'   → **카드** (좌측 아이콘 + 텍스트 + CTA, 116dp)
///
/// Impressions 자동 보고(첫 프레임), 클릭 시 ctaUrl 외부 브라우저 + 클릭 보고.
/// 이미지 로딩 실패 시 [onImageError] 호출 → 호출처(chat_room_list_screen)에서
/// AdMob/AdFit 폴백 흐름으로 자동 복귀.
class TopBannerView extends StatefulWidget {
  final HouseAd ad;
  final VoidCallback? onImageError;

  const TopBannerView({
    super.key,
    required this.ad,
    this.onImageError,
  });

  @override
  State<TopBannerView> createState() => _TopBannerViewState();
}

class _TopBannerViewState extends State<TopBannerView> {
  bool _impressionReported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markImpression();
    });
  }

  void _markImpression() {
    if (_impressionReported) return;
    _impressionReported = true;
    TopBannerCache.reportImpression(widget.ad.id);
  }

  Future<void> _onTap() async {
    TopBannerCache.reportClick(widget.ad.id);
    final url = widget.ad.ctaUrl;
    if (url == null || url.isEmpty || widget.ad.ctaType == 'none') return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onTap,
        child: widget.ad.isBanner ? _buildBanner() : _buildCard(context),
      ),
    );
  }

  /// 풀폭 그래픽 배너 — 이미지 자연 비율 그대로.
  /// 광고주가 1080×360 (3:1) 올리면 그 비율, 1080×1080 올리면 1:1, 자유.
  Widget _buildBanner() {
    return Stack(
      children: [
        Image.network(
          DkswCore.resolveAssetUrl(widget.ad.imageUrl),
          fit: BoxFit.fitWidth,
          width: double.infinity,
          // 이미지 자연 비율 사용 — height 강제 X
          errorBuilder: (_, __, ___) {
            // 폴백 트리거. build 도중 setState 직접 호출하면 안 되니 다음 프레임에.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onImageError?.call();
            });
            return const SizedBox.shrink();
          },
        ),
        // 좌상단 AD 라벨
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'AD',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 카드 — 좌측 아이콘 + 헤드라인/본문 + 우측 CTA. 톡비서 상단 톤(116dp).
  Widget _buildCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondary = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final cardBg = isDark ? const Color(0xFF12141A) : Colors.white;
    final border =
        isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0);
    final labelBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8ECF0);

    return Container(
      width: double.infinity,
      height: 116,
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: border, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              DkswCore.resolveAssetUrl(widget.ad.imageUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onImageError?.call();
                });
                return Icon(Icons.image_outlined, size: 24, color: _accent);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: labelBg,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'AD',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: secondary,
                          letterSpacing: 0.2,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.ad.headline ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primary,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((widget.ad.bodyText ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.ad.bodyText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if ((widget.ad.ctaLabel ?? '').isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.ad.ctaLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
