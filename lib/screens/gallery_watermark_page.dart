import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/photo_stamp_service.dart';

class GalleryWatermarkPage extends StatefulWidget {
  const GalleryWatermarkPage({super.key});

  @override
  State<GalleryWatermarkPage> createState() => _GalleryWatermarkPageState();
}

class _GalleryWatermarkPageState extends State<GalleryWatermarkPage> {
  static const _maxLocalPreviews = 10;
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
  final _picker = ImagePicker();
  late final TextEditingController _streetController;
  late final TextEditingController _villageController;
  late final TextEditingController _districtController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _staffController;

  DateTime? _date;
  TimeOfDay? _time;
  Uint8List? _photoBytes;
  String? _photoName;
  File? _previewFile;
  File? _editingPreviewFile;
  List<File> _localPreviews = [];
  Directory? _previewDirectory;
  bool _isPickingPhoto = false;
  bool _isGettingLocation = false;
  bool _isGenerating = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    final nowWib = DateTime.now().toUtc().add(const Duration(hours: 7));
    _date = DateTime(nowWib.year, nowWib.month, nowWib.day);
    _time = TimeOfDay(hour: nowWib.hour, minute: nowWib.minute);
    _streetController = TextEditingController();
    _villageController = TextEditingController();
    _districtController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _staffController = TextEditingController(
      text: context.read<AuthProvider>().user?.name ?? '',
    );
    _loadLocalPreviews();
  }

  @override
  void dispose() {
    _streetController.dispose();
    _villageController.dispose();
    _districtController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _staffController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')} WIB';

  Future<Directory> _getPreviewDirectory() async {
    final existing = _previewDirectory;
    if (existing != null) return existing;
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}watermarked_photos',
    );
    await directory.create(recursive: true);
    _previewDirectory = directory;
    return directory;
  }

  Future<void> _loadLocalPreviews() async {
    try {
      final directory = await _getPreviewDirectory();
      final files = await directory
          .list()
          .where((entry) => entry is File && entry.path.endsWith('.png'))
          .cast<File>()
          .toList();
      files.sort(
        (left, right) =>
            right.statSync().modified.compareTo(left.statSync().modified),
      );
      if (!mounted) return;
      setState(() {
        _localPreviews = files.take(_maxLocalPreviews).toList();
        _previewFile = _localPreviews.isEmpty ? null : _localPreviews.first;
      });
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal membaca preview lokal: $error', isError: true);
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _isPickingPhoto = true);
    try {
      final selected = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2560,
        maxHeight: 2560,
      );
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _photoBytes = bytes;
        _photoName = selected.name;
        _previewFile = null;
      });
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal membuka foto: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (selected != null && mounted) setState(() => _time = selected);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('Aktifkan layanan lokasi terlebih dahulu.', isError: true);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Izin lokasi belum diberikan.', isError: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal mengambil lokasi: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  String? _validateCoordinate(String? value, {required bool isLatitude}) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null) return 'Koordinat wajib diisi dengan angka';
    final min = isLatitude ? -90 : -180;
    final max = isLatitude ? 90 : 180;
    if (number < min || number > max) return 'Koordinat di luar rentang';
    return null;
  }

  bool _isGallerySaveSuccess(dynamic result) {
    if (result is! Map) return false;
    final success = result['isSuccess'] ?? result['success'];
    if (success == true || success == 1 || success == '1') return true;
    final filePath = result['filePath'];
    return filePath is String && filePath.isNotEmpty;
  }

  Future<bool> _requestGalleryPermission() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    final status = await Permission.photosAddOnly.request();
    if (status.isGranted || status.isLimited) return true;
    final fallback = await Permission.photos.request();
    return fallback.isGranted || fallback.isLimited;
  }

  String _safeVillageName() {
    final village = _villageController.text.trim();
    final safeVillage = village
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return safeVillage.isEmpty ? 'Foto' : safeVillage;
  }

  String _nextPreviewBaseName() {
    final village = _safeVillageName();
    final prefix = '${village}_'.toLowerCase();
    var highestNumber = 0;
    for (final file in _localPreviews) {
      final fileName = file.uri.pathSegments.last;
      final normalizedName = fileName.toLowerCase();
      if (!normalizedName.startsWith(prefix) ||
          !normalizedName.endsWith('.png')) {
        continue;
      }
      final numberText = fileName.substring(prefix.length, fileName.length - 4);
      final number = int.tryParse(numberText);
      if (number != null && number > highestNumber) highestNumber = number;
    }
    final sequence = (highestNumber + 1).toString().padLeft(3, '0');
    return '${village}_$sequence';
  }

  Future<void> _generateLocalPreview() async {
    if (_isGenerating) return;
    if (_photoBytes == null) {
      _showMessage('Pilih foto dari galeri terlebih dahulu.', isError: true);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final date = _date!;
      final time = _time!;
      final timestamp = DateTime.utc(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).subtract(const Duration(hours: 7));
      final bytes = await PhotoStampService.stamp(
        photoBytes: _photoBytes!,
        timestamp: timestamp,
        desa: _villageController.text.trim(),
        kecamatan: _districtController.text.trim(),
        locationPrefix: _streetController.text.trim(),
        latitude: _latitudeController.text.trim(),
        longitude: _longitudeController.text.trim(),
        staffName: _staffController.text.trim(),
      );
      if (!mounted) return;

      final directory = await _getPreviewDirectory();
      final editingFile = _editingPreviewFile;
      final preview = editingFile ?? File(
        '${directory.path}${Platform.pathSeparator}${_nextPreviewBaseName()}.png',
      );
      final originalFile = File(preview.path.replaceFirst(RegExp(r'\.png$'), '.original'));
      final metadataFile = File(preview.path.replaceFirst(RegExp(r'\.png$'), '.json'));

      // Simpan foto sumber hanya saat membuat watermark baru. Saat edit,
      // foto sumber lama dipakai agar watermark tidak bertumpuk.
      if (editingFile == null || !await originalFile.exists()) {
        await originalFile.writeAsBytes(_photoBytes!, flush: true);
      }
      await preview.writeAsBytes(bytes, flush: true);
      await metadataFile.writeAsString(jsonEncode({
        'date': '${date.year}-${date.month}-${date.day}',
        'hour': time.hour,
        'minute': time.minute,
        'street': _streetController.text.trim(),
        'village': _villageController.text.trim(),
        'district': _districtController.text.trim(),
        'latitude': _latitudeController.text.trim(),
        'longitude': _longitudeController.text.trim(),
        'staff': _staffController.text.trim(),
      }), flush: true);

      final allPreviews = editingFile != null
          ? _localPreviews
          : [preview, ..._localPreviews];
      for (final oldPreview in allPreviews.skip(_maxLocalPreviews)) {
        if (await oldPreview.exists()) await oldPreview.delete();
        final oldOriginal = File(oldPreview.path.replaceFirst(RegExp(r'\.png$'), '.original'));
        final oldMetadata = File(oldPreview.path.replaceFirst(RegExp(r'\.png$'), '.json'));
        if (await oldOriginal.exists()) await oldOriginal.delete();
        if (await oldMetadata.exists()) await oldMetadata.delete();
      }
      if (!mounted) return;
      setState(() {
        _previewFile = preview;
        _editingPreviewFile = null;
        _localPreviews = allPreviews.take(_maxLocalPreviews).toList();
      });
      _showMessage(editingFile == null
          ? 'Preview watermark tersimpan di aplikasi.'
          : 'Watermark berhasil diperbarui.');
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal membuat watermark: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _editPreview(File preview) async {
    final original = File(preview.path.replaceFirst(RegExp(r'\.png$'), '.original'));
    final metadata = File(preview.path.replaceFirst(RegExp(r'\.png$'), '.json'));
    if (!await original.exists() || !await metadata.exists()) {
      _showMessage(
        'Foto lama belum memiliki sumber asli untuk diedit. Foto baru yang dibuat setelah pembaruan mendukung edit.',
        isError: true,
      );
      return;
    }
    try {
      final data = jsonDecode(await metadata.readAsString()) as Map<String, dynamic>;
      final dateParts = (data['date'] as String).split('-').map(int.parse).toList();
      if (!mounted) return;
      setState(() {
        _photoBytes = original.readAsBytesSync();
        _photoName = preview.uri.pathSegments.last.replaceFirst('.png', '.original');
        _date = DateTime(dateParts[0], dateParts[1], dateParts[2]);
        _time = TimeOfDay(hour: data['hour'] as int, minute: data['minute'] as int);
        _streetController.text = data['street'] as String? ?? '';
        _villageController.text = data['village'] as String? ?? '';
        _districtController.text = data['district'] as String? ?? '';
        _latitudeController.text = data['latitude'] as String? ?? '';
        _longitudeController.text = data['longitude'] as String? ?? '';
        _staffController.text = data['staff'] as String? ?? '';
        _editingPreviewFile = preview;
        _previewFile = preview;
      });
      Navigator.of(context).pop();
      _showMessage('Mode edit aktif. Ubah data lalu tekan Buat Preview.');
    } catch (error) {
      _showMessage('Gagal membuka data edit: $error', isError: true);
    }
  }

  Future<void> _deletePreview(File preview) async {
    try {
      final original = File(preview.path.replaceFirst(RegExp(r'\.png$'), '.original'));
      final metadata = File(preview.path.replaceFirst(RegExp(r'\.png$'), '.json'));
      if (await preview.exists()) await preview.delete();
      if (await original.exists()) await original.delete();
      if (await metadata.exists()) await metadata.delete();
      if (!mounted) return;
      setState(() {
        _localPreviews.removeWhere((file) => file.path == preview.path);
        if (_previewFile?.path == preview.path) {
          _previewFile = _localPreviews.isEmpty ? null : _localPreviews.first;
        }
        if (_editingPreviewFile?.path == preview.path) {
          _editingPreviewFile = null;
        }
      });
      _showMessage('Foto watermark berhasil dihapus.');
    } catch (error) {
      _showMessage('Gagal menghapus foto: $error', isError: true);
    }
  }

  Future<void> _downloadPreview([File? selectedPreview]) async {
    final preview = selectedPreview ?? _previewFile;
    if (preview == null || _isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final granted = await _requestGalleryPermission();
      if (!granted) {
        _showMessage(
          'Izin simpan foto ke galeri belum diberikan.',
          isError: true,
        );
        return;
      }
      final result = await ImageGallerySaver.saveImage(
        await preview.readAsBytes(),
        name: preview.uri.pathSegments.last.replaceFirst('.png', ''),
        quality: 100,
      );
      if (!_isGallerySaveSuccess(result)) {
        throw Exception('Foto tidak berhasil disimpan ke galeri.');
      }
      _showMessage('Foto watermark tersimpan ke galeri.');
    } catch (error) {
      if (mounted) {
        _showMessage('Gagal mengunduh foto: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _showPreviewResults() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocalPreviewResultsSheet(
        files: _localPreviews,
        initialSelection: _previewFile,
        onDownload: _downloadPreview,
        onEdit: _editPreview,
        onDelete: _deletePreview,
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFB91C1C) : null,
        ),
      );
  }

  InputDecoration _decoration(
    String label, {
    String? hint,
    IconData? icon,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 20, color: const Color(0xFF64748B)),
        labelStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF0F766E),
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFDC2626),
            width: 1.4,
          ),
        ),
      );

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8EFEC)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123D35).withOpacity(0.045),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF173B35),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF81908B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _timestampButton({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: const Color(0xFFF7FAF9),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE1EAE6)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF3EC),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFF0F766E)),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF81908B),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF183B38),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0F766E);
    const darkGreen = Color(0xFF123D35);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F7F5),
        foregroundColor: darkGreen,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Watermark Foto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173B35),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Dokumentasi kegiatan lapangan',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF71817B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hasil preview',
            onPressed: _showPreviewResults,
            icon: Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFE1EAE6)),
              ),
              child: const Icon(
                Icons.collections_outlined,
                size: 20,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF3F7F5),
              Color(0xFFEDF5F1),
              Color(0xFFF8FAF9),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Header / intro
              Container(
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'DOKUMENTASI DIGITAL',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Abadikan momen,\nlengkapi informasinya.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tambahkan waktu, lokasi, dan identitas petugas pada foto.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Photo selection
              _sectionCard(
                title: 'Foto Dokumentasi',
                subtitle: 'Pilih foto yang akan diberi watermark',
                icon: Icons.photo_camera_back_rounded,
                iconColor: const Color(0xFF0F766E),
                child: Column(
                  children: [
                    if (_photoBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.memory(
                                _photoBytes!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.48),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF86EFAC),
                                    size: 17,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      _photoName ?? 'Foto dipilih',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Ganti foto',
                                    onPressed: _isPickingPhoto
                                        ? null
                                        : () => _pickPhoto(ImageSource.gallery),
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withOpacity(0.18),
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.edit_rounded),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 13),
                    ] else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 23),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAF9),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: const Color(0xFFDCE8E2),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 39,
                              color: Color(0xFF7B9A90),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Belum ada foto dipilih',
                              style: TextStyle(
                                color: Color(0xFF47645B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Gunakan kamera atau pilih dari galeri',
                              style: TextStyle(
                                color: Color(0xFF81908B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isPickingPhoto
                                ? null
                                : () => _pickPhoto(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_rounded, size: 19),
                            label: const Text('Kamera'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: const BorderSide(color: Color(0xFFB8D9CF)),
                              minimumSize: const Size.fromHeight(47),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isPickingPhoto
                                ? null
                                : () => _pickPhoto(ImageSource.gallery),
                            icon: _isPickingPhoto
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.photo_library_rounded,
                                    size: 19,
                                  ),
                            label: const Text('Galeri'),
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                              minimumSize: const Size.fromHeight(47),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: const Color(0xFFF0F8F5),
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        onTap: _showPreviewResults,
                        borderRadius: BorderRadius.circular(13),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.collections_bookmark_outlined,
                                size: 19,
                                color: primary,
                              ),
                              const SizedBox(width: 9),
                              const Expanded(
                                child: Text(
                                  'Lihat hasil watermark tersimpan',
                                  style: TextStyle(
                                    color: Color(0xFF24584E),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD5EEE5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_localPreviews.length}',
                                  style: const TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Timestamp
              _sectionCard(
                title: 'Waktu & Tanggal',
                subtitle: 'Atur waktu yang dicantumkan pada foto',
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFF2563EB),
                child: Row(
                  children: [
                    Expanded(
                      child: _timestampButton(
                        icon: Icons.calendar_month_rounded,
                        label: 'TANGGAL',
                        value: _formatDate(_date!),
                        onPressed: _chooseDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _timestampButton(
                        icon: Icons.access_time_filled_rounded,
                        label: 'WAKTU · WIB',
                        value: _formatTime(_time!),
                        onPressed: _chooseTime,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Location
              _sectionCard(
                title: 'Detail Lokasi',
                subtitle: 'Informasi tempat pengambilan foto',
                icon: Icons.location_on_rounded,
                iconColor: const Color(0xFFDC5252),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _streetController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(
                        'Jalan / patokan (opsional)',
                        hint: 'Contoh: Jalan A. Yani',
                        icon: Icons.add_road_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _villageController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(
                        'Desa / Kelurahan',
                        hint: 'Masukkan nama desa atau kelurahan',
                        icon: Icons.home_work_rounded,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Nama desa wajib diisi'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _districtController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoration(
                        'Kecamatan (opsional)',
                        hint: 'Masukkan nama kecamatan',
                        icon: Icons.map_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: _decoration(
                              'Latitude',
                              hint: '-2.000000',
                              icon: Icons.explore_outlined,
                            ),
                            validator: (value) => _validateCoordinate(
                              value,
                              isLatitude: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: _decoration(
                              'Longitude',
                              hint: '115.000000',
                              icon: Icons.explore_outlined,
                            ),
                            validator: (value) => _validateCoordinate(
                              value,
                              isLatitude: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isGettingLocation ? null : _useCurrentLocation,
                        icon: _isGettingLocation
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 19),
                        label: Text(
                          _isGettingLocation
                              ? 'Mengambil koordinat...'
                              : 'Ambil koordinat saat ini',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: const BorderSide(color: Color(0xFFB8D9CF)),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: Color(0xFF81908B),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Pastikan layanan lokasi perangkat aktif agar koordinat lebih akurat.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF81908B),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Officer
              _sectionCard(
                title: 'Informasi Petugas',
                subtitle: 'Nama yang dicantumkan pada watermark',
                icon: Icons.badge_rounded,
                iconColor: const Color(0xFF7C3AED),
                child: TextFormField(
                  controller: _staffController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(
                    'Nama petugas',
                    hint: 'Masukkan nama lengkap',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Nama petugas wajib diisi'
                          : null,
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Periksa kembali informasi sebelum membuat watermark.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF81908B),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: Color(0xFFE5ECE8)),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF123D35).withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _isGenerating ? null : _generateLocalPreview,
            icon: _isGenerating
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 21),
            label: Text(
              _isGenerating
                  ? 'Sedang membuat watermark...'
                  : (_editingPreviewFile != null
                      ? 'Simpan Perubahan Watermark'
                      : 'Buat Preview Watermark'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF83B8AD),
              minimumSize: const Size.fromHeight(54),
              elevation: 2,
              shadowColor: primary.withOpacity(0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _previewDisplayName(File file) {
  final name = file.uri.pathSegments.last.replaceFirst('.png', '');
  final parts = name.split('_');
  if (parts.length < 2) return name.replaceAll('-', ' ');
  final number = parts.removeLast();
  return '${parts.join(' ')} · $number';
}

class _LocalPreviewResultsSheet extends StatefulWidget {
  final List<File> files;
  final File? initialSelection;
  final Future<void> Function(File?) onDownload;
  final Future<void> Function(File) onEdit;
  final Future<void> Function(File) onDelete;

  const _LocalPreviewResultsSheet({
    required this.files,
    required this.initialSelection,
    required this.onDownload,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_LocalPreviewResultsSheet> createState() =>
      _LocalPreviewResultsSheetState();
}

class _LocalPreviewResultsSheetState extends State<_LocalPreviewResultsSheet> {
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _selectedFile = widget.initialSelection ?? widget.files.firstOrNull;
  }

  String _modifiedLabel(File file) {
    final modified = file.statSync().modified.toLocal();
    final day = modified.day.toString().padLeft(2, '0');
    final month = modified.month.toString().padLeft(2, '0');
    final hour = modified.hour.toString().padLeft(2, '0');
    final minute = modified.minute.toString().padLeft(2, '0');
    return '$day/$month/${modified.year}  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: screenHeight * 0.88,
        child: Material(
          color: const Color(0xFFF1F5F2),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
                  child: Column(
                    children: [
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB8C9C2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Hasil Preview',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF183B38),
                              ),
                            ),
                          ),
                          Text(
                            '${widget.files.length} tersimpan',
                            style: const TextStyle(
                              color: Color(0xFF62736E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
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
                  child: widget.files.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCEFE9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.photo_library_outlined,
                                    color: Color(0xFF0F766E),
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Belum ada preview tersimpan',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Buat preview watermark untuk melihat hasilnya di sini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF64756F),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                          children: [
                            if (_selectedFile != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: AspectRatio(
                                  aspectRatio: 4 / 3,
                                  child: ColoredBox(
                                    color: const Color(0xFF122C2B),
                                    child: Image.file(
                                      _selectedFile!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _previewDisplayName(_selectedFile!),
                                      style: const TextStyle(
                                        color: Color(0xFF5E706A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    tooltip: 'Edit watermark',
                                    onPressed: () => widget.onEdit(_selectedFile!),
                                    icon: const Icon(Icons.edit_rounded),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton.filledTonal(
                                    tooltip: 'Hapus foto',
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text('Hapus foto?'),
                                          content: const Text('Foto watermark dan data sumbernya akan dihapus dari penyimpanan aplikasi.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(dialogContext, false),
                                              child: const Text('Batal'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
                                              onPressed: () => Navigator.pop(dialogContext, true),
                                              child: const Text('Hapus'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await widget.onDelete(_selectedFile!);
                                        if (context.mounted) Navigator.of(context).pop();
                                      }
                                    },
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
                                  const SizedBox(width: 4),
                                  FilledButton.icon(
                                    onPressed: () => widget.onDownload(_selectedFile),
                                    icon: const Icon(Icons.download_rounded),
                                    label: const Text('Download'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F766E),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                            ],
                            const Text(
                              'Preview Tersimpan',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF183B38),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...widget.files.map(_buildPreviewRow),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewRow(File file) {
    final isSelected = file.path == _selectedFile?.path;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? const Color(0xFFE2F0EB) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: () => setState(() => _selectedFile = file),
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFE1E8E4),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.file(
                    file,
                    width: 82,
                    height: 62,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _previewDisplayName(file),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isSelected
                            ? 'Sedang dilihat · ${_modifiedLabel(file)}'
                            : 'Tersimpan · ${_modifiedLabel(file)}',
                        style: const TextStyle(
                          color: Color(0xFF64756F),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF94A3A0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
