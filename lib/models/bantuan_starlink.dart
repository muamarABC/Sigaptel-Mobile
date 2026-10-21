class BantuanStarlink {
  final int id;
  final int? userId;
  final String namaPetugas;
  final String kategoriProgram;
  final int tahunBantuan;
  final String kecamatan;
  final String desa;
  final String namaLokasi;
  final String alamat;
  final double latitude;
  final double longitude;
  final String idStarlink;
  final String namaKontak;
  final String telpKontak;
  final String status; // 'Online' | 'Offline'
  final String keterangan;
  final String fotoStarlink;
  final String createdAt;
  final String updatedAt;

  const BantuanStarlink({
    required this.id,
    this.userId,
    required this.namaPetugas,
    required this.kategoriProgram,
    required this.tahunBantuan,
    required this.kecamatan,
    required this.desa,
    required this.namaLokasi,
    required this.alamat,
    required this.latitude,
    required this.longitude,
    required this.idStarlink,
    required this.namaKontak,
    required this.telpKontak,
    required this.status,
    required this.keterangan,
    required this.fotoStarlink,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BantuanStarlink.fromJson(Map<String, dynamic> json) =>
      BantuanStarlink(
        id: _toInt(json['id']),
        userId: _toNullableInt(json['user_id']),
        namaPetugas: _toPetugasName(json),
        kategoriProgram: _toStr(json['kategori_program']),
        tahunBantuan: _toInt(json['tahun_bantuan']),
        kecamatan: _toStr(json['kecamatan']),
        desa: _toStr(json['desa']),
        namaLokasi: _toStr(json['nama_lokasi']),
        alamat: _toStr(json['alamat']),
        latitude: _toDouble(json['latitude']),
        longitude: _toDouble(json['longitude']),
        idStarlink: _toStr(json['id_starlink']),
        namaKontak: _toStr(json['nama_kontak']),
        telpKontak: _toStr(json['telp_kontak']),
        status: _toStr(json['status']),
        keterangan: _toStr(json['keterangan']),
        fotoStarlink: _toStr(json['foto_starlink']),
        createdAt: _toStr(json['created_at']),
        updatedAt: _toStr(json['updated_at']),
      );

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  static String _toStr(dynamic v) => v?.toString() ?? '';

  static String _toPetugasName(Map<String, dynamic> json) {
    final direct = [
      json['nama_petugas'],
      json['dibuat_oleh'],
      json['petugas'],
      json['user_name'],
      json['username'],
      json['created_by_name'],
    ];
    for (final value in direct) {
      final text = _toStr(value).trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    final user = json['user'];
    if (user is Map) {
      final userMap = Map<String, dynamic>.from(user);
      final userNames = [
        userMap['name'],
        userMap['nama'],
        userMap['username'],
      ];
      for (final value in userNames) {
        final text = _toStr(value).trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    final createdBy = json['created_by'];
    if (createdBy is Map) {
      final createdByMap = Map<String, dynamic>.from(createdBy);
      final text = _toStr(createdByMap['name']).trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }
}
