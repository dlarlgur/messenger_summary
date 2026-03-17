import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/api_constants.dart';
import '../../core/utils/navigation_util.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../data/services/api_service.dart';
import '../../providers/providers.dart';
import '../filter/ev_filter_sheet.dart';
import '../filter/gas_filter_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  NaverMapController? _mapController;
  late bool _showGas;
  late bool _showEv;
  dynamic _selectedStation;
  bool _isEvSelected = false;
  bool _showSearchHere = false;
  bool _mapReady = false;
  int _markersGeneration = 0;

  // 검색
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchLoading = false;

  @override
  void initState() {
    super.initState();
    final vehicleType = ref.read(settingsProvider).vehicleType;
    if (vehicleType == VehicleType.gas) {
      _showGas = true;
      _showEv = false;
    } else if (vehicleType == VehicleType.ev) {
      _showGas = false;
      _showEv = true;
    } else {
      final box = Hive.box(AppConstants.settingsBox);
      _showGas = box.get(AppConstants.keyMapShowGas, defaultValue: true);
      _showEv = box.get(AppConstants.keyMapShowEv, defaultValue: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setShowGas(bool value) {
    setState(() => _showGas = value);
    if (ref.read(settingsProvider).vehicleType == VehicleType.both) {
      Hive.box(AppConstants.settingsBox).put(AppConstants.keyMapShowGas, value);
    }
    _updateMarkers();
  }

  void _setShowEv(bool value) {
    setState(() => _showEv = value);
    if (ref.read(settingsProvider).vehicleType == VehicleType.both) {
      Hive.box(AppConstants.settingsBox).put(AppConstants.keyMapShowEv, value);
    }
    _updateMarkers();
  }

  void _moveToMyLocation() async {
    final loc = await ref.read(locationProvider.future);
    if (loc == null) return;
    _mapController?.updateCamera(NCameraUpdate.withParams(
      target: NLatLng(loc.lat, loc.lng), zoom: 14,
    ));
  }

  double _radiusToZoom(int radius) {
    if (radius <= 1000) return 15;
    if (radius <= 2000) return 14;
    if (radius <= 3000) return 13;
    if (radius <= 5000) return 12;
    if (radius <= 10000) return 11;
    if (radius <= 15000) return 10.5;
    return 10;
  }

  int _activeRadius() {
    if (_showEv) return ref.read(evFilterProvider).radius;
    return ref.read(gasFilterProvider).radius;
  }

  void _searchAtCurrentCenter() async {
    final controller = _mapController;
    if (controller == null) return;
    final pos = await controller.getCameraPosition();
    ref.read(mapCenterProvider.notifier).state = (lat: pos.target.latitude, lng: pos.target.longitude);
    _mapController?.updateCamera(NCameraUpdate.withParams(zoom: _radiusToZoom(_activeRadius())));
    setState(() { _showSearchHere = false; _selectedStation = null; });
    _updateMarkers();
  }

  // ─── 검색 ───
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearchLoading = true);
    try {
      final center = ref.read(mapCenterProvider);
      final results = await ApiService().searchPlaces(
        query.trim(),
        lat: center?.lat,
        lng: center?.lng,
      );
      if (mounted) setState(() { _searchResults = results; _isSearchLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _searchResults = []; _isSearchLoading = false; });
    }
  }

  void _moveToPlace(Map<String, dynamic> place) {
    final lat = (place['lat'] as num).toDouble();
    final lng = (place['lng'] as num).toDouble();
    _mapController?.updateCamera(NCameraUpdate.withParams(
      target: NLatLng(lat, lng),
      zoom: _radiusToZoom(_activeRadius()),
    ));
    ref.read(mapCenterProvider.notifier).state = (lat: lat, lng: lng);
    setState(() {
      _isSearchMode = false;
      _searchResults = [];
      _showSearchHere = false;
    });
    _searchController.clear();
  }

  // ─── 필터 열기 ───
  void _openFilter() {
    final vehicleType = ref.read(settingsProvider).vehicleType;
    if (vehicleType == VehicleType.gas || (_showGas && !_showEv)) {
      GasFilterSheet.show(context);
    } else if (vehicleType == VehicleType.ev || (_showEv && !_showGas)) {
      EvFilterSheet.show(context);
    } else {
      _showFilterChoiceSheet();
    }
  }

  void _showFilterChoiceSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('필터 선택', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.gasBlue.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.local_gas_station_rounded, color: AppColors.gasBlue, size: 20),
              ),
              title: const Text('주유소 필터'),
              onTap: () { Navigator.pop(context); GasFilterSheet.show(context); },
            ),
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.evGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.ev_station_rounded, color: AppColors.evGreen, size: 20),
              ),
              title: const Text('충전소 필터'),
              onTap: () { Navigator.pop(context); EvFilterSheet.show(context); },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vehicleType = ref.read(settingsProvider).vehicleType;

    ref.listen(mapGasStationsProvider, (_, __) => _updateMarkers());
    ref.listen(mapEvStationsProvider, (_, __) => _updateMarkers());
    ref.listen(gasFilterProvider, (prev, next) {
      if (prev?.radius != next.radius) {
        _mapController?.updateCamera(NCameraUpdate.withParams(zoom: _radiusToZoom(next.radius)));
      }
    });
    ref.listen(evFilterProvider, (prev, next) {
      if (prev?.radius != next.radius) {
        _mapController?.updateCamera(NCameraUpdate.withParams(zoom: _radiusToZoom(next.radius)));
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ─── 네이버 지도 ───
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: const NCameraPosition(
                target: NLatLng(37.5665, 126.9780),
                zoom: 14,
              ),
              nightModeEnable: isDark,
              locationButtonEnable: false,
              consumeSymbolTapEvents: false,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              ref.read(locationProvider.future).then((loc) {
                if (loc != null) {
                  controller.updateCamera(NCameraUpdate.withParams(
                    target: NLatLng(loc.lat, loc.lng),
                    zoom: _radiusToZoom(_activeRadius()),
                  ));
                  ref.read(mapCenterProvider.notifier).state = (lat: loc.lat, lng: loc.lng);
                  final overlay = controller.getLocationOverlay();
                  overlay.setIsVisible(true);
                  overlay.setPosition(NLatLng(loc.lat, loc.lng));
                  _updateMarkers();
                }
              });
              _mapReady = true;
              _updateMarkers();
            },
            onCameraChange: (_, __) {
              if (_mapReady && !_showSearchHere && !_isSearchMode) {
                setState(() => _showSearchHere = true);
              }
            },
            onMapTapped: (_, __) {
              if (_isSearchMode) {
                setState(() { _isSearchMode = false; _searchResults = []; _searchController.clear(); });
              } else if (_selectedStation != null) {
                setState(() => _selectedStation = null);
                _updateMarkers();
              }
            },
          ),

          // ─── 상단 오버레이 ───
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12, right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 검색창
                _buildSearchBar(isDark),
                const SizedBox(height: 8),
                // 탭 + 필터
                _buildTabRow(isDark, vehicleType),
                // 검색 결과
                if (_isSearchMode)
                  _buildSearchResults(isDark),
                // 이 지역 검색 버튼
                if (_showSearchHere && !_isSearchMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(child: _buildSearchHereButton(isDark)),
                  ),
              ],
            ),
          ),

          // ─── 현재 위치 버튼 ───
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + (_selectedStation != null ? 200 : 24),
            child: GestureDetector(
              onTap: _moveToMyLocation,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBg : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Icon(Icons.my_location_rounded, size: 22,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ),

          // ─── 하단 선택 카드 ───
          if (_selectedStation != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16, right: 16,
              child: _buildSelectedCard(isDark),
            ),
        ],
      ),
    );
  }

  // ─── 검색바 ───
  Widget _buildSearchBar(bool isDark) {
    return GestureDetector(
      onTap: _isSearchMode ? null : () => setState(() => _isSearchMode = true),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search_rounded, size: 20,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            const SizedBox(width: 8),
            Expanded(
              child: _isSearchMode
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '장소, 주소 검색',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 14,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87),
                      onChanged: _performSearch,
                      onSubmitted: _performSearch,
                    )
                  : Text('장소, 주소 검색',
                      style: TextStyle(fontSize: 14,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
            ),
            GestureDetector(
              onTap: _isSearchMode
                  ? () => setState(() {
                        _isSearchMode = false;
                        _searchResults = [];
                        _searchController.clear();
                      })
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _isSearchMode
                    ? Icon(Icons.close_rounded, size: 18,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                    : const SizedBox(width: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 탭 + 필터 행 ───
  Widget _buildTabRow(bool isDark, VehicleType vehicleType) {
    return Row(
      children: [
        // 필터 버튼
        GestureDetector(
          onTap: _openFilter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBg : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 15,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                const SizedBox(width: 4),
                Text('필터', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 주유 탭
        if (vehicleType != VehicleType.ev) ...[
          _buildTabChip('⛽ 주유', _showGas, AppColors.gasBlue, isDark,
              () => _setShowGas(!_showGas)),
          if (vehicleType == VehicleType.both) const SizedBox(width: 6),
        ],
        // 충전 탭
        if (vehicleType != VehicleType.gas)
          _buildTabChip('🔋 충전', _showEv, AppColors.evGreen, isDark,
              () => _setShowEv(!_showEv)),
      ],
    );
  }

  Widget _buildTabChip(String label, bool active, Color color, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? color : (isDark ? AppColors.darkBg : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 6, offset: const Offset(0, 2))],
          border: active ? null : Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder, width: 0.8),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: active ? Colors.white
              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        )),
      ),
    );
  }

  // ─── 검색 결과 ───
  Widget _buildSearchResults(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: _isSearchLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : _searchResults.isEmpty
              ? SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('검색 결과가 없습니다',
                        style: TextStyle(fontSize: 13,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  itemBuilder: (_, i) {
                    final place = _searchResults[i];
                    return GestureDetector(
                      onTap: () => _moveToPlace(place),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 16,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(place['name'] ?? '',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white : Colors.black87)),
                                  if ((place['address'] ?? '').isNotEmpty)
                                    Text(place['address'],
                                        style: TextStyle(fontSize: 11,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // ─── 이 지역 검색 버튼 ───
  Widget _buildSearchHereButton(bool isDark) {
    return GestureDetector(
      onTap: _searchAtCurrentCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10)],
          border: Border.all(color: AppColors.gasBlue.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 15, color: AppColors.gasBlue),
            const SizedBox(width: 5),
            Text('이 지역 검색',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gasBlue)),
          ],
        ),
      ),
    );
  }

  // ─── 마커 배지 아이콘 ───
  Future<NOverlayImage> _badgeIcon(String text, Color color, bool isSelected) {
    final fontSize = isSelected ? 13.0 : 11.0;
    final double w = text.length * (isSelected ? 9.0 : 7.5) + 20;
    final double h = isSelected ? 30.0 : 26.0;

    return NOverlayImage.fromWidget(
      widget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(h / 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))],
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(text, style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1,
            )),
          ),
          CustomPaint(
            size: const Size(8, 5),
            painter: _TrianglePainter(color),
          ),
        ],
      ),
      size: Size(w, h + 5),
      context: context,
    );
  }

  // ─── 마커 업데이트 ───
  Future<void> _updateMarkers() async {
    final controller = _mapController;
    if (controller == null) return;

    final gen = ++_markersGeneration;
    await controller.clearOverlays(type: NOverlayType.marker);
    if (gen != _markersGeneration) return;

    final gasStations = (ref.read(mapGasStationsProvider).valueOrNull ?? []).take(100).toList();
    final evStations = (ref.read(mapEvStationsProvider).valueOrNull ?? []).take(100).toList();

    if (_showGas) {
      for (final s in gasStations) {
        if (gen != _markersGeneration) return;
        final isSelected = _selectedStation == s;
        final color = isSelected ? const Color(0xFFE53E3E) : AppColors.gasBlue;
        final marker = NMarker(
          id: 'gas_${s.id}',
          position: NLatLng(s.lat, s.lng),
          icon: await _badgeIcon(s.priceText, color, isSelected),
        );
        marker.setOnTapListener((_) {
          setState(() { _selectedStation = s; _isEvSelected = false; });
          _updateMarkers();
        });
        await controller.addOverlay(marker);
      }
    }

    if (_showEv) {
      for (final s in evStations) {
        if (gen != _markersGeneration) return;
        final isSelected = _selectedStation == s;
        final color = isSelected
            ? const Color(0xFFE53E3E)
            : (s.hasAvailable ? AppColors.evGreen : const Color(0xFF94A3B8));
        final marker = NMarker(
          id: 'ev_${s.statId}',
          position: NLatLng(s.lat, s.lng),
          icon: await _badgeIcon('${s.chargingCount}/${s.totalCount}', color, isSelected),
        );
        marker.setOnTapListener((_) {
          setState(() { _selectedStation = s; _isEvSelected = true; });
          _updateMarkers();
        });
        await controller.addOverlay(marker);
      }
    }
  }

  void _openNavigation(double lat, double lng, String name) {
    showNavigationSheet(context, lat: lat, lng: lng, name: name);
  }

  // ─── 선택된 카드 ───
  Widget _buildSelectedCard(bool isDark) {
    if (_selectedStation is GasStation) {
      final s = _selectedStation as GasStation;
      return _bottomCard(
        isDark: isDark, isEv: false,
        name: s.name,
        subtitle: '${s.distanceText} · ${s.brandName}',
        trailingText: s.priceText,
        trailingColor: AppColors.gasBlue,
        onDetail: () => context.push('/gas/${s.id}'),
        onNavigate: () => _openNavigation(s.lat, s.lng, s.name),
        onDismiss: () { setState(() => _selectedStation = null); _updateMarkers(); },
      );
    } else if (_selectedStation is EvStation) {
      final s = _selectedStation as EvStation;
      return _bottomCard(
        isDark: isDark, isEv: true,
        name: s.name,
        subtitle: '${s.distanceText} · ${s.operator} · ${s.chargerTypeText}',
        trailingText: s.maxPowerText ?? '',
        trailingColor: AppColors.evGreen,
        hasAvailable: s.hasAvailable,
        onDetail: () => context.push('/ev/${s.statId}', extra: s),
        onNavigate: () => _openNavigation(s.lat, s.lng, s.name),
        onDismiss: () { setState(() => _selectedStation = null); _updateMarkers(); },
      );
    }
    return const SizedBox();
  }

  Widget _bottomCard({
    required bool isDark, required bool isEv,
    required String name, required String subtitle,
    required String trailingText, required Color trailingColor,
    bool hasAvailable = true,
    required VoidCallback onDetail,
    required VoidCallback onNavigate,
    required VoidCallback onDismiss,
  }) {
    final accentColor = isEv ? AppColors.evGreen : AppColors.gasBlue;
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, -4))],
          border: Border.all(color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isEv
                        ? (isDark ? AppColors.darkEvIconBg : AppColors.lightEvIconBg)
                        : (isDark ? AppColors.darkIconBg : AppColors.lightIconBg),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEv ? Icons.ev_station_rounded : Icons.local_gas_station_rounded,
                    size: 20,
                    color: isEv ? AppColors.evGreen : AppColors.gasBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(name,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis)),
                          if (isEv) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasAvailable
                                    ? (isDark ? AppColors.darkBadgeAvailBg : AppColors.lightBadgeAvailBg)
                                    : (isDark ? AppColors.darkBadgeOfflineBg : AppColors.lightBadgeOfflineBg),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(hasAvailable ? '이용가능' : '이용불가',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                                      color: hasAvailable ? AppColors.statusAvailable : AppColors.statusOffline)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text(trailingText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: trailingColor)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onNavigate,
                    style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                    child: const Text('길찾기'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDetail,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('상세보기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
