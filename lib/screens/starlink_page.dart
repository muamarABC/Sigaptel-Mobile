import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/bantuan_starlink.dart';
import '../providers/auth_provider.dart';
import '../providers/api_starlink_provider.dart';
import 'starlink_form_page.dart';

class StarlinkPage extends StatefulWidget {
  static const routeName = '/starlink';

  const StarlinkPage({super.key});

  @override
  State<StarlinkPage> createState() => _StarlinkPageState();
}

class _StarlinkPageState extends State<StarlinkPage> {
  static const List<Color> _grad = [Color(0xFF2563EB), Color(0xFF1D4ED8)];

  final TextEditingController _searchCtrl = TextEditingController();
  String _filterStatus = '';
  String _filterKecamatan = '';
  int? _filterTahun;
  int _page = 1;
  static const int _rowsPerPage = 10;

  static List<int> get _tahunOptions {
    final now = DateTime.now().year;
    return List<int>.generate(now - 2023, (i) => now - i);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() => context.read<ApiStarlinkProvider>().fetchAll(
    search: _searchCtrl.text.trim(),
    status: _filterStatus,
    kecamatan: _filterKecamatan,
    tahun: _filterTahun,
  );

  Future<void> _openForm(BuildContext ctx, {BantuanStarlink? item}) async {
    final result = await Navigator.of(ctx).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => StarlinkFormPage(item: item)),
    );
    if (result == true && mounted) _load();
  }

  void _applyFilter() {
    setState(() => _page = 1);
    _load();
  }

  // ─── helpers ─────────────────────────────────────────────────────────────

  Color _statusColor(String status) =>
      status == 'Online' ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

  IconData _statusIcon(String status) =>
      status == 'Online' ? Icons.wifi_rounded : Icons.wifi_off_rounded;

  String _photoUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return 'https://tower.baritotimurkab.go.id/storage/$path';
  }

  String _fmtDateTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw.trim().isEmpty ? '-' : raw;
    }
    final local = parsed.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d-$m-$y $hh:$mm';
  }

  String _resolvePetugasName(
    BuildContext context,
    String namaPetugas,
    int? userId,
  ) {
    final directName = namaPetugas.trim();
    if (directName.isNotEmpty) {
      return directName;
    }

    final authUser = context.read<AuthProvider>().user;
    final authName = authUser?.name.trim() ?? '';
    if (userId != null && authUser?.id == userId && authName.isNotEmpty) {
      return authName;
    }

    return userId != null ? 'User ID $userId' : '-';
  }

  String _buildDownloadFileName(BantuanStarlink item, String url) {
    final lokasi = item.namaLokasi.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    final cleanLokasi = lokasi
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
    final prefix = cleanLokasi.isEmpty ? 'foto-starlink' : cleanLokasi;
    return '${prefix}_$ts.$extension';
  }

  Future<bool> _requestGalleryPermission() async {
    if (Platform.isAndroid) {
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
      if (successRaw is bool) return successRaw;
      if (successRaw is num) return successRaw != 0;
      if (successRaw != null) {
        final text = successRaw.toString().toLowerCase();
        if (text == 'true' || text == '1') return true;
      }
      final dynamic filePath = result['filePath'];
      if (filePath != null && filePath.toString().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> _showDownloadSuccessDialog(
    BuildContext context,
    String locationName,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _grad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Download Berhasil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Foto untuk $locationName sudah tersimpan ke galeri perangkat.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Mantap'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPhoto(
    BuildContext context,
    BantuanStarlink item,
  ) async {
    final url = _photoUrl(item.fotoStarlink);
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto tidak tersedia untuk diunduh.')),
      );
      return;
    }

    try {
      final granted = await _requestGalleryPermission();
      if (!granted) {
        if (!context.mounted) return;
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
        return;
      }

      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final fileName = _buildDownloadFileName(item, url);
      final Uint8List bytes = resp.bodyBytes;
      final baseName = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      final result = await ImageGallerySaver.saveImage(
        bytes,
        name: baseName,
        quality: 100,
      );

      if (!_isGallerySaveSuccess(result)) {
        throw Exception('Plugin galeri gagal menyimpan gambar');
      }

      if (!context.mounted) return;
      await _showDownloadSuccessDialog(context, item.namaLokasi);
    } on MissingPluginException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fitur simpan galeri belum aktif. Tutup aplikasi lalu jalankan ulang (full restart).',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengunduh foto: $e')));
    }
  }

  // ─── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      appBar: AppBar(
        title: const Text(
          'Bantuan Starlink',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterCard(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ─── filter card ─────────────────────────────────────────────────────────

  Widget _buildFilterCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // search row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cari nama lokasi / desa / kecamatan…',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchCtrl,
                        builder: (_, v, _) => v.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _applyFilter();
                                },
                              )
                            : const SizedBox.shrink(),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.4,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _applyFilter(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _gradBtn(
                label: 'Cari',
                icon: Icons.search_rounded,
                onTap: _applyFilter,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // dropdown row
          Row(
            children: [
              // Status
              Expanded(
                child: _dropDown<String>(
                  hint: 'Status',
                  value: _filterStatus.isEmpty ? null : _filterStatus,
                  items: const ['Online', 'Offline'],
                  label: (v) => v,
                  onChanged: (v) {
                    setState(() {
                      _filterStatus = v ?? '';
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Tahun
              SizedBox(
                width: 100,
                child: _dropDown<int>(
                  hint: 'Tahun',
                  value: _filterTahun,
                  items: _tahunOptions,
                  label: (v) => v.toString(),
                  onChanged: (v) {
                    setState(() {
                      _filterTahun = v;
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Reset
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searchCtrl.clear();
                    _filterStatus = '';
                    _filterKecamatan = '';
                    _filterTahun = null;
                    _page = 1;
                  });
                  _load();
                },
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropDown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      height: 40,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12.5),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        items: [
          DropdownMenuItem<T>(value: null, child: Text(hint)),
          ...items.map(
            (e) => DropdownMenuItem<T>(value: e, child: Text(label(e))),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _gradBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: _grad),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return Consumer<ApiStarlinkProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB)),
          );
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(height: 12),
                Text(
                  provider.error!,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                _gradBtn(
                  label: 'Coba Lagi',
                  icon: Icons.refresh_rounded,
                  onTap: _load,
                ),
              ],
            ),
          );
        }

        final all = provider.items;
        if (all.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.satellite_alt_rounded,
                  size: 52,
                  color: Color(0xFFCBD5E1),
                ),
                SizedBox(height: 12),
                Text(
                  'Tidak ada data ditemukan',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
              ],
            ),
          );
        }

        // Pagination
        final total = all.length;
        final totalPages = (total / _rowsPerPage).ceil();
        final start = (_page - 1) * _rowsPerPage;
        final end = (start + _rowsPerPage).clamp(0, total);
        final pageItems = all.sublist(start, end);

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                itemCount: pageItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _buildCard(ctx, pageItems[i]),
              ),
            ),
            _buildBottomBar(total, totalPages),
          ],
        );
      },
    );
  }

  // ─── item card ────────────────────────────────────────────────────────────

  Widget _buildCard(BuildContext context, BantuanStarlink item) {
    final statusColor = _statusColor(item.status);
    final photoUrl = _photoUrl(item.fotoStarlink);

    return GestureDetector(
      onTap: () => _showDetail(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9EDF4)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left color strip
            Container(
              width: 5,
              height: 96,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Thumbnail (or icon)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      width: 62,
                      height: 62,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _photoPlaceholder(),
                    )
                  : _photoPlaceholder(),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.namaLokasi,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _statusBadge(item.status, statusColor),
                        const SizedBox(width: 12),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _infoRow(
                      Icons.location_on_rounded,
                      '${item.desa}, ${item.kecamatan}',
                      const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _chip(item.kategoriProgram, const Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        _chip(
                          item.tahunBantuan.toString(),
                          const Color(0xFF1D4ED8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
    width: 62,
    height: 62,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(
      Icons.satellite_alt_rounded,
      color: Colors.white,
      size: 30,
    ),
  );

  Widget _statusBadge(String status, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withAlpha(80)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_statusIcon(status), size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          status,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );

  Widget _infoRow(IconData icon, String text, Color color) => Row(
    children: [
      Icon(icon, size: 12, color: color.withAlpha(180)),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  // ─── bottom bar (tambah + pagination) ─────────────────────────────────────

  Widget _buildBottomBar(int total, int totalPages) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9EDF4))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Tambah Data button ──
          SizedBox(
            width: double.infinity,
            height: 44,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _openForm(context),
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: _grad,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x402563EB),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tambah Data',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ── Pagination row ──
          Row(
            children: [
              Text(
                'Total $total data',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const Spacer(),
              _pageBtn(
                icon: Icons.chevron_left_rounded,
                enabled: _page > 1,
                onTap: () => setState(() => _page--),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: _grad),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332563EB),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$_page / $totalPages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _pageBtn(
                icon: Icons.chevron_right_rounded,
                enabled: _page < totalPages,
                onTap: () => setState(() => _page++),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFEDE9FE) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? const Color(0xFF2563EB).withAlpha(80)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }

  // ─── detail bottom sheet ──────────────────────────────────────────────────

  void _showDetail(BuildContext context, BantuanStarlink item) {
    final statusColor = _statusColor(item.status);
    final photoUrl = _photoUrl(item.fotoStarlink);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Photo
              if (photoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    photoUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(height: 180, color: const Color(0xFFF1F5F9)),
                  ),
                )
              else
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: _grad),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.satellite_alt_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: photoUrl.isNotEmpty
                      ? () => _downloadPhoto(context, item)
                      : null,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download Foto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Title + status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.namaLokasi,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  _statusBadge(item.status, statusColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${item.desa}, Kec. ${item.kecamatan}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const Divider(height: 24),
              // Details
              _detailRow(
                'ID Starlink',
                item.idStarlink,
                Icons.tag_rounded,
                const Color(0xFF2563EB),
              ),
              _detailRow(
                'Kategori Program',
                item.kategoriProgram,
                Icons.category_rounded,
                const Color(0xFF2563EB),
              ),
              _detailRow(
                'Tahun Bantuan',
                item.tahunBantuan.toString(),
                Icons.calendar_today_rounded,
                const Color(0xFF1D4ED8),
              ),
              _detailRow(
                'Alamat',
                item.alamat,
                Icons.home_rounded,
                const Color(0xFF059669),
              ),
              _detailRow(
                'Koordinat',
                '${item.latitude}, ${item.longitude}',
                Icons.my_location_rounded,
                const Color(0xFFD97706),
              ),
              _detailRow(
                'Nama Kontak',
                item.namaKontak,
                Icons.person_rounded,
                const Color(0xFF2563EB),
              ),
              _detailRow(
                'Telp Kontak',
                item.telpKontak,
                Icons.phone_rounded,
                const Color(0xFF16A34A),
              ),
              _detailRow(
                'Nama Petugas',
                _resolvePetugasName(context, item.namaPetugas, item.userId),
                Icons.badge_rounded,
                const Color(0xFF2563EB),
              ),
              _detailRow(
                'Tanggal Upload',
                _fmtDateTime(item.createdAt),
                Icons.upload_rounded,
                const Color(0xFF1D4ED8),
              ),
              _detailRow(
                'Tanggal Update',
                _fmtDateTime(item.updatedAt),
                Icons.update_rounded,
                const Color(0xFF0EA5E9),
              ),
              if (item.keterangan.isNotEmpty)
                _detailRow(
                  'Keterangan',
                  item.keterangan,
                  Icons.notes_rounded,
                  const Color(0xFF64748B),
                ),
              const SizedBox(height: 16),
              // Edit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Material(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      _openForm(context, item: item);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Edit Data',
                              style: TextStyle(
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
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
