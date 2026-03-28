import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignalMetrics {
  final int? rsrp;
  final int? rsrq;
  final int? sinr;
  final int? rssi;
  final String? providerName;
  final String? networkType;
  final bool inService;
  final bool dataConnected;
  final bool validatedCellularInternet;

  const SignalMetrics({
    this.rsrp,
    this.rsrq,
    this.sinr,
    this.rssi,
    this.providerName,
    this.networkType,
    this.inService = false,
    this.dataConnected = false,
    this.validatedCellularInternet = false,
  });

  bool get hasAnyValue =>
      rsrp != null || rsrq != null || sinr != null || rssi != null;
}

class SpeedMetrics {
  final double? downloadMbps;
  final double? uploadMbps;
  final int? pingMs;

  const SpeedMetrics({
    this.downloadMbps,
    this.uploadMbps,
    this.pingMs,
  });
}

enum SpeedTestStage {
  download,
  upload,
  ping,
}

typedef SpeedTestProgressCallback = void Function(
  SpeedTestStage stage,
  double progressPercent,
);

enum SpeedTestMode {
  cepat,
  standar,
  akurat,
}

extension SpeedTestModeX on SpeedTestMode {
  String get storageValue {
    return switch (this) {
      SpeedTestMode.cepat => 'cepat',
      SpeedTestMode.standar => 'standar',
      SpeedTestMode.akurat => 'akurat',
    };
  }

  String get label {
    return switch (this) {
      SpeedTestMode.cepat => 'Cepat (1 run)',
      SpeedTestMode.standar => 'Standar (2 run)',
      SpeedTestMode.akurat => 'Akurat (3 run)',
    };
  }

  static SpeedTestMode fromStorage(String? raw) {
    switch ((raw ?? '').toLowerCase().trim()) {
      case 'cepat':
        return SpeedTestMode.cepat;
      case 'akurat':
        return SpeedTestMode.akurat;
      default:
        return SpeedTestMode.standar;
    }
  }
}

class SpeedTestSettings {
  static const String _downloadUrlKey = 'speedtest_download_url';
  static const String _uploadUrlKey = 'speedtest_upload_url';
  static const String _pingUrlKey = 'speedtest_ping_url';
  static const String _downloadBytesKey = 'speedtest_download_bytes';
  static const String _uploadBytesKey = 'speedtest_upload_bytes';
  static const String _modeKey = 'speedtest_mode';

  static const String defaultDownloadUrl =
      'https://speed.cloudflare.com/__down?bytes=5000000';
  static const String defaultUploadUrl = 'https://httpbin.org/post';
  static const String defaultPingUrl = 'https://www.google.com/generate_204';
  static const int defaultDownloadBytes = 5000000;
  static const int defaultUploadBytes = 1000000;

  final String downloadUrl;
  final String uploadUrl;
  final String pingUrl;
  final int downloadBytes;
  final int uploadBytes;
  final SpeedTestMode mode;

  const SpeedTestSettings({
    required this.downloadUrl,
    required this.uploadUrl,
    required this.pingUrl,
    required this.downloadBytes,
    required this.uploadBytes,
    required this.mode,
  });

  factory SpeedTestSettings.defaults() {
    return const SpeedTestSettings(
      downloadUrl: defaultDownloadUrl,
      uploadUrl: defaultUploadUrl,
      pingUrl: defaultPingUrl,
      downloadBytes: defaultDownloadBytes,
      uploadBytes: defaultUploadBytes,
      mode: SpeedTestMode.standar,
    );
  }

  static Future<SpeedTestSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final downloadUrl = prefs.getString(_downloadUrlKey) ?? defaultDownloadUrl;
    final uploadUrl = prefs.getString(_uploadUrlKey) ?? defaultUploadUrl;
    final pingUrl = prefs.getString(_pingUrlKey) ?? defaultPingUrl;
    final downloadBytes = prefs.getInt(_downloadBytesKey) ?? defaultDownloadBytes;
    final uploadBytes = prefs.getInt(_uploadBytesKey) ?? defaultUploadBytes;
    final mode = SpeedTestModeX.fromStorage(prefs.getString(_modeKey));

