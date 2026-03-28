class Survey {
  final int? id;
  final int? userId;
  final String kecamatan;
  final String desa;
  final DateTime date;
  final double latitude;
  final double longitude;
  final String operatorName;
  final int? rsrp;
  final int? rsrq;
  final int? sinr;
  final int? rssi;
  final double? downloadSpeed;
  final double? uploadSpeed;
  final int? ping;
  final String tahunSurvei;
  final int? revisiKe;
  final int? isAktif;
  final int? parentId;
  final String jaringan;
  final String kekuatanSinyal;
  final String? fotoLokasiSurvei;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Survey({
    this.id,
    this.userId,
    required this.kecamatan,
    required this.desa,
    required this.date,
    required this.latitude,
    required this.longitude,
    required this.operatorName,
    required this.jaringan,
    this.rsrp,
    this.rsrq,
    this.sinr,
    this.rssi,
    this.downloadSpeed,
    this.uploadSpeed,
    this.ping,
    required this.tahunSurvei,
    this.revisiKe,
    this.isAktif,
    this.parentId,
    this.kekuatanSinyal = '',
    this.fotoLokasiSurvei,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  Survey copyWith({
    int? id,
    int? userId,
    String? kecamatan,
    String? desa,
    DateTime? date,
    double? latitude,
    double? longitude,
    String? operatorName,
    int? rsrp,
    int? rsrq,
    int? sinr,
    int? rssi,
    double? downloadSpeed,
    double? uploadSpeed,
    int? ping,
    String? tahunSurvei,
    int? revisiKe,
    int? isAktif,
    int? parentId,
    String? jaringan,
    String? kekuatanSinyal,
    String? fotoLokasiSurvei,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Survey(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      kecamatan: kecamatan ?? this.kecamatan,
      desa: desa ?? this.desa,
      date: date ?? this.date,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      operatorName: operatorName ?? this.operatorName,
      rsrp: rsrp ?? this.rsrp,
      rsrq: rsrq ?? this.rsrq,
      sinr: sinr ?? this.sinr,
      rssi: rssi ?? this.rssi,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      ping: ping ?? this.ping,
      tahunSurvei: tahunSurvei ?? this.tahunSurvei,
      revisiKe: revisiKe ?? this.revisiKe,
      isAktif: isAktif ?? this.isAktif,
      parentId: parentId ?? this.parentId,
      jaringan: jaringan ?? this.jaringan,
      kekuatanSinyal: kekuatanSinyal ?? this.kekuatanSinyal,
      fotoLokasiSurvei: fotoLokasiSurvei ?? this.fotoLokasiSurvei,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'kecamatan': kecamatan,
        'desa': desa,
        'date': date.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'operator': operatorName,
        'rsrp': rsrp,
        'rsrq': rsrq,
        'sinr': sinr,
        'rssi': rssi,
        'download_speed': downloadSpeed,
        'upload_speed': uploadSpeed,
        'ping': ping,
        'tahun_survei': tahunSurvei,
        'revisi_ke': revisiKe,
        'is_aktif': isAktif,
        'parent_id': parentId,
        'jaringan': jaringan,
        'kekuatan_sinyal': kekuatanSinyal,
        'foto_lokasi_survei': fotoLokasiSurvei,
        'notes': notes,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Map<String, String> toApiPayload() {
    final Map<String, String> payload = {
      'kecamatan': kecamatan,
      'desa': desa,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'operator': operatorName,
      'jaringan': jaringan,
      'tahun_survei': tahunSurvei,
      'revisi_ke': (revisiKe ?? 0).toString(),
      'is_aktif': (isAktif ?? 1).toString(),
    };

    void addIfNotNull(String key, dynamic value) {
      if (value == null) {
        return;
      }
      final text = value.toString();
      if (text.isNotEmpty) {
        payload[key] = text;
      }
    }

    addIfNotNull('rsrp', rsrp);
    addIfNotNull('user_id', userId);
    addIfNotNull('rsrq', rsrq);
    addIfNotNull('sinr', sinr);
    addIfNotNull('rssi', rssi);
    addIfNotNull('download_speed', downloadSpeed);
    addIfNotNull('upload_speed', uploadSpeed);
    addIfNotNull('ping', ping);
    final computedSignal = hitungKekuatanSinyal(rsrp);
    addIfNotNull(
      'kekuatan_sinyal',
      kekuatanSinyal.isEmpty ? computedSignal : kekuatanSinyal,
    );
    addIfNotNull('notes', notes);

    if (parentId != null) {
      addIfNotNull('parent_id', parentId);
    }

    return payload;
  }

  factory Survey.fromJson(Map<String, dynamic> json) => Survey(
        id: _toNullableInt(json['id']),
        userId: _toNullableInt(json['user_id']),
        kecamatan: _toStr(json['kecamatan']),
        desa: _toStr(json['desa']),
        date: DateTime.tryParse(_toStr(json['date'])) ??
            DateTime.tryParse(_toStr(json['created_at'])) ??
            DateTime.now(),
        latitude: _toDouble(json['latitude']),
        longitude: _toDouble(json['longitude']),
        operatorName: _toStr(json['operator']),
        rsrp: _toNullableInt(json['rsrp']),
        rsrq: _toNullableInt(json['rsrq']),
        sinr: _toNullableInt(json['sinr']),
        rssi: _toNullableInt(json['rssi']),
        downloadSpeed: _toNullableDouble(json['download_speed']),
        uploadSpeed: _toNullableDouble(json['upload_speed']),
        ping: _toNullableInt(json['ping']),
        tahunSurvei: _toStr(json['tahun_survei']),
        revisiKe: _toNullableInt(json['revisi_ke']),
        isAktif: _toNullableInt(json['is_aktif']),
        parentId: _toNullableInt(json['parent_id']),
        jaringan: _toStr(json['jaringan']),
        kekuatanSinyal: _toStr(
          json['kekuatan_sinyal'] ?? json['signalStrength'],
        ),
        fotoLokasiSurvei: _toNullableStr(
          json['foto_lokasi_survei'] ?? json['photoPath'],
        ),
        notes: _toNullableStr(json['notes']),
        createdAt: DateTime.tryParse(_toStr(json['created_at'])),
        updatedAt: DateTime.tryParse(_toStr(json['updated_at'])),
      );

  static String _toStr(dynamic value) => value?.toString() ?? '';

  static String? _toNullableStr(dynamic value) {
    if (value == null) {
      return null;
    }
    final parsed = value.toString();
    return parsed.isEmpty ? null : parsed;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    return int.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static String hitungKekuatanSinyal(int? rsrp) {
    if (rsrp == null || rsrp == 0 || rsrp >= 0) {
      return 'Total Blankspot';
    }
    if (rsrp >= -80) {
      return 'Sangat Bagus';
    }
    if (rsrp >= -90) {
      return 'Bagus';
    }
    if (rsrp >= -100) {
      return 'Normal';
    }
    if (rsrp >= -120) {
      return 'Lemah';
    }
    return 'Sangat Lemah';
  }
}