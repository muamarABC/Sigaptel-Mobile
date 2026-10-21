class RemoteSurvey {
  final int id;
  final int userId;
  final String namaPembuat;
  final String kecamatan;
  final String desa;
  final String latitude;
  final String longitude;
  final String operator;
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
  final String fotoLokasiSurvei;
  final String notes;
  final String createdAt;
  final String updatedAt;

  RemoteSurvey({
    required this.id,
    required this.userId,
    required this.namaPembuat,
    required this.kecamatan,
    required this.desa,
    required this.latitude,
    required this.longitude,
    required this.operator,
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
    required this.jaringan,
    required this.kekuatanSinyal,
    required this.fotoLokasiSurvei,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteSurvey.fromJson(Map<String, dynamic> json) => RemoteSurvey(
    id: _toInt(json['id']),
    userId: _toInt(json['user_id']),
    namaPembuat: _toCreatorName(json),
    kecamatan: _toStr(json['kecamatan']),
    desa: _toStr(json['desa']),
    latitude: _toStr(json['latitude']),
    longitude: _toStr(json['longitude']),
    operator: _toStr(json['operator']),
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
    kekuatanSinyal: _toStr(json['kekuatan_sinyal']),
    fotoLokasiSurvei: _toStr(json['foto_lokasi_survei']),
    notes: _toStr(json['notes']),
    createdAt: _toStr(json['created_at']),
    updatedAt: _toStr(json['updated_at']),
  );

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
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

  static String _toStr(dynamic value) {
    return value?.toString() ?? '';
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

  static String _toCreatorName(Map<String, dynamic> json) {
    final candidates = [
      json['nama_pembuat'],
      json['nama_petugas'],
      json['dibuat_oleh'],
      json['created_by_name'],
      json['user_name'],
    ];

    for (final value in candidates) {
      final text = _toStr(value).trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    final user = json['user'];
    if (user is Map) {
      final userMap = Map<String, dynamic>.from(user);
      final names = [userMap['name'], userMap['nama'], userMap['username']];
      for (final value in names) {
        final text = _toStr(value).trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    return '';
  }
}