    return SpeedTestSettings(
      downloadUrl: downloadUrl,
      uploadUrl: uploadUrl,
      pingUrl: pingUrl,
      downloadBytes: downloadBytes <= 0 ? defaultDownloadBytes : downloadBytes,
      uploadBytes: uploadBytes <= 0 ? defaultUploadBytes : uploadBytes,
      mode: mode,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadUrlKey, downloadUrl);
    await prefs.setString(_uploadUrlKey, uploadUrl);
    await prefs.setString(_pingUrlKey, pingUrl);
    await prefs.setInt(_downloadBytesKey, downloadBytes);
    await prefs.setInt(_uploadBytesKey, uploadBytes);
    await prefs.setString(_modeKey, mode.storageValue);
  }
}

class NetworkMetricsService {
  static const MethodChannel _channel =
      MethodChannel('com.sigaptel/network_metrics');

  Future<SignalMetrics> readSignalMetrics() async {
    if (!Platform.isAndroid) {
      return const SignalMetrics();
    }

    final allowed = await _ensureSignalPermissions();
    if (!allowed) {
      return const SignalMetrics();
    }

    try {
      final dynamic result = await _channel.invokeMethod('getSignalMetrics');
      if (result is! Map) {
        return const SignalMetrics();
      }

      int? toNullableInt(dynamic value) {
        if (value == null) {
          return null;
        }
        if (value is int) {
          return value;
        }
        return int.tryParse(value.toString());
      }

      bool toBool(dynamic value) {
        if (value is bool) {
          return value;
        }
        if (value is num) {
          return value != 0;
        }
        final text = value?.toString().toLowerCase();
        return text == 'true' || text == '1';
      }

      return SignalMetrics(
        rsrp: toNullableInt(result['rsrp']),
        rsrq: toNullableInt(result['rsrq']),
        sinr: toNullableInt(result['sinr']),
        rssi: toNullableInt(result['rssi']),
        providerName: result['providerName']?.toString(),
        networkType: result['networkType']?.toString(),
        inService: toBool(result['inService']),
        dataConnected: toBool(result['dataConnected']),
        validatedCellularInternet: toBool(result['validatedCellularInternet']),
      );
    } catch (_) {
      return const SignalMetrics();
    }
  }

  Future<bool> _ensureSignalPermissions() async {
    final locationStatus = await Permission.locationWhenInUse.request();
    final phoneStatus = await Permission.phone.request();

    final locationGranted =
        locationStatus.isGranted || locationStatus.isLimited;
    final phoneGranted = phoneStatus.isGranted;

    return locationGranted && phoneGranted;
  }

  Future<SpeedMetrics> runSpeedTest({
    Duration timeout = const Duration(seconds: 60),
    SpeedTestProgressCallback? onProgress,
  }) async {
    final settings = await SpeedTestSettings.load();

    final config = switch (settings.mode) {
      SpeedTestMode.cepat => (
          runs: 1,
          streams: 3,
          pingSamples: 3,
          warmUp: false,
        ),
      SpeedTestMode.standar => (
          runs: 2,
          streams: 4,
          pingSamples: 5,
          warmUp: true,
        ),
      SpeedTestMode.akurat => (
          runs: 3,
          streams: 4,
          pingSamples: 9,
          warmUp: true,
        ),
    };

    return runSpeedTestAccurate(
      timeout: timeout,
      onProgress: onProgress,
      runs: config.runs,
      parallelStreams: config.streams,
      pingSamples: config.pingSamples,
      enableWarmUp: config.warmUp,
    );
  }

