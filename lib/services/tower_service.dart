import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/tower.dart';
import '../models/config_wilayah.dart';
import '../config/app_config.dart';

class TowerService {
  static Future<List<Tower>> fetchAllTowers() async {
    try {
      final response = await http.get(
        AppConfig.apiUri('/api/towers'),
        headers: AppConfig.authHeaders(),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        
        // Handle jika response berupa array langsung
        if (jsonData is List) {
          return jsonData.map((tower) => Tower.fromJson(tower as Map<String, dynamic>)).toList();
        }
        
        // Handle jika response berupa object dengan data key
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
          final data = jsonData['data'];
          if (data is List) {
            return data.map((tower) => Tower.fromJson(tower as Map<String, dynamic>)).toList();
          }
        }

        return [];
      } else {
        throw Exception('Failed to load towers: ${response.statusCode}');
      }
    } catch (e) {
      return [];
    }
  }

  static Future<Tower?> fetchTowerById(int towerId) async {
    try {
      final response = await http.get(
        AppConfig.apiUri('/api/towers/$towerId'),
        headers: AppConfig.authHeaders(),
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        
        // Handle jika response berupa object dengan data key
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
          return Tower.fromJson(jsonData['data'] as Map<String, dynamic>);
        }
        
        // Handle jika response langsung adalah tower object
        if (jsonData is Map<String, dynamic>) {
          return Tower.fromJson(jsonData);
        }

        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<List<Tower>> fetchTowersByKecamatan(String kecamatan) async {
    try {
      final response = await http.get(
        AppConfig.apiUri(
          '/api/towers/filter/kecamatan',
          queryParameters: {'kecamatan': kecamatan},
        ),
        headers: AppConfig.authHeaders(),
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        
        if (jsonData is List) {
          return jsonData.map((tower) => Tower.fromJson(tower as Map<String, dynamic>)).toList();
        }
        
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
          final data = jsonData['data'];
          if (data is List) {
            return data.map((tower) => Tower.fromJson(tower as Map<String, dynamic>)).toList();
          }
        }

        return [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static Future<List<Tower>> fetchTowersByStatus(String status) async {
    try {
      final response = await http.get(
        AppConfig.apiUri(
          '/api/towers/filter/status',
          queryParameters: {'status': status},
        ),
        headers: AppConfig.authHeaders(),
      ).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData is List) {
          return (jsonData).map((tower) => Tower.fromJson(tower)).toList();
        }
        
        if (jsonData is Map && jsonData.containsKey('data')) {
          return (jsonData['data'] as List).map((tower) => Tower.fromJson(tower)).toList();
        }

        return [];
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Fetch semua titik koordinat polygon kecamatan dari config_wilayah
  static Future<Map<String, List<ConfigWilayah>>> fetchWilayahPolygons() async {
    try {
      final response = await http.get(
        AppConfig.apiUri('/api/wilayah'),
        headers: AppConfig.authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);

        List<dynamic> rawList;
        if (jsonData is List) {
          rawList = jsonData;
        } else if (jsonData is Map && jsonData.containsKey('data')) {
          rawList = jsonData['data'] as List<dynamic>;
        } else {
          return {};
        }

        final list = rawList
            .map((e) => ConfigWilayah.fromJson(e as Map<String, dynamic>))
            .toList();

        // Kelompokkan berdasarkan kecamatan, urut by urutan
        final grouped = <String, List<ConfigWilayah>>{};
        for (final item in list) {
          grouped.putIfAbsent(item.kecamatan, () => []).add(item);
        }
        for (final key in grouped.keys) {
          grouped[key]!.sort((a, b) => a.urutan.compareTo(b.urutan));
        }
        return grouped;
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
