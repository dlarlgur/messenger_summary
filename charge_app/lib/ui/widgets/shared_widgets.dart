import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../favorites/favorites_screen.dart';

// ─── 브랜드 컬러 로고 ───
class BrandLogo extends StatelessWidget {
  final String brand;
  const BrandLogo({super.key, required this.brand});

  static const _validBrands = {'SKE', 'GSC', 'HDO', 'SOL', 'NHO', 'E1G', 'RTO', 'RTX', 'ETC'};

  @override
  Widget build(BuildContext context) {
    final assetBrand = _validBrands.contains(brand) ? brand : 'ETC';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/brands/$assetBrand.png',
        width: 38, height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: const Color(0xFF94A3B8), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text(
            brand.isNotEmpty ? brand.substring(0, brand.length > 2 ? 2 : brand.length) : '?',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
          ),
        ),
      ),
    );
  }
}

// ─── 주유소 카드 ───
class GasStationCard extends ConsumerWidget {
  final GasStation station;
  final bool isTop;
  /// 1번 항목 배지 문구. 가격순이면 '최저가', 거리순이면 '최단거리'
  final String topBadgeLabel;
  final VoidCallback? onTap;

  const GasStationCard({super.key, required this.station, this.isTop = false, this.topBadgeLabel = '최저가', this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFav = ref.watch(favoritesProvider).any((f) => f['type'] == 'gas' && f['id'] == station.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isTop
              ? (isDark ? AppColors.darkGasActiveCard : AppColors.lightGasActiveCard)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(14),
          border: isTop
              ? Border.all(color: isDark ? AppColors.darkGasActiveBorder : AppColors.gasBlue, width: 1.5)
              : Border.all(color: isDark ? AppColors.darkCardBorder : const Color(0xFFDDE3EC), width: 1),
        ),
        child: Row(
          children: [
            BrandLogo(brand: station.brand),
            const SizedBox(width: 12),
            // 이름 + 거리/브랜드
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    '${station.distanceText} · ${station.brandName}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            // 가격 + 최저가 배지
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isTop)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gasBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(topBadgeLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                Text(
                  station.priceText,
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: isTop ? AppColors.gasBlue : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => ref.read(favoritesProvider.notifier).toggle(
                id: station.id, type: 'gas', name: station.name,
                subtitle: '${station.brandName} · ${station.address}',
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 20,
                  color: isFav ? AppColors.gasBlue : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EV 운영사 로고 ───
class EvOperatorLogo extends StatelessWidget {
  final String operator;
  const EvOperatorLogo({super.key, required this.operator});

  static String _toCode(String op) {
    if (op.contains('한국전력') || op.contains('한전') || op.contains('KEPCO')) return 'KEP';
    if (op.contains('환경부')) return 'ENV';
    if (op.contains('GS') || op.contains('gs')) return 'GSC';
    if (op.contains('SK')) return 'SKP';
    if (op.contains('현대') || op.contains('E-pit') || op.contains('이핏')) return 'HMC';
    if (op.contains('테슬라') || op.contains('Tesla')) return 'TSL';
    if (op.contains('차지비')) return 'CHV';
    if (op.contains('대영') || op.contains('채비')) return 'DYC';
    if (op.contains('에버온')) return 'EVR';
    if (op.contains('에스트래픽') || op.contains('S-트래픽')) return 'STR';
    if (op.contains('롯데')) return 'LTR';
    if (op.contains('클린')) return 'KLP';
    return 'ETC';
  }

  @override
  Widget build(BuildContext context) {
    final code = _toCode(operator);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/ev_operators/$code.png',
        width: 38, height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: AppColors.evGreen, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: const Icon(Icons.ev_station, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

// ─── 충전소 카드 ───
class EvStationCard extends ConsumerWidget {
  final EvStation station;
  final bool isTop;
  final VoidCallback? onTap;

  const EvStationCard({super.key, required this.station, this.isTop = false, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFav = ref.watch(favoritesProvider).any((f) => f['type'] == 'ev' && f['id'] == station.statId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isTop
              ? (isDark ? AppColors.darkEvActiveCard : AppColors.lightEvActiveCard)
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(12),
          border: isTop
              ? Border.all(color: isDark ? AppColors.darkEvActiveBorder : AppColors.lightEvActiveBorder, width: 0.5)
              : Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder, width: 0.5),
        ),
        child: Row(
          children: [
            EvOperatorLogo(operator: station.operator),
            const SizedBox(width: 12),
            // 이름 + 상태 배지 + 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(station.name, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      EvStatusBadge(station: station),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${station.distanceText} · ${station.operator} · ${station.chargerTypeText}',
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (station.maxPowerText != null)
                  Text(
                    station.maxPowerText!,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: isTop ? AppColors.evGreen : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                if (station.effectiveUnitPrice != null)
                  Text(
                    '${station.effectiveUnitPrice}원/kWh',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => ref.read(favoritesProvider.notifier).toggle(
                id: station.statId, type: 'ev', name: station.name,
                subtitle: '${station.operator} · ${station.address}',
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 20,
                  color: isFav ? AppColors.evGreen : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── EV 상태 배지 ───
class EvStatusBadge extends StatelessWidget {
  final EvStation station;
  const EvStatusBadge({super.key, required this.station});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color textColor;
    String label;

    final inUse = station.totalCount - station.availableCount;
    if (station.hasAvailable) {
      bgColor = isDark ? AppColors.darkBadgeAvailBg : AppColors.lightBadgeAvailBg;
      textColor = isDark ? AppColors.statusAvailable : AppColors.evGreenDark;
      label = '$inUse/${station.totalCount} 이용가능';
    } else {
      bgColor = isDark ? AppColors.darkBadgeOfflineBg : AppColors.lightBadgeOfflineBg;
      textColor = AppColors.statusOffline;
      label = station.totalCount > 0 ? '${station.totalCount}/${station.totalCount} 이용불가' : '이용불가';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

// ─── 필터 칩 ───
class FilterChip2 extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isEv;
  final VoidCallback? onTap;

  const FilterChip2({super.key, required this.label, this.isActive = false, this.isEv = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isEv ? AppColors.evGreen : AppColors.gasBlue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor
              : (isDark ? const Color(0x0DFFFFFF) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? null
              : Border.all(color: isDark ? AppColors.darkCardBorder : const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}

// ─── 요약 카드 (주유) ───
class GasSummaryCard extends StatelessWidget {
  final double avgPrice;
  final double priceDiff;

  const GasSummaryCard({super.key, required this.avgPrice, required this.priceDiff});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? AppColors.gasSummaryGradientDark : AppColors.gasSummaryGradientLight;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('주변 평균 휘발유', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3,
                color: isDark ? const Color(0xFF60A5FA) : AppColors.gasBlueDark)),
              const SizedBox(height: 4),
              RichText(text: TextSpan(children: [
                TextSpan(text: '${avgPrice.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                TextSpan(text: '원/L', style: TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
              ])),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${priceDiff >= 0 ? "▲" : "▼"} ${priceDiff.abs().toInt()}원',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: priceDiff >= 0 ? AppColors.error : AppColors.success),
              ),
              Text('전주 대비', style: TextStyle(fontSize: 10, color: AppColors.darkTextMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 요약 카드 (충전) ───
class EvSummaryCard extends StatelessWidget {
  final int totalStations;
  final int availableStations;

  const EvSummaryCard({super.key, required this.totalStations, required this.availableStations});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? AppColors.evSummaryGradientDark : AppColors.evSummaryGradientLight;
    final rate = totalStations > 0 ? (availableStations / totalStations * 100).toInt() : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('주변 충전소', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3,
                color: isDark ? const Color(0xFF34D399) : AppColors.evGreenDark)),
              const SizedBox(height: 4),
              RichText(text: TextSpan(children: [
                TextSpan(text: '$totalStations',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                TextSpan(text: '개 · 이용가능 $availableStations개', style: TextStyle(fontSize: 13, color: AppColors.darkTextMuted)),
              ])),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$rate%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.success : AppColors.evGreenDark)),
              Text('가용률', style: TextStyle(fontSize: 10, color: AppColors.darkTextMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 탭 바 (주유/충전) ───
class GasEvTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const GasEvTabBar({super.key, required this.activeIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x0AFFFFFF) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _tab(context, 0, '⛽ 주유', isDark)),
          Expanded(child: _tab(context, 1, '🔋 충전', isDark)),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, int index, String label, bool isDark) {
    final isActive = activeIndex == index;
    final isEv = index == 1;
    Color bgColor;

    if (isActive) {
      bgColor = isEv ? AppColors.evGreen : AppColors.gasBlue;
    } else {
      bgColor = Colors.transparent;
    }

    return GestureDetector(
      onTap: () => onChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ),
      ),
    );
  }
}

// ─── Skeleton 로딩 카드 ───
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E2330) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF2A3040) : const Color(0xFFF1F5F9);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 100, height: 14, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(width: 150, height: 10, decoration: BoxDecoration(color: highlightColor, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
          Container(width: 60, height: 20, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }
}
