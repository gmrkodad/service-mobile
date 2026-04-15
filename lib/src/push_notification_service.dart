import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

class PushNotificationService {
  PushNotificationService({required ApiService api}) : _api = api;

  final ApiService _api;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _currentToken;

  String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      _ => 'unknown',
    };
  }

  Future<void> configureForAuthenticatedUser() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        await _api.registerDeviceToken(token: token, platform: _platform);
      }
      _tokenRefreshSub ??= messaging.onTokenRefresh.listen((token) async {
        if (token.isEmpty) return;
        _currentToken = token;
        try {
          await _api.registerDeviceToken(token: token, platform: _platform);
        } catch (_) {
          // Keep app usable even if token refresh sync fails.
        }
      });
    } catch (_) {
      // Firebase may not be configured on all environments during development.
    }
  }

  Future<void> unregisterCurrentDeviceToken() async {
    try {
      final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _api.unregisterDeviceToken(token: token);
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }
}
