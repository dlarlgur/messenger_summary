import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

class EvFilterSheet extends ConsumerStatefulWidget {
  const EvFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EvFilterSheet(),
    );
  }

  @override
  ConsumerState<EvFilterSheet> createState() => _EvFilterSheetState();
}

class _EvFilterSheetState extends ConsumerState<EvFilterSheet> {
  late EvFilterOptions _options;

  @override
  void initState() {
    super.initState();
    _options = ref.read(evFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
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
                Text('충전소 필터', style: Theme.of(context).textTheme.headlineSmall),
                TextButton(
                  onPressed: () => setState(() => _options = const EvFilterOptions()),
                  child: Text('초기화', style: TextStyle(color: AppColors.evGreen, fontWeight: FontWeight.w500)),
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
                  _section('검색 반경', AppConstants.radiusOptions.map((r) =>
                    _chip('${(r / 1000).toInt()}Km', _options.radius == r,
                        () => setState(() => _options = _options.copyWith(radius: r)))
                  ).toList()),

                  _section('충전기 타입', [
                    _chip('전체', _options.chargerTypes.isEmpty,
                        () => setState(() => _options = _options.copyWith(chargerTypes: []))),
                    _chip('DC콤보', _options.chargerTypes.isEmpty || _options.chargerTypes.contains('03'), () => _toggleType('03')),
                    _chip('DC차데모', _options.chargerTypes.isEmpty || _options.chargerTypes.contains('01'), () => _toggleType('01')),
                    _chip('AC완속', _options.chargerTypes.isEmpty || _options.chargerTypes.contains('02'), () => _toggleType('02')),
                    _chip('AC3상', _options.chargerTypes.isEmpty || _options.chargerTypes.contains('04'), () => _toggleType('04')),
                    _chip('NACS', _options.chargerTypes.isEmpty || _options.chargerTypes.contains('09'), () => _toggleType('09')),
                  ]),

                  _section('상태', [
                    _chip('이용가능만', _options.availableOnly,
                        () => setState(() => _options = _options.copyWith(availableOnly: true))),
                    _chip('전체보기', !_options.availableOnly,
                        () => setState(() => _options = _options.copyWith(availableOnly: false))),
                  ]),

                  _section('정렬', [
                    _chip('거리순', _options.sort == 1,
                        () => setState(() => _options = _options.copyWith(sort: 1))),
                    _chip('가격순', _options.sort == 2,
                        () => setState(() => _options = _options.copyWith(sort: 2))),
                  ]),

                  _kindSection(),

                  _section('운영기관', [
                    _chip('전체', _options.operators.isEmpty,
                        () => setState(() => _options = _options.copyWith(operators: []))),
                    _chip('환경부', _options.operators.isEmpty || _options.operators.contains('환경부'), () => _toggleOp('환경부')),
                    _chip('해피차저', _options.operators.isEmpty || _options.operators.contains('해피차저'), () => _toggleOp('해피차저')),
                    _chip('GS차지비', _options.operators.isEmpty || _options.operators.contains('GS차지비'), () => _toggleOp('GS차지비')),
                    _chip('SK일렉링크', _options.operators.isEmpty || _options.operators.contains('SK일렉링크'), () => _toggleOp('SK일렉링크')),
                    _chip('파워큐브', _options.operators.isEmpty || _options.operators.contains('파워큐브'), () => _toggleOp('파워큐브')),
                    _chip('에버온', _options.operators.isEmpty || _options.operators.contains('에버온'), () => _toggleOp('에버온')),
                    _chip('채비', _options.operators.isEmpty || _options.operators.contains('채비'), () => _toggleOp('채비')),
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
                  ref.read(evFilterProvider.notifier).update(_options);
                  ref.invalidate(evStationsProvider);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.evGreen),
                child: const Text('적용하기'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _allChargerTypes = ['03', '01', '02', '04', '09'];

  void _toggleType(String type) {
    setState(() {
      if (_options.chargerTypes.isEmpty) {
        // 전체 모드 → 클릭한 것만 제외한 나머지 선택
        final types = _allChargerTypes.where((t) => t != type).toList();
        _options = _options.copyWith(chargerTypes: types);
      } else {
        final types = List<String>.from(_options.chargerTypes);
        if (types.contains(type)) {
          types.remove(type);
          _options = _options.copyWith(chargerTypes: types.isEmpty ? [] : types);
        } else {
          types.add(type);
          // 모두 선택되면 전체로
          if (_allChargerTypes.every((t) => types.contains(t))) {
            _options = _options.copyWith(chargerTypes: []);
          } else {
            _options = _options.copyWith(chargerTypes: types);
          }
        }
      }
    });
  }

  // 장소 그룹 정의: 라벨 → kind 코드 목록
  static const _kindGroups = {
    '공공기관': ['A0', 'G0'],
    '공영주차': ['B0'],
    '숙박시설': ['H0'],
    '아파트': ['J0'],
    '일반충전소': ['D0', 'E0', 'F0', 'I0'],
    '고속도로': ['C0'],
  };

  bool _kindGroupActive(List<String> codes) {
    if (_options.kinds.isEmpty) return true;
    return codes.any((c) => _options.kinds.contains(c));
  }

  static const _allKindCodes = ['A0', 'G0', 'B0', 'H0', 'J0', 'D0', 'E0', 'F0', 'I0', 'C0'];

  void _toggleKindGroup(List<String> codes) {
    setState(() {
      if (_options.kinds.isEmpty) {
        // 전체 모드 → 클릭한 그룹만 제외한 나머지 선택
        final kinds = _allKindCodes.where((c) => !codes.contains(c)).toList();
        _options = _options.copyWith(kinds: kinds.isEmpty ? [] : kinds);
      } else {
        final kinds = List<String>.from(_options.kinds);
        final allSelected = codes.every((c) => kinds.contains(c));
        if (allSelected) {
          for (final c in codes) kinds.remove(c);
        } else {
          for (final c in codes) {
            if (!kinds.contains(c)) kinds.add(c);
          }
        }
        // 모두 선택되면 전체로
        if (_allKindCodes.every((c) => kinds.contains(c))) {
          _options = _options.copyWith(kinds: []);
        } else {
          _options = _options.copyWith(kinds: kinds.isEmpty ? [] : kinds);
        }
      }
    });
  }

  Widget _kindSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text('충전 장소',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _options = _options.copyWith(kinds: [])),
              child: Text('전체',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: _options.kinds.isEmpty ? AppColors.evGreen : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _kindRow('일반도로', ['공공기관', '공영주차', '숙박시설', '아파트', '일반충전소'], isDark),
        const SizedBox(height: 8),
        _kindRow('고속도로', ['고속도로'], isDark),
        if (_options.kinds.isEmpty || _options.kinds.contains('C0')) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('방향',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    _chip('전체', _options.highwayDir.isEmpty,
                      () => setState(() => _options = _options.copyWith(highwayDir: ''))),
                    _chip('상행', _options.highwayDir == '상행',
                      () => setState(() => _options = _options.copyWith(
                        highwayDir: _options.highwayDir == '상행' ? '' : '상행'))),
                    _chip('하행', _options.highwayDir == '하행',
                      () => setState(() => _options = _options.copyWith(
                        highwayDir: _options.highwayDir == '하행' ? '' : '하행'))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _kindRow(String label, List<String> groupKeys, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6, runSpacing: 6,
            children: groupKeys.map((key) {
              final codes = _kindGroups[key]!;
              final active = _kindGroupActive(codes);
              return _chip(key, active, () => _toggleKindGroup(codes));
            }).toList(),
          ),
        ),
      ],
    );
  }

  static const _allOperators = ['환경부', '해피차저', 'GS차지비', 'SK일렉링크', '파워큐브', '에버온', '채비'];

  void _toggleOp(String op) {
    setState(() {
      if (_options.operators.isEmpty) {
        // 전체 모드 → 클릭한 것만 제외한 나머지 선택
        final ops = _allOperators.where((o) => o != op).toList();
        _options = _options.copyWith(operators: ops);
      } else {
        final ops = List<String>.from(_options.operators);
        if (ops.contains(op)) {
          ops.remove(op);
          _options = _options.copyWith(operators: ops.isEmpty ? [] : ops);
        } else {
          ops.add(op);
          // 모두 선택되면 전체로
          if (_allOperators.every((o) => ops.contains(o))) {
            _options = _options.copyWith(operators: []);
          } else {
            _options = _options.copyWith(operators: ops);
          }
        }
      }
    });
  }

  Widget _section(String title, List<Widget> chips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.evGreen : (isDark ? const Color(0x0AFFFFFF) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: active ? null : Border.all(
            color: isDark ? AppColors.darkCardBorder : const Color(0xFFE2E8F0), width: 0.5),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: active ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        )),
      ),
    );
  }
}
