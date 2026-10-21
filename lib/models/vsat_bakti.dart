class VsatBakti {
  final int id;
  final int? userId;
  final String namaPetugas;
  final String kategori;
  final int tahunOperasional;
  final String kecamatan;
  final String desa;
  final String namaLokasi;
  final String alamat;
  final double latitude;
  final double longitude;
  final String bandwidth;
  final String sumberListrik;
  final String namaKontak;
  final String emailKontak;
  final String telpKontak;
  final String status;
  final String keterangan;
  final String fotoVsat;
  final String createdAt;
  final String updatedAt;

  const VsatBakti({
    required this.id,
    this.userId,
    required this.namaPetugas,
    required this.kategori,
    required this.tahunOperasional,
    required this.kecamatan,
    required this.desa,
    required this.namaLokasi,
    required this.alamat,
    required this.latitude,
    required this.longitude,
    required this.bandwidth,
    required this.sumberListrik,
    required this.namaKontak,
    required this.emailKontak,
    required this.telpKontak,
    required this.status,
    required this.keterangan,
    required this.fotoVsat,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VsatBakti.fromJson(Map<String, dynamic> json) {
    return VsatBakti(
      id: _toInt(json['id']),
      userId: _toNullableInt(json['user_id']),
      namaPetugas: _toPetugasName(json),
      kategori: _toStr(json['kategori']),
      tahunOperasional: _toInt(json['tahun_operasional']),
      kecamatan: _toStr(json['kecamatan']),
      desa: _toStr(json['desa']),
      namaLokasi: _toStr(json['nama_lokasi']),
      alamat: _toStr(json['alamat']),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      bandwidth: _toStr(json['bandwidth']),
      sumberListrik: _toStr(json['sumber_listrik']),
      namaKontak: _toStr(json['nama_kontak']),
      emailKontak: _toStr(json['email_kontak']),
      telpKontak: _toStr(json['telp_kontak']),
      status: _toStr(json['status']),
      keterangan: _toStr(json['keterangan']),
      fotoVsat: _toStr(json['foto_vsat']),
      createdAt: _toStr(json['created_at']),
      updatedAt: _toStr(json['updated_at']),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static int? _toNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static String _toStr(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

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
