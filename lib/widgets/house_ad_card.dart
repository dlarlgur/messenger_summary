import 'package:dksw_app_core/dksw_app_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/house_ad_service.dart';

const Color _accent = Color(0xFF2563EB);

/// 콘솔에서 등록한 house ad 카드 (chat_llm 톤).
///
/// 두 가지 표시 모드:
///   - 구조화: 좌측 아이콘 + 헤드라인/본문 + 우측 CTA (AdMob 카드와 동일)
///   - 배너: imageUrl만 풀 폭으로 깔리고 좌상단 AD 라벨
///
/// Impressions 자동 보고(첫 프레임), 클릭 시 ctaUrl 외부 브라우저 + 클릭 보고.
class HouseAdCard extends StatefulWidget {
  final HouseAd ad;
  final EdgeInsets margin;

  const HouseAdCard({
    super.key,
    required this.ad,
    this.margin = const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
  });

  @override
  State<HouseAdCard> createState() => _HouseAdCardState();
}

class _HouseAdCardState extends State<HouseAdCard> {
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
    HouseAdCache.reportImpression(widget.ad.id);
  }

  Future<void> _onTap() async {
    HouseAdCache.reportClick(widget.ad.id);
    final url = widget.ad.ctaUrl;
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF12141A) : Colors.white;
    final borderColor =
        isDark ? const Color(0x14FFFFFF) : const Color(0xFFE2E8F0);

    final inner = widget.ad.isStructured
        ? _StructuredAdContent(ad: widget.ad)
        : _BannerAdContent(ad: widget.ad);

    return Container(
      margin: widget.margin,
      height: 96, // chat_llm 채팅 타일 톤에 맞춘 높이
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onTap,
          child: inner,
        ),
      ),
    );
  }
}

class _StructuredAdContent extends StatelessWidget {
  final HouseAd ad;
  const _StructuredAdContent({required this.ad});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondary = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final labelBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8ECF0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              DkswCore.resolveAssetUrl(ad.imageUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.image_outlined, size: 20, color: _accent),
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
                        ad.headline ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primary,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((ad.bodyText ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ad.bodyText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: secondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if ((ad.ctaLabel ?? '').isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                ad.ctaLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
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

class _BannerAdContent extends StatelessWidget {
  final HouseAd ad;
  const _BannerAdContent({required this.ad});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          DkswCore.resolveAssetUrl(ad.imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
}
