import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../models/remote_survey.dart';
import '../models/tower.dart';
import '../providers/api_survey_provider.dart';
import '../services/tower_service.dart';

class MapPage extends StatefulWidget {
  static const routeName = '/map';
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

enum MapLayerCategory {
  towerBts,
  vsatBakti,
  bantuanStarlink,
  surveiBlankspot4g,
  surveiJaringanSeluler,
  wifiPublik,
}

enum SignalRange {
  lte4g,
  hsdpa3_5g,
  g3,
  edge,
  gprs,
  g2,
}

enum TowerAirStatus {
  onAir,
  offAir,
}

class MapPoint {
  final String id;
  final String kecamatan;
  final LatLng coordinate;
  final MapLayerCategory category;
  final SignalRange signalRange;
  final String title;
  final TowerAirStatus? towerStatus;

  const MapPoint({
    required this.id,
    required this.kecamatan,
    required this.coordinate,
    required this.category,
    required this.signalRange,
    required this.title,
    this.towerStatus,
  });
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  // Diisi otomatis dari GeoJSON asset saat initState
  Map<String, List<LatLng>> _wilayahKecamatan = {};

  final Map<String, Color> _kecamatanColors = const {
    'Dusun Timur': Color(0xFF28A745),
    'Dusun Tengah': Color(0xFF33FF57),
    'Benua Lima': Color(0xFF007BFF),
    'Patangkep Tutui': Color(0xFFDC3605),
    'Awang': Color(0xFF7FFA41),
    'Paju Epat': Color(0xFF997BF0),
    'Karusen Janang': Color(0xFF2FF5FF),
    'Paku': Color(0xFFFFAA45),
    'Pematang Karau': Color(0xFFFFF545),
    'Raren Batuah': Color(0xFF4606FF),
  };

  final Map<SignalRange, Color> _technologyColors = const {
    SignalRange.lte4g: Color(0xFF28A745),
    SignalRange.hsdpa3_5g: Color(0xFF007BFF),
    SignalRange.g3: Color(0xFFF97316),
    SignalRange.edge: Color(0xFFEAB308),
    SignalRange.gprs: Color(0xFF7C3AED),
    SignalRange.g2: Color(0xFFDC3545),
  };

  final Set<MapLayerCategory> _filterCategories = const {
    MapLayerCategory.towerBts,
  };

  late Set<String> _selectedKecamatan;
  late Set<MapLayerCategory> _selectedCategories;
  late Set<SignalRange> _selectedRanges;
  late Set<TowerAirStatus> _selectedTowerStates;

  bool _showAllDisplay = true;
  bool _showAllRange = true;
  bool _showTowerLayer = false;
  bool _showSurveySeluler = true;
  bool _isLoadingTowers = false;
  bool _isLoadingSurveys = false;
  String? _fetchError;
  StateSetter? _modalFilterSetState;
  final ApiSurveyProvider _surveyApi = ApiSurveyProvider();
  final int _currentYear = DateTime.now().year;
  final List<int> _quickSurveyYears = const [2024, 2025, 2026];
  late int _selectedSurveyYear;
  List<int> _availableSurveyYears = [];

  // Data dari API
  List<MapPoint> _apiTowerPoints = [];
  List<MapPoint> _apiSurveyPoints = [];
  final Map<String, RemoteSurvey> _surveyData = {};

  // Dummy non-tower points dihapus: data peta sekarang diambil dari API.
  final List<MapPoint> _staticPoints = const [];

  int _mapDataRevision = 0;
  int _filterRevision = 0;
  int _polygonCacheRevision = -1;
  String? _filteredPointsCacheKey;
  List<MapPoint>? _filteredPointsCache;
  String? _rangeCirclesCacheKey;
  List<CircleMarker>? _rangeCirclesCache;
  String? _polygonLayerCacheKey;
  List<Polygon>? _polygonLayerCache;
  String? _kecamatanLabelsCacheKey;
  List<Marker>? _kecamatanLabelsCache;
  String? _markersCacheKey;
  List<Marker>? _markersCache;
  final Map<String, List<LatLng>> _polygonCoordsCache = {};
  int _countsCacheRevision = -1;
  final Map<MapLayerCategory, int> _categoryCountCache = {};
  int _towerOnAirCountCache = 0;
  int _towerOffAirCountCache = 0;

  List<MapPoint> get _points => [
        ..._apiTowerPoints,
        ..._apiSurveyPoints,
        ..._staticPoints,
      ];

  String get _derivedCacheKey => 'd$_mapDataRevision-f$_filterRevision';

  void _invalidateFilterCaches() {
    _filterRevision += 1;
    _filteredPointsCacheKey = null;
    _rangeCirclesCacheKey = null;
    _polygonLayerCacheKey = null;
    _kecamatanLabelsCacheKey = null;
    _markersCacheKey = null;
  }

  void _invalidateMapDataCaches() {
    _mapDataRevision += 1;
    _polygonCacheRevision = -1;
    _countsCacheRevision = -1;
    _polygonCoordsCache.clear();
    _invalidateFilterCaches();
  }

