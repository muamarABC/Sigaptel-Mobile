import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
  final String? downloadError;
  final String? uploadError;

  const SpeedMetrics({
    this.downloadMbps,
    this.uploadMbps,
    this.pingMs,
    this.downloadError,
    this.uploadError,
  });
}

enum SpeedTestStage { download, upload, ping }

typedef SpeedTestProgressCallback =
    void Function(SpeedTestStage stage, double progressPercent);

typedef SpeedTestSpeedCallback =
    void Function(SpeedTestStage stage, double speedMbps);

enum SpeedTestMode { cepat, standar, akurat }

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
      'https://speed.cloudflare.com/__down?bytes=50000000';
  static const String defaultUploadUrl = 'https://httpbin.org/post';
  static const String defaultPingUrl = 'https://www.google.com/generate_204';
  static const int defaultDownloadBytes = 50000000;
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
    final downloadBytes =
        prefs.getInt(_downloadBytesKey) ?? defaultDownloadBytes;
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
  static const MethodChannel _channel = MethodChannel(
    'com.sigaptel/network_metrics',
  );
  String? _lastDownloadError;
  String? _lastUploadError;

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
    SpeedTestSpeedCallback? onSpeedUpdate,
  }) async {
    final settings = await SpeedTestSettings.load();

    final config = switch (settings.mode) {
      SpeedTestMode.cepat => (
        runs: 1,
        streams: 2,
        downloadDuration: const Duration(seconds: 6),
        pingSamples: 3,
        warmUp: false,
      ),
      SpeedTestMode.standar => (
        runs: 2,
        streams: 2,
        downloadDuration: const Duration(seconds: 8),
        pingSamples: 5,
        warmUp: true,
      ),
      SpeedTestMode.akurat => (
        runs: 3,
        streams: 2,
        downloadDuration: const Duration(seconds: 10),
        pingSamples: 9,
        warmUp: true,
      ),
    };

    return runSpeedTestAccurate(
      timeout: timeout,
      onProgress: onProgress,
      onSpeedUpdate: onSpeedUpdate,
      runs: config.runs,
      parallelStreams: config.streams,
      downloadDuration: config.downloadDuration,
      pingSamples: config.pingSamples,
      enableWarmUp: config.warmUp,
    );
  }

  Future<SpeedMetrics> runSpeedTestAccurate({
    Duration timeout = const Duration(seconds: 90),
    SpeedTestProgressCallback? onProgress,
    SpeedTestSpeedCallback? onSpeedUpdate,
    int runs = 3,
    int parallelStreams = 2,
    Duration downloadDuration = const Duration(seconds: 8),
    int pingSamples = 9,
    bool enableWarmUp = true,
  }) async {
    final settings = await SpeedTestSettings.load();
    _lastDownloadError = null;
    _lastUploadError = null;
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
      final download = _lastDownloadError?.startsWith('HTTP 429') == true
          ? null
          : await _measureParallelDownloadMbps(
              settings: settings,
              timeout: timeout,
              streams: safeStreams,
              testDuration: downloadDuration,
              onSpeedUpdate: onSpeedUpdate,
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
        onSpeedUpdate: onSpeedUpdate,
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
      downloadError: downloadResults.isEmpty ? _lastDownloadError : null,
      uploadError: uploadResults.isEmpty ? _lastUploadError : null,
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

  double _mapRunProgressToStage(
    int runIndex,
    int totalRuns,
    double runPercent,
  ) {
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
    final uploadBytes = max(120000, settings.uploadBytes ~/ 10);

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
    required Duration testDuration,
    SpeedTestSpeedCallback? onSpeedUpdate,
    required void Function(double runPercent) onRunProgress,
  }) async {
    final safeStreams = streams < 1 ? 1 : streams;
    onRunProgress(0);
    final stopwatch = Stopwatch()..start();
    var totalDownloadedBytes = 0;
    var lastReportedAt = 0;
    var lastReportedBytes = 0;
    var lastProgressAt = 0;
    final requestBytes = max(settings.downloadBytes, 50 * 1024 * 1024);
    var rateLimited = false;

    Future<void> downloadStream() async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        while (!rateLimited && stopwatch.elapsed < testDuration) {
          final remaining = testDuration - stopwatch.elapsed;
          final requestTimeout = remaining < timeout ? remaining : timeout;
          if (requestTimeout <= Duration.zero) break;

          final request = await client
              .getUrl(_buildDownloadUri(settings.downloadUrl, requestBytes))
              .timeout(requestTimeout);
          request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
          request.headers.set(HttpHeaders.pragmaHeader, 'no-cache');
          final response = await request.close().timeout(requestTimeout);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            if (response.statusCode == 429) {
              final retryAfter = response.headers.value(
                HttpHeaders.retryAfterHeader,
              );
              final waitText = _formatRetryAfter(retryAfter);
              _lastDownloadError = waitText == null
                  ? 'Server membatasi permintaan (HTTP 429). Coba lagi nanti atau gunakan server lain.'
                  : 'Server membatasi permintaan (HTTP 429). Coba lagi dalam $waitText atau gunakan server lain.';
              rateLimited = true;
            } else {
              _lastDownloadError =
                  'Server pengujian menolak unduhan (HTTP ${response.statusCode}).';
            }
            await response.drain<void>().timeout(requestTimeout);
            break;
          }

          var bytesInResponse = 0;
          final completer = Completer<void>();
          late StreamSubscription<List<int>> subscription;
          subscription = response.listen(
            (chunk) {
              bytesInResponse += chunk.length;
              totalDownloadedBytes += chunk.length;
              final elapsedMs = stopwatch.elapsedMilliseconds;
              if (elapsedMs - lastReportedAt >= 200) {
                final elapsedUs = stopwatch.elapsedMicroseconds;
                final intervalBytes = totalDownloadedBytes - lastReportedBytes;
                final intervalUs = elapsedUs - lastReportedAt * 1000;
                if (intervalBytes > 0 && intervalUs > 0) {
                  onSpeedUpdate?.call(
                    SpeedTestStage.download,
                    _calculateMbps(intervalBytes, intervalUs) ?? 0,
                  );
                  lastReportedBytes = totalDownloadedBytes;
                  lastReportedAt = elapsedMs;
                }
              }
              if (elapsedMs - lastProgressAt >= 200) {
                onRunProgress(
                  (stopwatch.elapsedMicroseconds /
                          testDuration.inMicroseconds *
                          100)
                      .clamp(0, 100)
                      .toDouble(),
                );
                lastProgressAt = elapsedMs;
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              _lastDownloadError ??= _describeTransferError(
                error,
                direction: 'unduhan',
              );
              if (!completer.isCompleted)
                completer.completeError(error, stackTrace);
            },
            onDone: () {
              if (!completer.isCompleted) completer.complete();
            },
            cancelOnError: true,
          );

          final bodyTimeLeft = testDuration - stopwatch.elapsed;
          if (bodyTimeLeft <= Duration.zero) {
            await subscription.cancel();
            break;
          }
          final durationTimer = Timer(bodyTimeLeft, () async {
            await subscription.cancel();
            if (!completer.isCompleted) completer.complete();
          });
          try {
            await completer.future.timeout(requestTimeout);
          } on TimeoutException {
            _lastDownloadError ??=
                'Koneksi terlalu lambat: waktu tunggu unduhan habis.';
            await subscription.cancel();
          } catch (_) {
            // Keep any bytes already received and stop this stream on errors.
          } finally {
            durationTimer.cancel();
          }

          if (bytesInResponse == 0) {
            _lastDownloadError ??= 'Server mengirim 0 byte';
            break;
          }
        }
      } catch (error) {
        _lastDownloadError ??= _describeTransferError(
          error,
          direction: 'unduhan',
        );
      } finally {
        client.close(force: true);
      }
    }

    await Future.wait(List.generate(safeStreams, (_) => downloadStream()));
    stopwatch.stop();
    final finalIntervalBytes = totalDownloadedBytes - lastReportedBytes;
    final finalIntervalUs =
        stopwatch.elapsedMicroseconds - (lastReportedAt * 1000);
    if (finalIntervalBytes > 0 && finalIntervalUs > 0) {
      onSpeedUpdate?.call(
        SpeedTestStage.download,
        _calculateMbps(finalIntervalBytes, finalIntervalUs) ?? 0,
      );
    }

    onRunProgress(100);
    if (totalDownloadedBytes <= 0 || stopwatch.elapsedMicroseconds <= 0) {
      return null;
    }

    return _calculateMbps(totalDownloadedBytes, stopwatch.elapsedMicroseconds);
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

  String? _formatRetryAfter(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final seconds = int.tryParse(value.trim());
    if (seconds != null && seconds >= 0) {
      if (seconds < 60) return '$seconds detik';
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (minutes < 60) {
        return remainingSeconds == 0
            ? '$minutes menit'
            : '$minutes menit $remainingSeconds detik';
      }
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return remainingMinutes == 0
          ? '$hours jam'
          : '$hours jam $remainingMinutes menit';
    }

    try {
      final retryAt = HttpDate.parse(value).toUtc();
      final secondsUntilRetry = retryAt
          .difference(DateTime.now().toUtc())
          .inSeconds;
      if (secondsUntilRetry <= 0) return 'segera';
      return _formatRetryAfter(secondsUntilRetry.toString());
    } on FormatException {
      return 'sesuai instruksi server';
    }
  }

  String _describeTransferError(Object error, {required String direction}) {
    if (error is TimeoutException) {
      return 'Koneksi terlalu lambat: waktu tunggu $direction habis.';
    }
    if (error is SocketException) {
      return 'Koneksi internet terputus saat menguji $direction.';
    }
    if (error is HandshakeException) {
      return 'Koneksi aman ke server pengujian gagal (TLS).';
    }
    return 'Gagal menguji $direction: ${error.runtimeType}.';
  }

  Future<double?> _measureParallelUploadMbps({
    required SpeedTestSettings settings,
    required Duration timeout,
    required int streams,
    SpeedTestSpeedCallback? onSpeedUpdate,
    required void Function(double runPercent) onRunProgress,
  }) async {
    final safeStreams = streams < 1 ? 1 : streams;
    final perStreamBytes = max(250000, settings.uploadBytes ~/ safeStreams);
    var finished = 0;

    onRunProgress(0);
    final stopwatch = Stopwatch()..start();
    var totalUploadedBytes = 0;
    var lastReportedAt = 0;
    var lastReportedBytes = 0;

    final futures = List.generate(safeStreams, (index) async {
      final sentBytes = await _measureSingleUploadBytes(
        url: settings.uploadUrl,
        payloadSize: perStreamBytes,
        timeout: timeout,
        onBytesSent: (chunkBytes) {
          totalUploadedBytes += chunkBytes;
          final elapsedMs = stopwatch.elapsedMilliseconds;
          if (elapsedMs - lastReportedAt < 200) {
            return;
          }
          final elapsedUs = stopwatch.elapsedMicroseconds;
          final intervalBytes = totalUploadedBytes - lastReportedBytes;
          final intervalUs = elapsedUs - (lastReportedAt * 1000);
          if (intervalBytes > 0 && intervalUs > 0) {
            onSpeedUpdate?.call(
              SpeedTestStage.upload,
              _calculateMbps(intervalBytes, intervalUs) ?? 0,
            );
            lastReportedBytes = totalUploadedBytes;
            lastReportedAt = elapsedMs;
          }
        },
      );
      finished += 1;
      onRunProgress((finished / safeStreams) * 100.0);
      return sentBytes;
    });

    final sentList = await Future.wait(futures);
    stopwatch.stop();
    final finalIntervalBytes = totalUploadedBytes - lastReportedBytes;
    final finalIntervalUs =
        stopwatch.elapsedMicroseconds - (lastReportedAt * 1000);
    if (finalIntervalBytes > 0 && finalIntervalUs > 0) {
      onSpeedUpdate?.call(
        SpeedTestStage.upload,
        _calculateMbps(finalIntervalBytes, finalIntervalUs) ?? 0,
      );
    }

    final totalBytes = sentList.fold<int>(0, (sum, value) => sum + value);
    if (totalBytes <= 0 || stopwatch.elapsedMilliseconds <= 0) {
      return null;
    }

    return _calculateMbps(totalBytes, stopwatch.elapsedMicroseconds);
  }

  /// Uses microseconds so short tests are not rounded down to whole milliseconds.
  double? _calculateMbps(int bytes, int elapsedMicroseconds) {
    if (bytes <= 0 || elapsedMicroseconds <= 0) {
      return null;
    }
    return (bytes * 8) / elapsedMicroseconds;
  }

  Future<int> _measureSingleUploadBytes({
    required String url,
    required int payloadSize,
    required Duration timeout,
    void Function(int chunkBytes)? onBytesSent,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final request = await client.postUrl(Uri.parse(url)).timeout(timeout);
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/octet-stream',
      );
      request.contentLength = payloadSize;

      final random = Random();
      const chunkSize = 32 * 1024;
      var remaining = payloadSize;
      await request.addStream(() async* {
        while (remaining > 0) {
          final length = min(chunkSize, remaining);
          final chunk = Uint8List(length);
          for (var i = 0; i < length; i++) {
            chunk[i] = random.nextInt(256);
          }
          remaining -= length;
          onBytesSent?.call(length);
          yield chunk;
        }
      }());

      final response = await request.close().timeout(timeout);
      await response.drain();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastUploadError = response.statusCode == 429
            ? 'Server membatasi unggahan (HTTP 429). Gunakan server lain atau coba lagi nanti.'
            : 'Server pengujian menolak unggahan (HTTP ${response.statusCode}).';
        return 0;
      }
      return payloadSize;
    } catch (error) {
      _lastUploadError ??= _describeTransferError(error, direction: 'unggahan');
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
