import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/remote_survey.dart';
import '../models/survey.dart';
import '../providers/api_survey_provider.dart';
import '../services/photo_stamp_service.dart';
import 'survey_page.dart';

class SurveyDetailPage extends StatefulWidget {
  static const routeName = '/survey-detail';
  const SurveyDetailPage({super.key});

  @override
  State<SurveyDetailPage> createState() => _SurveyDetailPageState();
}

class _SurveyDetailPageState extends State<SurveyDetailPage> {
  Future<void>? _loadFuture;
  int? _surveyId;

  Survey _toEditableSurvey(RemoteSurvey remote) => Survey(
    id: remote.id,
    userId: remote.userId,
    kecamatan: remote.kecamatan,
    desa: remote.desa,
    date: DateTime.tryParse(remote.createdAt) ?? DateTime.now(),
    latitude: double.tryParse(remote.latitude) ?? 0,
    longitude: double.tryParse(remote.longitude) ?? 0,
    operatorName: remote.operator,
    rsrp: remote.rsrp,
    rsrq: remote.rsrq,
    sinr: remote.sinr,
    rssi: remote.rssi,
    downloadSpeed: remote.downloadSpeed,
    uploadSpeed: remote.uploadSpeed,
    ping: remote.ping,
    tahunSurvei: remote.tahunSurvei,
    revisiKe: remote.revisiKe,
    isAktif: remote.isAktif,
    parentId: remote.parentId,
    jaringan: remote.jaringan,
    kekuatanSinyal: remote.kekuatanSinyal,
    fotoLokasiSurvei: remote.fotoLokasiSurvei,
    notes: remote.notes,
  );

  bool _isTemporaryUploadPath(String raw) {
    final trimmed = raw.trim();
    return trimmed.startsWith('/tmp/') || trimmed.startsWith('tmp/');
  }

