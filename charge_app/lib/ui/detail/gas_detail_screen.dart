import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/navigation_util.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../data/services/api_service.dart';
import '../favorites/favorites_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GasDetailScreen extends ConsumerStatefulWidget {
  final String stationId;
  final GasStation? station; // 목록에서 넘어온 데이터 (price, brand 포함)
  const GasDetailScreen({super.key, required this.stationId, this.station});
  @override
  ConsumerState<GasDetailScreen> createState() => _GasDetailScreenState();
}

class _GasDetailScreenState extends ConsumerState<GasDetailScreen> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = FavoriteService.isFavorite(widget.stationId, 'gas');
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final data = await ApiService().getGasStationDetail(widget.stationId);
      if (mounted) setState(() { _detail = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('주유소 상세'),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? AppColors.gasBlue : null),
            onPressed: () {
              final d = _detail;
              final name = d?['OS_NM'] ?? d?['name'] ?? widget.station?.name ?? '주유소';
              final address = d?['NEW_ADR'] ?? d?['address'] ?? widget.station?.address ?? '';
              final result = FavoriteService.toggle(
                id: widget.stationId, type: 'gas', name: name, subtitle: address,
              );
              setState(() => _isFavorite = result);
              // 즐겨찾기 탭과 임베드 뷰를 즉시 갱신
              ref.read(favoritesProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _detail == null
              ? const Center(child: Text('정보를 불러올 수 없습니다'))
              : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    final d = _detail!;
    final name = d['OS_NM'] ?? d['name'] ?? '주유소';
    // 목록에서 넘어온 price/brand 우선 사용 (detail API는 미포함)
    final price = widget.station?.price ?? (d['PRICE'] ?? d['price'] ?? 0.0) * 1.0;
    final brand = widget.station?.brand ?? d['brand'] ?? '';
    final address = d['NEW_ADR'] ?? d['address'] ?? '';
    final phone = d['TEL'] ?? d['phone'] ?? '';
    final isSelf = d['SELF_DIV_CD'] == 'Y' || d['isSelf'] == true;
    final hasCarWash = d['CAR_WASH_YN'] == 'Y' || d['hasCarWash'] == true;
    final distanceText = widget.station?.distanceText ?? d['distanceText'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 히어로 카드
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: isDark ? null : Border.all(color: AppColors.lightCardBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x1F3B82F6) : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(brand, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gasBlue)),
                ),
                const SizedBox(height: 12),
                Text(
                  '${price.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원/L',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.gasBlue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 정보 행
          _infoRow('주소', address),
          _infoRow('영업시간', d['openTime'] ?? '정보 없음'),
          _infoRow('셀프', isSelf ? '가능' : '불가', valueColor: isSelf ? AppColors.success : null),
          _infoRow('세차', hasCarWash ? '가능' : '불가', valueColor: hasCarWash ? AppColors.success : null),
          _infoRow('거리', distanceText),
          const SizedBox(height: 20),
          // 액션 버튼
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openNavigation(d),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('길찾기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _callPhone(phone),
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: const Text('전화하기'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Flexible(child: Text(value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: valueColor),
            textAlign: TextAlign.end,
          )),
        ],
      ),
    );
  }

  void _openNavigation(Map<String, dynamic> d) {
    final lat = (d['lat'] ?? d['GIS_Y_COOR'])?.toDouble() ?? 0.0;
    final lng = (d['lng'] ?? d['GIS_X_COOR'])?.toDouble() ?? 0.0;
    final name = d['OS_NM'] ?? d['name'] ?? '';
    showNavigationSheet(context, lat: lat, lng: lng, name: name);
  }

  void _callPhone(String phone) {
    if (phone.isNotEmpty) launchUrl(Uri.parse('tel:$phone'));
  }
}
