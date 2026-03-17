import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';
import '../map/map_screen.dart';
import '../widgets/shared_widgets.dart';
import '../filter/gas_filter_sheet.dart';
import '../filter/ev_filter_sheet.dart';
import '../favorites/favorites_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<bool> _onWillPop(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('앱 종료'),
        content: const Text('풀업을 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('종료', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomIndex = ref.watch(bottomNavIndexProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _onWillPop(context);
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      body: IndexedStack(
        index: bottomIndex,
        children: const [
          _HomeTab(),
          _MapTab(),
          _FavoritesTab(),
          _SettingsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: bottomIndex,
        onTap: (i) => ref.read(bottomNavIndexProvider.notifier).state = i,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: '지도'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_rounded), label: '즐겨찾기'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: '설정'),
        ],
      ),
    ),
    );
  }
}

// ─── 홈 탭 ───
class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final vehicleType = settings.vehicleType;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 차량 타입에 따라 activeTab 강제 지정
    final activeTab = vehicleType == VehicleType.ev ? 1 : ref.watch(activeTabProvider);
    final showTab = vehicleType == VehicleType.both;

    return SafeArea(
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text('풀업', style: Theme.of(context).textTheme.headlineSmall),
          ),
          // 탭 바 (둘 다 사용일 때만 표시)
          if (showTab) ...[
            GasEvTabBar(
              activeIndex: activeTab,
              onChanged: (i) => ref.read(activeTabProvider.notifier).state = i,
            ),
            const SizedBox(height: 4),
          ],
          // 리스트 (둘 다 모드는 IndexedStack으로 백그라운드 프리로드)
          Expanded(
            child: vehicleType == VehicleType.ev
                ? const _EvListView()
                : vehicleType == VehicleType.gas
                    ? const _GasListView()
                    : GestureDetector(
                        onHorizontalDragEnd: (details) {
                          final dx = details.primaryVelocity ?? 0;
                          if (dx < -300 && activeTab == 0) {
                            // 왼쪽 스와이프 → 충전
                            ref.read(activeTabProvider.notifier).state = 1;
                          } else if (dx > 300 && activeTab == 1) {
                            // 오른쪽 스와이프 → 주유
                            ref.read(activeTabProvider.notifier).state = 0;
                          }
                        },
                        child: IndexedStack(
                          index: activeTab,
                          children: const [_GasListView(), _EvListView()],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── 주유소 리스트 뷰 ───
class _GasListView extends ConsumerStatefulWidget {
  const _GasListView();
  @override
  ConsumerState<_GasListView> createState() => _GasListViewState();
}

class _GasListViewState extends ConsumerState<_GasListView> {
  static const _pageSize = 50;
  int _displayCount = _pageSize;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        setState(() => _displayCount += _pageSize);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(gasStationsProvider);
    final filter = ref.watch(gasFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _displayCount = _pageSize; _searchQuery = ''; _searchController.clear(); });
        ref.invalidate(gasStationsProvider);
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 검색 + 필터 버튼
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(Icons.search_rounded, size: 17,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(() { _searchQuery = v; _displayCount = _pageSize; }),
                              decoration: InputDecoration(
                                hintText: '주유소 검색',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintStyle: TextStyle(fontSize: 13,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              style: TextStyle(fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () => setState(() { _searchQuery = ''; _searchController.clear(); }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.close_rounded, size: 15,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => GasFilterSheet.show(context),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.gasBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tune_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            filter.sort == 1 ? '가격순' : '거리순',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 요약 카드
          SliverToBoxAdapter(
            child: stationsAsync.when(
              loading: () => const GasSummaryCard(avgPrice: 0, priceDiff: 0),
              error: (_, __) => const GasSummaryCard(avgPrice: 0, priceDiff: 0),
              data: (stations) {
                final avgPrice = stations.isEmpty ? 0.0
                    : stations.map((s) => s.price).reduce((a, b) => a + b) / stations.length;
                final avgAsync = ref.watch(gasAvgPriceProvider);
                final fuelCode = filter.fuelTypes.isNotEmpty ? filter.fuelTypes.first : 'B027';
                final priceDiff = avgAsync.when(
                  data: (m) => (m[fuelCode]?['diff'] as num?)?.toDouble() ?? 0.0,
                  loading: () => 0.0,
                  error: (_, __) => 0.0,
                );
                return GasSummaryCard(avgPrice: avgPrice, priceDiff: priceDiff);
              },
            ),
          ),
          // 리스트
          stationsAsync.when(
            loading: () => SliverList(delegate: SliverChildBuilderDelegate(
              (_, __) => const SkeletonCard(), childCount: 6,
            )),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.darkTextMuted),
                  const SizedBox(height: 12),
                  Text('데이터를 불러올 수 없습니다', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => ref.invalidate(gasStationsProvider), child: const Text('다시 시도')),
                ]),
              )),
            ),
            data: (stations) {
              final filtered = _searchQuery.isEmpty ? stations
                  : stations.where((s) =>
                      s.name.contains(_searchQuery) ||
                      s.address.contains(_searchQuery)).toList();
              if (filtered.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(_searchQuery.isEmpty ? '주변에 주유소가 없습니다' : '\'$_searchQuery\' 검색 결과가 없습니다',
                        style: Theme.of(context).textTheme.bodyMedium),
                  )),
                );
              }
              final shown = filtered.take(_displayCount).toList();
              return SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => GasStationCard(
                  station: shown[i],
                  isTop: i == 0,
                  topBadgeLabel: filter.sort == 1 ? '최저가' : '최단거리',
                  onTap: () => context.push('/gas/${shown[i].id}', extra: shown[i]),
                ),
                childCount: shown.length,
              ));
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

