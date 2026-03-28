import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import '../models/remote_survey.dart';
import '../models/survey.dart';

class ApiSurveyProvider with ChangeNotifier {
  List<RemoteSurvey> _surveys = [];
  RemoteSurvey? _selected;
  bool _isSubmitting = false;

  List<RemoteSurvey> get surveys => List.unmodifiable(_surveys);
  RemoteSurvey? get selected => _selected;
  bool get isSubmitting => _isSubmitting;

  Future<bool> hasNetwork() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<SubmitSurveyResult> submitSurvey(Survey survey) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      final fields = survey.toApiPayload();
      final request = http.MultipartRequest(
        'POST',
        AppConfig.apiUri('/api/survei'),
      );
      request.fields.addAll(fields);
      request.headers.addAll(AppConfig.authHeaders());
      // Guard: photo must only be sent as multipart file, never as plain text.
      request.fields.remove('foto_lokasi_survei');
      request.fields.remove('foto');
      request.fields.remove('photo');

      final photoPath = survey.fotoLokasiSurvei;
      if (photoPath != null && photoPath.isNotEmpty) {
        final photoFile = File(photoPath);
        if (!photoFile.existsSync()) {
          throw Exception(
            'File foto tidak ditemukan untuk upload. Ambil ulang foto lalu coba kirim lagi.',
          );
        }

        final fileLength = await photoFile.length();
        if (fileLength <= 0) {
          throw Exception('File foto kosong dan tidak bisa diupload.');
        }

        final fileName = photoFile.uri.pathSegments.isNotEmpty
            ? photoFile.uri.pathSegments.last
            : 'foto_lokasi_survei.jpg';
        final contentType = _detectImageContentType(fileName);

        // Send a single photo file to avoid oversized multipart payloads.
        request.files.add(
          http.MultipartFile(
            'foto_lokasi_survei',
            http.ByteStream(photoFile.openRead()),
            fileLength,
            filename: fileName,
            contentType: contentType,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 413) {
          throw Exception(
            'Gagal upload foto: ukuran file terlalu besar (413). Coba ambil ulang foto dengan kualitas lebih rendah.',
          );
        }
        if (response.statusCode == 301 ||
            response.statusCode == 302 ||
            response.statusCode == 307 ||
            response.statusCode == 308) {
          throw Exception(
            'Gagal kirim survey: endpoint melakukan redirect (${response.statusCode}). Pastikan URL API mengarah langsung ke endpoint HTTPS API.',
          );
        }
        throw Exception(
          'Gagal simpan survey: ${response.statusCode} ${response.body}',
        );
      }

      final submitResult = _extractSubmitResult(response.body);
      final verifiedPath = await _resolveUploadedPhotoPathAfterSubmit(
        responseBody: response.body,
        initialPath: submitResult.uploadedPhotoPath,
      );
      final uploadedPath = verifiedPath?.trim() ?? '';
      if (_isTemporaryServerPath(uploadedPath)) {
        throw Exception(
          'Upload foto belum tersimpan permanen di server (masih /tmp). Perlu perbaikan endpoint Laravel saat menyimpan file.',
        );
      }

      return SubmitSurveyResult(
        message: submitResult.message,
        uploadedPhotoPath: verifiedPath,
        rawBody: submitResult.rawBody,
      );
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  MediaType _detectImageContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
  }

  bool _isTemporaryServerPath(String path) {
    if (path.isEmpty) {
      return false;
    }
    return path.startsWith('/tmp/') || path.startsWith('tmp/');
  }

