class RemoteSurvey {
  final int id;
  final int userId;
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
  final String jaringan;
  final String kekuatanSinyal;
  final String fotoLokasiSurvei;
  final String createdAt;
  final String updatedAt;

  RemoteSurvey({
    required this.id,
    required this.userId,
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
    required this.jaringan,
    required this.kekuatanSinyal,
    required this.fotoLokasiSurvei,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RemoteSurvey.fromJson(Map<String, dynamic> json) => RemoteSurvey(
        id: _toInt(json['id']),
        userId: _toInt(json['user_id']),
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
        jaringan: _toStr(json['jaringan']),
        kekuatanSinyal: _toStr(json['kekuatan_sinyal']),
        fotoLokasiSurvei: _toStr(json['foto_lokasi_survei']),
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
}