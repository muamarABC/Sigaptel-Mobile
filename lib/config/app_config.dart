import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _apiBaseUrl = String.fromEnvironment(
    'SIGAPTEL_API_BASE_URL',
  );
  static const String _appAccessCode = String.fromEnvironment(
    'SIGAPTEL_APP_ACCESS_CODE',
  );

  static const String _debugFallbackApiBaseUrl = 'http://10.0.2.2:8000';
  static const String _debugFallbackAppAccessCode = 'DEV-LOCAL';

  static bool get _canUseDebugFallback => kDebugMode;

  static String get apiBaseUrl {
    if (_apiBaseUrl.trim().isNotEmpty) {
      return _apiBaseUrl;
    }
    if (_canUseDebugFallback) {
      return _debugFallbackApiBaseUrl;
    }
    return '';
  }

  static String get appAccessCode {
    if (_appAccessCode.trim().isNotEmpty) {
      return _appAccessCode;
    }
    if (_canUseDebugFallback) {
      return _debugFallbackAppAccessCode;
    }
    return '';
  }

  static String? get validationError {
    if (_apiBaseUrl.trim().isEmpty && !_canUseDebugFallback) {
      return 'Parameter SIGAPTEL_API_BASE_URL belum diisi.';
    }
    if (_appAccessCode.trim().isEmpty && !_canUseDebugFallback) {
      return 'Parameter SIGAPTEL_APP_ACCESS_CODE belum diisi.';
    }
    return null;
  }

  static Uri apiUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$apiBaseUrl$normalizedPath').replace(
      queryParameters: queryParameters,
    );
  }

  static Map<String, String> authHeaders({
    Map<String, String>? extra,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-App-Code': appAccessCode,
    };
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  static String storageUrl(String relativePath) {
    final cleaned = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    return '$apiBaseUrl/storage/$cleaned';
  }
}
