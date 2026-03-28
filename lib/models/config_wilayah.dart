class ConfigWilayah {
  final int id;
  final String kecamatan;
  final double latitude;
  final double longitude;
  final int urutan;

  const ConfigWilayah({
    required this.id,
    required this.kecamatan,
    required this.latitude,
    required this.longitude,
    required this.urutan,
  });

  factory ConfigWilayah.fromJson(Map<String, dynamic> json) {
    return ConfigWilayah(
      id: json['id'] as int,
      kecamatan: json['kecamatan']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      urutan: (json['urutan'] as num?)?.toInt() ?? 0,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
