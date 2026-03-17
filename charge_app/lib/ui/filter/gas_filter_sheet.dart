import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

class GasFilterSheet extends ConsumerStatefulWidget {
  const GasFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GasFilterSheet(),
    );
  }

  @override
  ConsumerState<GasFilterSheet> createState() => _GasFilterSheetState();
}

class _GasFilterSheetState extends ConsumerState<GasFilterSheet> {
  late GasFilterOptions _options;

  @override
  void initState() {
    super.initState();
    _options = ref.read(gasFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('주유소 필터', style: Theme.of(context).textTheme.headlineSmall),
                TextButton(
                  onPressed: () => setState(() => _options = const GasFilterOptions()),
                  child: Text('초기화', style: TextStyle(color: AppColors.gasBlue, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _filterSection('정렬', [
                    _chip('가격순', _options.sort == 1, () => setState(() => _options = _options.copyWith(sort: 1))),
                    _chip('거리순', _options.sort == 2, () => setState(() => _options = _options.copyWith(sort: 2))),
                  ]),
                  _filterSection('검색 반경', AppConstants.radiusOptions.map((r) {
                    final label = '${(r / 1000).toInt()}Km';
                    return _chip(label, _options.radius == r, () => setState(() => _options = _options.copyWith(radius: r)));
                  }).toList()),
                  _filterSection('유류 종류', FuelType.values.map((t) =>
                    _chip(t.label, _options.fuelTypes.contains(t.code), () {
                      // 단일 선택: 항상 하나만 남도록 설정
                      setState(() {
                        _options = _options.copyWith(fuelTypes: [t.code]);
                      });
                    })
                  ).toList()),
                  _filterSection('브랜드', [
                    _chip('전체', _options.brands.isEmpty, () => setState(() => _options = _options.copyWith(brands: []))),
                    _chip('SK에너지',    _options.brands.isEmpty || _options.brands.contains('SKE'), () => _toggleBrand('SKE')),
                    _chip('GS칼텍스',   _options.brands.isEmpty || _options.brands.contains('GSC'), () => _toggleBrand('GSC')),
                    _chip('현대오일뱅크', _options.brands.isEmpty || _options.brands.contains('HDO'), () => _toggleBrand('HDO')),
                    _chip('S-OIL',      _options.brands.isEmpty || _options.brands.contains('SOL'), () => _toggleBrand('SOL')),
                    _chip('NH주유소',   _options.brands.isEmpty || _options.brands.contains('NHO'), () => _toggleBrand('NHO')),
                    _chip('E1에너지',   _options.brands.isEmpty || _options.brands.contains('E1G'), () => _toggleBrand('E1G')),
                    _chip('알뜰주유소', _options.brands.isEmpty || _options.brands.contains('RTO'), () => _toggleBrand('RTO')),
                    _chip('기타',        _options.brands.isEmpty || _options.brands.contains('ETC'), () => _toggleBrand('ETC')),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(gasFilterProvider.notifier).update(_options);
                  Navigator.pop(context);
                },
                child: const Text('적용하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _allBrands = ['SKE', 'GSC', 'HDO', 'SOL', 'NHO', 'E1G', 'RTO', 'ETC'];

  void _toggleBrand(String brand) {
    setState(() {
      if (_options.brands.isEmpty) {
        // 전체 모드 → 클릭한 것만 제외한 나머지 선택
        final brands = _allBrands.where((b) => b != brand).toList();
        _options = _options.copyWith(brands: brands);
      } else {
        final brands = List<String>.from(_options.brands);
        if (brands.contains(brand)) {
          brands.remove(brand);
          _options = _options.copyWith(brands: brands.isEmpty ? [] : brands);
        } else {
          brands.add(brand);
          // 모두 선택되면 전체로
          if (_allBrands.every((b) => brands.contains(b))) {
            _options = _options.copyWith(brands: []);
          } else {
            _options = _options.copyWith(brands: brands);
          }
        }
      }
    });
  }

  Widget _filterSection(String title, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            letterSpacing: 0.3)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }

  Widget _chip(String label, bool isActive, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.gasBlue : (isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: isActive ? null : Border.all(
            color: isDark ? AppColors.darkCardBorder : const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: isActive ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        )),
      ),
    );
  }
}
