class Tower {
  final int id;
  final String siteName;
  final String? siteId;
  final String kecamatan;
  final String desa;
  final double latitude;
  final double longitude;
  final String? address;
  final String? operator;
  final String status; // 'on_air' atau 'off_air'
  final double? tinggi;
  final String? konstruksiMenara;
  final String? tipeBentukMenara;

  Tower({
    required this.id,
    required this.siteName,
    this.siteId,
    required this.kecamatan,
    required this.desa,
    required this.latitude,
    required this.longitude,
    this.address,
    this.operator,
    required this.status,
    this.tinggi,
    this.konstruksiMenara,
    this.tipeBentukMenara,
  });

  factory Tower.fromJson(Map<String, dynamic> json) {
    return Tower(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      siteName: json['site_name']?.toString() ?? '',
      siteId: json['site_id']?.toString(),
      kecamatan: json['kecamatan']?.toString() ?? '',
      desa: json['desa']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      address: json['address']?.toString(),
      operator: json['operator']?.toString(),
      status: (json['status'] ?? 'off_air').toString().toLowerCase(),
      tinggi: _parseNullableDouble(json['tinggi']),
      konstruksiMenara: json['konstruksi_menara']?.toString(),
      tipeBentukMenara: json['tipe_bentuk_menara']?.toString(),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
