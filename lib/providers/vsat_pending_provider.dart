import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingVsatItem {
  final String id;
  final Map<String, String> fields;
  final String photoPath;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const PendingVsatItem({
    required this.id,
    required this.fields,
    required this.photoPath,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  PendingVsatItem copyWith({
    String? id,
    Map<String, String>? fields,
    String? photoPath,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
  }) {
    return PendingVsatItem(
      id: id ?? this.id,
      fields: fields ?? this.fields,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fields': fields,
        'photo_path': photoPath,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'last_error': lastError,
      };

  factory PendingVsatItem.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    final mappedFields = <String, String>{};
    if (rawFields is Map) {
      rawFields.forEach((key, value) {
        mappedFields[key.toString()] = value?.toString() ?? '';
      });
    }

    return PendingVsatItem(
      id: (json['id'] ?? '').toString(),
      fields: mappedFields,
      photoPath: (json['photo_path'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      retryCount: (json['retry_count'] as int?) ?? 0,
      lastError: json['last_error']?.toString(),
    );
  }
}

class VsatPendingProvider with ChangeNotifier {
  static const _storageKey = 'pending_vsat_bakti';

  final List<PendingVsatItem> _items = [];
  bool _isSyncing = false;

  List<PendingVsatItem> get items => List.unmodifiable(_items);
  int get count => _items.length;
  bool get isSyncing => _isSyncing;

  VsatPendingProvider() {
    _load();
  }

  Future<void> addPending({
    required Map<String, String> fields,
    required String photoPath,
  }) async {
    _items.add(
      PendingVsatItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        fields: Map<String, String>.from(fields),
        photoPath: photoPath,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> removeById(String id) async {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> replaceAll(List<PendingVsatItem> newItems) async {
    _items
      ..clear()
      ..addAll(newItems);
    notifyListeners();
    await _save();
  }

  Future<void> setSyncing(bool value) async {
    _isSyncing = value;
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) {
      return;
    }

    final decoded = jsonDecode(jsonString);
    if (decoded is! List) {
      return;
    }

    _items
      ..clear()
      ..addAll(
        decoded
            .whereType<Map>()
            .map((e) => PendingVsatItem.fromJson(Map<String, dynamic>.from(e))),
      );
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}