  String _buildPhotoUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/tmp/') || trimmed.startsWith('tmp/')) {
      // Temporary upload paths are not publicly accessible.
      return '';
    }

    var normalized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    if (normalized.startsWith('public/')) {
      normalized = normalized.substring('public/'.length);
    }
    if (normalized.startsWith('storage/')) {
      normalized = normalized.substring('storage/'.length);
    }

    return 'https://tower.baritotimurkab.go.id/storage/$normalized';
  }

  LatLng? _parseCoordinate(RemoteSurvey survey) {
    final lat = double.tryParse(survey.latitude.trim());
    final lng = double.tryParse(survey.longitude.trim());
    if (lat == null || lng == null) {
      return null;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  String _buildDownloadFileName(
    RemoteSurvey survey,
    String url, {
    String? desa,
  }) {
    final village = (desa ?? survey.desa).trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    final cleanDesa = village
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final uri = Uri.tryParse(url);
    final lastSegment = (uri != null && uri.pathSegments.isNotEmpty)
        ? uri.pathSegments.last
        : '';

    String extension = 'jpg';
    if (lastSegment.contains('.')) {
      extension = lastSegment.split('.').last.toLowerCase();
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final prefix = cleanDesa.isEmpty ? 'foto-survey' : cleanDesa;
    return '${prefix}_$ts.$extension';
  }

  Future<bool> _requestGalleryPermission() async {
    if (Platform.isAndroid) {
      // On modern Android (scoped storage), gallery save can work without
      // runtime storage permission. Don't block save flow by permission check.
      return true;
    }

    if (Platform.isIOS) {
      final photosAddStatus = await Permission.photosAddOnly.request();
      if (photosAddStatus.isGranted || photosAddStatus.isLimited) {
        return true;
      }

      final photosStatus = await Permission.photos.request();
      return photosStatus.isGranted || photosStatus.isLimited;
    }

    return true;
  }

  bool _isGallerySaveSuccess(dynamic result) {
    if (result is Map) {
      final dynamic successRaw = result['isSuccess'] ?? result['success'];
      if (successRaw is bool) {
        return successRaw;
      }
      if (successRaw is num) {
        return successRaw != 0;
      }
      if (successRaw != null) {
        final text = successRaw.toString().toLowerCase();
        if (text == 'true' || text == '1') {
          return true;
        }
      }
      final dynamic filePath = result['filePath'];
      if (filePath != null && filePath.toString().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  String _staffName(RemoteSurvey survey) => survey.namaPembuat.trim().isNotEmpty
      ? survey.namaPembuat.trim()
      : survey.userId > 0
      ? 'User ID ${survey.userId}'
      : '-';

  Future<Uint8List> _loadStampedPhoto(
    RemoteSurvey survey, {
    DateTime? timestamp,
    String? desa,
    String? locationPrefix,
  }) async {
    final url = _buildPhotoUrl(survey.fotoLokasiSurvei);
    if (url.isEmpty) {
      throw Exception('Foto tidak bisa dimuat karena path tidak valid.');
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal memuat foto (HTTP ${response.statusCode}).');
    }

    return PhotoStampService.stamp(
      photoBytes: response.bodyBytes,
      timestamp: timestamp ?? DateTime.tryParse(survey.createdAt),
      desa: desa ?? survey.desa,
      kecamatan: survey.kecamatan,
      locationPrefix: locationPrefix ?? '',
      latitude: survey.latitude,
      longitude: survey.longitude,
      staffName: _staffName(survey),
    );
  }

  Future<void> _openStampedPhoto(RemoteSurvey survey) async {
    final url = _buildPhotoUrl(survey.fotoLokasiSurvei);
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto tidak bisa dibuka karena path tidak valid.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _WatermarkedPhotoViewer(
          title: survey.desa.trim().isEmpty ? 'Foto Survei' : survey.desa,
          photoFuture: _loadStampedPhoto(survey),
        ),
      ),
    );
  }

  Future<void> _editWatermarkAndDownload(RemoteSurvey survey) async {
    final createdAt = DateTime.tryParse(survey.createdAt);
    final initialWib =
        createdAt?.toUtc().add(const Duration(hours: 7)) ??
        DateTime.now().toUtc().add(const Duration(hours: 7));
    final metadata = await showModalBottomSheet<_StampMetadata>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WatermarkMetadataEditor(
        initialTimestamp: initialWib,
        initialVillage: survey.desa,
      ),
    );
    if (metadata != null && mounted) {
      await _downloadPhoto(
        context,
        survey,
        timestamp: metadata.timestamp,
        desa: metadata.village,
        locationPrefix: metadata.locationPrefix,
      );
    }
  }

  Future<void> _watermarkGalleryPhoto(RemoteSurvey survey) async {
    try {
      final pickedPhoto = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedPhoto == null || !mounted) return;

      final createdAt = DateTime.tryParse(survey.createdAt);
      final initialWib =
          createdAt?.toUtc().add(const Duration(hours: 7)) ??
          DateTime.now().toUtc().add(const Duration(hours: 7));
      final metadata = await showModalBottomSheet<_StampMetadata>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _WatermarkMetadataEditor(
          initialTimestamp: initialWib,
          initialVillage: survey.desa,
        ),
      );
      if (metadata == null || !mounted) return;

      final stampedBytes = await PhotoStampService.stamp(
        photoBytes: await pickedPhoto.readAsBytes(),
        timestamp: metadata.timestamp,
        desa: metadata.village,
        kecamatan: survey.kecamatan,
        locationPrefix: metadata.locationPrefix,
        latitude: survey.latitude,
        longitude: survey.longitude,
        staffName: _staffName(survey),
      );
      if (!context.mounted) return;
      final fileName = _buildDownloadFileName(
        survey,
        pickedPhoto.name,
        desa: metadata.village,
      );
      final baseName = fileName.substring(0, fileName.lastIndexOf('.'));
      final saved = await _saveWatermarkedBytes(
        context,
        stampedBytes,
        baseName,
      );
      if (saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto galeri ber-watermark tersimpan ke galeri.'),
          ),
        );
      }
    } on MissingPluginException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fitur galeri belum aktif. Tutup aplikasi lalu jalankan ulang.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memberi watermark: $e')));
    }
  }

  Future<bool> _saveWatermarkedBytes(
    BuildContext context,
    Uint8List bytes,
    String baseName,
  ) async {
    final granted = await _requestGalleryPermission();
    if (!granted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Izin akses foto ditolak. Aktifkan izin untuk menyimpan gambar.',
            ),
            action: SnackBarAction(
              label: 'Pengaturan',
              onPressed: openAppSettings,
            ),
          ),
        );
      }
      return false;
    }

    final result = await ImageGallerySaver.saveImage(
      bytes,
      name: baseName,
      quality: 100,
    );
    if (!_isGallerySaveSuccess(result)) {
      throw Exception('Plugin galeri gagal menyimpan foto.');
    }
    return true;
  }

  Future<void> _downloadPhoto(
    BuildContext context,
    RemoteSurvey survey, {
    DateTime? timestamp,
    String? desa,
    String? locationPrefix,
  }) async {
    final raw = survey.fotoLokasiSurvei;
    final url = _buildPhotoUrl(raw);
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto tidak bisa diunduh karena path tidak valid.'),
        ),
      );
      return;
    }

    try {
      final fileName = _buildDownloadFileName(survey, url, desa: desa);
      final bytes = await _loadStampedPhoto(
        survey,
        timestamp: timestamp,
        desa: desa,
        locationPrefix: locationPrefix,
      );
      if (!context.mounted) return;
      final baseName = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      final saved = await _saveWatermarkedBytes(context, bytes, baseName);
      if (!saved) return;

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto ber-watermark tersimpan ke galeri.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengunduh foto: $e')));
    }
  }

  String _fmtMbps(double? value) {
    if (value == null) {
      return '-';
    }
    return '${value.toStringAsFixed(2)} Mbps';
  }

  String _fmtPing(int? value) {
    if (value == null) {
      return '-';
    }
    return '$value ms';
  }

  String _downloadQuality(double? value) {
    if (value == null) {
      return 'Belum ada data';
    }
    if (value >= 20) {
      return 'Sangat cepat';
    }
    if (value >= 10) {
      return 'Cepat';
    }
    if (value >= 3) {
      return 'Cukup';
    }
    return 'Lambat';
  }

  String _uploadQuality(double? value) {
    if (value == null) {
      return 'Belum ada data';
    }
    if (value >= 10) {
      return 'Sangat baik';
    }
    if (value >= 5) {
      return 'Baik';
    }
    if (value >= 1) {
      return 'Cukup';
    }
    return 'Rendah';
  }

  String _pingQuality(int? value) {
    if (value == null) {
      return 'Belum ada data';
    }
    if (value <= 30) {
      return 'Responsif';
    }
    if (value <= 80) {
      return 'Normal';
    }
    if (value <= 150) {
      return 'Tinggi';
    }
    return 'Sangat tinggi';
  }

  Widget _buildPhotoPreview(RemoteSurvey survey) {
    final raw = survey.fotoLokasiSurvei;
    final isTemporaryPath = _isTemporaryUploadPath(raw);
    final url = _buildPhotoUrl(raw);
    if (raw.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Foto tidak tersedia')),
      );
    }

    if (isTemporaryPath) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDBA74)),
        ),
        padding: const EdgeInsets.all(12),
        child: const Center(
          child: Text(
            'Foto lama invalid, perlu upload ulang.\nPath tersimpan masih bersifat sementara (/tmp).',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9A3412),
            ),
          ),
        ),
      );
    }

    if (url.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Path foto tidak valid')),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: InkWell(
          onTap: () => _openStampedPhoto(survey),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFF1F5F9),
                    alignment: Alignment.center,
                    child: SelectableText(
                      'Gagal memuat foto.\nPath: $raw',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  );
                },
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC111827),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Lihat Watermark',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)!.settings.arguments as int;
    if (_surveyId != id) {
      _surveyId = id;
      _loadFuture = context.read<ApiSurveyProvider>().loadDetail(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _surveyId!;

    return FutureBuilder(
      future: _loadFuture,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final survey = context.watch<ApiSurveyProvider>().selected;
        if (survey == null) {
          return const Scaffold(
            body: Center(child: Text('Data tidak ditemukan')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  survey.desa.trim().isEmpty
                      ? 'Detail Survei'
                      : 'Desa ${survey.desa}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Detail Survei',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(170),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Edit survey',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final updated = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) =>
                          SurveyPage(initialSurvey: _toEditableSurvey(survey)),
                    ),
                  );
                  if (updated == true && mounted) {
                    setState(() {
                      _loadFuture = context
                          .read<ApiSurveyProvider>()
                          .loadDetail(id);
                    });
                  }
                },
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEFF6FF),
                  Color(0xFFF8FAFC),
                  Color(0xFFF0FDFA),
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _HeroHeader(survey: survey),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Foto Lokasi',
                    icon: Icons.photo_camera_back_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPhotoPreview(survey),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _downloadPhoto(context, survey),
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Download Foto'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _editWatermarkAndDownload(survey),
                                icon: const Icon(Icons.tune_rounded),
                                label: const Text('Download & Edit'),
                                style: FilledButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF0F766E),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _watermarkGalleryPhoto(survey),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Watermark Foto dari Galeri'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF9A3412),
                              backgroundColor: const Color(0xFFFFF7ED),
                              side: const BorderSide(color: Color(0xFFFDBA74)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Lokasi & Jaringan',
                    icon: Icons.cell_tower,
                    child: Column(
                      children: [
                        _DetailTile(
                          label: 'Kecamatan',
                          value: survey.kecamatan,
                        ),
                        _DetailTile(label: 'Desa', value: survey.desa),
                        _DetailTile(label: 'Latitude', value: survey.latitude),
                        _DetailTile(
                          label: 'Longitude',
                          value: survey.longitude,
                        ),
                        _DetailTile(label: 'Operator', value: survey.operator),
                        _DetailTile(
                          label: 'Nama Pembuat Survey',
                          value: survey.namaPembuat.isNotEmpty
                              ? survey.namaPembuat
                              : (survey.userId > 0
                                    ? 'User ID ${survey.userId}'
                                    : '-'),
                        ),
                        _DetailTile(label: 'Jaringan', value: survey.jaringan),
                        _DetailTile(
                          label: 'Kekuatan Sinyal',
                          value: survey.kekuatanSinyal,
                        ),
                        _DetailTile(
                          label: 'RSRP',
                          value: survey.rsrp?.toString() ?? '-',
                        ),
                        _DetailTile(
                          label: 'RSRQ',
                          value: survey.rsrq?.toString() ?? '-',
                        ),
                        _DetailTile(
                          label: 'SINR',
                          value: survey.sinr?.toString() ?? '-',
                        ),
                        _DetailTile(
                          label: 'RSSI',
                          value: survey.rssi?.toString() ?? '-',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Speed Test',
                    icon: Icons.speed,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SpeedMetricCard(
                                title: 'Download',
                                value: _fmtMbps(survey.downloadSpeed),
                                subtitle: _downloadQuality(
                                  survey.downloadSpeed,
                                ),
                                accent: const Color(0xFF0369A1),
                                icon: Icons.download_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SpeedMetricCard(
                                title: 'Upload',
                                value: _fmtMbps(survey.uploadSpeed),
                                subtitle: _uploadQuality(survey.uploadSpeed),
                                accent: const Color(0xFF15803D),
                                icon: Icons.upload_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _SpeedMetricCard(
                          title: 'Ping',
                          value: _fmtPing(survey.ping),
                          subtitle: _pingQuality(survey.ping),
                          accent: const Color(0xFFB45309),
                          icon: Icons.wifi_tethering,
                          fullWidth: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: 'Koordinat Lokasi',
                    icon: Icons.location_on_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final point = _parseCoordinate(survey);
                            if (point == null) {
                              return const SizedBox(
                                height: 90,
                                child: Center(
                                  child: Text(
                                    'Koordinat tidak valid untuk ditampilkan di peta.',
                                  ),
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lat: ${point.latitude.toStringAsFixed(6)}, Lng: ${point.longitude.toStringAsFixed(6)}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    height: 220,
                                    child: FlutterMap(
                                      options: MapOptions(
                                        initialCenter: point,
                                        initialZoom: 15,
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate:
                                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          userAgentPackageName: 'sigaptel',
                                        ),
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: point,
                                              width: 42,
                                              height: 42,
                                              child: const Icon(
                                                Icons.location_pin,
                                                color: Color(0xFFDC2626),
                                                size: 38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StampMetadata {
  final DateTime timestamp;
  final String village;
  final String locationPrefix;

  const _StampMetadata({
    required this.timestamp,
    required this.village,
    required this.locationPrefix,
  });
}

class _WatermarkMetadataEditor extends StatefulWidget {
  final DateTime initialTimestamp;
  final String initialVillage;

  const _WatermarkMetadataEditor({
    required this.initialTimestamp,
    required this.initialVillage,
  });

  @override
  State<_WatermarkMetadataEditor> createState() =>
      _WatermarkMetadataEditorState();
}

class _WatermarkMetadataEditorState extends State<_WatermarkMetadataEditor> {
  static const _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _villageController;
  late final TextEditingController _locationPrefixController;
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _villageController = TextEditingController(text: widget.initialVillage);
    _locationPrefixController = TextEditingController();
    _date = DateTime(
      widget.initialTimestamp.year,
      widget.initialTimestamp.month,
      widget.initialTimestamp.day,
    );
    _time = TimeOfDay(
      hour: widget.initialTimestamp.hour,
      minute: widget.initialTimestamp.minute,
    );
  }

  @override
  void dispose() {
    _villageController.dispose();
    _locationPrefixController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')} WIB';

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) {
      setState(() => _date = selected);
    }
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) {
      setState(() => _time = selected);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final timestamp = DateTime.utc(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    ).subtract(const Duration(hours: 7));
    Navigator.of(context).pop(
      _StampMetadata(
        timestamp: timestamp,
        village: _villageController.text.trim(),
        locationPrefix: _locationPrefixController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: screenHeight * 0.82,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 12, 4),
                    child: Column(
                      children: [
                        Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Download & Edit',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Tutup',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                      children: [
                        const Text(
                          'Jam, tanggal, dan desa terisi dari data survei.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Tanggal dan waktu',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _chooseDate,
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: Text(_formatDate(_date)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _chooseTime,
                                icon: const Icon(Icons.schedule_rounded),
                                label: Text(_formatTime(_time)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _locationPrefixController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Jalan / patokan (opsional)',
                            hintText: 'Contoh: Jalan ...',
                            prefixIcon: Icon(Icons.add_road_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _villageController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Desa',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Nama desa wajib diisi'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Terapkan & Download Foto'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WatermarkedPhotoViewer extends StatelessWidget {
  final String title;
  final Future<Uint8List> photoFuture;

  const _WatermarkedPhotoViewer({
    required this.title,
    required this.photoFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D14),
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: FutureBuilder<Uint8List>(
        future: photoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal menampilkan foto: ${snapshot.error ?? 'data kosong'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) => InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Image.memory(snapshot.data!, fit: BoxFit.contain),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SpeedMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final bool fullWidth;

  const _SpeedMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withAlpha(22), Colors.white],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final RemoteSurvey survey;

  const _HeroHeader({required this.survey});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(36),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.wifi_tethering, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  survey.desa.isEmpty ? '-' : survey.desa,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${survey.kecamatan} • ${survey.operator} • ${survey.tahunSurvei}',
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(245),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;

  const _DetailTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final safe = value.isEmpty ? '-' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              safe,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