  void _ensureCountsCache() {
    if (_countsCacheRevision == _mapDataRevision) {
      return;
    }

    _categoryCountCache
      ..clear()
      ..addEntries(MapLayerCategory.values.map((category) => MapEntry(category, 0)));
    _towerOnAirCountCache = 0;
    _towerOffAirCountCache = 0;

    for (final point in _points) {
      _categoryCountCache.update(
        point.category,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      if (point.category == MapLayerCategory.towerBts) {
        if (point.towerStatus == TowerAirStatus.onAir) {
          _towerOnAirCountCache += 1;
        } else if (point.towerStatus == TowerAirStatus.offAir) {
          _towerOffAirCountCache += 1;
        }
      }
    }

    _countsCacheRevision = _mapDataRevision;
  }

  void _applyFilterChange(VoidCallback change) {
    if (!mounted) return;
    setState(() {
      change();
      _invalidateFilterCaches();
    });
    _modalFilterSetState?.call(() {});
  }

  // Map untuk menyimpan data tower asli (untuk detail popup)
  final Map<String, Tower> _towerData = {};

  @override
  void dispose() {
    _surveyApi.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedKecamatan = _kecamatanColors.keys.toSet();
    _selectedCategories = <MapLayerCategory>{};
    _selectedRanges = SignalRange.values.toSet();
    _selectedTowerStates = TowerAirStatus.values.toSet();
    _selectedSurveyYear = _currentYear;
    _availableSurveyYears = [_currentYear];
    _showAllDisplay = false;
    _showTowerLayer = false;
    _showSurveySeluler = true;
    _loadKecamatanBoundaries();
    _loadAvailableSurveyYears();
    _fetchTowers();
    _fetchSurveiJaringanSeluler(year: _selectedSurveyYear);
  }

  Future<void> _loadAvailableSurveyYears() async {
    final years = await _surveyApi.fetchAvailableSurveyYears();
    if (!mounted) return;

    final previousSelectedYear = _selectedSurveyYear;
    final normalized = years.isEmpty ? <int>[_currentYear] : years;
    final selected = normalized.contains(_selectedSurveyYear)
        ? _selectedSurveyYear
        : normalized.first;

    _applyFilterChange(() {
      _availableSurveyYears = normalized;
      _selectedSurveyYear = selected;
    });

    if (selected != previousSelectedYear) {
      _fetchSurveiJaringanSeluler(year: selected);
    }
  }

  Future<void> _loadKecamatanBoundaries() async {
    try {
      final grouped = await TowerService.fetchWilayahPolygons();
      if (grouped.isEmpty) return;

      final result = <String, List<LatLng>>{};
      for (final entry in grouped.entries) {
        final normalizedKec = _normalizeKecamatan(entry.key);
        final points = entry.value
            .map((w) => LatLng(w.latitude, w.longitude))
            .toList();
        if (points.length >= 3) {
          result[normalizedKec] = points;
        }
      }

      if (mounted) {
        setState(() {
          _wilayahKecamatan = result;
          _invalidateMapDataCaches();
        });
      }
    } catch (e) {
      debugPrint('Wilayah load error: $e');
    }
  }

  Future<void> _fetchTowers() async {
    setState(() {
      _isLoadingTowers = true;
      _fetchError = null;
    });

    try {
      final towers = await TowerService.fetchAllTowers();

      final mapPoints = <MapPoint>[];
      for (final tower in towers) {
        // Lewati tower dengan koordinat tidak valid
        if (tower.latitude == 0.0 && tower.longitude == 0.0) continue;

        final status = tower.status == 'on_air'
            ? TowerAirStatus.onAir
            : TowerAirStatus.offAir;

        final point = MapPoint(
          id: 'tower_${tower.id}',
          kecamatan: _normalizeKecamatan(tower.kecamatan),
          coordinate: LatLng(tower.latitude, tower.longitude),
          category: MapLayerCategory.towerBts,
          signalRange: SignalRange.lte4g,
          title: tower.siteName.isNotEmpty ? tower.siteName : 'Tower - ${tower.desa}',
          towerStatus: status,
        );

        mapPoints.add(point);
        _towerData['tower_${tower.id}'] = tower;
      }

      setState(() {
        _apiTowerPoints = mapPoints;
        _isLoadingTowers = false;
        _invalidateMapDataCaches();
      });
    } catch (e) {
      setState(() {
        _fetchError = 'Gagal memuat data tower';
        _isLoadingTowers = false;
      });
    }
  }

  Future<void> _fetchSurveiJaringanSeluler({required int year}) async {
    setState(() => _isLoadingSurveys = true);
    try {
      final surveys = await _surveyApi.fetchSurveysByYear(year: year);
      final points = <MapPoint>[];
      _surveyData.clear();

      for (final survey in surveys) {
        final lat = double.tryParse(survey.latitude) ?? 0;
        final lng = double.tryParse(survey.longitude) ?? 0;
        if (lat == 0 || lng == 0) {
          continue;
        }

        final id = 'survey_${survey.id}';
        points.add(
          MapPoint(
            id: id,
            kecamatan: _normalizeKecamatan(survey.kecamatan),
            coordinate: LatLng(lat, lng),
            category: MapLayerCategory.surveiJaringanSeluler,
            signalRange: _surveySignalRange(survey),
            title: 'Survei ${survey.operator} - ${survey.desa} (${survey.tahunSurvei})',
          ),
        );
        _surveyData[id] = survey;
      }

      if (mounted) {
        setState(() {
          _apiSurveyPoints = points;
          _isLoadingSurveys = false;
          _invalidateMapDataCaches();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _apiSurveyPoints = [];
          _isLoadingSurveys = false;
          _invalidateMapDataCaches();
        });
      }
    }
  }

  List<MapPoint> get _filteredPoints {
    final cacheKey = _derivedCacheKey;
    if (_filteredPointsCacheKey == cacheKey && _filteredPointsCache != null) {
      return _filteredPointsCache!;
    }

    final computed = _points.where((point) {
      final kecamatanOk = _selectedKecamatan.contains(point.kecamatan);
      final categoryOk = point.category == MapLayerCategory.surveiJaringanSeluler
          ? _showSurveySeluler
          : point.category == MapLayerCategory.towerBts
              ? _showTowerLayer && _selectedCategories.contains(point.category)
              : false;
      final rangeOk = _selectedRanges.contains(point.signalRange);
      final towerStateOk = point.category != MapLayerCategory.towerBts ||
          (point.towerStatus != null &&
              _selectedTowerStates.contains(point.towerStatus!));
      return kecamatanOk && categoryOk && rangeOk && towerStateOk;
    }).toList();

    _filteredPointsCacheKey = cacheKey;
    _filteredPointsCache = computed;
    return computed;
  }

  int _countByCategory(MapLayerCategory category) {
    _ensureCountsCache();
    return _categoryCountCache[category] ?? 0;
  }

  int get _towerOnAirCount {
    _ensureCountsCache();
    return _towerOnAirCountCache;
  }

  int get _towerOffAirCount {
    _ensureCountsCache();
    return _towerOffAirCountCache;
  }

  SignalRange _surveySignalRange(RemoteSurvey survey) {
    final jaringan = survey.jaringan.toLowerCase();
    if (jaringan.contains('4g') || jaringan.contains('lte')) {
      return SignalRange.lte4g;
    }
    if (jaringan.contains('edge')) {
      return SignalRange.edge;
    }
    if (jaringan.contains('gprs')) {
      return SignalRange.gprs;
    }
    if (jaringan.contains('3.5') || jaringan.contains('hsdpa')) {
      return SignalRange.hsdpa3_5g;
    }
    if (jaringan.contains('3g')) {
      return SignalRange.g3;
    }
    return SignalRange.g2;
  }

  String _categoryLabel(MapLayerCategory category) {
    switch (category) {
      case MapLayerCategory.towerBts:
        return 'Tower BTS';
      case MapLayerCategory.vsatBakti:
        return 'VSAT BAKTI';
      case MapLayerCategory.bantuanStarlink:
        return 'Bantuan Starlink';
      case MapLayerCategory.surveiBlankspot4g:
        return 'Survei Blankspot 4G';
      case MapLayerCategory.surveiJaringanSeluler:
        return 'Survei Jaringan Seluler';
      case MapLayerCategory.wifiPublik:
        return 'Wifi Publik';
    }
  }

  String _rangeLabel(SignalRange range) {
    switch (range) {
      case SignalRange.lte4g:
        return '4G / LTE';
      case SignalRange.hsdpa3_5g:
        return '3.5G / HSDPA';
      case SignalRange.g3:
        return '3G';
      case SignalRange.edge:
        return 'EDGE';
      case SignalRange.gprs:
        return 'GPRS';
      case SignalRange.g2:
        return '2G';
    }
  }

  String _rangeLogoText(SignalRange range) {
    switch (range) {
      case SignalRange.lte4g:
        return '4G';
      case SignalRange.edge:
        return 'E';
      case SignalRange.gprs:
        return 'G';
      case SignalRange.hsdpa3_5g:
        return 'H';
      case SignalRange.g3:
        return '3G';
      case SignalRange.g2:
        return '2G';
    }
  }

  IconData _categoryIcon(MapLayerCategory category) {
    switch (category) {
      case MapLayerCategory.towerBts:
        return Icons.cell_tower;
      case MapLayerCategory.vsatBakti:
        return Icons.satellite_alt_outlined;
      case MapLayerCategory.bantuanStarlink:
        return Icons.settings_input_antenna;
      case MapLayerCategory.surveiBlankspot4g:
        return Icons.portable_wifi_off;
      case MapLayerCategory.surveiJaringanSeluler:
        return Icons.network_cell;
      case MapLayerCategory.wifiPublik:
        return Icons.wifi;
    }
  }

  Color _categoryColor(MapLayerCategory category) {
    switch (category) {
      case MapLayerCategory.towerBts:
        return const Color(0xFF2563EB);
      case MapLayerCategory.vsatBakti:
        return const Color(0xFF0EA5E9);
      case MapLayerCategory.bantuanStarlink:
        return const Color(0xFFF59E0B);
      case MapLayerCategory.surveiBlankspot4g:
        return const Color(0xFFEF4444);
      case MapLayerCategory.surveiJaringanSeluler:
        return const Color(0xFF10B981);
      case MapLayerCategory.wifiPublik:
        return const Color(0xFF8B5CF6);
    }
  }

  double _rangeRadius(SignalRange range) {
    switch (range) {
      case SignalRange.lte4g:
        return 600;
      case SignalRange.hsdpa3_5g:
        return 420;
      case SignalRange.g3:
        return 300;
      case SignalRange.edge:
        return 220;
      case SignalRange.gprs:
        return 160;
      case SignalRange.g2:
        return 180;
    }
  }

  Widget _badge(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFF475569)).withAlpha(36),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color ?? const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _panelCard({required Widget child}) {
    final isWide = MediaQuery.of(context).size.width >= 980;

    return Container(
      width: isWide ? 265 : double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xF8FFFFFF),
            Color(0xF2F8FAFF),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          checkboxTheme: CheckboxThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            side: const BorderSide(color: Color(0xFF93A9C7)),
            visualDensity: VisualDensity.compact,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _panelTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        fontSize: 14.5,
        color: Color(0xFF0B2340),
      ),
    );
  }

  Widget _leftKecamatanPanel() {
    final allKecamatanChecked =
        _selectedKecamatan.length == _kecamatanColors.length;

    return _panelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _panelTitle('Wilayah Kecamatan'),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: allKecamatanChecked,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (value) {
              _applyFilterChange(() {
                if (value == true) {
                  _selectedKecamatan = _kecamatanColors.keys.toSet();
                } else {
                  _selectedKecamatan = <String>{};
                }
              });
            },
            title: const Text('Semua Kecamatan', style: TextStyle(fontSize: 13.2)),
          ),
          ..._kecamatanColors.entries.map((entry) {
            final selected = _selectedKecamatan.contains(entry.key);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: selected,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                _applyFilterChange(() {
                  if (value == true) {
                    _selectedKecamatan.add(entry.key);
                  } else {
                    _selectedKecamatan.remove(entry.key);
                  }
                });
              },
              title: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: entry.value,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 13.2),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _rightFilterPanel() {
    return _panelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _panelTitle('Filter Tampilan'),
              const Spacer(),
              IconButton(
                onPressed: () {
                  _applyFilterChange(() {
                    _showAllDisplay = !_showAllDisplay;
                    _showSurveySeluler = _showAllDisplay;
                    _showTowerLayer = _showAllDisplay;
                    _selectedCategories = _showTowerLayer
                        ? _filterCategories.toSet()
                        : <MapLayerCategory>{};
                  });
                },
                icon: const Icon(Icons.remove, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: 'Toggle semua layer',
              ),
            ],
          ),
          CheckboxListTile(
            dense: true,
            value: _showAllDisplay,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              _applyFilterChange(() {
                _showAllDisplay = value ?? false;
                _showSurveySeluler = _showAllDisplay;
                _showTowerLayer = _showAllDisplay;
                _selectedCategories = _showTowerLayer
                    ? _filterCategories.toSet()
                    : <MapLayerCategory>{};
              });
            },
            title: const Text('Tampilkan Semua', style: TextStyle(fontSize: 13.2)),
          ),
          ..._filterCategories.map((category) {
            final selected = _showTowerLayer && _selectedCategories.contains(category);
            return CheckboxListTile(
              dense: true,
              value: selected,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                _applyFilterChange(() {
                  _showTowerLayer = value == true;
                  if (_showTowerLayer) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                  _showAllDisplay = _showSurveySeluler && _showTowerLayer;
                });
              },
              title: Row(
                children: [
                  Icon(
                    _categoryIcon(category),
                    size: 15,
                    color: _categoryColor(category),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _categoryLabel(category),
                      style: const TextStyle(fontSize: 13.2),
                    ),
                  ),
                  _badge(
                    '${_countByCategory(category)}',
                    color: const Color(0xFF475569),
                  ),
                ],
              ),
            );
          }),
            if (_showTowerLayer &&
              _selectedCategories.contains(MapLayerCategory.towerBts)) ...[
            const SizedBox(height: 4),
            CheckboxListTile(
              dense: true,
              value:
                  _selectedTowerStates.length == TowerAirStatus.values.length,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                _applyFilterChange(() {
                  _selectedTowerStates = value == true
                      ? TowerAirStatus.values.toSet()
                      : <TowerAirStatus>{};
                });
              },
              title: const Text('Semua Status Tower', style: TextStyle(fontSize: 13.2)),
            ),
            Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    value: _selectedTowerStates.contains(TowerAirStatus.onAir),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      _applyFilterChange(() {
                        if (value == true) {
                          _selectedTowerStates.add(TowerAirStatus.onAir);
                        } else {
                          _selectedTowerStates.remove(TowerAirStatus.onAir);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(child: Text('On Air', style: TextStyle(fontSize: 13))),
                        _badge('$_towerOnAirCount', color: const Color(0xFF16A34A)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    value: _selectedTowerStates.contains(TowerAirStatus.offAir),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      _applyFilterChange(() {
                        if (value == true) {
                          _selectedTowerStates.add(TowerAirStatus.offAir);
                        } else {
                          _selectedTowerStates.remove(TowerAirStatus.offAir);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(child: Text('Off Air', style: TextStyle(fontSize: 13))),
                        _badge('$_towerOffAirCount', color: const Color(0xFFDC2626)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          _panelTitle('Survei Jaringan Seluler'),
          CheckboxListTile(
            dense: true,
            value: _showSurveySeluler,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              _applyFilterChange(() {
                _showSurveySeluler = value ?? false;
                _showAllDisplay = _showSurveySeluler && _showTowerLayer;
              });
            },
            title: Row(
              children: [
                const Expanded(
                  child: Text('Tampilkan Survei', style: TextStyle(fontSize: 13.2)),
                ),
                _badge('${_apiSurveyPoints.length}', color: const Color(0xFF10B981)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD7E4F6)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedSurveyYear,
                isExpanded: true,
                items: _availableSurveyYears
                    .map(
                      (year) => DropdownMenuItem<int>(
                        value: year,
                        child: Text('Tahun $year'),
                      ),
                    )
                    .toList(),
                onChanged: (year) {
                  if (year == null || year == _selectedSurveyYear) {
                    return;
                  }
                  _applyFilterChange(() {
                    _selectedSurveyYear = year;
                  });
                  _fetchSurveiJaringanSeluler(year: year);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          _panelTitle('Jangkauan Sinyal Tower'),
          CheckboxListTile(
            dense: true,
            value: _showAllRange,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              _applyFilterChange(() {
                _showAllRange = value ?? false;
                _selectedRanges = _showAllRange
                    ? SignalRange.values.toSet()
                    : <SignalRange>{};
              });
            },
            title: const Text('Semua Jangkauan', style: TextStyle(fontSize: 13.2)),
          ),
          ...SignalRange.values.map((range) {
            final selected = _selectedRanges.contains(range);
            return CheckboxListTile(
              dense: true,
              value: selected,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                _applyFilterChange(() {
                  if (value == true) {
                    _selectedRanges.add(range);
                  } else {
                    _selectedRanges.remove(range);
                  }
                  _showAllRange = _selectedRanges.length == SignalRange.values.length;
                });
              },
              title: Row(
                children: [
                  Container(
                    width: 26,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _technologyColors[range],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      _rangeLogoText(range),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(_rangeLabel(range), style: const TextStyle(fontSize: 13.2)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<CircleMarker> _buildRangeCircles() {
    final cacheKey = '$_derivedCacheKey-circles';
    if (_rangeCirclesCacheKey == cacheKey && _rangeCirclesCache != null) {
      return _rangeCirclesCache!;
    }

    final computed = _filteredPoints
        .where((point) => point.category == MapLayerCategory.towerBts)
        .map((point) {
      final color = _technologyColors[point.signalRange] ?? const Color(0xFF2563EB);
      return CircleMarker(
        point: point.coordinate,
        radius: _rangeRadius(point.signalRange),
        useRadiusInMeter: true,
        color: color.withAlpha(28),
        borderColor: color.withAlpha(160),
        borderStrokeWidth: 1,
      );
    }).toList();

    _rangeCirclesCacheKey = cacheKey;
    _rangeCirclesCache = computed;
    return computed;
  }

  List<Polygon> _buildKecamatanPolygons() {
    final cacheKey = '$_derivedCacheKey-polygons';
    if (_polygonLayerCacheKey == cacheKey && _polygonLayerCache != null) {
      return _polygonLayerCache!;
    }

    final polygons = <Polygon>[];

    for (final kec in _kecamatanColors.keys) {
      if (!_selectedKecamatan.contains(kec)) {
        continue;
      }

      final coords = _polygonCoordsForKecamatan(kec);
      if (coords.length < 3) {
        continue;
      }

      final color = _kecamatanColors[kec] ?? const Color(0xFF64748B);
      polygons.add(
        Polygon(
          points: coords,
          color: color.withAlpha(22),
          borderColor: color.withAlpha(210),
          borderStrokeWidth: 2,
        ),
      );
    }

    _polygonLayerCacheKey = cacheKey;
    _polygonLayerCache = polygons;
    return polygons;
  }

  List<Marker> _buildKecamatanLabels() {
    final cacheKey = '$_derivedCacheKey-labels';
    if (_kecamatanLabelsCacheKey == cacheKey && _kecamatanLabelsCache != null) {
      return _kecamatanLabelsCache!;
    }

    final labels = <Marker>[];

    for (final kec in _kecamatanColors.keys) {
      if (!_selectedKecamatan.contains(kec)) {
        continue;
      }

      final coords = _polygonCoordsForKecamatan(kec);
      if (coords.length < 3) {
        continue;
      }

      final center = _centroid(coords);
      labels.add(
        Marker(
          point: center,
          width: 150,
          height: 26,
          child: IgnorePointer(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                'Kecamatan: $kec',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.8,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ),
        ),
      );
    }

    _kecamatanLabelsCacheKey = cacheKey;
    _kecamatanLabelsCache = labels;
    return labels;
  }

  List<LatLng> _polygonCoordsForKecamatan(String kec) {
    if (_polygonCacheRevision != _mapDataRevision) {
      _polygonCoordsCache.clear();
      _polygonCacheRevision = _mapDataRevision;
    }
    final cached = _polygonCoordsCache[kec];
    if (cached != null) {
      return cached;
    }

    final explicit = _wilayahKecamatan[kec] ?? const <LatLng>[];
    final validExplicit = explicit.where(_isValidCoordinate).toList();
    if (validExplicit.length >= 3) {
      final closed = _closePolygon(validExplicit);
      _polygonCoordsCache[kec] = closed;
      return closed;
    }

    final fallbackPoints = _points
      .where((p) => _normalizeKecamatan(p.kecamatan) == _normalizeKecamatan(kec))
        .map((p) => p.coordinate)
        .where(_isValidCoordinate)
        .toList();
    if (fallbackPoints.length < 3) {
      return const <LatLng>[];
    }

    final hull = _convexHull(fallbackPoints);
    if (hull.length < 3) {
      return const <LatLng>[];
    }
    final closed = _closePolygon(hull);
    _polygonCoordsCache[kec] = closed;
    return closed;
  }

  List<LatLng> _convexHull(List<LatLng> points) {
    if (points.length <= 3) {
      return points;
    }

    final sorted = [...points]
      ..sort((a, b) {
        final byLng = a.longitude.compareTo(b.longitude);
        if (byLng != 0) return byLng;
        return a.latitude.compareTo(b.latitude);
      });

    double cross(LatLng o, LatLng a, LatLng b) {
      return (a.longitude - o.longitude) * (b.latitude - o.latitude) -
          (a.latitude - o.latitude) * (b.longitude - o.longitude);
    }

    final lower = <LatLng>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower[lower.length - 1], p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }

    final upper = <LatLng>[];
    for (final p in sorted.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper[upper.length - 1], p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }

    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  bool _isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) {
      return false;
    }

    // Ray-casting: longitude sebagai sumbu x, latitude sebagai sumbu y.
    var inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;

      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
      if (intersect) {
        inside = !inside;
      }
    }
    return inside;
  }

  String? _kecamatanFromTap(LatLng tapPoint) {
    for (final kec in _kecamatanColors.keys) {
      final coords = _polygonCoordsForKecamatan(kec);
      if (coords.length >= 3 && _isPointInsidePolygon(tapPoint, coords)) {
        return kec;
      }
    }
    return null;
  }

  void _focusKecamatan(String kecamatan) {
    final coords = _polygonCoordsForKecamatan(kecamatan);
    if (coords.length < 3) {
      return;
    }

    _applyFilterChange(() {
      _selectedKecamatan = {kecamatan};
      _selectedTowerStates = TowerAirStatus.values.toSet();
      _selectedRanges = SignalRange.values.toSet();
      _showAllRange = true;
    });

    final bounds = LatLngBounds.fromPoints(coords);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(36),
      ),
    );
  }

  String _normalizeKecamatan(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean == 'banua lima' || clean == 'benua lima') {
      return 'Benua Lima';
    }
    if (clean == 'dusun timur') return 'Dusun Timur';
    if (clean == 'dusun tengah') return 'Dusun Tengah';
    if (clean == 'patangkep tutui') return 'Patangkep Tutui';
    if (clean == 'awang') return 'Awang';
    if (clean == 'paju epat') return 'Paju Epat';
    if (clean == 'karusen janang') return 'Karusen Janang';
    if (clean == 'paku') return 'Paku';
    if (clean == 'pematang karau') return 'Pematang Karau';
    if (clean == 'raren batuah') return 'Raren Batuah';
    return raw.trim();
  }

  bool _isValidCoordinate(LatLng point) {
    return point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  List<LatLng> _closePolygon(List<LatLng> coords) {
    if (coords.isEmpty) {
      return coords;
    }
    final first = coords.first;
    final last = coords.last;
    final samePoint = first.latitude == last.latitude &&
        first.longitude == last.longitude;
    if (samePoint) {
      return coords;
    }
    return [...coords, first];
  }

  LatLng _centroid(List<LatLng> coords) {
    var lat = 0.0;
    var lng = 0.0;
    for (final c in coords) {
      lat += c.latitude;
      lng += c.longitude;
    }
    return LatLng(lat / coords.length, lng / coords.length);
  }

  List<Marker> _buildMarkers() {
    final cacheKey = '$_derivedCacheKey-markers';
    if (_markersCacheKey == cacheKey && _markersCache != null) {
      return _markersCache!;
    }

    final computed = _filteredPoints.map((point) {
      final isTower = point.category == MapLayerCategory.towerBts;
      final towerColor = point.towerStatus == TowerAirStatus.offAir
          ? const Color(0xFFEF4444)
          : const Color(0xFF22C55E);
      final markerColor = isTower ? towerColor : _categoryColor(point.category);

      return Marker(
        point: point.coordinate,
        width: 42,
        height: 42,
        child: Tooltip(
          message: point.title,
          child: InkWell(
            onTap: () {
              final tower = _towerData[point.id];
              if (tower != null) {
                _showTowerDetail(context, tower);
                return;
              }

              final survey = _surveyData[point.id];
              if (survey != null) {
                _showSurveyDetail(context, survey);
                return;
              } else {
                final subtitle = isTower && point.towerStatus != null
                    ? ' (${point.towerStatus == TowerAirStatus.onAir ? 'On Air' : 'Off Air'})'
                    : '';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${point.title}$subtitle')),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: markerColor.withAlpha(34),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: markerColor, width: 1.2),
              ),
              child: point.category == MapLayerCategory.surveiJaringanSeluler
                  ? Center(
                      child: Container(
                        width: 24,
                        height: 14,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: markerColor,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _rangeLogoText(point.signalRange),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  : Icon(
                      _categoryIcon(point.category),
                      color: markerColor,
                      size: 22,
                    ),
            ),
          ),
        ),
      );
    }).toList();

    _markersCacheKey = cacheKey;
    _markersCache = computed;
    return computed;
  }

  void _showTowerDetail(BuildContext context, Tower tower) {
    final isOnAir = tower.status == 'on_air';
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cell_tower,
                      color: isOnAir ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tower.siteName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOnAir
                            ? const Color(0xFF22C55E).withAlpha(30)
                            : const Color(0xFFEF4444).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOnAir ? 'On Air' : 'Off Air',
                        style: TextStyle(
                          color: isOnAir ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _detailRow(Icons.location_on, 'Kecamatan', tower.kecamatan),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _detailRow(Icons.holiday_village, 'Desa', tower.desa),
                        ),
                        if (tower.siteId != null && tower.siteId!.isNotEmpty)
                          SizedBox(
                            width: tileWidth,
                            child: _detailRow(Icons.tag, 'Site ID', tower.siteId!),
                          ),
                        if (tower.operator != null && tower.operator!.isNotEmpty)
                          SizedBox(
                            width: tileWidth,
                            child: _detailRow(Icons.business, 'Operator', tower.operator!),
                          ),
                        if (tower.tinggi != null)
                          SizedBox(
                            width: tileWidth,
                            child: _detailRow(Icons.height, 'Tinggi', '${tower.tinggi} m'),
                          ),
                        if (tower.tipeBentukMenara != null && tower.tipeBentukMenara!.isNotEmpty)
                          SizedBox(
                            width: tileWidth,
                            child: _detailRow(Icons.account_tree, 'Tipe Bentuk', tower.tipeBentukMenara!),
                          ),
                        if (tower.konstruksiMenara != null && tower.konstruksiMenara!.isNotEmpty)
                          SizedBox(
                            width: tileWidth,
                            child: _detailRow(Icons.architecture, 'Konstruksi', tower.konstruksiMenara!),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _towerPhotoSection(),
                const SizedBox(height: 4),
                _coordinateSection(
                  latitude: tower.latitude,
                  longitude: tower.longitude,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSurveyDetail(BuildContext context, RemoteSurvey survey) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.network_cell, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Survei ${survey.operator}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        survey.tahunSurvei,
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _detailRow(Icons.location_on, 'Kecamatan', survey.kecamatan),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _detailRow(Icons.holiday_village, 'Desa', survey.desa),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _detailRow(Icons.settings_input_antenna, 'Jaringan', survey.jaringan),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _detailRow(
                            Icons.signal_cellular_alt,
                            'Kekuatan Sinyal',
                            survey.kekuatanSinyal,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Parameter Radio',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _surveyMetricCard('RSRP', survey.rsrp != null ? '${survey.rsrp} dBm' : '-'),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _surveyMetricCard('RSRQ', survey.rsrq != null ? '${survey.rsrq} dB' : '-'),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _surveyMetricCard('SINR', survey.sinr != null ? '${survey.sinr} dB' : '-'),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _surveyMetricCard('RSSI', survey.rssi != null ? '${survey.rssi} dBm' : '-'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Speedtest',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _speedMetricCard(
                            icon: Icons.download_rounded,
                            label: 'Download',
                            value: '${survey.downloadSpeed ?? 0} Mbps',
                            iconColor: const Color(0xFF2563EB),
                            backgroundColor: const Color(0xFFEFF6FF),
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _speedMetricCard(
                            icon: Icons.upload_rounded,
                            label: 'Upload',
                            value: '${survey.uploadSpeed ?? 0} Mbps',
                            iconColor: const Color(0xFF16A34A),
                            backgroundColor: const Color(0xFFF0FDF4),
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _speedMetricCard(
                            icon: Icons.timer_outlined,
                            label: 'Ping',
                            value: survey.ping != null ? '${survey.ping} ms' : '-',
                            iconColor: const Color(0xFFEA580C),
                            backgroundColor: const Color(0xFFFFF7ED),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _surveyPhotoSection(survey),
                const SizedBox(height: 4),
                _coordinateSection(
                  latitude: double.tryParse(survey.latitude) ?? 0,
                  longitude: double.tryParse(survey.longitude) ?? 0,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _surveyMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _speedMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconColor.withAlpha(45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isTemporaryUploadPath(String raw) {
    final trimmed = raw.trim();
    return trimmed.startsWith('/tmp/') || trimmed.startsWith('tmp/');
  }

  void _showPhotoPreview(BuildContext context, String photoUrl, String title, {bool fullscreen = false}) {
    if (fullscreen) {
      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          fullscreenDialog: true,
          pageBuilder: (context, animation, secondaryAnimation) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: EdgeInsets.zero,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) {
                          return child;
                        }
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            'Gagal memuat foto',
                            style: TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.65,
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: InteractiveViewer(
                        panEnabled: true,
                        boundaryMargin: const EdgeInsets.all(10),
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) {
                              return child;
                            }
                            return Container(
                              color: Colors.grey[300],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Text(
                                  'Gagal memuat foto',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(200),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  String _buildSurveyPhotoUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (_isTemporaryUploadPath(trimmed)) {
      return '';
    }

    var normalized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    if (normalized.startsWith('public/')) {
      normalized = normalized.substring('public/'.length);
    }
    if (normalized.startsWith('storage/')) {
      normalized = normalized.substring('storage/'.length);
    }
    return AppConfig.storageUrl(normalized);
  }

  Widget _surveyPhotoSection(RemoteSurvey survey) {
    final raw = survey.fotoLokasiSurvei;
    final isTemporary = _isTemporaryUploadPath(raw);
    final photoUrl = _buildSurveyPhotoUrl(raw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Lokasi',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            if (photoUrl.isNotEmpty && !isTemporary && raw.trim().isNotEmpty) {
              _showPhotoPreview(context, photoUrl, 'Foto Lokasi Survei');
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 160,
              width: double.infinity,
              color: const Color(0xFFF1F5F9),
              child: () {
                if (raw.trim().isEmpty) {
                  return const Center(
                    child: Text(
                      'Foto tidak tersedia',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                  );
                }

                if (isTemporary || photoUrl.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Path foto belum valid atau masih sementara.\nPerlu upload ulang foto.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) {
                          return child;
                        }
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Gagal memuat foto dari server',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(120),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                );
              }(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _towerPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dokumentasi Menara',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            width: double.infinity,
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 32,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Dokumentasi menara belum tersedia',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 14, color: const Color(0xFF334155)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coordinateSection({
    required double latitude,
    required double longitude,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Koordinat Lokasi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            _miniCoordinatePreview(latitude: latitude, longitude: longitude),
            const SizedBox(height: 2),
            Text(
              '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => _openCoordinateInMaps(latitude, longitude),
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Buka di Maps', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniCoordinatePreview({
    required double latitude,
    required double longitude,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 110,
        width: double.infinity,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(latitude, longitude),
                initialZoom: 13,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.sigaptel',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(latitude, longitude),
                      width: 26,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF2563EB),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFF2563EB),
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x4D0F172A),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCoordinateInMaps(double latitude, double longitude) async {
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    final geoUrl = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      return;
    }

    if (await canLaunchUrl(geoUrl)) {
      await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aplikasi Maps tidak tersedia di perangkat ini.')),
    );
  }

  void _resetToAllPolygons() {
    _applyFilterChange(() {
      _selectedKecamatan = _kecamatanColors.keys.toSet();
      _selectedCategories = <MapLayerCategory>{};
      _selectedRanges = SignalRange.values.toSet();
      _selectedTowerStates = TowerAirStatus.values.toSet();
      _showTowerLayer = false;
      _showSurveySeluler = true;
      _showAllDisplay = false;
      _showAllRange = true;
    });

    final allPolygonPoints = <LatLng>[];
    for (final kec in _kecamatanColors.keys) {
      final coords = _polygonCoordsForKecamatan(kec);
      if (coords.length >= 3) {
        allPolygonPoints.addAll(coords);
      }
    }

    if (allPolygonPoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(allPolygonPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(28),
        ),
      );
    }
  }

  Widget _showAllPolygonsButton() {
    return Positioned(
      right: 16,
      bottom: 20,
      child: FloatingActionButton.small(
        heroTag: 'mapShowAllPolygonBtn',
        tooltip: 'Tampilkan semua polygon',
        onPressed: _resetToAllPolygons,
        backgroundColor: Colors.white,
        child: const Icon(Icons.select_all),
      ),
    );
  }

  Widget _inlineLayerChip({
    required bool selected,
    required IconData icon,
    required String label,
    required ValueChanged<bool> onSelected,
    required Color iconColor,
  }) {
    return FilterChip(
      selected: selected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 1),
      avatarBoxConstraints: const BoxConstraints(minHeight: 12, minWidth: 12),
      avatar: Icon(icon, size: 11, color: iconColor),
      label: Text(label, style: const TextStyle(fontSize: 10.5)),
      onSelected: onSelected,
    );
  }

  Future<void> _setSurveyYear(int year) async {
    if (year == _selectedSurveyYear) {
      return;
    }

    _applyFilterChange(() {
      _selectedSurveyYear = year;
    });
    await _fetchSurveiJaringanSeluler(year: year);
  }

  Widget _inlineYearFilter() {
    return PopupMenuButton<int>(
      tooltip: 'Filter tahun survei',
      initialValue: _selectedSurveyYear,
      padding: EdgeInsets.zero,
      onSelected: _setSurveyYear,
      itemBuilder: (context) {
        return _quickSurveyYears
            .map(
              (year) => PopupMenuItem<int>(
                value: year,
                child: Row(
                  children: [
                    if (_selectedSurveyYear == year)
                      const Icon(Icons.check, size: 14, color: Color(0xFF2563EB))
                    else
                      const SizedBox(width: 14),
                    const SizedBox(width: 6),
                    Text(year.toString()),
                  ],
                ),
              ),
            )
            .toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(245),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD7E4F6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month, size: 12, color: Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(
              _selectedSurveyYear.toString(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 12, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _mobileFilterButton() {
    return Positioned(
      top: 13,
      right: 14,
      child: FloatingActionButton.small(
        heroTag: 'mapFilterBtn',
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            barrierColor: const Color(0x66111E34),
            builder: (context) {
              return StatefulBuilder(
                builder: (context, modalSetState) {
                  _modalFilterSetState = modalSetState;
                  final maxHeight = MediaQuery.of(context).size.height * 0.86;
                  return SafeArea(
                    top: false,
                    child: Container(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFF8FBFF),
                            Color(0xFFF2F7FF),
                          ],
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x3D0F172A),
                            blurRadius: 20,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Container(
                            width: 46,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFF9EB2CE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                            child: Row(
                              children: [
                                const Icon(Icons.tune_rounded, color: Color(0xFF1E3A5F)),
                                const SizedBox(width: 8),
                                const Text(
                                  'Filter Peta',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0B2340),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  tooltip: 'Tutup',
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFD7E4F6)),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _leftKecamatanPanel(),
                                  const SizedBox(height: 12),
                                  _rightFilterPanel(),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ).whenComplete(() {
            _modalFilterSetState = null;
          });
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.tune),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 980;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Infrastruktur & Survei'),
        actions: [
          IconButton(
            tooltip: 'Reset filter',
            onPressed: () {
              _applyFilterChange(() {
                _selectedKecamatan = _kecamatanColors.keys.toSet();
                _selectedCategories = <MapLayerCategory>{};
                _selectedRanges = SignalRange.values.toSet();
                _selectedTowerStates = TowerAirStatus.values.toSet();
                _showTowerLayer = false;
                _showSurveySeluler = true;
                _selectedSurveyYear = _availableSurveyYears.contains(_currentYear)
                    ? _currentYear
                    : _availableSurveyYears.first;
                _showAllDisplay = false;
                _showAllRange = true;
              });
              _fetchSurveiJaringanSeluler(year: _selectedSurveyYear);
            },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(-2.1102526, 115.164298),
              initialZoom: 10.2,
              minZoom: 7,
              maxZoom: 18,
              onTap: (_, tapPoint) {
                final kecamatan = _kecamatanFromTap(tapPoint);
                if (kecamatan != null) {
                  _focusKecamatan(kecamatan);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
                maxZoom: 19,
              ),
              PolygonLayer(polygons: _buildKecamatanPolygons()),
              CircleLayer(circles: _buildRangeCircles()),
              MarkerLayer(markers: _buildMarkers()),
              MarkerLayer(markers: _buildKecamatanLabels()),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
          if (isWide) ...[
            Positioned(
              left: 16,
              bottom: 16,
              child: _leftKecamatanPanel(),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: _rightFilterPanel(),
            ),
          ] else
            _mobileFilterButton(),
          _showAllPolygonsButton(),
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(238),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoadingTowers || _isLoadingSurveys)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_fetchError != null)
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444))
                  else
                    const Icon(Icons.location_on, size: 16, color: Color(0xFF334155)),
                  const SizedBox(width: 3),
                  Text(
                    (_isLoadingTowers || _isLoadingSurveys)
                      ? 'Memuat data peta...'
                        : _fetchError != null
                            ? _fetchError!
                            : '${_filteredPoints.length} titik aktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _fetchError != null
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  if (_fetchError != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _fetchTowers,
                      child: const Icon(Icons.refresh, size: 16, color: Color(0xFF334155)),
                    ),
                  ] else ...[
                    const SizedBox(width: 6),
                    _inlineLayerChip(
                      selected: _showSurveySeluler,
                      icon: Icons.network_cell,
                      label: 'Survei',
                      iconColor: const Color(0xFF10B981),
                      onSelected: (value) {
                        _applyFilterChange(() {
                          _showSurveySeluler = value;
                          _showAllDisplay = _showSurveySeluler && _showTowerLayer;
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    _inlineLayerChip(
                      selected: _showTowerLayer,
                      icon: Icons.cell_tower,
                      label: 'Tower',
                      iconColor: const Color(0xFF2563EB),
                      onSelected: (value) {
                        _applyFilterChange(() {
                          _showTowerLayer = value;
                          _selectedCategories = _showTowerLayer
                              ? _filterCategories.toSet()
                              : <MapLayerCategory>{};
                          _showAllDisplay = _showSurveySeluler && _showTowerLayer;
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    _inlineYearFilter(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
