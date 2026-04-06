import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../api.dart';
import '../models.dart';
import 'common.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.api, required this.onAuthenticated});

  final ApiService api;
  final Future<void> Function() onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _activeTabIndex = 0;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpPhoneController = TextEditingController();
  final _otpCodeController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _otpPhoneFocusNode = FocusNode();
  final _otpCodeFocusNode = FocusNode();

  final _fullNameController = TextEditingController();
  final _registerUsernameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _providerCityController = TextEditingController();

  bool _busy = false;
  bool _signupBusy = false;
  bool _providerLocating = false;
  bool _registerAsProvider = false;
  bool _providerServicesLoaded = false;

  List<(String, ServiceItem)> _providerSignupServices =
      <(String, ServiceItem)>[];
  final Set<int> _selectedServiceIds = <int>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _otpPhoneController.dispose();
    _otpCodeController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _otpPhoneFocusNode.dispose();
    _otpCodeFocusNode.dispose();
    _fullNameController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _providerCityController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_activeTabIndex == _tabController.index || !mounted) {
      return;
    }
    setState(() {
      _activeTabIndex = _tabController.index;
    });
    _maybeLoadProviderServices();
  }

  void _maybeLoadProviderServices() {
    if (_providerServicesLoaded ||
        _activeTabIndex != 1 ||
        !_registerAsProvider) {
      return;
    }
    _providerServicesLoaded = true;
    _loadPublicServices();
  }

  Future<void> _loadPublicServices() async {
    try {
      final categories = await widget.api.fetchCategories(auth: false);
      if (!mounted) return;
      setState(() {
        _providerSignupServices = categories
            .expand(
              (category) =>
                  category.services.map((svc) => (category.name, svc)),
            )
            .toList(growable: false);
      });
    } catch (_) {
      // Keep signup usable; provider service selection may remain empty.
    }
  }

  Future<void> _loginWithPassword() async {
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      showApiError(
        context,
        const ApiException('Username and password are required'),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
    });
    try {
      await widget.api.loginPassword(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await widget.onAuthenticated();
    } catch (error) {
      if (!mounted) return;
      showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _sendLoginOtp() async {
    if (_otpPhoneController.text.trim().isEmpty) {
      showApiError(context, const ApiException('Enter mobile number'));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
    });
    try {
      await widget.api.sendLoginOtp(_otpPhoneController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent to mobile number')),
      );
    } catch (error) {
      if (!mounted) return;
      showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _verifyLoginOtp() async {
    if (_otpPhoneController.text.trim().isEmpty ||
        _otpCodeController.text.trim().isEmpty) {
      showApiError(context, const ApiException('Phone and OTP are required'));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
    });
    try {
      await widget.api.verifyLoginOtp(
        phone: _otpPhoneController.text.trim(),
        otp: _otpCodeController.text.trim(),
      );
      await widget.onAuthenticated();
    } catch (error) {
      if (!mounted) return;
      showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _submitSignup() async {
    if (_fullNameController.text.trim().isEmpty ||
        _registerUsernameController.text.trim().isEmpty ||
        _registerEmailController.text.trim().isEmpty ||
        _registerPasswordController.text.isEmpty) {
      showApiError(
        context,
        const ApiException('All signup fields are required'),
      );
      return;
    }

    if (_registerAsProvider) {
      if (_providerCityController.text.trim().isEmpty) {
        showApiError(
          context,
          const ApiException('City is required for provider signup'),
        );
        return;
      }
      if (_selectedServiceIds.isEmpty) {
        showApiError(
          context,
          const ApiException('Select at least one service'),
        );
        return;
      }
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _signupBusy = true;
    });
    try {
      if (_registerAsProvider) {
        await widget.api.signupProvider(
          fullName: _fullNameController.text.trim(),
          username: _registerUsernameController.text.trim(),
          email: _registerEmailController.text.trim(),
          password: _registerPasswordController.text,
          city: _providerCityController.text.trim(),
          services: _selectedServiceIds.toList(),
        );
      } else {
        await widget.api.signupCustomer(
          fullName: _fullNameController.text.trim(),
          username: _registerUsernameController.text.trim(),
          email: _registerEmailController.text.trim(),
          password: _registerPasswordController.text,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signup successful. Please login.')),
      );
      _tabController.animateTo(0);
    } catch (error) {
      if (!mounted) return;
      showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _signupBusy = false;
        });
      }
    }
  }

  String _normalizeCity(String raw) {
    final city = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (city.isEmpty) return '';
    if (city.length > 64) return '';
    return city;
  }

  Future<void> _useProviderCurrentLocation() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _providerLocating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const ApiException('Location services are turned off');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const ApiException('Location permission was denied');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const ApiException(
          'Location permission is permanently denied. Enable it in system settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = places.isEmpty ? null : places.first;
      final resolvedCity = _normalizeCity(
        place?.locality ??
            place?.subAdministrativeArea ??
            place?.administrativeArea ??
            '',
      );
      if (resolvedCity.isEmpty) {
        throw const ApiException('Could not determine provider city');
      }

      if (!mounted) return;
      setState(() {
        _providerCityController.text = resolvedCity;
      });
    } catch (error) {
      if (!mounted) return;
      showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _providerLocating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF7F2E8),
              Color(0xFFF3ECE0),
              Color(0xFFEAE4D8),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -140,
              right: -80,
              child: _bgBlob(
                size: 300,
                color: const Color(0xFFC86A3B).withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              left: -80,
              top: 110,
              child: _bgBlob(
                size: 220,
                color: const Color(0xFF123B6D).withValues(alpha: 0.11),
              ),
            ),
            Positioned(
              left: -80,
              bottom: -110,
              child: _bgBlob(
                size: 280,
                color: const Color(0xFF5B8EE8).withValues(alpha: 0.11),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    child: Column(
                      children: <Widget>[
                        _buildHero(),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: elevatedSurface(
                            color: Colors.white.withValues(alpha: 0.72),
                            radius: 24,
                            border: Colors.white.withValues(alpha: 0.7),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              color: const Color(0xFF16345C),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x220F172A),
                                  blurRadius: 18,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: const Color(0xFF605C55),
                            tabs: const <Widget>[
                              Tab(text: 'Login'),
                              Tab(text: 'Sign Up'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: KeyedSubtree(
                            key: ValueKey<int>(_activeTabIndex),
                            child: _activeTabIndex == 0
                                ? _buildLoginTab()
                                : _buildSignupTab(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: elevatedSurface(
        color: const Color(0xFF132A4A),
        radius: 34,
        border: const Color(0xFF1D4168),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.home_repair_service_rounded,
                  color: Color(0xFFFFD2A1),
                ),
                SizedBox(width: 8),
                Text(
                  'ServiceApp',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Book trusted help for home in a much calmer way.',
            style: TextStyle(
              fontSize: 30,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Clean booking flow, transparent pricing, and professionals who feel verified before you ever tap pay.',
            style: TextStyle(
              color: Color(0xFFD9E7FA),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              _BenefitPill(
                icon: Icons.workspace_premium_outlined,
                label: 'Verified specialists',
              ),
              _BenefitPill(icon: Icons.bolt_rounded, label: 'Fast booking'),
              _BenefitPill(
                icon: Icons.credit_score_outlined,
                label: 'Clear pricing',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: elevatedSurface(
              color: Colors.white.withValues(alpha: 0.08),
              radius: 28,
              border: Colors.white.withValues(alpha: 0.09),
            ),
            child: const Row(
              children: <Widget>[
                Expanded(
                  child: _HeroMetric(
                    value: '4.8',
                    label: 'Average provider rating',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _HeroMetric(
                    value: '2 min',
                    label: 'To place a booking',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginTab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _authCard(
            title: 'Welcome Back',
            subtitle:
                'Sign in with your password for the fastest way back into your bookings and account.',
            icon: Icons.login_rounded,
            accent: UiTone.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _sectionLabel('Password sign in'),
                TextField(
                  focusNode: _usernameFocusNode,
                  controller: _usernameController,
                  enabled: !_busy,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  decoration: _inputDecoration(
                    label: 'Username',
                    hint: 'Enter your username',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  focusNode: _passwordFocusNode,
                  controller: _passwordController,
                  enabled: !_busy,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_busy) {
                      _loginWithPassword();
                    }
                  },
                  decoration: _inputDecoration(
                    label: 'Password',
                    hint: 'Enter your password',
                    icon: Icons.key_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _loginWithPassword,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue'),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F1E7),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE5D8C5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Row(
                        children: <Widget>[
                          Icon(Icons.sms_outlined, color: UiTone.secondary),
                          SizedBox(width: 8),
                          Text(
                            'Quick OTP access',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Prefer a one-time code? Use your mobile number and sign in without remembering a password.',
                        style: TextStyle(color: UiTone.softText, height: 1.35),
                      ),
                      const SizedBox(height: 14),
                      _sectionLabel('OTP login'),
                      TextField(
                        focusNode: _otpPhoneFocusNode,
                        controller: _otpPhoneController,
                        enabled: !_busy,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _otpCodeFocusNode.requestFocus(),
                        decoration: _inputDecoration(
                          label: 'Mobile Number',
                          hint: '10-digit phone number',
                          icon: Icons.call_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _sendLoginOtp,
                        icon: const Icon(Icons.mark_email_read_outlined),
                        label: const Text('Send OTP'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        focusNode: _otpCodeFocusNode,
                        controller: _otpCodeController,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!_busy) {
                            _verifyLoginOtp();
                          }
                        },
                        decoration: _inputDecoration(
                          label: 'OTP Code',
                          hint: '6-digit OTP',
                          icon: Icons.password_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy ? null : _verifyLoginOtp,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Verify & Login'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildSignupTab() {
    final services = _providerSignupServices;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _authCard(
            title: 'Create Your Account',
            subtitle:
                'Join as a customer to book services or as a provider to start receiving requests.',
            icon: Icons.person_add_alt_1_rounded,
            accent: UiTone.secondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _sectionLabel('Choose your role'),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _signupRoleCard(
                        selected: !_registerAsProvider,
                        icon: Icons.person_outline,
                        title: 'Customer',
                        subtitle: 'Book home services',
                        onTap: () {
                          setState(() {
                            _registerAsProvider = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _signupRoleCard(
                        selected: _registerAsProvider,
                        icon: Icons.handyman_outlined,
                        title: 'Provider',
                        subtitle: 'Offer your services',
                        onTap: () {
                          setState(() {
                            _registerAsProvider = true;
                          });
                          _maybeLoadProviderServices();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _sectionLabel('Your details'),
                TextField(
                  controller: _fullNameController,
                  enabled: !_signupBusy,
                  decoration: _inputDecoration(
                    label: 'Full Name',
                    hint: 'Your full name',
                    icon: Icons.badge_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _registerUsernameController,
                  enabled: !_signupBusy,
                  decoration: _inputDecoration(
                    label: 'Username',
                    hint: 'Choose a username',
                    icon: Icons.alternate_email_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _registerEmailController,
                  enabled: !_signupBusy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(
                    label: 'Email',
                    hint: 'you@example.com',
                    icon: Icons.mail_outline_rounded,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _registerPasswordController,
                  enabled: !_signupBusy,
                  obscureText: true,
                  decoration: _inputDecoration(
                    label: 'Password',
                    hint: 'Create a strong password',
                    icon: Icons.key_outlined,
                  ),
                ),
                const SizedBox(height: 18),
                if (_registerAsProvider) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F1E7),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE5D8C5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Icon(
                              Icons.storefront_outlined,
                              color: UiTone.secondary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Provider setup',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tell customers where you work and what services you want to offer.',
                          style: TextStyle(
                            color: UiTone.softText,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionLabel('Service city'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: TextField(
                                controller: _providerCityController,
                                enabled: !_signupBusy,
                                decoration: _inputDecoration(
                                  label: 'City',
                                  hint: 'Where do you provide services?',
                                  icon: Icons.location_city_outlined,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _signupBusy || _providerLocating
                                    ? null
                                    : _useProviderCurrentLocation,
                                icon: _providerLocating
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.my_location_rounded),
                                label: const Text('Locate'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _sectionLabel('Select services'),
                        if (services.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE6D8C4),
                              ),
                            ),
                            child: const Text(
                              'Service catalog is still loading. You can keep filling the form and come back here in a moment.',
                              style: TextStyle(
                                color: UiTone.softText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: services.map((item) {
                              final categoryName = item.$1;
                              final service = item.$2;
                              final selected = _selectedServiceIds.contains(
                                service.id,
                              );
                              return FilterChip(
                                selected: selected,
                                selectedColor: const Color(0xFFF0E1D0),
                                label: Text('$categoryName - ${service.name}'),
                                side: BorderSide(
                                  color: selected
                                      ? UiTone.secondary
                                      : const Color(0xFFE0D5C4),
                                ),
                                onSelected: _signupBusy
                                    ? null
                                    : (value) {
                                        setState(() {
                                          if (value) {
                                            _selectedServiceIds.add(service.id);
                                          } else {
                                            _selectedServiceIds.remove(
                                              service.id,
                                            );
                                          }
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _signupBusy ? null : _submitSignup,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _registerAsProvider
                        ? 'Create provider account'
                        : 'Create customer account',
                  ),
                ),
              ],
            ),
          ),
          if (_signupBusy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: UiTone.primary,
        ),
      ),
    );
  }

  Widget _signupRoleCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: elevatedSurface(
          radius: 22,
          color: selected ? const Color(0xFFF0E1D0) : const Color(0xFFFFFBF6),
          border: selected ? UiTone.secondary : const Color(0xFFE6DAC8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: selected ? UiTone.secondary : UiTone.primary),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: UiTone.softText,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bgBlob({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _authCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      decoration: elevatedSurface(
        color: Colors.white.withValues(alpha: 0.92),
        radius: 30,
        border: const Color(0xFFE6DAC8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: UiTone.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: UiTone.softText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      prefixIconColor: const Color(0xFF7C756D),
    );
  }
}

class _BenefitPill extends StatelessWidget {
  const _BenefitPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: const Color(0xFFFFD2A1)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD9E7FA),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
