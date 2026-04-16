import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Whether the app is running in production mode.
  /// Set via --dart-define=PRODUCTION=true during release builds.
  static const bool isProduction =
      bool.fromEnvironment('PRODUCTION', defaultValue: false);

  static String get baseUrl {
    final defined = _definedBaseUrl.trim();
    if (defined.isNotEmpty) return defined;
    // Development defaults — all traffic goes through HTTPS in production.
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

/// Stores sensitive authentication tokens using platform-secure storage
/// (Android Keystore / iOS Keychain) instead of plaintext SharedPreferences.
///
/// Non-sensitive preferences (city, address book) remain in SharedPreferences.
class TokenStore {
  // Secure storage for sensitive auth tokens.
  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';

  // Non-sensitive keys stay in SharedPreferences.
  static const cityKey = 'location_city';
  static const addressBookKey = 'address_book_v1';

  // ---------------------------------------------------------------------------
  // Secure token operations
  // ---------------------------------------------------------------------------

  static Future<AuthSession?> read() async {
    try {
      final access = await _secureStorage.read(key: _accessKey);
      final refresh = await _secureStorage.read(key: _refreshKey);
      if (access == null || refresh == null) {
        return null;
      }
      return AuthSession(access: access, refresh: refresh);
    } catch (_) {
      // If secure storage fails (rare edge case), treat as logged out.
      return null;
    }
  }

  static Future<void> save({
    required String access,
    required String refresh,
  }) async {
    await _secureStorage.write(key: _accessKey, value: access);
    await _secureStorage.write(key: _refreshKey, value: refresh);
  }

  static Future<void> clear() async {
    await _secureStorage.delete(key: _accessKey);
    await _secureStorage.delete(key: _refreshKey);
  }

  // ---------------------------------------------------------------------------
  // Non-sensitive preferences (city, address book)
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Migration: move tokens from old SharedPreferences to secure storage.
  // Call once during app startup. After migration, old keys are removed.
  // ---------------------------------------------------------------------------

  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final oldAccess = prefs.getString('access');
    final oldRefresh = prefs.getString('refresh');
    if (oldAccess != null && oldRefresh != null) {
      await save(access: oldAccess, refresh: oldRefresh);
      await prefs.remove('access');
      await prefs.remove('refresh');
    }
  }
}
