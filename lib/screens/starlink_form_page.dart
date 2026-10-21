import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/bantuan_starlink.dart';
import '../providers/auth_provider.dart';
import '../providers/api_starlink_provider.dart';

class StarlinkFormPage extends StatefulWidget {
  /// Null → tambah baru, non-null → edit existing record.
  final BantuanStarlink? item;

  const StarlinkFormPage({super.key, this.item});

  @override
  State<StarlinkFormPage> createState() => _StarlinkFormPageState();
}

class _StarlinkFormPageState extends State<StarlinkFormPage> {
  // ─── constants ────────────────────────────────────────────────────────────

  static const List<Color> _grad = [Color(0xFF5B21B6), Color(0xFF7C3AED)];

  static const List<String> _kategoriOptions = [
    'Program Provinsi',
    'Program Kabupaten',
  ];

  static const Map<String, List<String>> _kecamatanDesa = {
    'Dusun Timur': [
      'Tamiang Layang', 'Pulau Patai', 'Sarapat', 'Magantis', 'Jaar',
      'Matabu', 'Jaweten', 'Haringen', 'Dorong', 'Didi', 'Karang Langit',
      'Harara', 'Mangkarap', 'Matarah', 'Gumpa', 'Maragut', 'Sumur',
    ],
    'Dusun Tengah': [
      'Ampah Kota', 'Saing', 'Ampah Dua', 'Putai', 'Netampin',
      'Sumber Garunggung', 'Muara Awang', 'Rodok',
    ],
    'Banua Lima': [
      'Kandris', 'Banyu Landas', 'Bagok', 'Bamban', 'Tewah Pupuh',
      'Gudang Seng',
    ],
    'Patangkep Tutui': [
      'Pulau Padang', 'Ramania', 'Kambitin', 'Bentot', 'Ampari Bora',
      'Kotam', 'Betang Nalong', 'Mawani', 'Jango', 'Lalap',
    ],
    'Awang': [
      'Janah Jari', 'Bangkirayen', 'Tangkan', 'Ampari', 'Wungkur Nanakan',
      'Hayaping', 'Biwan', 'Apar Batu', 'Pianggu', 'Danau', 'Janah Mansiwui',
    ],
    'Paju Epat': [
      'Telang', 'Murutuwu', 'Balawa', 'Maipe', 'Telang Baru',
      'Juru Banu', 'Tampu Langit', 'Siong', 'Kalinapu',
    ],
    'Karusen Janang': [
      'Dayu', 'Wuran', 'Ipu Mea', 'Simpang Naneng', 'Lagan',
      'Putut Tawuluh', 'Kandris',
    ],
    'Paku': [
      'Tampa', 'Runggu Raya', 'Patung', 'Kalamus', 'Simpang Bingkuang',
      'Kupang Baru', 'Luwau Jawuk', 'Tarinsing', 'Bantai Napu',
      'Pangkan', 'Gandrung', 'Paku Beto',
    ],
    'Pematang Karau': [
      'Muara Palantau', 'Ketab', 'Kupang Bersih', 'Tuyau', 'Pinang Tunggal',
      'Nagaleah', 'Lampeong', 'Bararawa', 'Bambulung', 'Lebo',
      'Tumpung Ulung', 'Muruduyung', 'Sumberejo',
    ],
    'Raren Batuah': [
      'Unsum', 'Baruyan', 'Lenggang', 'Puri', 'Batuah',
      'Turan Amis', 'Tangkum', 'Sibung', 'Malintut',
    ],
  };

  // ─── state ────────────────────────────────────────────────────────────────

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  String? _kategori;
  late final TextEditingController _namaLokasiCtrl;
  late final TextEditingController _alamatCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _idStarlinkCtrl;
  late final TextEditingController _namaKontakCtrl;
  late final TextEditingController _telpKontakCtrl;
  late final TextEditingController _keteranganCtrl;

  int? _tahunBantuan;
  String? _kecamatan;
  String? _desa;
  String? _status;
  File? _photoFile;
  bool _isGettingLocation = false;

  bool get _isEdit => widget.item != null;

  List<String> get _desaOptions =>
      _kecamatan != null ? (_kecamatanDesa[_kecamatan] ?? []) : [];

