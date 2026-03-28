import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/survey.dart';
import '../providers/api_survey_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/survey_provider.dart';
import '../services/network_metrics_service.dart';
import 'pending_list_page.dart';

enum _NoSignalAction { checkFirst, validateAgain }

class SurveyContent extends StatefulWidget {
  const SurveyContent({super.key});

  @override
  State<SurveyContent> createState() => _SurveyContentState();
}

class _SurveyContentState extends State<SurveyContent> {
  static const int _maxPhotoBytes = 500 * 1024;
  static const List<String> _operatorOptions = ['Telkomsel', 'Indosat', 'XL'];

  static const List<String> _jaringanOptions = [
    'Blankspot',
    'GSM/GPRS',
    'EDGE',
    'UMTS/WCDMA',
    'HSDPA',
    'LTE',
  ];

  static const Map<String, List<String>> _baritoTimurArea = {
    // 'Awang': ['Ampah Kota', 'Hayaping', 'Bagok', 'Juru Banu', 'Pangkan'],
    // 'Benua Lima': ['Taniran', 'Kandris', 'Bamban', 'Tewah Pupuh', 'Banyu Landas'],
    // 'Dusun Tengah': ['Sumber Garunggung', 'Matabu', 'Putai', 'Pulau Patai', 'Netampin'],
    // 'Dusun Timur': ['Tamiang Layang', 'Nansarunai', 'Tewah', 'Kupang Bersih', 'Jaweten'],
    // 'Karusen Janang': ['Dayu', 'Telang Baru', 'Siong', 'Pampa', 'Tangkan'],
    // 'Paju Epat': ['Tampu Langit', 'Kalinapu', 'Murutuwu', 'Nunu', 'Pangkan'],
    // 'Paku': ['Tampa', 'Juru Banu', 'Tarinsing', 'Bantai Napu', 'Pulau Patai'],
    // 'Patangkep Tutui': ['Bentot', 'Ampari', 'Runggu Raya', 'Kalanis', 'Murutuwu'],
    // 'Raren Batuah': ['Lenggang', 'Raren', 'Baruyan', 'Pulau Padang', 'Tuyau'],
    'Dusun Timur' : ['Tamiang Layang','Pulau patai', 'Sarapat', 'Magantis', 'Jaar', 'Matabu', 'Jaweten', 'Haringen', 'Dorong', 'Didi', 'Karang langit', 'Harara', 'Mangkarap', 'Matarah', 'Gumpa', 'Maragut', 'Sumur'],
    'Dusun Tengah' : ['Ampah Kota','Saing', 'Ampah Dua', 'Putai', 'Netampin', 'Sumber Garunggung', 'Muara awang', 'Rodok'],
    'Banua Lima' : ['Kandris', 'Banyu Landas', 'Bagok', 'Bamban', 'Tewah Pupuh', 'Gudang Seng', 'Taniran'],
    'Patangkep Tutui' : ['Pulau Padang', 'Ramania', 'Kambitin', 'Bentot', 'Ampari Bora', 'Kotam', 'Betang Nalong', 'Mawani', 'Jango', 'Lalap'],
    'Awang' : ['Janah Jari', 'Bangkirayen', 'Tangkan', 'Ampari', 'Wungkur Nanakan', 'Hayaping', 'Biwan', 'Apar Batu', 'Pianggu', 'Danau', 'Janah Mansiwui'],
    'Paju Epat' : ['Telang', 'Murutuwu', 'Balawa', 'Maipe', 'Telang Baru', 'Juru Banu', 'Tampu Langit', 'Siong', 'Kalinapu'],
    'Karusen Janang' : ['Dayu', 'Wuran', 'Ipu Mea', 'Simpang Naneng', 'Lagan', 'Putut Tawuluh', 'Kandris'],
    'Paku' : ['Tampa', 'Runggu Raya', 'Patung', 'Kalamus', 'Simpang Bingkuang', 'Kupang Baru', 'Luwau jawuk', 'Tarinsing', 'Bantai Napu', 'Pangkan', 'Gandrung', 'Paku Beto'],
    'Pematang Karau' : ['Muara palantau', 'Ketab', 'Kupang bersih', 'Tuyau', 'Pinang tunggal', 'Nagaleah', 'Lampeong', 'Bararawa', 'Bambulung', 'Lebo', 'Tumpung ulung', 'Muruduyung', 'Sumberejo'],
    'Raren Batuah' : ['Unsum', 'Baruyan', 'Lenggang', 'Puri', 'Batuah', 'Turan Amis', 'Tangkum', 'Sibung', 'Malintut']
  };

