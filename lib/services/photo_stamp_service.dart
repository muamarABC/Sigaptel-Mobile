import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

class PhotoStampService {
  static Future<Uint8List> stamp({
    required Uint8List photoBytes,
    required DateTime? timestamp,
    required String desa,
    required String kecamatan,
    String locationPrefix = '',
    required String latitude,
    required String longitude,
    required String staffName,
  }) async {
    final mapTile = await _fetchMapTile(latitude, longitude);
    final codec = await ui.instantiateImageCodec(photoBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    try {
      ui.Codec? mapCodec;
      ui.Image? mapImage;
      if (mapTile != null) {
        try {
          mapCodec = await ui.instantiateImageCodec(mapTile.bytes);
          mapImage = (await mapCodec.getNextFrame()).image;
        } catch (_) {
          mapCodec?.dispose();
          mapCodec = null;
        }
      }

      try {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final width = image.width.toDouble();
        final height = image.height.toDouble();
        final scale = math
            .min(width / 720, height / 900)
            .clamp(0.5, 1.3)
            .toDouble();
        final padding = 19.0 * scale;
        final clockSize = math.min(72.0 * scale, width * 0.18).toDouble();
        final dateSize = math.max(24.0 * scale, 14.0).toDouble();
        final detailSize = math.max(21.0 * scale, 14.0).toDouble();
        final clockHeight = clockSize * 1.15;
        final dateLineHeight = dateSize * 1.3;
        final detailLineHeight = detailSize * 1.48;
        final dateGap = dateSize * 0.12;
        final topBlockHeight = clockHeight + dateGap + dateLineHeight;
        final rowGap = detailSize * 0.35;
        final infoBlockHeight = topBlockHeight + rowGap + detailLineHeight * 3;
        final mapSize = mapImage == null
            ? 0.0
            : math
                  .min(width * 0.27, math.min(height * 0.25, 190.0 * scale))
                  .toDouble();
        final panelHeight = math
            .min(
              height * 0.58,
              padding * 2 + math.max(infoBlockHeight, mapSize),
            )
            .toDouble();
        final panelTop = height - panelHeight;
        final textWidth = math.max(0.0, width - padding * 2).toDouble();
        final detailTextWidth = math
            .max(0.0, width - padding * 2 - mapSize - padding * 0.45)
            .toDouble();
        final localTime = timestamp?.toUtc().add(const Duration(hours: 7));
        final clock = localTime == null
            ? '--:--'
            : '${localTime.hour.toString().padLeft(2, '0')}:'
                  '${localTime.minute.toString().padLeft(2, '0')}';
        const weekdays = [
          'Senin',
          'Selasa',
          'Rabu',
          'Kamis',
          'Jumat',
          'Sabtu',
          'Minggu',
        ];
        const months = [
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
        final dateLine = localTime == null
            ? 'Waktu survei tidak tersedia'
            : '${weekdays[localTime.weekday - 1]}, '
                  '${localTime.day} ${months[localTime.month - 1]} ${localTime.year}';
        final cleanDesa = desa.trim().isEmpty ? '-' : desa.trim();
        final cleanKecamatan = kecamatan.trim();
        final cleanPrefix = locationPrefix.trim();
        final locationParts = [
          if (cleanPrefix.isNotEmpty) cleanPrefix,
          'Desa $cleanDesa',
          if (cleanKecamatan.isNotEmpty) cleanKecamatan,
        ];
        final location = locationParts.join(', ');
        final latitudeValue = double.tryParse(latitude.trim());
        final longitudeValue = double.tryParse(longitude.trim());
        final coordinate =
            'Koordinat: '
            '${latitudeValue?.toStringAsFixed(5) ?? latitude}, '
            '${longitudeValue?.toStringAsFixed(5) ?? longitude}';

        canvas.drawImage(image, ui.Offset.zero, ui.Paint());
        canvas.drawRect(
          ui.Rect.fromLTWH(0, panelTop, width, panelHeight),
          ui.Paint()
            ..shader = ui.Gradient.linear(
              ui.Offset(0, panelTop),
              ui.Offset(0, height),
              const [ui.Color(0x00111620), ui.Color(0xE6111620)],
            ),
        );

        final clockPainter = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(
                text: clock,
                style: TextStyle(
                  color: const ui.Color(0xFFFFFFFF),
                  fontSize: clockSize,
                  fontWeight: FontWeight.w700,
                  shadows: const [
                    Shadow(color: ui.Color(0x66000000), blurRadius: 2),
                  ],
                ),
              ),
              TextSpan(
                text: ' WIB',
                style: TextStyle(
                  color: const ui.Color(0xFFFFFFFF),
                  fontSize: math.max(14.0, clockSize * 0.38),
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(color: ui.Color(0x66000000), blurRadius: 2),
                  ],
                ),
              ),
            ],
          ),
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        )..layout(maxWidth: textWidth);
        final datePainter = _textPainter(
          dateLine,
          fontSize: dateSize,
          maxWidth: textWidth,
          fontWeight: FontWeight.w600,
          color: const ui.Color(0xFFFFD166),
        );
        final topRow = height - padding - infoBlockHeight;
        clockPainter.paint(canvas, ui.Offset(padding, topRow));
        datePainter.paint(
          canvas,
          ui.Offset(padding, topRow + clockHeight + dateGap),
        );

        final detailTop = topRow + topBlockHeight + rowGap;
        final accentY = detailTop - rowGap * 0.55;
        canvas.drawLine(
          ui.Offset(padding, accentY),
          ui.Offset(padding + detailTextWidth, accentY),
          ui.Paint()
            ..color = const ui.Color(0x66FFFFFF)
            ..strokeWidth = math.max(0.7, scale)
            ..strokeCap = ui.StrokeCap.round,
        );
        final accentLineWidth = math.min(42.0 * scale, detailTextWidth * 0.24);
        canvas.drawLine(
          ui.Offset(padding, accentY),
          ui.Offset(padding + accentLineWidth, accentY),
          ui.Paint()
            ..color = const ui.Color(0xFFFFD166)
            ..strokeWidth = math.max(1.4, 1.8 * scale)
            ..strokeCap = ui.StrokeCap.round,
        );
        final details = [location, coordinate, 'Petugas: $staffName'];
        for (var index = 0; index < details.length; index++) {
          final painter = _textPainter(
            details[index],
            fontSize: detailSize,
            maxWidth: detailTextWidth,
            fontWeight: index == 0 ? FontWeight.w700 : FontWeight.w500,
            color: index == 0
                ? const ui.Color(0xFFFFFFFF)
                : const ui.Color(0xFFD5DFEB),
          );
          painter.paint(
            canvas,
            ui.Offset(padding, detailTop + detailLineHeight * index),
          );
        }

        if (mapImage != null && mapTile != null && mapSize > 0) {
          final mapRect = ui.Rect.fromLTWH(
            width - padding - mapSize,
            height - padding - mapSize,
            mapSize,
            mapSize,
          );
          final mapBorder = ui.RRect.fromRectAndRadius(
            mapRect,
            ui.Radius.circular(7.0 * scale),
          );
          canvas.save();
          canvas.clipRRect(mapBorder);
          final tileWidth = mapImage.width.toDouble();
          final tileHeight = mapImage.height.toDouble();
          final markerTileX = mapTile.markerX * tileWidth;
          final markerTileY = mapTile.markerY * tileHeight;
          final sourceSide = mapTile.sourceSide;
          final sourceLeft = (markerTileX - sourceSide / 2)
              .clamp(0.0, tileWidth - sourceSide)
              .toDouble();
          final sourceTop = (markerTileY - sourceSide / 2)
              .clamp(0.0, tileHeight - sourceSide)
              .toDouble();
          canvas.drawImageRect(
            mapImage,
            ui.Rect.fromLTWH(sourceLeft, sourceTop, sourceSide, sourceSide),
            mapRect,
            ui.Paint()..filterQuality = ui.FilterQuality.high,
          );

          final attributionFont = math.max(7.0 * scale, 5.5).toDouble();
          final attributionLineHeight = attributionFont * 1.15;
          final attributionHeight = attributionLineHeight * 2 + 3.0 * scale;
          final attributionTop = mapRect.bottom - attributionHeight;
          canvas.drawRect(
            ui.Rect.fromLTWH(
              mapRect.left,
              attributionTop,
              mapSize,
              attributionHeight,
            ),
            ui.Paint()..color = const ui.Color(0xCC111827),
          );
          final attributionWidth = math.max(0.0, mapSize - 6.0 * scale);
          _textPainter(
            '\u00a9 OpenStreetMap',
            fontSize: attributionFont,
            maxWidth: attributionWidth,
            fontWeight: FontWeight.w500,
          ).paint(
            canvas,
            ui.Offset(mapRect.left + 3.0 * scale, attributionTop + 1.0 * scale),
          );
          _textPainter(
            'contributors',
            fontSize: attributionFont,
            maxWidth: attributionWidth,
            fontWeight: FontWeight.w400,
            color: const ui.Color(0xFFD5DFEB),
          ).paint(
            canvas,
            ui.Offset(
              mapRect.left + 3.0 * scale,
              attributionTop + 1.0 * scale + attributionLineHeight,
            ),
          );
          final marker = mapRect.center;
          final markerRadius = math.max(3.5, 5.0 * scale);
          canvas.drawCircle(
            marker,
            markerRadius * 1.7,
            ui.Paint()..color = const ui.Color(0xE6FFFFFF),
          );
          canvas.drawCircle(
            marker,
            markerRadius,
            ui.Paint()..color = const ui.Color(0xFFE53935),
          );
          canvas.restore();
          canvas.drawRRect(
            mapBorder,
            ui.Paint()
              ..color = const ui.Color(0xCCFFFFFF)
              ..style = ui.PaintingStyle.stroke
              ..strokeWidth = math.max(1.0, scale),
          );
        }

        final stampedImage = await recorder.endRecording().toImage(
          image.width,
          image.height,
        );
        try {
          final byteData = await stampedImage.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData == null) {
            throw StateError('Gagal membuat foto dengan watermark.');
          }
          return byteData.buffer.asUint8List();
        } finally {
          stampedImage.dispose();
        }
      } finally {
        mapImage?.dispose();
        mapCodec?.dispose();
      }
    } finally {
      image.dispose();
      codec.dispose();
    }
  }

  static Future<_MapTile?> _fetchMapTile(
    String latitude,
    String longitude,
  ) async {
    final lat = double.tryParse(latitude.trim());
    final lng = double.tryParse(longitude.trim());
    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }

    final clampedLatitude = lat.clamp(-85.0511, 85.0511);
    final latitudeRadians = clampedLatitude * math.pi / 180;
    const zoom = 18;
    final tileCount = math.pow(2, zoom).toDouble();
    final x = (lng + 180) / 360 * tileCount;
    final y =
        (1 -
            math.log(
                  math.tan(latitudeRadians) + 1 / math.cos(latitudeRadians),
                ) /
                math.pi) /
        2 *
        tileCount;
    final tileX = x.floor().clamp(0, tileCount.toInt() - 1).toInt();
    final tileY = y.floor().clamp(0, tileCount.toInt() - 1).toInt();
    final markerInTileX = x - tileX;
    final markerInTileY = y - tileY;
    final sourceSide =
        100 / (156543.03392804097 * math.cos(latitudeRadians) / tileCount);
    final startTileX =
        (markerInTileX * 256 < sourceSide / 2 ? tileX - 1 : tileX)
            .clamp(0, tileCount.toInt() - 2)
            .toInt();
    final startTileY =
        (markerInTileY * 256 < sourceSide / 2 ? tileY - 1 : tileY)
            .clamp(0, tileCount.toInt() - 2)
            .toInt();
    final markerX = (x - startTileX) / 2;
    final markerY = (y - startTileY) / 2;

    Future<Uint8List?> downloadTile(int x, int y) async {
      final uri = Uri.https('tile.openstreetmap.org', '/$zoom/$x/$y.png');
      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'image/png',
              'User-Agent':
                  'SIGAPTELMOBIL/1.0 (SIGAPTEL survey app; https://tower.baritotimurkab.go.id)',
              'Referer': 'https://tower.baritotimurkab.go.id/',
            },
          )
          .timeout(const Duration(seconds: 3));
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (response.statusCode != 200 ||
          !contentType.startsWith('image/') ||
          response.bodyBytes.isEmpty) {
        return null;
      }
      return response.bodyBytes;
    }

    try {
      final tiles = await Future.wait([
        downloadTile(startTileX, startTileY),
        downloadTile(startTileX + 1, startTileY),
        downloadTile(startTileX, startTileY + 1),
        downloadTile(startTileX + 1, startTileY + 1),
      ]);
      if (tiles.any((tile) => tile == null)) {
        return null;
      }

      final codecs = <ui.Codec>[];
      final tileImages = <ui.Image>[];
      try {
        for (final tile in tiles) {
          final codec = await ui.instantiateImageCodec(tile!);
          codecs.add(codec);
          tileImages.add((await codec.getNextFrame()).image);
        }

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        for (var index = 0; index < tileImages.length; index++) {
          final column = index % 2;
          final row = index ~/ 2;
          final tileImage = tileImages[index];
          canvas.drawImageRect(
            tileImage,
            ui.Rect.fromLTWH(
              0,
              0,
              tileImage.width.toDouble(),
              tileImage.height.toDouble(),
            ),
            ui.Rect.fromLTWH(column * 256, row * 256, 256, 256),
            ui.Paint()..filterQuality = ui.FilterQuality.high,
          );
        }

        final mosaic = await recorder.endRecording().toImage(512, 512);
        try {
          final byteData = await mosaic.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteData == null) return null;
          return _MapTile(
            bytes: byteData.buffer.asUint8List(),
            markerX: markerX,
            markerY: markerY,
            sourceSide: sourceSide,
          );
        } finally {
          mosaic.dispose();
        }
      } finally {
        for (final tileImage in tileImages) {
          tileImage.dispose();
        }
        for (final codec in codecs) {
          codec.dispose();
        }
      }
    } catch (_) {
      return null;
    }
  }

  static TextPainter _textPainter(
    String text, {
    required double fontSize,
    required double maxWidth,
    required FontWeight fontWeight,
    TextAlign textAlign = TextAlign.left,
    ui.Color color = const ui.Color(0xFFFFFFFF),
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          shadows: const [Shadow(color: ui.Color(0x66000000), blurRadius: 2)],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 1,
      ellipsis: '...',
    )..layout(
      minWidth: textAlign == TextAlign.center ? maxWidth : 0,
      maxWidth: maxWidth,
    );
  }
}

class _MapTile {
  final Uint8List bytes;
  final double markerX;
  final double markerY;
  final double sourceSide;

  const _MapTile({
    required this.bytes,
    required this.markerX,
    required this.markerY,
    required this.sourceSide,
  });
}