  Future<SpeedMetrics> runSpeedTestAccurate({
    Duration timeout = const Duration(seconds: 90),
    SpeedTestProgressCallback? onProgress,
    int runs = 3,
    int parallelStreams = 4,
    int pingSamples = 9,
    bool enableWarmUp = true,
  }) async {
    final settings = await SpeedTestSettings.load();
    final safeRuns = runs < 1 ? 1 : runs;
    final safeStreams = parallelStreams < 1 ? 1 : parallelStreams;
    final safePingSamples = pingSamples < 3 ? 3 : pingSamples;

    if (enableWarmUp) {
      await _warmUpSpeedTest(settings: settings, timeout: timeout);
    }

    final downloadResults = <double>[];
    final uploadResults = <double>[];
    final pingResults = <int>[];

    for (var runIndex = 0; runIndex < safeRuns; runIndex++) {
      final download = await _measureParallelDownloadMbps(
        settings: settings,
        timeout: timeout,
        streams: safeStreams,
        onRunProgress: (runPercent) {
          _emitProgress(
            onProgress,
            SpeedTestStage.download,
            _mapRunProgressToStage(runIndex, safeRuns, runPercent),
          );
        },
      );
      if (download != null) {
        downloadResults.add(download);
      }

      final upload = await _measureParallelUploadMbps(
        settings: settings,
        timeout: timeout,
        streams: safeStreams,
        onRunProgress: (runPercent) {
          _emitProgress(
            onProgress,
            SpeedTestStage.upload,
            _mapRunProgressToStage(runIndex, safeRuns, runPercent),
          );
        },
      );
      if (upload != null) {
        uploadResults.add(upload);
      }

      final ping = await _measurePingMedianMs(
        pingUrl: settings.pingUrl,
        samples: safePingSamples,
        onRunProgress: (runPercent) {
          _emitProgress(
            onProgress,
            SpeedTestStage.ping,
            _mapRunProgressToStage(runIndex, safeRuns, runPercent),
          );
        },
      );
      if (ping != null) {
        pingResults.add(ping);
      }
    }

    _emitProgress(onProgress, SpeedTestStage.download, 100);
    _emitProgress(onProgress, SpeedTestStage.upload, 100);
    _emitProgress(onProgress, SpeedTestStage.ping, 100);

    return SpeedMetrics(
      downloadMbps: _medianDouble(downloadResults),
      uploadMbps: _medianDouble(uploadResults),
      pingMs: _medianInt(pingResults),
    );
  }

  void _emitProgress(
    SpeedTestProgressCallback? callback,
    SpeedTestStage stage,
    double value,
  ) {
    if (callback == null) {
      return;
    }
    callback(stage, value.clamp(0, 100).toDouble());
  }

  double _mapRunProgressToStage(int runIndex, int totalRuns, double runPercent) {
    if (totalRuns <= 0) {
      return runPercent.clamp(0, 100).toDouble();
    }
    final clampedRun = runPercent.clamp(0, 100).toDouble();
    return ((runIndex + (clampedRun / 100.0)) / totalRuns) * 100.0;
  }

  Future<void> _warmUpSpeedTest({
    required SpeedTestSettings settings,
    required Duration timeout,
  }) async {
    final warmupTimeout = timeout > const Duration(seconds: 12)
        ? const Duration(seconds: 12)
        : timeout;
    final downloadBytes = max(300000, settings.downloadBytes ~/ 10);
    final uploadBytes = max(120000, settings.uploadBytes ~/ 10);

    try {
      final warmupUri = _buildDownloadUri(settings.downloadUrl, downloadBytes);
      await _measureSingleDownloadBytes(url: warmupUri, timeout: warmupTimeout);
    } catch (_) {
      // Best effort warm-up.
    }

    try {
      await _measureSingleUploadBytes(
        url: settings.uploadUrl,
        payloadSize: uploadBytes,
        timeout: warmupTimeout,
      );
    } catch (_) {
      // Best effort warm-up.
    }

    try {
      await _measurePingMs(settings.pingUrl);
    } catch (_) {
      // Best effort warm-up.
    }
  }

  Future<double?> _measureParallelDownloadMbps({
    required SpeedTestSettings settings,
    required Duration timeout,
    required int streams,
    required void Function(double runPercent) onRunProgress,
  }) async {
    final safeStreams = streams < 1 ? 1 : streams;
    final perStreamBytes = max(1000000, settings.downloadBytes ~/ safeStreams);
    var finished = 0;

    onRunProgress(0);
    final stopwatch = Stopwatch()..start();

    final futures = List.generate(safeStreams, (index) async {
      final uri = _buildDownloadUri(settings.downloadUrl, perStreamBytes);
      final bytes = await _measureSingleDownloadBytes(url: uri, timeout: timeout);
      finished += 1;
      onRunProgress((finished / safeStreams) * 100.0);
      return bytes;
    });

    final bytesList = await Future.wait(futures);
    stopwatch.stop();

    final totalBytes = bytesList.fold<int>(0, (sum, value) => sum + value);
    if (totalBytes <= 0 || stopwatch.elapsedMilliseconds <= 0) {
      return null;
    }

    final bitsPerSecond = (totalBytes * 8) / (stopwatch.elapsedMilliseconds / 1000.0);
    return bitsPerSecond / 1000000.0;
  }

