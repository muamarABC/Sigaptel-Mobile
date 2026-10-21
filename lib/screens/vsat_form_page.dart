import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/vsat_bakti.dart';
import '../providers/auth_provider.dart';
import '../providers/api_vsat_provider.dart';
import '../providers/vsat_pending_provider.dart';
import '../services/network_metrics_service.dart';

class VsatFormPage extends StatefulWidget {
  final VsatBakti? item;

  const VsatFormPage({super.key, this.item});

  @override
  State<VsatFormPage> createState() => _VsatFormPageState();
}

class _VsatFormPageState extends State<VsatFormPage> {
  // ─── constants ────────────────────────────────────────────────────────────

  static const List<Color> _grad = [Color(0xFF0E7490), Color(0xFF0891B2)];

  static const Map<String, List<String>> _kecamatanDesa = {
    'Dusun Timur': [
      'Tamiang Layang',
      'Pulau Patai',
      'Sarapat',
      'Magantis',
      'Jaar',
      'Matabu',
      'Jaweten',
      'Haringen',
      'Dorong',
      'Didi',
      'Karang Langit',
      'Harara',
      'Mangkarap',
      'Matarah',
      'Gumpa',
      'Maragut',
      'Sumur',
    ],
    'Dusun Tengah': [
      'Ampah Kota',
      'Saing',
      'Ampah Dua',
      'Putai',
      'Netampin',
      'Sumber Garunggung',
      'Muara Awang',
      'Rodok',
    ],
    'Banua Lima': [
      'Kandris',
      'Banyu Landas',
      'Bagok',
      'Bamban',
      'Tewah Pupuh',
      'Gudang Seng',
    ],
    'Patangkep Tutui': [
      'Pulau Padang',
      'Ramania',
      'Kambitin',
      'Bentot',
      'Ampari Bora',
      'Kotam',
      'Betang Nalong',
      'Mawani',
      'Jango',
      'Lalap',
    ],
    'Awang': [
      'Janah Jari',
      'Bangkirayen',
      'Tangkan',
      'Ampari',
      'Wungkur Nanakan',
      'Hayaping',
      'Biwan',
      'Apar Batu',
      'Pianggu',
      'Danau',
      'Janah Mansiwui',
    ],
    'Paju Epat': [
      'Telang',
      'Murutuwu',
      'Balawa',
      'Maipe',
      'Telang Baru',
      'Juru Banu',
      'Tampu Langit',
      'Siong',
      'Kalinapu',
    ],
    'Karusen Janang': [
      'Dayu',
      'Wuran',
      'Ipu Mea',
      'Simpang Naneng',
      'Lagan',
      'Putut Tawuluh',
      'Kandris',
    ],
    'Paku': [
      'Tampa',
      'Runggu Raya',
      'Patung',
      'Kalamus',
      'Simpang Bingkuang',
      'Kupang Baru',
      'Luwau Jawuk',
      'Tarinsing',
      'Bantai Napu',
      'Pangkan',
      'Gandrung',
      'Paku Beto',
    ],
    'Pematang Karau': [
      'Muara Palantau',
      'Ketab',
      'Kupang Bersih',
      'Tuyau',
      'Pinang Tunggal',
      'Nagaleah',
      'Lampeong',
      'Bararawa',
      'Bambulung',
      'Lebo',
      'Tumpung Ulung',
      'Muruduyung',
      'Sumberejo',
    ],
    'Raren Batuah': [
      'Unsum',
      'Baruyan',
      'Lenggang',
      'Puri',
      'Batuah',
      'Turan Amis',
      'Tangkum',
      'Sibung',
      'Malintut',
    ],
  };

  static const List<String> _kategoriOptions = [
    'Pendidikan',
    'Kesehatan',
    'Pertahanan & Keamanan',
    'Kantor Pemerintahan',
  ];

  static const List<String> _sumberListrikOptions = [
    'PLN',
    'PLTS',
    'Generator',
    'Hybrid (PLN + PLTS)',
    'Lainnya',
  ];

  // ─── state ────────────────────────────────────────────────────────────────

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  String? _kategori;
  late final TextEditingController _namaLokasiCtrl;
  late final TextEditingController _alamatCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _bandwidthCtrl;
  late final TextEditingController _namaKontakCtrl;
  late final TextEditingController _emailKontakCtrl;
  late final TextEditingController _telpKontakCtrl;
  late final TextEditingController _keteranganCtrl;

