import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/bantuan_starlink.dart';

class ApiStarlinkProvider with ChangeNotifier {
  static const String _baseUrl =
      'https://tower.baritotimurkab.go.id/api/bantuan-starlink';

  List<BantuanStarlink> _items = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  List<BantuanStarlink> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  /// Fetch all starlink data, optionally filtered by [search], [status],
  /// [kecamatan], [kategori], or [tahun].
  Future<void> fetchAll({
    String? search,
    String? status,
    String? kecamatan,
    String? kategori,
    int? tahun,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, String>{};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (status != null && status.isNotEmpty) params['status'] = status;
      if (kecamatan != null && kecamatan.isNotEmpty) {
        params['kecamatan'] = kecamatan;
      }
      if (kategori != null && kategori.isNotEmpty) {
        params['kategori_program'] = kategori;
      }
      if (tahun != null) params['tahun_bantuan'] = tahun.toString();

      final uri =
          Uri.parse(_baseUrl).replace(queryParameters: params.isNotEmpty ? params : null);

      final resp = await http.get(uri, headers: {'Accept': 'application/json'});

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final dynamic decoded = jsonDecode(resp.body);
        final List<dynamic> list = _extractList(decoded);
        _items = list
            .map((e) => BantuanStarlink.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _error = 'Gagal memuat data (${resp.statusCode})';
      }
    } catch (e) {
      _error = 'Terjadi kesalahan: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch a single record by [id].
  Future<BantuanStarlink?> fetchDetail(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl/$id');
      final resp = await http.get(uri, headers: {'Accept': 'application/json'});
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final dynamic decoded = jsonDecode(resp.body);
        final map = _extractMap(decoded);
        if (map != null) return BantuanStarlink.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  /// Fetch unique kecamatan options for filter dropdowns.
  Future<List<String>> fetchKecamatanOptions() async {
    try {
      final uri = Uri.parse('$_baseUrl/options/kecamatan');
      final resp = await http.get(uri, headers: {'Accept': 'application/json'});
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final dynamic decoded = jsonDecode(resp.body);
        final list = _extractList(decoded);
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    // Fallback: derive from loaded items
    final seen = <String>{};
    return _items.map((e) => e.kecamatan).where(seen.add).toList()..sort();
  }

  /// Store a new record. Returns null on success, error message on failure.
  Future<String?> store(Map<String, String> fields, File photo) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath(
        'foto_starlink',
        photo.path,
        contentType: _mediaType(photo.path),
      ));
      final resp = await http.Response.fromStream(await request.send());
      if (resp.statusCode >= 200 && resp.statusCode < 300) return null;
      return _errorFromResp(resp);
    } catch (e) {
      return 'Kesalahan jaringan: $e';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Update an existing record. [photo] is optional for update.
  /// Returns null on success, error message on failure.
  Future<String?> update(int id, Map<String, String> fields, File? photo) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$_baseUrl/$id'));
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);
      if (photo != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'foto_starlink',
          photo.path,
          contentType: _mediaType(photo.path),
        ));
      }
      final resp = await http.Response.fromStream(await request.send());
      if (resp.statusCode >= 200 && resp.statusCode < 300) return null;
      return _errorFromResp(resp);
    } catch (e) {
      return 'Kesalahan jaringan: $e';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  MediaType _mediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  String _errorFromResp(http.Response resp) {
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        final msg = decoded['message'] ?? decoded['error'];
        if (msg != null) return msg.toString();
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
      }
    } catch (_) {}
    return 'Gagal menyimpan data (${resp.statusCode})';
  }

  static List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      for (final key in ['data', 'items', 'result', 'results']) {
        if (decoded[key] is List) return decoded[key] as List;
      }
    }
    return [];
  }

  static Map<String, dynamic>? _extractMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      for (final key in ['data', 'item', 'result']) {
        if (decoded[key] is Map<String, dynamic>) {
          return decoded[key] as Map<String, dynamic>;
        }
      }
      return decoded;
    }
    return null;
  }
}