  SubmitSurveyResult _extractSubmitResult(String body) {
    if (body.trim().isEmpty) {
      return const SubmitSurveyResult(
        message: 'Survey berhasil dikirim ke database',
      );
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = _extractSuccessMessage(body);
        final photoPath = _extractUploadedPhotoPath(decoded);
        return SubmitSurveyResult(
          message: message,
          uploadedPhotoPath: photoPath,
          rawBody: body,
        );
      }

      return SubmitSurveyResult(message: decoded.toString(), rawBody: body);
    } catch (_) {
      return SubmitSurveyResult(message: body, rawBody: body);
    }
  }

  Future<String?> _resolveUploadedPhotoPathAfterSubmit({
    required String responseBody,
    required String? initialPath,
  }) async {
    final initial = _normalizePathCandidate(initialPath);
    if (initial != null && !_isTemporaryServerPath(initial)) {
      return initial;
    }

    final id = _extractCreatedSurveyId(responseBody);
    if (id == null) {
      return initial;
    }

    try {
      final uri = AppConfig.apiUri('/api/survei/$id');
      final resp = await http.get(uri, headers: AppConfig.authHeaders());
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return initial;
      }

      final decoded = jsonDecode(resp.body);
      final detailMap = _extractMapPayload(decoded);
      final fromDetail = _extractUploadedPhotoPath(detailMap);
      return _normalizePathCandidate(fromDetail) ?? initial;
    } catch (_) {
      return initial;
    }
  }

  int? _extractCreatedSurveyId(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return null;
      }

      int? readInt(dynamic value) {
        if (value == null) {
          return null;
        }
        if (value is int) {
          return value;
        }
        return int.tryParse(value.toString());
      }

      final map = Map<String, dynamic>.from(decoded);
      final directId = readInt(map['id']);
      if (directId != null && directId > 0) {
        return directId;
      }

      final data = map['data'];
      if (data is Map) {
        final dataId = readInt(data['id']);
        if (dataId != null && dataId > 0) {
          return dataId;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String? _extractUploadedPhotoPath(Map<String, dynamic> decoded) {
    String? readPath(dynamic value) {
      if (value == null) {
        return null;
      }
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    final candidates = <String>[];

    void addCandidate(dynamic value) {
      final parsed = readPath(value);
      if (parsed != null) {
        candidates.add(parsed);
      }
    }

    addCandidate(decoded['foto_lokasi_survei']);
    addCandidate(decoded['foto']);
    addCandidate(decoded['photo']);
    addCandidate(decoded['url']);
    addCandidate(decoded['path']);
    addCandidate(decoded['file_path']);

    final data = decoded['data'];
    if (data is Map) {
      addCandidate(data['foto_lokasi_survei']);
      addCandidate(data['foto']);
      addCandidate(data['photo']);
      addCandidate(data['url']);
      addCandidate(data['path']);
      addCandidate(data['file_path']);
    }

    if (candidates.isEmpty) {
      return null;
    }

    String? bestNonTmp;
    String? firstTmp;
    for (final raw in candidates) {
      final normalized = _normalizePathCandidate(raw);
      if (normalized == null) {
        continue;
      }

      if (_isTemporaryServerPath(normalized)) {
        firstTmp ??= normalized;
      } else {
        bestNonTmp = normalized;
        break;
      }
    }

    return bestNonTmp ?? firstTmp;
  }

  String? _normalizePathCandidate(String? rawPath) {
    if (rawPath == null) {
      return null;
    }
    final path = rawPath.trim();
    if (path.isEmpty) {
      return null;
    }

    // Keep URL or storage-relative path, but reject obvious non-file placeholders.
    final lower = path.toLowerCase();
    if (lower == 'null' || lower == 'undefined' || lower == '-') {
      return null;
    }
    return path;
  }

  String _extractSuccessMessage(String body) {
    if (body.trim().isEmpty) {
      return 'Survey berhasil dikirim ke database';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['msg'] ?? decoded['status'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
        return decoded.toString();
      }
      return decoded.toString();
    } catch (_) {
      return body;
    }
  }

  Future<void> loadSurveys({int? tahun}) async {
    try {
      final uri = AppConfig.apiUri(
        '/api/survei',
        queryParameters: tahun != null ? {'tahun': tahun.toString()} : null,
      );
      final resp = await http.get(uri, headers: AppConfig.authHeaders());
      if (resp.statusCode == 200) {
        final dynamic decoded = jsonDecode(resp.body);
        final List<dynamic> list = _extractListPayload(decoded);
        _surveys = list
            .map((e) => RemoteSurvey.fromJson(_asStringDynamicMap(e)))
            .toList();
        notifyListeners();
      } else {
        throw Exception('Failed to load surveys: ${resp.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<RemoteSurvey>> fetchSurveysByYear({int? year}) async {
    final selectedYear = year ?? DateTime.now().year;
    await loadSurveys(tahun: selectedYear);
    return List<RemoteSurvey>.from(_surveys);
  }

  Future<List<int>> fetchAvailableSurveyYears() async {
    try {
      final uri = AppConfig.apiUri('/api/survei/tahun');
      final resp = await http.get(uri, headers: AppConfig.authHeaders());
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final dynamic decoded = jsonDecode(resp.body);
        final years = _extractYearListPayload(decoded);
        if (years.isNotEmpty) {
          return years;
        }
      }
    } catch (_) {
      // Fallback handled below.
    }

    // Fallback: derive from loaded surveys + current year.
    final years = <int>{DateTime.now().year};
    for (final s in _surveys) {
      final y = int.tryParse(s.tahunSurvei);
      if (y != null) {
        years.add(y);
      }
    }
    final result = years.toList()..sort((a, b) => b.compareTo(a));
    return result;
  }

  Future<void> loadDetail(int id) async {
    try {
      final uri = AppConfig.apiUri('/api/survei/$id');
      final resp = await http.get(uri, headers: AppConfig.authHeaders());
      if (resp.statusCode == 200) {
        final dynamic decoded = jsonDecode(resp.body);
        final Map<String, dynamic> json = _extractMapPayload(decoded);
        _selected = RemoteSurvey.fromJson(json);
        notifyListeners();
      } else {
        throw Exception('Failed to load detail: ${resp.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException('Invalid survey item format');
  }

  List<dynamic> _extractListPayload(dynamic decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      const keys = ['data', 'results', 'items', 'survei', 'surveys'];
      for (final key in keys) {
        final value = map[key];
        if (value is List) {
          return value;
        }
      }

      if (map['id'] != null) {
        return [map];
      }
    }

    throw const FormatException('Unexpected list response format');
  }

  List<int> _extractYearListPayload(dynamic decoded) {
    final years = <int>{};

    void collectFromList(List<dynamic> list) {
      for (final item in list) {
        if (item is int) {
          years.add(item);
          continue;
        }
        final parsedDirect = int.tryParse(item.toString());
        if (parsedDirect != null) {
          years.add(parsedDirect);
          continue;
        }
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final candidates = [
            map['tahun'],
            map['year'],
            map['tahun_survei'],
          ];
          for (final c in candidates) {
            final parsed = int.tryParse(c?.toString() ?? '');
            if (parsed != null) {
              years.add(parsed);
              break;
            }
          }
        }
      }
    }

    if (decoded is List) {
      collectFromList(decoded);
    } else if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      const keys = ['data', 'results', 'items', 'years', 'tahun'];
      for (final key in keys) {
        final value = map[key];
        if (value is List) {
          collectFromList(value);
        }
      }
    }

    final result = years.toList()..sort((a, b) => b.compareTo(a));
    return result;
  }

  Map<String, dynamic> _extractMapPayload(dynamic decoded) {
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final data = map['data'];
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      if (map['id'] != null) {
        return map;
      }
    }

    if (decoded is List && decoded.isNotEmpty) {
      return _asStringDynamicMap(decoded.first);
    }

    throw const FormatException('Unexpected detail response format');
  }
}

class SubmitSurveyResult {
  final String message;
  final String? uploadedPhotoPath;
  final String? rawBody;

  const SubmitSurveyResult({
    required this.message,
    this.uploadedPhotoPath,
    this.rawBody,
  });
}