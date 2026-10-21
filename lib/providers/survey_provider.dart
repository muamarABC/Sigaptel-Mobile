import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/survey.dart';
import 'api_survey_provider.dart';

class SurveyProvider with ChangeNotifier {
  static const _storageKey = 'surveys';
  static const _pendingStorageKey = 'pending_surveys';

  final List<Survey> _surveys = [];
  final List<PendingSurveyItem> _pendingSurveys = [];
  bool _isSyncingPending = false;

  List<Survey> get surveys => List.unmodifiable(_surveys);
  List<PendingSurveyItem> get pendingSurveys =>
      List.unmodifiable(_pendingSurveys);
  int get pendingCount => _pendingSurveys.length;
  bool get isSyncingPending => _isSyncingPending;

  SurveyProvider() {
    _load();
  }

  Future<void> addSurvey(Survey s) async {
    _surveys.add(s);
    notifyListeners();
    await _save();
  }

  Future<void> addPendingSurvey(Survey s) async {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    final matching = _pendingSurveys.where((item) {
      final old = item.survey;
      return normalize(old.kecamatan) == normalize(s.kecamatan) &&
          normalize(old.desa) == normalize(s.desa) &&
          old.tahunSurvei.trim() == s.tahunSurvei.trim();
    }).toList();

    int? existingId;
    for (final item in matching) {
      if (item.survey.id != null) {
        existingId = item.survey.id;
        break;
      }
    }
    final surveyToSave = s.id == null && existingId != null
        ? s.copyWith(id: existingId)
        : s;
    _pendingSurveys.removeWhere((item) => matching.contains(item));
    _pendingSurveys.add(
      PendingSurveyItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        survey: surveyToSave,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    await _savePending();
  }

  Future<SyncPendingResult> syncPendingSurveys(
    Future<SubmitSurveyResult> Function(Survey survey) submitFn,
  ) async {
    if (_isSyncingPending) {
      return const SyncPendingResult(
        sent: 0,
        failed: 0,
        messages: ['Sync sedang berjalan, mohon tunggu hingga selesai.'],
      );
    }

    if (_pendingSurveys.isEmpty) {
      return const SyncPendingResult(sent: 0, failed: 0, messages: []);
    }

    _isSyncingPending = true;
    notifyListeners();

    var sent = 0;
    var failed = 0;
    final messages = <String>[];
    final failedItems = <PendingSurveyItem>[];
    final itemsToSync = List<PendingSurveyItem>.from(_pendingSurveys);

    try {
      for (final item in itemsToSync) {
        try {
          final result = await submitFn(item.survey);
          sent += 1;
          messages.add(result.message);
        } catch (e) {
          failed += 1;
          failedItems.add(
            item.copyWith(
              retryCount: item.retryCount + 1,
              lastError: e.toString(),
            ),
          );
        }
      }

      _pendingSurveys
        ..clear()
        ..addAll(failedItems);
      notifyListeners();
      await _savePending();
    } finally {
      _isSyncingPending = false;
      notifyListeners();
    }

    return SyncPendingResult(sent: sent, failed: failed, messages: messages);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      final List<dynamic> list = jsonDecode(jsonString);
      _surveys
        ..clear()
        ..addAll(list.map((e) => Survey.fromJson(e as Map<String, dynamic>)));
      notifyListeners();
    }

    final pendingJsonString = prefs.getString(_pendingStorageKey);
    if (pendingJsonString != null) {
      final List<dynamic> list = jsonDecode(pendingJsonString);
      _pendingSurveys
        ..clear()
        ..addAll(
          list.map(
            (e) => PendingSurveyItem.fromJson(e as Map<String, dynamic>),
          ),
        );
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_surveys.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  Future<void> _savePending() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(
      _pendingSurveys.map((s) => s.toJson()).toList(),
    );
    await prefs.setString(_pendingStorageKey, jsonString);
  }
}

class PendingSurveyItem {
  final String id;
  final Survey survey;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  const PendingSurveyItem({
    required this.id,
    required this.survey,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  PendingSurveyItem copyWith({
    String? id,
    Survey? survey,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
  }) {
    return PendingSurveyItem(
      id: id ?? this.id,
      survey: survey ?? this.survey,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'survey': survey.toJson(),
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
    'last_error': lastError,
  };

  factory PendingSurveyItem.fromJson(Map<String, dynamic> json) {
    return PendingSurveyItem(
      id: (json['id'] ?? '').toString(),
      survey: Survey.fromJson(Map<String, dynamic>.from(json['survey'] as Map)),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      retryCount: (json['retry_count'] as int?) ?? 0,
      lastError: json['last_error']?.toString(),
    );
  }
}

class SyncPendingResult {
  final int sent;
  final int failed;
  final List<String> messages;

  const SyncPendingResult({
    required this.sent,
    required this.failed,
    required this.messages,
  });
}
