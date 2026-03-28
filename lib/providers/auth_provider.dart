import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class AuthProvider with ChangeNotifier {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  bool _loggedIn = false;
  String? _email;
  String? _token;
  AppUser? _user;
  bool _isLoading = false;
  bool _isRestoring = true;
  String? _lastError;

  bool get isLoggedIn => _loggedIn;
  String? get email => _email;
  String? get token => _token;
  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isRestoring => _isRestoring;
  String? get lastError => _lastError;

  AuthProvider() {
    _restoreSession();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await http.post(
        AppConfig.apiUri('/api/login'),
        headers: AppConfig.authHeaders(
          extra: {'Content-Type': 'application/json'},
        ),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _lastError = _extractMessage(response.body) ??
            'Login gagal (${response.statusCode})';
        return false;
      }

      final dynamic decoded = jsonDecode(response.body);
      final map = _toMap(decoded);
      final userMap = _extractUserMap(map);

      _user = AppUser.fromJson(userMap);
      _email = _user?.email ?? email;
      _token = _extractToken(map);
      _loggedIn = true;

      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString(_tokenKey, _token!);
      } else {
        await prefs.remove(_tokenKey);
      }
      if (_user != null) {
        await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
      }

      return true;
    } catch (_) {
      _lastError = 'Tidak bisa terhubung ke server login';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _loggedIn = false;
    _email = null;
    _token = null;
    _user = null;
    _lastError = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);

    notifyListeners();
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);
      final savedUserJson = prefs.getString(_userKey);

      if (savedUserJson == null) {
        return;
      }

      final userMap = _toMap(jsonDecode(savedUserJson));
      _user = AppUser.fromJson(userMap);
      _email = _user?.email;
      _token = savedToken;
      _loggedIn = true;
    } catch (_) {
      // ignore broken persisted state
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String? _extractToken(Map<String, dynamic> map) {
    final direct = map['token'];
    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }

    final data = map['data'];
    if (data is Map) {
      final nested = data['token'] ?? data['access_token'];
      if (nested != null && nested.toString().isNotEmpty) {
        return nested.toString();
      }
    }
    return null;
  }

  String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['msg'] ?? decoded['error'];
        return message?.toString();
      }
      return decoded.toString();
    } catch (_) {
      return body;
    }
  }

  Map<String, dynamic> _extractUserMap(Map<String, dynamic> map) {
    final data = map['data'];
    if (data is Map) {
      final maybeUser = data['user'];
      if (maybeUser is Map) {
        return Map<String, dynamic>.from(maybeUser);
      }
      return Map<String, dynamic>.from(data);
    }

    final user = map['user'];
    if (user is Map) {
      return Map<String, dynamic>.from(user);
    }

    return map;
  }
}

class AppUser {
  final int? id;
  final String name;
  final String jabatan;
  final String email;
  final String phone;
  final String role;

  const AppUser({
    this.id,
    required this.name,
    required this.jabatan,
    required this.email,
    required this.phone,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    String toStr(dynamic v) => v?.toString() ?? '';
    int? toNullableInt(dynamic v) {
      if (v == null) {
        return null;
      }
      if (v is int) {
        return v;
      }
      return int.tryParse(v.toString());
    }

    return AppUser(
      id: toNullableInt(json['id'] ?? json['user_id']),
      name: toStr(json['name']),
      jabatan: toStr(json['jabatan']),
      email: toStr(json['email']),
      phone: toStr(json['phone']),
      role: toStr(json['role']),
    );
  }

  Map<String, dynamic> toJson() => {
      'id': id,
        'name': name,
        'jabatan': jabatan,
        'email': email,
        'phone': phone,
        'role': role,
      };
}
