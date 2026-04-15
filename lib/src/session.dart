import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    final defined = _definedBaseUrl.trim();
    if (defined.isNotEmpty) return defined;
    if (kIsWeb) return 'http://127.0.0.1:8000';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:8000',
      _ => 'http://127.0.0.1:8000',
    };
  }
}

class AuthSession {
  const AuthSession({required this.access, required this.refresh});

  final String access;
  final String refresh;
}

class TokenStore {
  static const _accessKey = 'access';
  static const _refreshKey = 'refresh';
  static const cityKey = 'location_city';
  static const addressBookKey = 'address_book_v1';

  static Future<AuthSession?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_accessKey);
    final refresh = prefs.getString(_refreshKey);
    if (access == null || refresh == null) {
      return null;
    }
    return AuthSession(access: access, refresh: refresh);
  }

  static Future<void> save({required String access, required String refresh}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  static Future<String?> readCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(cityKey);
  }

  static Future<void> saveCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cityKey, city);
  }

  static Future<List<Map<String, dynamic>>> readAddressBook() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(addressBookKey);
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <Map<String, dynamic>>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Future<void> saveAddressBook(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(addressBookKey, jsonEncode(entries));
  }
}
