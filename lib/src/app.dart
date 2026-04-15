import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
import 'push_notification_service.dart';
import 'session.dart';
import 'ui/admin_shell.dart';
import 'ui/auth_page.dart';
import 'ui/customer_shell.dart';
import 'ui/provider_shell.dart';

class ServiceApp extends StatefulWidget {
  const ServiceApp({super.key});

  @override
  State<ServiceApp> createState() => _ServiceAppState();
}

class _ServiceAppState extends State<ServiceApp> {
  final ApiService _api = ApiService();
  late final PushNotificationService _pushNotifications =
      PushNotificationService(api: _api);
  bool _initializing = true;
  UserProfile? _profile;
  final DateTime _bootStartedAt = DateTime.now();

  ThemeData _buildTheme() {
    const background = Color(0xFFF5F7F6);
    const surface = Color(0xFFFFFFFF);
    const primary = Color(0xFF0D7C66);
    const onPrimary = Colors.white;
    const secondary = Color(0xFF14A38B);
    const onSecondary = Colors.white;
    const textPrimary = Color(0xFF1A2B23);
    const textMuted = Color(0xFF5A6B63);
    const stroke = Color(0xFFDCE5E0);

    const colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: surface,
      onSurface: textPrimary,
      error: Color(0xFFDC2626),
      onError: Colors.white,
      outline: stroke,
      outlineVariant: Color(0xFFEDF0EE),
    );

    final base = ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'Poppins',
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.8,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textMuted,
        ),
        bodyMedium: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: textMuted,
        ),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: const Color(0xFFE6F5F0),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? primary : textMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primary : textMuted,
            fontWeight: FontWeight.w700,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: const EdgeInsets.all(0),
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x081A2B23),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: stroke, width: 0.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: primary,
          foregroundColor: onPrimary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          side: const BorderSide(color: stroke, width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F6F5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: stroke, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: stroke, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        labelStyle: const TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF8A9B93),
          fontWeight: FontWeight.w700,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF4F6F5),
        selectedColor: const Color(0xFFE6F5F0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: stroke, width: 0.5),
        ),
        labelStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A2B23),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    Future<void> ensureMinimumSplash() async {
      final elapsed = DateTime.now().difference(_bootStartedAt);
      const minDuration = Duration(milliseconds: 1200);
      if (elapsed < minDuration) {
        await Future<void>.delayed(minDuration - elapsed);
      }
    }

    final session = await TokenStore.read();
    if (session == null) {
      await ensureMinimumSplash();
      setState(() {
        _initializing = false;
        _profile = null;
      });
      return;
    }

    try {
      final profile = await _api.fetchProfile();
      await ensureMinimumSplash();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _initializing = false;
      });
      await _pushNotifications.configureForAuthenticatedUser();
    } catch (_) {
      await _api.logout();
      await ensureMinimumSplash();
      if (!mounted) return;
      setState(() {
        _profile = null;
        _initializing = false;
      });
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final profile = await _api.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        _expireSession();
      }
    }
  }

  Future<void> _authenticated() async {
    await _refreshProfile();
    if (!mounted) return;
    if (_profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load profile after login')),
      );
      return;
    }
    await _pushNotifications.configureForAuthenticatedUser();
  }

  Future<void> _logout() async {
    await _pushNotifications.unregisterCurrentDeviceToken();
    await _api.logout();
    if (!mounted) return;
    setState(() {
      _profile = null;
    });
  }

  void _expireSession() {
    _pushNotifications.unregisterCurrentDeviceToken();
    _api.logout();
    setState(() {
      _profile = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired. Please login again.')),
    );
  }

  @override
  void dispose() {
    _pushNotifications.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (_initializing) {
      home = const _SplashScreen();
    } else if (_profile == null) {
      home = AuthPage(api: _api, onAuthenticated: _authenticated);
    } else {
        switch (_profile!.role) {
          case 'ADMIN':
          case 'SUPPORT':
            home = AdminShell(
              api: _api,
              profile: _profile!,
              onRefreshProfile: _refreshProfile,
              onLogout: _logout,
              onSessionExpired: _expireSession,
            );
            break;
          case 'PROVIDER':
            home = ProviderShell(
              api: _api,
              profile: _profile!,
              onRefreshProfile: _refreshProfile,
              onLogout: _logout,
              onSessionExpired: _expireSession,
            );
            break;
          default:
            home = CustomerShell(
              api: _api,
              profile: _profile!,
              onRefreshProfile: _refreshProfile,
              onLogout: _logout,
              onSessionExpired: _expireSession,
            );
        }
    }

    return MaterialApp(
      key: ValueKey<String>(
        _initializing
            ? 'bootstrap'
            : (_profile == null ? 'guest' : 'user-${_profile!.role}'),
      ),
      title: 'ServiceApp Mobile',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: home,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFF0D7C66),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x220D7C66),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.home_repair_service_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'ServiceApp',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Trusted help at your doorstep',
              style: TextStyle(
                color: Color(0xFF5A6B63),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