  Uri _buildDownloadUri(String rawUrl, int targetBytes) {
    final uri = Uri.parse(rawUrl);
    final hasBytesParam = uri.queryParameters.containsKey('bytes');
    final looksLikeCloudflareDown = uri.path.contains('__down');
    if (!hasBytesParam && !looksLikeCloudflareDown) {
      return uri;
    }

    final updatedQuery = Map<String, String>.from(uri.queryParameters)
      ..['bytes'] = targetBytes.toString();
    return uri.replace(queryParameters: updatedQuery);
  }

  Future<int> _measureSingleDownloadBytes({
    required Uri url,
    required Duration timeout,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(url).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        return 0;
      }

      var totalBytes = 0;
      await for (final chunk in response) {
        totalBytes += chunk.length;
      }
      return totalBytes;
    } catch (_) {
      return 0;
    } finally {
      client?.close(force: true);
    }
  }

  Future<double?> _measureParallelUploadMbps({
    required SpeedTestSettings settings,
    required Duration timeout,
    required int streams,
    required void Function(double runPercent) onRunProgress,
  }) async {
    final safeStreams = streams < 1 ? 1 : streams;
    final perStreamBytes = max(250000, settings.uploadBytes ~/ safeStreams);
    var finished = 0;

    onRunProgress(0);
    final stopwatch = Stopwatch()..start();

    final futures = List.generate(safeStreams, (index) async {
      final sentBytes = await _measureSingleUploadBytes(
        url: settings.uploadUrl,
        payloadSize: perStreamBytes,
        timeout: timeout,
      );
      finished += 1;
      onRunProgress((finished / safeStreams) * 100.0);
      return sentBytes;
    });

    final sentList = await Future.wait(futures);
    stopwatch.stop();

    final totalBytes = sentList.fold<int>(0, (sum, value) => sum + value);
    if (totalBytes <= 0 || stopwatch.elapsedMilliseconds <= 0) {
      return null;
    }

    final bitsPerSecond = (totalBytes * 8) / (stopwatch.elapsedMilliseconds / 1000.0);
    return bitsPerSecond / 1000000.0;
  }

  Future<int> _measureSingleUploadBytes({
    required String url,
    required int payloadSize,
    required Duration timeout,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(Uri.parse(url)).timeout(timeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/octet-stream');

      final random = Random();
      final payload = List<int>.generate(payloadSize, (_) => random.nextInt(256));
      request.add(payload);

      final response = await request.close().timeout(timeout);
      await response.drain();
      if (response.statusCode < 200 || response.statusCode >= 400) {
        return 0;
      }
      return payload.length;
    } catch (_) {
      return 0;
    } finally {
      client?.close(force: true);
    }
  }

  Future<int?> _measurePingMedianMs({
    required String pingUrl,
    required int samples,
    required void Function(double runPercent) onRunProgress,
  }) async {
    final safeSamples = samples < 1 ? 1 : samples;
    final values = <int>[];

    onRunProgress(0);
    for (var i = 0; i < safeSamples; i++) {
      final ping = await _measurePingMs(pingUrl);
      if (ping != null) {
        values.add(ping);
      }
      onRunProgress(((i + 1) / safeSamples) * 100.0);
    }

    return _medianInt(values);
  }

  double? _medianDouble(List<double> values) {
    if (values.isEmpty) {
      return null;
    }
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2.0;
  }

  int? _medianInt(List<int> values) {
    if (values.isEmpty) {
      return null;
    }
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return ((sorted[middle - 1] + sorted[middle]) / 2.0).round();
  }

  Future<int?> _measurePingMs(String pingUrl) async {
    final stopwatch = Stopwatch()..start();
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(pingUrl));
      final response = await request.close();
      await response.drain();
      stopwatch.stop();
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return stopwatch.elapsedMilliseconds;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      stopwatch.stop();
      client?.close(force: true);
    }
  }
}
