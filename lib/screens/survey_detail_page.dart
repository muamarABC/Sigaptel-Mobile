import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/remote_survey.dart';
import '../providers/api_survey_provider.dart';

class SurveyDetailPage extends StatelessWidget {
  static const routeName = '/survey-detail';
  const SurveyDetailPage({super.key});

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

    return AppConfig.storageUrl(normalized);
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

  String _buildDownloadFileName(RemoteSurvey survey, String url) {
    final desa = survey.desa.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final cleanDesa = desa.replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    final uri = Uri.tryParse(url);
    final lastSegment =
        (uri != null && uri.pathSegments.isNotEmpty) ? uri.pathSegments.last : '';

    String extension = 'jpg';
    if (lastSegment.contains('.')) {
      extension = lastSegment.split('.').last.toLowerCase();
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final prefix = cleanDesa.isEmpty ? 'foto-survey' : cleanDesa;
    return '${prefix}_$ts.$extension';
  }

  Future<void> _downloadPhoto(BuildContext context, RemoteSurvey survey) async {
    final raw = survey.fotoLokasiSurvei;
    final url = _buildPhotoUrl(raw);
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto tidak bisa diunduh karena path tidak valid.')),
      );
      return;
    }

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final baseDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${baseDir.path}${Platform.pathSeparator}downloaded_photos');
      if (!downloadDir.existsSync()) {
        downloadDir.createSync(recursive: true);
      }

      final fileName = _buildDownloadFileName(survey, url);
      final outFile = File('${downloadDir.path}${Platform.pathSeparator}$fileName');
      await outFile.writeAsBytes(resp.bodyBytes, flush: true);

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto berhasil diunduh ke: ${outFile.path}')),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh foto: $e')),
      );
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
        child: Image.network(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = ModalRoute.of(context)!.settings.arguments as int;

    return FutureBuilder(
      future: context.read<ApiSurveyProvider>().loadDetail(id),
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
            title: Text('Detail Survey #${survey.id}'),
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _downloadPhoto(context, survey),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Download Foto'),
                            ),
                          ],
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
                        _DetailTile(label: 'Kecamatan', value: survey.kecamatan),
                        _DetailTile(label: 'Desa', value: survey.desa),
                        _DetailTile(label: 'Latitude', value: survey.latitude),
                        _DetailTile(label: 'Longitude', value: survey.longitude),
                        _DetailTile(label: 'Operator', value: survey.operator),
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
                                subtitle: _downloadQuality(survey.downloadSpeed),
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
                                  child: Text('Koordinat tidak valid untuk ditampilkan di peta.'),
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
                                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
            ),
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

  const _DetailTile({
    required this.label,
    required this.value,
  });

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
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12.5,
              ),
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
