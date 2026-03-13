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
    const background = Color(0xFFF4F7FD);
    const surface = Color(0xFFFFFFFF);
    const primary = Color(0xFF0E4BA8);
    const onPrimary = Colors.white;
    const secondary = Color(0xFF0E8A78);
    const onSecondary = Colors.white;
    const textPrimary = Color(0xFF14203A);

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
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: textPrimary,
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
          color: Color(0xFF2A3C63),
        ),
        bodyMedium: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFF44557A),
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
        backgroundColor: const Color(0xFFFCFDFF),
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        indicatorColor: const Color(0xFFE1EBFF),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : const Color(0xFF5E7094),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? primary : const Color(0xFF5E7094),
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
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD8E2F4)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          side: const BorderSide(color: Color(0xFFB6C5E3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD7EE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD7EE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF3E4F72),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: Color(0xFF6E7D9B)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF5F8FF),
        selectedColor: const Color(0xFFE7EEFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFD0DBF2)),
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF22365D),
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
        backgroundColor: const Color(0xFF172A50),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
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