  int? _tahunOperasional;
  String? _kecamatan;
  String? _desa;
  String? _sumberListrik;
  String? _status;
  File? _photoFile;
  bool _isGettingLocation = false;
  bool _isTestingSpeed = false;
  final _networkMetricsService = NetworkMetricsService();

  bool get _isEdit => widget.item != null;

  List<String> get _desaOptions =>
      _kecamatan != null ? (_kecamatanDesa[_kecamatan] ?? []) : [];

  static List<int> get _tahunOptions {
    final now = DateTime.now().year;
    return List<int>.generate(now - 2009, (i) => now - i);
  }

  // ─── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    if (d != null && d.kategori.isNotEmpty) {
      try {
        _kategori = _kategoriOptions.firstWhere(
          (k) => k.toLowerCase() == d.kategori.toLowerCase(),
        );
      } catch (_) {
        _kategori = d.kategori;
      }
    }
    _namaLokasiCtrl = TextEditingController(text: d?.namaLokasi ?? '');
    _alamatCtrl = TextEditingController(text: d?.alamat ?? '');
    _latCtrl = TextEditingController(
      text: d != null && d.latitude != 0 ? d.latitude.toString() : '',
    );
    _lngCtrl = TextEditingController(
      text: d != null && d.longitude != 0 ? d.longitude.toString() : '',
    );
    _bandwidthCtrl = TextEditingController(text: d?.bandwidth ?? '');
    _namaKontakCtrl = TextEditingController(text: d?.namaKontak ?? '');
    _emailKontakCtrl = TextEditingController(text: d?.emailKontak ?? '');
    _telpKontakCtrl = TextEditingController(text: d?.telpKontak ?? '');
    _keteranganCtrl = TextEditingController(text: d?.keterangan ?? '');

    if (d != null) {
      _tahunOperasional = d.tahunOperasional != 0 ? d.tahunOperasional : null;

      if (d.kecamatan.isNotEmpty) {
        try {
          _kecamatan = _kecamatanDesa.keys.firstWhere(
            (k) => k.toLowerCase() == d.kecamatan.toLowerCase(),
          );
        } catch (_) {
          _kecamatan = d.kecamatan;
        }
      }
      if (_kecamatan != null && d.desa.isNotEmpty) {
        final desaList = _kecamatanDesa[_kecamatan] ?? [];
        try {
          _desa = desaList.firstWhere(
            (v) => v.toLowerCase() == d.desa.toLowerCase(),
          );
        } catch (_) {}
      }
      if (d.sumberListrik.isNotEmpty) {
        try {
          _sumberListrik = _sumberListrikOptions.firstWhere(
            (v) => v.toLowerCase() == d.sumberListrik.toLowerCase(),
          );
        } catch (_) {
          _sumberListrik = d.sumberListrik;
        }
      }
      _status = d.status.isNotEmpty ? d.status : null;
    }
  }

  @override
  void dispose() {
    _namaLokasiCtrl.dispose();
    _alamatCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _bandwidthCtrl.dispose();
    _namaKontakCtrl.dispose();
    _emailKontakCtrl.dispose();
    _telpKontakCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  // ─── actions ──────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _snack('Layanan lokasi tidak aktif', error: true);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) _snack('Izin lokasi ditolak', error: true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) _snack('Izin lokasi ditolak permanen', error: true);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _latCtrl.text = position.latitude.toStringAsFixed(6);
        _lngCtrl.text = position.longitude.toStringAsFixed(6);
      });
      _snack('Koordinat berhasil diambil');
    } catch (e) {
      if (mounted) _snack('Gagal mendapatkan lokasi: $e', error: true);
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _runDownloadTest() async {
    if (_isTestingSpeed) return;
    setState(() => _isTestingSpeed = true);
    try {
      final speed = await showDialog<SpeedMetrics>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DownloadTestDialog(service: _networkMetricsService),
      );
      if (!mounted) return;
      if (speed?.downloadMbps != null) {
        _bandwidthCtrl.text = '${speed!.downloadMbps!.toStringAsFixed(2)} Mbps';
        _snack('Download speed berhasil diisi ke Bandwidth');
      }
    } finally {
      if (mounted) setState(() => _isTestingSpeed = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final xFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (xFile != null && mounted) {
      setState(() => _photoFile = File(xFile.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kecamatan == null) {
      _snack('Pilih kecamatan terlebih dahulu', error: true);
      return;
    }
    if (_desa == null) {
      _snack('Pilih desa terlebih dahulu', error: true);
      return;
    }
    if (_sumberListrik == null) {
      _snack('Pilih sumber listrik', error: true);
      return;
    }
    if (_status == null) {
      _snack('Pilih status perangkat', error: true);
      return;
    }
    if (!_isEdit && _photoFile == null) {
      _snack('Foto wajib dipilih', error: true);
      return;
    }

    final fields = <String, String>{
      'kategori': _kategori ?? '',
      'tahun_operasional': _tahunOperasional.toString(),
      'kecamatan': _kecamatan!,
      'desa': _desa!,
      'nama_lokasi': _namaLokasiCtrl.text.trim(),
      'alamat': _alamatCtrl.text.trim(),
      'latitude': _latCtrl.text.trim(),
      'longitude': _lngCtrl.text.trim(),
      'bandwidth': _bandwidthCtrl.text.trim(),
      'sumber_listrik': _sumberListrik!,
      'nama_kontak': _namaKontakCtrl.text.trim(),
      'email_kontak': _emailKontakCtrl.text.trim(),
      'telp_kontak': _telpKontakCtrl.text.trim(),
      'status': _status!,
      'keterangan': _keteranganCtrl.text.trim(),
    };

    final user = context.read<AuthProvider>().user;
    final userName = user?.name.trim() ?? '';
    if (userName.isNotEmpty) {
      fields['nama_petugas'] = userName;
    }

    final provider = context.read<ApiVsatProvider>();
    if (!_isEdit) {
      final hasNetwork = await provider.hasNetwork();
      if (!hasNetwork) {
        await context.read<VsatPendingProvider>().addPending(
          fields: fields,
          photoPath: _photoFile!.path,
        );
        if (!mounted) return;
        _snack('Offline: data disimpan ke pending list');
        Navigator.of(context).pop(true);
        return;
      }
    }

    final String? error = _isEdit
        ? await provider.update(widget.item!.id, fields, _photoFile)
        : await provider.store(fields, _photoFile!);

    if (!mounted) return;

    if (error != null) {
      _snack(error, error: true);
    } else {
      _snack(_isEdit ? 'Data berhasil diperbarui' : 'Data berhasil disimpan');
      Navigator.of(context).pop(true);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
      ),
    );
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isSubmitting = context.watch<ApiVsatProvider>().isSubmitting;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFE),
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Data VSAT Bakti' : 'Tambah Data VSAT Bakti',
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: _grad,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            // 1. Informasi Program
            _sectionCard(
              icon: Icons.category_rounded,
              title: 'Informasi Program',
              color: const Color(0xFF0E7490),
              children: [
                _dropdownField<String>(
                  label: 'Kategori',
                  value: _kategori,
                  items: _kategoriOptions,
                  displayText: (v) => v,
                  hint: 'Pilih Kategori',
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                  onChanged: (v) => setState(() => _kategori = v),
                ),
                const SizedBox(height: 12),
                _dropdownField<int>(
                  label: 'Tahun Operasional',
                  value: _tahunOperasional,
                  items: _tahunOptions,
                  displayText: (v) => v.toString(),
                  hint: 'Pilih tahun',
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                  onChanged: (v) => setState(() => _tahunOperasional = v),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Lokasi
            _sectionCard(
              icon: Icons.location_on_rounded,
              title: 'Lokasi',
              color: const Color(0xFF2563EB),
              children: [
                _dropdownField<String>(
                  label: 'Kecamatan',
                  value: _kecamatan,
                  items: _kecamatanDesa.keys.toList(),
                  displayText: (v) => v,
                  hint: 'Pilih kecamatan',
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                  onChanged: (v) => setState(() {
                    _kecamatan = v;
                    _desa = null;
                  }),
                ),
                const SizedBox(height: 12),
                _dropdownField<String>(
                  label: 'Desa',
                  value: _desa,
                  items: _desaOptions,
                  displayText: (v) => v,
                  hint: _kecamatan == null
                      ? 'Pilih kecamatan dulu'
                      : 'Pilih desa',
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                  onChanged: _kecamatan == null
                      ? null
                      : (v) => setState(() => _desa = v),
                ),
                const SizedBox(height: 12),
                _textField(
                  label: 'Nama Lokasi',
                  ctrl: _namaLokasiCtrl,
                  hint: 'Contoh: Kantor Desa Kupang Bersih',
                  validator: _required,
                ),
                const SizedBox(height: 12),
                _textField(
                  label: 'Alamat',
                  ctrl: _alamatCtrl,
                  hint: 'Alamat lengkap lokasi',
                  maxLines: 3,
                  validator: _required,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Koordinat
            _sectionCard(
              icon: Icons.my_location_rounded,
              title: 'Koordinat',
              color: const Color(0xFFD97706),
              children: [
                // Auto-fill button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: _isGettingLocation ? null : _getCurrentLocation,
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: _isGettingLocation
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF059669),
                                    Color(0xFF0891B2),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: _isGettingLocation
                              ? const Color(0xFFE2E8F0)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _isGettingLocation
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x3005968D),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isGettingLocation)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            else
                              const Icon(
                                Icons.my_location_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _isGettingLocation
                                  ? 'Mengambil lokasi…'
                                  : 'Ambil Lokasi Otomatis',
                              style: TextStyle(
                                color: _isGettingLocation
                                    ? const Color(0xFF64748B)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _textField(
                        label: 'Latitude',
                        ctrl: _latCtrl,
                        hint: '-1.848630',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*\.?\d*'),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Wajib diisi';
                          if (double.tryParse(v) == null) {
                            return 'Format salah';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _textField(
                        label: 'Longitude',
                        ctrl: _lngCtrl,
                        hint: '115.033380',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*\.?\d*'),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Wajib diisi';
                          if (double.tryParse(v) == null) {
                            return 'Format salah';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 4. Teknis
            _sectionCard(
              icon: Icons.settings_input_antenna_rounded,
              title: 'Teknis',
              color: const Color(0xFF7C3AED),
              children: [
                _textField(
                  label: 'Bandwidth',
                  ctrl: _bandwidthCtrl,
                  hint: 'Contoh: 10 Mbps',
                  validator: _required,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: _isTestingSpeed ? null : _runDownloadTest,
                      borderRadius: BorderRadius.circular(10),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: _isTestingSpeed
                              ? null
                              : const LinearGradient(
                                  colors: _grad,
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: _isTestingSpeed
                              ? const Color(0xFFE2E8F0)
                              : null,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _isTestingSpeed
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0x300E7490),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isTestingSpeed)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            else
                              const Icon(
                                Icons.speed_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _isTestingSpeed
                                  ? 'Menguji kecepatan...'
                                  : 'Uji Download Otomatis',
                              style: TextStyle(
                                color: _isTestingSpeed
                                    ? const Color(0xFF64748B)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _dropdownField<String>(
                  label: 'Sumber Listrik',
                  value: _sumberListrik,
                  items: _sumberListrikOptions,
                  displayText: (v) => v,
                  hint: 'Pilih sumber listrik',
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                  onChanged: (v) => setState(() => _sumberListrik = v),
                ),
                const SizedBox(height: 12),
                _dropdownField<String>(
                  label: 'Status',
                  value: _status,
                  items: const ['On Air', 'Off Air'],
                  displayText: (v) => v,
                  hint: 'Pilih status',
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                  onChanged: (v) => setState(() => _status = v),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Kontak
            _sectionCard(
              icon: Icons.contacts_rounded,
              title: 'Kontak',
              color: const Color(0xFF059669),
              children: [
                _textField(
                  label: 'Nama Kontak',
                  ctrl: _namaKontakCtrl,
                  hint: 'Nama penanggung jawab',
                  validator: _required,
                ),
                const SizedBox(height: 12),
                _textField(
                  label: 'Email',
                  ctrl: _emailKontakCtrl,
                  hint: 'kontak@email.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _textField(
                  label: 'Telepon',
                  ctrl: _telpKontakCtrl,
                  hint: '0812xxxxxxxx',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 6. Keterangan
            _sectionCard(
              icon: Icons.notes_rounded,
              title: 'Keterangan',
              color: const Color(0xFF64748B),
              children: [
                _textField(
                  label: 'Keterangan (opsional)',
                  ctrl: _keteranganCtrl,
                  hint: 'Catatan tambahan…',
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 7. Foto
            _sectionCard(
              icon: Icons.photo_camera_rounded,
              title: 'Foto VSAT',
              color: const Color(0xFF0891B2),
              children: [
                if (_photoFile != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _photoFile!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else if (_isEdit &&
                    (widget.item?.fotoVsat.isNotEmpty ?? false)) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          'https://tower.baritotimurkab.go.id/storage/${widget.item!.fotoVsat}',
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _photoPlaceholder(160),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Foto saat ini',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  _photoPlaceholder(110),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _photoButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Kamera',
                        onTap: () => _pickPhoto(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _photoButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Galeri',
                        onTap: () => _pickPhoto(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                if (!_isEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '* Foto wajib diisi',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildSubmitFab(isSubmitting),
    );
  }

  Widget _buildSubmitFab(bool isSubmitting) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: isSubmitting ? null : _submit,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                gradient: isSubmitting
                    ? null
                    : const LinearGradient(
                        colors: _grad,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                color: isSubmitting ? const Color(0xFFE2E8F0) : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSubmitting
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0x400E7490),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSubmitting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF64748B),
                      ),
                    )
                  else
                    const Icon(
                      Icons.save_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  const SizedBox(width: 10),
                  Text(
                    isSubmitting
                        ? 'Menyimpan…'
                        : (_isEdit ? 'Simpan Perubahan' : 'Simpan Data'),
                    style: TextStyle(
                      color: isSubmitting
                          ? const Color(0xFF64748B)
                          : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.4,
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

  // ─── reusable widgets ─────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0F2FE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withAlpha(12),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: color.withAlpha(30))),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController ctrl,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFADB5BD)),
        filled: true,
        fillColor: const Color(0xFFF8FFFE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0891B2), width: 1.8),
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required String hint,
    required ValueChanged<T?>? onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FFFE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFBAE6FD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0891B2), width: 1.8),
        ),
      ),
      hint: Text(
        hint,
        style: const TextStyle(fontSize: 12.5, color: Color(0xFFADB5BD)),
      ),
      validator: validator,
      items: items
          .map(
            (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(
                displayText(e),
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDFE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0891B2)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF0E7490),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder(double height) => Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFE0F2FE),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(
          Icons.add_photo_alternate_rounded,
          size: 36,
          color: Color(0xFF0891B2),
        ),
        SizedBox(height: 6),
        Text(
          'Pilih foto VSAT',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    ),
  );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;
}

// ─── Download speed-test dialog ───────────────────────────────────────────────

class _DownloadTestDialog extends StatefulWidget {
  final NetworkMetricsService service;

  const _DownloadTestDialog({required this.service});

  @override
  State<_DownloadTestDialog> createState() => _DownloadTestDialogState();
}

class _DownloadTestDialogState extends State<_DownloadTestDialog> {
  bool _running = true;
  double _progress = 0;
  double? _liveSpeedMbps;
  String _stageLabel = 'Memulai...';
  SpeedMetrics? _result;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final result = await widget.service.runSpeedTest(
        onProgress: (stage, percent) {
          if (!mounted) return;
          setState(() {
            _progress = (percent / 100.0).clamp(0.0, 1.0);
            _stageLabel = switch (stage) {
              SpeedTestStage.download =>
                'Download (${percent.toStringAsFixed(0)}%)',
              SpeedTestStage.upload => 'Upload...',
              SpeedTestStage.ping => 'Ping...',
            };
          });
        },
        onSpeedUpdate: (stage, speedMbps) {
          if (!mounted || stage != SpeedTestStage.download) return;
          setState(() => _liveSpeedMbps = speedMbps);
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _running = false;
        _stageLabel = 'Selesai';
        _progress = 1;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = const SpeedMetrics();
        _running = false;
        _stageLabel = 'Gagal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = _result?.downloadMbps;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.speed_rounded, color: Color(0xFF0E7490)),
          SizedBox(width: 8),
          Text('Uji Download'),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF0E7490)),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      _running
                          ? '${(_liveSpeedMbps ?? 0).toStringAsFixed(2)} Mbps'
                          : '${(_progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _stageLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6EE7B7)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Download Speed',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                  Text(
                    _running
                        ? '${(_liveSpeedMbps ?? 0).toStringAsFixed(2)} Mbps'
                        : dl != null
                        ? '${dl.toStringAsFixed(2)} Mbps'
                        : '-',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0E7490),
                    ),
                  ),
                ],
              ),
            ),
            if (!_running && dl == null && _result?.downloadError != null) ...[
              const SizedBox(height: 10),
              Text(
                'Download gagal: ${_result!.downloadError}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
              ),
            ],
            if (!_running &&
                _result?.uploadMbps == null &&
                _result?.uploadError != null) ...[
              const SizedBox(height: 10),
              Text(
                'Upload gagal: ${_result!.uploadError}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _running || dl == null
              ? null
              : () => Navigator.of(context).pop(_result),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0E7490),
          ),
          child: const Text('Gunakan Hasil'),
        ),
      ],
    );
  }
}