// ─── 충전소 리스트 뷰 ───
class _EvListView extends ConsumerStatefulWidget {
  const _EvListView();
  @override
  ConsumerState<_EvListView> createState() => _EvListViewState();
}

class _EvListViewState extends ConsumerState<_EvListView> {
  static const _pageSize = 50;
  int _displayCount = _pageSize;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        setState(() => _displayCount += _pageSize);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(evStationsProvider);
    final filter = ref.watch(evFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() { _displayCount = _pageSize; _searchQuery = ''; _searchController.clear(); });
        ref.invalidate(evStationsProvider);
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 검색 + 필터 버튼
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(Icons.search_rounded, size: 17,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (v) => setState(() { _searchQuery = v; _displayCount = _pageSize; }),
                              decoration: InputDecoration(
                                hintText: '충전소 검색',
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintStyle: TextStyle(fontSize: 13,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              style: TextStyle(fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () => setState(() { _searchQuery = ''; _searchController.clear(); }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.close_rounded, size: 15,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => EvFilterSheet.show(context),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.evGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tune_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            filter.sort == 1 ? '거리순' : '가격순',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 요약 카드
          SliverToBoxAdapter(
            child: stationsAsync.when(
              loading: () => const EvSummaryCard(totalStations: 0, availableStations: 0),
              error: (_, __) => const EvSummaryCard(totalStations: 0, availableStations: 0),
              data: (stations) => EvSummaryCard(
                totalStations: stations.length,
                availableStations: stations.where((s) => s.hasAvailable).length,
              ),
            ),
          ),
          // 리스트
          stationsAsync.when(
            loading: () => SliverList(delegate: SliverChildBuilderDelegate(
              (_, __) => const SkeletonCard(), childCount: 6,
            )),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.darkTextMuted),
                  const SizedBox(height: 12),
                  Text('데이터를 불러올 수 없습니다', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => ref.invalidate(evStationsProvider), child: const Text('다시 시도')),
                ]),
              )),
            ),
            data: (stations) {
              final filtered = _searchQuery.isEmpty ? stations
                  : stations.where((s) =>
                      s.name.contains(_searchQuery) ||
                      s.address.contains(_searchQuery) ||
                      s.operator.contains(_searchQuery)).toList();
              if (filtered.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(_searchQuery.isEmpty ? '주변에 충전소가 없습니다' : '\'$_searchQuery\' 검색 결과가 없습니다',
                        style: Theme.of(context).textTheme.bodyMedium),
                  )),
                );
              }
              final shown = filtered.take(_displayCount).toList();
              return SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => EvStationCard(
                  station: shown[i],
                  isTop: i == 0,
                  onTap: () => context.push('/ev/${shown[i].statId}', extra: shown[i]),
                ),
                childCount: shown.length,
              ));
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

String _fuelTypesLabel(List<String> fuelTypes) {
  if (fuelTypes.isEmpty) return '휘발유';
  final first = FuelType.fromCode(fuelTypes.first).label;
  if (fuelTypes.length == 1) return first;
  return '$first 외 ${fuelTypes.length - 1}';
}

// 필터 칩 공통 라벨: 전체면 기본명, 1개면 항목명, 복수면 "첫번째 외 N"
String _chipLabel(List<String> items, String Function(String) labelFn, String defaultLabel) {
  if (items.isEmpty) return defaultLabel;

  // 코드가 여러 개여도 같은 라벨(예: A0/G0 둘 다 '공공기관')이면
  // 한 개로 취급하기 위해 라벨 기준으로 중복 제거
  final labels = items.map(labelFn).toSet().toList();
  final first = labels.first;
  // 충전장소: 모든 종류가 선택된 경우에는 기본 라벨("충전장소")로 표기
  if (defaultLabel == '충전장소' && labels.length >= 6) {
    return defaultLabel;
  }
  if (labels.length == 1) return first;
  return '$first 외 ${labels.length - 1}';
}