  final _formKey = GlobalKey<FormState>();

  final _tahunC = TextEditingController(text: DateTime.now().year.toString());
  final _latC = TextEditingController();
  final _longC = TextEditingController();
  final _rsrpC = TextEditingController();
  final _rsrqC = TextEditingController();
  final _sinrC = TextEditingController();
  final _rssiC = TextEditingController();
  final _downloadC = TextEditingController();
  final _uploadC = TextEditingController();
  final _pingC = TextEditingController();
  final _notesC = TextEditingController();

  String? _selectedKecamatan;
  String? _selectedDesa;
  String? _selectedOperator;
  String? _selectedJaringan;
  String? _signalSuggestion;
  File? _photo;
  bool _submitting = false;
  bool _collectingMetrics = false;
  String? _metricsStatus;
  String _networkStatusText = 'Belum diuji';
  Color _networkStatusColor = const Color(0xFF64748B);
  DateTime? _lastSignalCheckedAt;

  final NetworkMetricsService _networkMetricsService = NetworkMetricsService();

  Future<T?> _showAnimatedDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    if (!mounted) {
      return Future.value(null);
    }

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'dialog',
      barrierColor: Colors.black.withAlpha(90),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Builder(builder: builder),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFB91C1C) : null,
        ),
      );
  }

  Future<void> _showStatusDialog({
    required String title,
    required String message,
    bool success = true,
  }) async {
    if (!mounted) {
      return;
    }

    await _showAnimatedDialog<void>(
      barrierDismissible: true,
      builder: (dialogContext) {
        final accent = success ? const Color(0xFF16A34A) : const Color(0xFFB91C1C);
        final accentSoft = success ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
        return Center(
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(
                      color: accentSoft,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      border: Border(bottom: BorderSide(color: accent.withAlpha(70))),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                    child: SingleChildScrollView(
                      child: Text(
                        message,
                        style: const TextStyle(
                          height: 1.35,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('OK'),
                      ),
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

  List<String> _collectInputIssues() {
    final issues = <String>[];

    final tahun = _tahunC.text.trim();
    if (tahun.isEmpty || int.tryParse(tahun) == null) {
      issues.add('- Tahun survei harus diisi angka yang valid.');
    }
    if (_selectedKecamatan == null || _selectedKecamatan!.isEmpty) {
      issues.add('- Kecamatan wajib dipilih.');
    }
    if (_selectedDesa == null || _selectedDesa!.isEmpty) {
      issues.add('- Desa/Kelurahan wajib dipilih.');
    }
    if (_selectedOperator == null || _selectedOperator!.isEmpty) {
      issues.add('- Operator wajib dipilih.');
    }
    if (_selectedJaringan == null || _selectedJaringan!.isEmpty) {
      issues.add('- Jenis jaringan wajib dipilih.');
    }
    final lat = double.tryParse(_latC.text.trim());
    final lng = double.tryParse(_longC.text.trim());
    if (lat == null || lng == null) {
      issues.add('- Latitude dan Longitude harus valid.');
    }
    if (_photo == null) {
      issues.add('- Foto lokasi survei wajib diisi.');
    }

    return issues;
  }

  @override
  void dispose() {
    _tahunC.dispose();
    _latC.dispose();
    _longC.dispose();
    _rsrpC.dispose();
    _rsrqC.dispose();
    _sinrC.dispose();
    _rssiC.dispose();
    _downloadC.dispose();
    _uploadC.dispose();
    _pingC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD0D9E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.3),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  int? _toIntOrNull(String text) {
    final parsed = int.tryParse(text.trim());
    return parsed;
  }

  double? _toDoubleOrNull(String text) {
    final parsed = double.tryParse(text.trim());
    return parsed;
  }

  String _fmtTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  void _applySignalValues(SignalMetrics signal) {
    _rsrpC.text = signal.rsrp?.toString() ?? '';
    _rsrqC.text = signal.rsrq?.toString() ?? '';
    _sinrC.text = signal.sinr?.toString() ?? '';
    _rssiC.text = signal.rssi?.toString() ?? '';
  }

  void _applyZeroSignalValues() {
    _rsrpC.text = '0';
    _rsrqC.text = '0';
    _sinrC.text = '0';
    _rssiC.text = '0';
  }

  Widget _gradBtn({
    required String label,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: disabled
                ? const [Color(0xFF94A3B8), Color(0xFF64748B)]
                : colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: disabled
              ? const []
              : [
                  BoxShadow(
                    color: colors.first.withAlpha(77),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.white24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                else
                  Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignalStrengthBadge(String mappedSignal) {
    const empty = '-';
    final label = mappedSignal.isEmpty ? empty : mappedSignal;

    final colorMap = <String, List<Color>>{
      'Sangat Bagus': [const Color(0xFF16A34A), const Color(0xFF15803D)],
      'Bagus': [const Color(0xFF0891B2), const Color(0xFF0E7490)],
      'Normal': [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
      'Lemah': [const Color(0xFFD97706), const Color(0xFFB45309)],
      'Sangat Lemah': [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
      'Total Blankspot': [const Color(0xFF7C3AED), const Color(0xFF6D28D9)],
    };
    final iconMap = <String, IconData>{
      'Sangat Bagus': Icons.signal_cellular_4_bar,
      'Bagus': Icons.signal_cellular_alt,
      'Normal': Icons.signal_cellular_alt_2_bar,
      'Lemah': Icons.signal_cellular_alt_1_bar,
      'Sangat Lemah': Icons.signal_cellular_0_bar,
      'Total Blankspot': Icons.signal_cellular_off,
    };

    final colors = colorMap[label] ??
        [const Color(0xFF94A3B8), const Color(0xFF64748B)];
    final signalIcon = iconMap[label] ?? Icons.signal_cellular_null;
    final isEmpty = label == empty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.first.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: colors.first.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isEmpty
                    ? [const Color(0xFFCBD5E1), const Color(0xFF94A3B8)]
                    : colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(signalIcon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kekuatan Sinyal',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isEmpty
                        ? const Color(0xFF94A3B8)
                        : colors.first,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isEmpty
                    ? [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)]
                    : colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'dari RSRP',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isEmpty ? const Color(0xFF94A3B8) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _buildSignalSuggestion(SignalMetrics signal) {
    final parts = <String>[];
    if (signal.providerName != null && signal.providerName!.isNotEmpty) {
      parts.add(signal.providerName!);
    }
    if (signal.networkType != null && signal.networkType!.isNotEmpty) {
      parts.add(signal.networkType!);
    }
    return parts.isNotEmpty ? 'Terdeteksi: ${parts.join(' · ')}' : null;
  }

  Future<_NoSignalAction?> _showNoSignalCheckDialog(SignalMetrics signal) async {
    if (!mounted) {
      return null;
    }

    final hints = <String>[
      'Pastikan mode pesawat tidak aktif.',
      'Pastikan jaringan paket data seluler aktif.',
    ];
    if (!signal.inService) {
      hints.add('Perangkat belum terhubung ke layanan seluler.');
    }
    if (!signal.dataConnected) {
      hints.add('Koneksi data seluler belum tersambung.');
    }
    if (signal.dataConnected && !signal.validatedCellularInternet) {
      hints.add('Data seluler aktif, tetapi internet belum tervalidasi.');
    }

    return _showAnimatedDialog<_NoSignalAction>(
      barrierDismissible: true,
      builder: (dialogContext) {
        const accent = Color(0xFFD97706);
        return Center(
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      border: Border(bottom: BorderSide(color: accent.withAlpha(70))),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.wifi_tethering_error_rounded, color: accent),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sinyal Belum Terdeteksi',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Silakan cek terlebih dahulu apakah perangkat sedang dalam mode pesawat atau paket data seluler belum aktif.',
                          style: TextStyle(
                            height: 1.35,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...hints.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(Icons.circle, size: 6, color: Color(0xFFB45309)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      height: 1.3,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(_NoSignalAction.checkFirst),
                          child: const Text('Checking'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(_NoSignalAction.validateAgain),
                          child: const Text('Sudah Dicek'),
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

  Future<void> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layanan lokasi tidak aktif')),
        );
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi ditolak permanen')),
        );
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _latC.text = position.latitude.toStringAsFixed(6);
        _longC.text = position.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapatkan lokasi: $e')),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null) {
      return;
    }

    try {
      final persistedPhoto = await _persistPickedPhoto(file.path);
      final optimizedPhoto = await _ensurePhotoUnderLimit(persistedPhoto);
      setState(() {
        _photo = optimizedPhoto;
      });

      if (mounted) {
        final sizeKb = (await optimizedPhoto.length()) / 1024;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto siap upload (${sizeKb.toStringAsFixed(0)} KB)')),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan foto: $e')),
      );
    }
  }

  Future<void> _collectSignalAutomatically() async {
    if (_collectingMetrics) {
      return;
    }

    setState(() {
      _collectingMetrics = true;
      _metricsStatus = 'Mengambil metrik sinyal otomatis...';
    });

    try {
      final signal = await _networkMetricsService.readSignalMetrics();

      _applySignalValues(signal);

      setState(() {
        _signalSuggestion = _buildSignalSuggestion(signal);
      });

      setState(() {
        if (!signal.hasAnyValue) {
          _networkStatusText = 'Tidak valid';
          _networkStatusColor = const Color(0xFFDC2626);
        } else {
          _networkStatusText = 'Valid';
          _networkStatusColor = const Color(0xFF16A34A);
        }
        _lastSignalCheckedAt = DateTime.now();
      });

      if (!mounted) {
        return;
      }

      if (!signal.hasAnyValue) {
        final action = await _showNoSignalCheckDialog(signal);
        if (!mounted) {
          return;
        }

        if (action == _NoSignalAction.checkFirst) {
          _showSnack(
            'Silakan cek mode pesawat dan aktifkan paket data, lalu tekan ambil sinyal lagi.',
            isError: true,
          );
          return;
        }

        if (action == _NoSignalAction.validateAgain) {
          setState(() {
            _metricsStatus = 'Memvalidasi ulang kondisi jaringan...';
          });

          final validatedSignal = await _networkMetricsService.readSignalMetrics();
          _applySignalValues(validatedSignal);

          if (!mounted) {
            return;
          }

          if (!validatedSignal.hasAnyValue) {
            _applyZeroSignalValues();
            setState(() {
              _signalSuggestion = _buildSignalSuggestion(validatedSignal);
              _networkStatusText = 'Tidak ada sinyal';
              _networkStatusColor = const Color(0xFFDC2626);
              _lastSignalCheckedAt = DateTime.now();
            });
            await _showStatusDialog(
              title: 'Tidak Ada Sinyal',
              message:
                  'Mode pesawat dan paket data sudah divalidasi, tetapi sinyal tetap tidak terdeteksi. Nilai RSRP, RSRQ, SINR, dan RSSI diisi 0 agar survei tetap bisa dilanjutkan.',
              success: false,
            );
            return;
          }

          setState(() {
            _signalSuggestion = _buildSignalSuggestion(validatedSignal);
            _networkStatusText = 'Valid';
            _networkStatusColor = const Color(0xFF16A34A);
            _lastSignalCheckedAt = DateTime.now();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Metrik sinyal berhasil diisi setelah validasi ulang.')),
          );
          return;
        }

        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Metrik sinyal berhasil diisi otomatis.')),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ambil metrik sinyal: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _collectingMetrics = false;
          _metricsStatus = null;
        });
      }
    }
  }

  Future<void> _startSpeedTestWithPopup() async {
    if (_collectingMetrics) {
      return;
    }

    setState(() {
      _collectingMetrics = true;
    });

    try {
      final speed = await showDialog<SpeedMetrics>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return _SpeedTestDialog(service: _networkMetricsService);
        },
      );

      if (!mounted) {
        return;
      }

      final resolvedSpeed = speed ?? const SpeedMetrics();

      _downloadC.text = (resolvedSpeed.downloadMbps ?? 0).toStringAsFixed(2);
      _uploadC.text = (resolvedSpeed.uploadMbps ?? 0).toStringAsFixed(2);
      _pingC.text = (resolvedSpeed.pingMs ?? 0).toString();

      final speedUnavailable =
          resolvedSpeed.downloadMbps == null &&
          resolvedSpeed.uploadMbps == null &&
          resolvedSpeed.pingMs == null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            speedUnavailable
                ? 'Speed test tidak mendapat hasil, cek endpoint di settings.'
                : 'Hasil speed test berhasil diisi ke form.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _collectingMetrics = false;
        });
      }
    }
  }

  Future<File> _persistPickedPhoto(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${docsDir.path}/survey_photos');
    if (!photosDir.existsSync()) {
      photosDir.createSync(recursive: true);
    }

    final source = File(sourcePath);
    final extension = source.uri.pathSegments.isNotEmpty && source.uri.pathSegments.last.contains('.')
        ? '.${source.uri.pathSegments.last.split('.').last}'
        : '.jpg';
    final targetPath = '${photosDir.path}/survey_${DateTime.now().microsecondsSinceEpoch}$extension';
    return source.copy(targetPath);
  }

  Future<File> _ensurePhotoUnderLimit(File source) async {
    final initialLength = await source.length();
    if (initialLength <= _maxPhotoBytes) {
      return source;
    }

    final tempDir = await getTemporaryDirectory();
    final baseName = source.uri.pathSegments.isNotEmpty
        ? source.uri.pathSegments.last.split('.').first
        : 'survey_photo';
    final qualitySteps = <int>[72, 64, 56, 48, 40, 32, 26, 22, 18];
    final dimensionSteps = <int>[1600, 1400, 1200, 1000, 900, 800];

    File? best;
    var bestLength = initialLength;

    for (final maxDim in dimensionSteps) {
      for (final quality in qualitySteps) {
        final outPath =
            '${tempDir.path}/$baseName-${DateTime.now().microsecondsSinceEpoch}-$maxDim-$quality.jpg';

        final compressedXFile = await FlutterImageCompress.compressAndGetFile(
          source.absolute.path,
          outPath,
          quality: quality,
          minWidth: maxDim,
          minHeight: maxDim,
          format: CompressFormat.jpeg,
          keepExif: true,
        );

        if (compressedXFile == null) {
          continue;
        }

        final candidate = File(compressedXFile.path);
        final candidateLength = await candidate.length();

        if (candidateLength < bestLength) {
          best = candidate;
          bestLength = candidateLength;
        }

        if (candidateLength <= _maxPhotoBytes) {
          final sourceName = source.uri.pathSegments.isNotEmpty
              ? source.uri.pathSegments.last
              : 'survey_photo.jpg';
          final targetPath = '${source.parent.path}/${DateTime.now().microsecondsSinceEpoch}-$sourceName';
          return candidate.copy(targetPath);
        }
      }
    }

    if (best != null) {
      final sourceName = source.uri.pathSegments.isNotEmpty
          ? source.uri.pathSegments.last
          : 'survey_photo.jpg';
      final targetPath = '${source.parent.path}/${DateTime.now().microsecondsSinceEpoch}-$sourceName';
      return best.copy(targetPath);
    }

    return source;
  }

  Future<Survey?> _buildSurveyIfValid() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      final issues = _collectInputIssues();
      final detail = issues.isEmpty
          ? 'Periksa kembali data yang bertanda * sebelum submit.'
          : 'Periksa input berikut:\n\n${issues.join('\n')}';
      await _showStatusDialog(
        title: 'Input Belum Lengkap',
        message: detail,
        success: false,
      );
      return null;
    }

    if (_photo == null) {
      await _showStatusDialog(
        title: 'Foto Belum Ada',
        message: 'Silakan ambil foto lokasi survei sebelum data dikirim.',
        success: false,
      );
      return null;
    }

    final latitude = double.tryParse(_latC.text.trim());
    final longitude = double.tryParse(_longC.text.trim());
    if (latitude == null || longitude == null) {
      await _showStatusDialog(
        title: 'Koordinat Tidak Valid',
        message: 'Latitude/Longitude harus berupa angka yang valid.',
        success: false,
      );
      return null;
    }

    final tahun = _tahunC.text.trim().isEmpty
        ? DateTime.now().year.toString()
        : _tahunC.text.trim();
    final authUserId = context.read<AuthProvider>().user?.id;

    return Survey(
      kecamatan: _selectedKecamatan!,
      desa: _selectedDesa!,
      userId: authUserId,
      date: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      operatorName: _selectedOperator!,
      jaringan: _selectedJaringan!,
      rsrp: _toIntOrNull(_rsrpC.text),
      rsrq: _toIntOrNull(_rsrqC.text),
      sinr: _toIntOrNull(_sinrC.text),
      rssi: _toIntOrNull(_rssiC.text),
      downloadSpeed: _toDoubleOrNull(_downloadC.text),
      uploadSpeed: _toDoubleOrNull(_uploadC.text),
      ping: _toIntOrNull(_pingC.text),
      tahunSurvei: tahun,
      revisiKe: 0,
      isAktif: 1,
      parentId: null,
      kekuatanSinyal: Survey.hitungKekuatanSinyal(_toIntOrNull(_rsrpC.text)),
      fotoLokasiSurvei: _photo!.path,
      notes: _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
    );
  }

  Future<bool> _confirmSubmit() async {
    final result = await _showAnimatedDialog<bool>(
      barrierDismissible: true,
      builder: (context) {
        const accent = Color(0xFF2563EB);
        return Center(
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      border: Border(bottom: BorderSide(color: accent.withAlpha(70))),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.rocket_launch_rounded, color: accent),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Siap Kirim Data?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
                    child: Text(
                      'Pastikan semua input sudah benar. Data akan langsung dikirim ke server. Jika jaringan tidak stabil, data otomatis disimpan ke pending lokal.',
                      style: TextStyle(
                        height: 1.35,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Kirim Sekarang'),
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

    return result ?? false;
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    final apiProvider = context.read<ApiSurveyProvider>();
    final localProvider = context.read<SurveyProvider>();

    final survey = await _buildSurveyIfValid();
    if (survey == null) {
      return;
    }

    final confirmed = await _confirmSubmit();
    if (!confirmed) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final hasNetwork = await apiProvider.hasNetwork();
      if (!hasNetwork) {
        await localProvider.addPendingSurvey(survey);
        await localProvider.addSurvey(survey);
        if (!mounted) {
          return;
        }
        await _showStatusDialog(
          title: 'Disimpan ke Pending Lokal',
          message:
              'Jaringan minim/blankspot. Data berhasil disimpan ke pending lokal dan akan dikirim saat jaringan membaik.',
          success: true,
        );
        return;
      }

      final response = await apiProvider.submitSurvey(survey);
      final savedSurvey = survey.copyWith(
        fotoLokasiSurvei: response.uploadedPhotoPath ?? survey.fotoLokasiSurvei,
      );
      await localProvider.addSurvey(savedSurvey);

      final syncResult = await localProvider.syncPendingSurveys(
        apiProvider.submitSurvey,
      );

      if (!mounted) {
        return;
      }

        final syncSummary = syncResult.sent > 0
          ? '\n\nSinkronisasi pending: ${syncResult.sent} terkirim, ${syncResult.failed} gagal.'
          : '';
        final successDetail =
            'Data survey berhasil tersimpan ke server.\nTerima kasih, input kamu sudah masuk.$syncSummary';

      await _showStatusDialog(
        title: 'Input Berhasil',
        message: successDetail,
        success: true,
      );

      setState(() {
        _selectedKecamatan = null;
        _selectedDesa = null;
        _selectedOperator = null;
        _selectedJaringan = null;
        _signalSuggestion = null;
        _photo = null;
      });
      _tahunC.text = DateTime.now().year.toString();
      _latC.clear();
      _longC.clear();
      _rsrpC.clear();
      _rsrqC.clear();
      _sinrC.clear();
      _rssiC.clear();
      _downloadC.clear();
      _uploadC.clear();
      _pingC.clear();
      _notesC.clear();
    } catch (e) {
      if (mounted) {
        await _showStatusDialog(
          title: 'Gagal Mengirim Data',
          message: e.toString(),
          success: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _syncPendingNow() async {
    final apiProvider = context.read<ApiSurveyProvider>();
    final localProvider = context.read<SurveyProvider>();

    final hasNetwork = await apiProvider.hasNetwork();
    if (!hasNetwork) {
      if (mounted) {
        _showSnack('Belum ada jaringan internet untuk sync', isError: true);
      }
      return;
    }

    final result = await localProvider.syncPendingSurveys(apiProvider.submitSurvey);
    if (!mounted) {
      return;
    }
    _showSnack(
      'Sync selesai. Terkirim: ${result.sent}, gagal: ${result.failed}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final localProvider = context.watch<SurveyProvider>();
    final desaOptions = _selectedKecamatan == null
        ? <String>[]
        : _baritoTimurArea[_selectedKecamatan] ?? <String>[];
    final mappedSignal = Survey.hitungKekuatanSinyal(_toIntOrNull(_rsrpC.text));

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEFF6FF),
            Color(0xFFF8FAFC),
            Color(0xFFECFEFF),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SurveyHeader(submitting: _submitting),
              const SizedBox(height: 14),
              _SectionCard(
                title: 'Pending Upload',
                icon: Icons.cloud_upload_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending upload: ${localProvider.pendingCount} data',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _gradBtn(
                            label: localProvider.isSyncingPending
                                ? 'Sinkronisasi...'
                                : 'Sync Sekarang',
                            icon: Icons.sync_rounded,
                            colors: const [Color(0xFF0EA5E9), Color(0xFF0369A1)],
                            onTap: (_submitting || localProvider.isSyncingPending)
                                ? null
                                : _syncPendingNow,
                            loading: localProvider.isSyncingPending,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _gradBtn(
                            label: 'Lihat Pending',
                            icon: Icons.format_list_bulleted_rounded,
                            colors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PendingListPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Data Utama',
                icon: Icons.edit_note,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _tahunC,
                      enabled: false,
                      keyboardType: TextInputType.number,
                      decoration: _decoration('Tahun Survei * (paling atas)'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Tahun survei wajib diisi';
                        }
                        if (int.tryParse(value.trim()) == null) {
                          return 'Tahun survei harus angka';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedKecamatan,
                      decoration: _decoration('Kecamatan *'),
                      items: _baritoTimurArea.keys
                          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedKecamatan = value;
                          _selectedDesa = null;
                        });
                      },
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Kecamatan wajib dipilih' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDesa,
                      decoration: _decoration('Desa/Kelurahan *'),
                      items: desaOptions
                          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedDesa = value),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Desa/Kelurahan wajib dipilih'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latC,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _decoration('Latitude *'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Latitude wajib diisi';
                              }
                              if (double.tryParse(value.trim()) == null) {
                                return 'Format latitude tidak valid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _longC,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _decoration('Longitude *'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Longitude wajib diisi';
                              }
                              if (double.tryParse(value.trim()) == null) {
                                return 'Format longitude tidak valid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _gradBtn(
                      label: 'Ambil Lokasi Otomatis',
                      icon: Icons.my_location_rounded,
                      colors: const [Color(0xFF059669), Color(0xFF0891B2)],
                      onTap: _getCurrentLocation,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                            image: _photo == null
                                ? null
                                : DecorationImage(
                                    image: FileImage(_photo!),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          child: _photo == null
                              ? const Icon(Icons.camera_alt, color: Color(0xFF475569))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Ambil Foto Lokasi *'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Parameter Tambahan',
                icon: Icons.network_check,
                child: Column(
                  children: [
                    _gradBtn(
                      label: _collectingMetrics
                          ? 'Mengambil Sinyal...'
                          : 'Ambil Otomatis Sinyal',
                      icon: Icons.signal_cellular_alt_rounded,
                      colors: const [Color(0xFF4F46E5), Color(0xFF2563EB)],
                      onTap: (_submitting || _collectingMetrics)
                          ? null
                          : _collectSignalAutomatically,
                      loading: _collectingMetrics,
                    ),
                    if (_metricsStatus != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _metricsStatus!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Status jaringan: ',
                            style: TextStyle(fontSize: 12.8),
                          ),
                          Text(
                            _networkStatusText,
                            style: TextStyle(
                              fontSize: 12.8,
                              fontWeight: FontWeight.w700,
                              color: _networkStatusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_lastSignalCheckedAt != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Terakhir dicek: ${_fmtTime(_lastSignalCheckedAt!)}',
                          style: const TextStyle(
                            fontSize: 11.8,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedOperator,
                      decoration: _decoration('Operator *'),
                      items: _operatorOptions
                          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedOperator = value),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Operator wajib dipilih' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedJaringan,
                      decoration: _decoration('Jenis Jaringan *'),
                      items: _jaringanOptions
                          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedJaringan = value),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Jenis jaringan wajib dipilih'
                          : null,
                    ),
                    if (_signalSuggestion != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Color(0xFF0369A1)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _signalSuggestion!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0369A1),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rsrpC,
                            keyboardType: TextInputType.number,
                            decoration: _decoration('RSRP'),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return null;
                              }
                              final parsed = int.tryParse(text);
                              if (parsed == null) {
                                return 'RSRP harus angka';
                              }
                              if (parsed >= 0) {
                                return 'RSRP harus bernilai negatif';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _rsrqC,
                            keyboardType: TextInputType.number,
                            decoration: _decoration('RSRQ'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _sinrC,
                            keyboardType: TextInputType.number,
                            decoration: _decoration('SINR'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _rssiC,
                            keyboardType: TextInputType.number,
                            decoration: _decoration('RSSI'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildSignalStrengthBadge(mappedSignal),
                    const SizedBox(height: 10),
                    _gradBtn(
                      label: _collectingMetrics
                          ? 'Menjalankan Speedtest...'
                          : 'Mulai Speedtest',
                      icon: Icons.speed_rounded,
                      colors: const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                      onTap: (_submitting || _collectingMetrics)
                          ? null
                          : _startSpeedTestWithPopup,
                      loading: _collectingMetrics,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _downloadC,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _decoration('Download Speed (Mbps)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _uploadC,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _decoration('Upload Speed (Mbps)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _pingC,
                      keyboardType: TextInputType.number,
                      decoration: _decoration('Ping (ms)'),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return null;
                        }
                        final parsed = int.tryParse(text);
                        if (parsed == null) {
                          return 'Ping harus angka';
                        }
                        if (parsed < 0) {
                          return 'Ping minimal 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesC,
                      maxLines: 2,
                      decoration: _decoration('Catatan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_submitting ? 'Mengirim...' : 'Cek & Kirim ke Database'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedTestDialog extends StatefulWidget {
  final NetworkMetricsService service;

  const _SpeedTestDialog({required this.service});

  @override
  State<_SpeedTestDialog> createState() => _SpeedTestDialogState();
}

class _SpeedTestDialogState extends State<_SpeedTestDialog> {
  bool _running = true;
  double _progress = 0;
  String _stageLabel = 'Persiapan';
  SpeedMetrics? _result;
  SpeedTestStage? _currentStage;

  int _stageNumber(SpeedTestStage stage) {
    return switch (stage) {
      SpeedTestStage.download => 1,
      SpeedTestStage.upload => 2,
      SpeedTestStage.ping => 3,
    };
  }

  String _stageText(SpeedTestStage stage) {
    return switch (stage) {
      SpeedTestStage.download => 'Download',
      SpeedTestStage.upload => 'Upload',
      SpeedTestStage.ping => 'Ping',
    };
  }

  Future<void> _applyStageProgress(SpeedTestStage stage, double percent) async {
    if (!mounted) {
      return;
    }

    final changedStage = _currentStage != stage;
    if (changedStage) {
      setState(() {
        _currentStage = stage;
        _stageLabel = '${_stageText(stage)} (${_stageNumber(stage)}/3)';
        _progress = 0;
      });

      // Small delay so users can see the bar restart on each stage.
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || _currentStage != stage) {
        return;
      }
    }

    setState(() {
      _stageLabel = '${_stageText(stage)} (${_stageNumber(stage)}/3)';
      _progress = (percent / 100.0).clamp(0.0, 1.0);
    });
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final result = await widget.service.runSpeedTest(
        onProgress: (stage, percent) {
          if (!mounted) {
            return;
          }

          _applyStageProgress(stage, percent);
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _running = false;
        _stageLabel = 'Selesai';
        _progress = 1;
        _currentStage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _result = const SpeedMetrics();
        _running = false;
        _stageLabel = 'Gagal';
        _currentStage = null;
      });
    }
  }

  String _fmt(double? value) {
    if (value == null) {
      return '-';
    }
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Speedtest'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _stageLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailItem(
              label: 'Download',
              value: '${_fmt(_result?.downloadMbps)} Mbps',
            ),
            _DetailItem(
              label: 'Upload',
              value: '${_fmt(_result?.uploadMbps)} Mbps',
            ),
            _DetailItem(
              label: 'Ping',
              value: _result?.pingMs == null ? '-' : '${_result!.pingMs} ms',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        FilledButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(_result),
          child: const Text('Gunakan Hasil'),
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;

  const _DetailItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveyHeader extends StatelessWidget {
  final bool submitting;

  const _SurveyHeader({required this.submitting});

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
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cell_tower, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Input Survey Jaringan',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  submitting
                      ? 'Mengirim data ke server...'
                      : 'Isi data inti, lalu kirim atau simpan pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                  ),
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
        color: Colors.white.withAlpha(240),
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

class SurveyPage extends StatelessWidget {
  static const routeName = '/survey';
  const SurveyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Survey Jaringan')),
      body: const SurveyContent(),
    );
  }
}