  static List<int> get _tahunOptions {
    final now = DateTime.now().year;
    return List<int>.generate(now - 2019, (i) => now - i);
  }

  // ─── lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final d = widget.item;
    if (d != null && d.kategoriProgram.isNotEmpty) {
      try {
        _kategori = _kategoriOptions.firstWhere(
          (k) => k.toLowerCase() == d.kategoriProgram.toLowerCase(),
        );
      } catch (_) {
        _kategori = d.kategoriProgram;
      }
    }
    _namaLokasiCtrl = TextEditingController(text: d?.namaLokasi ?? '');
    _alamatCtrl = TextEditingController(text: d?.alamat ?? '');
    _latCtrl = TextEditingController(
        text: d != null && d.latitude != 0 ? d.latitude.toString() : '');
    _lngCtrl = TextEditingController(
        text: d != null && d.longitude != 0 ? d.longitude.toString() : '');
    _idStarlinkCtrl = TextEditingController(text: d?.idStarlink ?? '');
    _namaKontakCtrl = TextEditingController(text: d?.namaKontak ?? '');
    _telpKontakCtrl = TextEditingController(text: d?.telpKontak ?? '');
    _keteranganCtrl = TextEditingController(text: d?.keterangan ?? '');

    if (d != null) {
      _tahunBantuan = d.tahunBantuan != 0 ? d.tahunBantuan : null;
      // Case-insensitive kecamatan match
      if (d.kecamatan.isNotEmpty) {
        try {
          _kecamatan = _kecamatanDesa.keys.firstWhere(
            (k) => k.toLowerCase() == d.kecamatan.toLowerCase(),
          );
        } catch (_) {
          _kecamatan = d.kecamatan;
        }
      }
      // Case-insensitive desa match
      if (_kecamatan != null && d.desa.isNotEmpty) {
        final desaList = _kecamatanDesa[_kecamatan] ?? [];
        try {
          _desa = desaList.firstWhere(
            (v) => v.toLowerCase() == d.desa.toLowerCase(),
          );
        } catch (_) {}
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
    _idStarlinkCtrl.dispose();
    _namaKontakCtrl.dispose();
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

  Future<void> _pickPhoto(ImageSource source) async {
    final xFile =
        await _picker.pickImage(source: source, imageQuality: 80);
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
    if (_status == null) {
      _snack('Pilih status perangkat', error: true);
      return;
    }
    if (!_isEdit && _photoFile == null) {
      _snack('Foto wajib dipilih', error: true);
      return;
    }

    final fields = <String, String>{
      'kategori_program': _kategori ?? '',
      'tahun_bantuan': _tahunBantuan.toString(),
      'kecamatan': _kecamatan!,
      'desa': _desa!,
      'nama_lokasi': _namaLokasiCtrl.text.trim(),
      'alamat': _alamatCtrl.text.trim(),
      'latitude': _latCtrl.text.trim(),
      'longitude': _lngCtrl.text.trim(),
      'id_starlink': _idStarlinkCtrl.text.trim(),
      'nama_kontak': _namaKontakCtrl.text.trim(),
      'telp_kontak': _telpKontakCtrl.text.trim(),
      'status': _status!,
      'keterangan': _keteranganCtrl.text.trim(),
    };

    final user = context.read<AuthProvider>().user;
    final userName = user?.name.trim() ?? '';
    if (userName.isNotEmpty) {
      fields['nama_petugas'] = userName;
    }

    final provider = context.read<ApiStarlinkProvider>();
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor:
          error ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
    ));
  }

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title:
            Text(_isEdit ? 'Edit Data Starlink' : 'Tambah Data Starlink'),
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
              color: const Color(0xFF7C3AED),
              children: [
                _dropdownField<String>(
                  label: 'Kategori Program',
                  value: _kategori,
                  items: _kategoriOptions,
                  displayText: (v) => v,
                  hint: 'Pilih Kategori',
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                  onChanged: (v) => setState(() => _kategori = v),
                ),
                const SizedBox(height: 12),
                _dropdownField<int>(
                  label: 'Tahun Bantuan',
                  value: _tahunBantuan,
                  items: _tahunOptions,
                  displayText: (v) => v.toString(),
                  hint: 'Pilih tahun',
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                  onChanged: (v) => setState(() => _tahunBantuan = v),
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
                                    Color(0xFF0891B2)
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
                                      offset: Offset(0, 3))
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
                              const Icon(Icons.my_location_rounded,
                                  color: Colors.white, size: 18),
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
                // Manual fields
                Row(
                  children: [
                    Expanded(
                      child: _textField(
                        label: 'Latitude',
                        ctrl: _latCtrl,
                        hint: '-1.848630',
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*\.?\d*')),
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
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^-?\d*\.?\d*')),
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

            // 4. Perangkat
            _sectionCard(
              icon: Icons.satellite_alt_rounded,
              title: 'Perangkat',
              color: const Color(0xFF0891B2),
              children: [
                _textField(
                  label: 'ID Starlink',
                  ctrl: _idStarlinkCtrl,
                  hint: 'Contoh: ACC',
                  validator: _required,
                ),
                const SizedBox(height: 12),
                _dropdownField<String>(
                  label: 'Status',
                  value: _status,
                  items: const ['Online', 'Offline'],
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
              icon: Icons.person_rounded,
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
                  label: 'Nomor Telepon',
                  ctrl: _telpKontakCtrl,
                  hint: '08xxxxxxxxxx',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    if (v.length > 13) return 'Maks 13 digit';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 6. Keterangan
            _sectionCard(
              icon: Icons.notes_rounded,
              title: 'Keterangan (opsional)',
              color: const Color(0xFF64748B),
              children: [
                _textField(
                  label: 'Keterangan',
                  ctrl: _keteranganCtrl,
                  hint: 'Catatan tambahan...',
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 7. Foto
            _buildPhotoSection(),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Consumer<ApiStarlinkProvider>(
        builder: (_, p, _) => SizedBox(
          width: MediaQuery.of(context).size.width - 32,
          height: 50,
          child: p.isSubmitting
              ? Container(
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: _grad),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    ),
                  ),
                )
              : Material(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _submit,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient:
                            const LinearGradient(colors: _grad),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x555B21B6),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.save_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isEdit
                                  ? 'Simpan Perubahan'
                                  : 'Simpan Data',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  // ─── photo section ────────────────────────────────────────────────────────

  Widget _buildPhotoSection() {
    final existingUrl =
        _isEdit && (widget.item?.fotoStarlink.isNotEmpty ?? false)
            ? 'https://tower.baritotimurkab.go.id/storage/${widget.item!.fotoStarlink}'
            : null;

    return _sectionCard(
      icon: Icons.photo_camera_rounded,
      title: _isEdit
          ? 'Foto Starlink (kosongkan jika tidak diubah)'
          : 'Foto Starlink *',
      color: const Color(0xFF7C3AED),
      children: [
        if (_photoFile != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _photoFile!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else if (existingUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              existingUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        if (_photoFile != null || existingUrl != null)
          const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _outlineBtn(
                icon: Icons.photo_library_rounded,
                label: 'Galeri',
                onTap: () => _pickPhoto(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _outlineBtn(
                icon: Icons.camera_alt_rounded,
                label: 'Kamera',
                onTap: () => _pickPhoto(ImageSource.camera),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _outlineBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF7C3AED),
        side: const BorderSide(color: Color(0xFF7C3AED)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  // ─── section card ─────────────────────────────────────────────────────────

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
        border: Border.all(color: const Color(0xFFE9EDF4)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // ─── field helpers ────────────────────────────────────────────────────────

  static String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null;

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 12.5, color: Color(0xFFCBD5E1)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: Color(0xFFDC2626), width: 1.5),
        ),
      );

  Widget _textField({
    required String label,
    required TextEditingController ctrl,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: _deco(label, hint: hint),
      );

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) displayText,
    required String hint,
    required ValueChanged<T?>? onChanged,
    String? Function(T?)? validator,
  }) =>
      DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        style:
            const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
        decoration: _deco(label),
        hint: Text(hint,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFFCBD5E1))),
        validator: validator,
        items: items
            .map((e) => DropdownMenuItem<T>(
                value: e, child: Text(displayText(e))))
            .toList(),
        onChanged: onChanged,
      );
}