String _brandLabel(String brand) {
  switch (brand) {
    case 'SKE': return 'SK에너지';
    case 'GSC': return 'GS칼텍스';
    case 'HDO': return '현대오일뱅크';
    case 'SOL': return 'S-OIL';
    case 'NHO': return 'NH주유소';
    case 'E1G': return 'E1에너지';
    case 'RTO': return '알뜰주유소';
    case 'ETC': return '기타';
    default: return brand;
  }
}

String _kindLabel(String kind) {
  switch (kind) {
    case 'A0': case 'G0': return '공공기관';
    case 'B0': return '공영주차';
    case 'C0': return '고속도로';
    case 'D0': case 'E0': case 'F0': case 'I0': return '일반충전소';
    case 'H0': return '숙박시설';
    case 'J0': return '아파트';
    default: return kind;
  }
}

String _chargerTypeLabel(String type) {
  switch (type) {
    case '01': return 'DC차데모';
    case '02': return 'AC완속';
    case '03': return 'DC콤보';
    case '04': return 'AC3상';
    case '05': return '차데모+AC3상';
    case '06': return '차데모+DC콤보';
    case '07': return '차데모+AC+DC';
    default: return type;
  }
}

// ─── 지도 탭 ───
class _MapTab extends StatelessWidget {
  const _MapTab();
  @override
  Widget build(BuildContext context) {
    return const MapScreen();
  }
}

// ─── 즐겨찾기 탭 ───
class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('즐겨찾기', style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          const Expanded(child: FavoritesScreen()),
        ],
      ),
    );
  }
}


// ─── 설정 탭 래퍼 ───
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();
  @override
  Widget build(BuildContext context) {
    return const SettingsScreenEmbed();
  }
}

/// 설정 화면 임베드 (홈 탭에서 사용)
class SettingsScreenEmbed extends ConsumerWidget {
  const SettingsScreenEmbed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Text('설정', style: Theme.of(context).textTheme.headlineSmall),
          ),
          _sectionHeader(context, '차량 설정'),
          _tile(context, isDark, Icons.directions_car_rounded, '차량 타입', settings.vehicleType.label, () {
            _showPicker(context, '차량 타입', VehicleType.values.map((t) => t.label).toList(),
              VehicleType.values.indexOf(settings.vehicleType),
              (i) => ref.read(settingsProvider.notifier).setVehicleType(VehicleType.values[i]));
          }),
          if (settings.vehicleType != VehicleType.ev)
            _tile(context, isDark, Icons.local_gas_station_rounded, '유종', settings.fuelType.label, () {
              _showPicker(context, '유종', FuelType.values.map((t) => t.label).toList(),
                FuelType.values.indexOf(settings.fuelType),
                (i) => ref.read(settingsProvider.notifier).setFuelType(FuelType.values[i]));
            }),
          _tile(context, isDark, Icons.radar_rounded, '검색 반경', '${(settings.radius / 1000).toInt()}Km', () {
            _showPicker(context, '검색 반경',
              AppConstants.radiusOptions.map((r) => '${(r / 1000).toInt()}Km').toList(),
              AppConstants.radiusOptions.indexOf(settings.radius),
              (i) => ref.read(settingsProvider.notifier).setRadius(AppConstants.radiusOptions[i]));
          }),
          const SizedBox(height: 16),
          _sectionHeader(context, '앱 설정'),
          _tile(context, isDark, Icons.dark_mode_rounded, '테마',
            themeMode == ThemeMode.dark ? '다크' : '라이트', () {
              const modes = [ThemeMode.light, ThemeMode.dark];
              _showPicker(context, '테마', ['라이트 모드', '다크 모드'],
                modes.indexOf(themeMode == ThemeMode.system ? ThemeMode.light : themeMode),
                (i) => ref.read(themeModeProvider.notifier).setTheme(modes[i]));
          }),
          const SizedBox(height: 16),
          _sectionHeader(context, '정보'),
          _tile(context, isDark, Icons.info_outline_rounded, '앱 버전', '1.0.0', null),
          const SizedBox(height: 24),
          Center(child: Text('com.dksw.charge', style: Theme.of(context).textTheme.labelSmall)),
          const SizedBox(height: 4),
          Center(child: Text('데이터: 오피넷(한국석유공사) · 한국환경공단', style: Theme.of(context).textTheme.labelSmall)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gasBlue)),
    );
  }

  Widget _tile(BuildContext context, bool isDark, IconData icon, String title, String value, VoidCallback? onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, size: 22, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: Theme.of(context).textTheme.bodyMedium),
        if (onTap != null) Icon(Icons.chevron_right_rounded, size: 20,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
      ]),
      onTap: onTap,
    );
  }

  void _showPicker(BuildContext context, String title, List<String> options, int selected, ValueChanged<int> onSelect) {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(options.length, (i) => ListTile(
          title: Text(options[i]),
          trailing: i == selected ? const Icon(Icons.check, color: AppColors.gasBlue) : null,
          onTap: () { onSelect(i); Navigator.pop(context); },
        )),
        const SizedBox(height: 16),
      ]),
    ));
  }
}
