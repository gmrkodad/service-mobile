import 'package:flutter/material.dart';

import 'api.dart';
import 'models.dart';
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
  bool _initializing = true;
  UserProfile? _profile;

  ThemeData _buildTheme() {
    const background = Color(0xFFF5F4EE);
    const surface = Color(0xFFFFFCF7);
    const primary = Color(0xFF123B6D);
    const onPrimary = Colors.white;
    const secondary = Color(0xFFC86A3B);
    const onSecondary = Colors.white;
    const textPrimary = Color(0xFF1E2430);

    const colorScheme = ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: surface,
      onSurface: textPrimary,
      error: Color(0xFFB42318),
      onError: Colors.white,
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
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.8,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
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
          fontWeight: FontWeight.w500,
          color: Color(0xFF404754),
        ),
        bodyMedium: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFF6E6A63),
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
        backgroundColor: const Color(0xFFFFFCF7),
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        indicatorColor: const Color(0xFFE8F0FB),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : const Color(0xFF817B72),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primary : const Color(0xFF817B72),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: const EdgeInsets.all(0),
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x14071933),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE0D5C4)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          backgroundColor: primary,
          foregroundColor: onPrimary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 54),
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          side: const BorderSide(color: Color(0xFFD3C4B1)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFF8EE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE0D5C4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE0D5C4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF5F5B54),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: Color(0xFF948E84)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF6EFE4),
        selectedColor: const Color(0xFFDDEBFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE0D5C4)),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF39404C),
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E2430),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final session = await TokenStore.read();
    if (session == null) {
      setState(() {
        _initializing = false;
        _profile = null;
      });
      return;
    }

    try {
      final profile = await _api.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _initializing = false;
      });
    } catch (_) {
      await _api.logout();
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
    }
  }

  Future<void> _logout() async {
    await _api.logout();
    if (!mounted) return;
    setState(() {
      _profile = null;
    });
  }

  void _expireSession() {
    _api.logout();
    setState(() {
      _profile = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session expired. Please login again.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    Widget home;
    if (_profile == null) {
      home = AuthPage(api: _api, onAuthenticated: _authenticated);
    } else {
      switch (_profile!.role) {
        case 'ADMIN':
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
      title: 'ServiceApp Mobile',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: home,
    );
  }
}
