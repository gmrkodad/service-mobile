import 'package:flutter/material.dart';

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
              Color(0xFFF5F8FF),
              Color(0xFFEAF0FF),
              Color(0xFFDDE8FF),
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -90,
              right: -60,
              child: _bgBlob(
                size: 240,
                color: const Color(0xFF2F68FF).withValues(alpha: 0.15),
              ),
            ),
            Positioned(
              left: -90,
              bottom: -110,
              child: _bgBlob(
                size: 280,
                color: const Color(0xFF17C4A2).withValues(alpha: 0.14),
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: _buildHero(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFCFD9F2)),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x19000000),
                                  blurRadius: 14,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            labelColor: const Color(0xFF0D2352),
                            unselectedLabelColor: const Color(0xFF4A5D86),
                            tabs: const <Widget>[
                              Tab(text: 'Login'),
                              Tab(text: 'Sign Up'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: KeyedSubtree(
                            key: ValueKey<int>(_activeTabIndex),
                            child: _activeTabIndex == 0
                                ? _buildLoginTab()
                                : _buildSignupTab(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'ServiceApp',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF122447),
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Book trusted home experts in minutes.',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF3E4F72),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const <Widget>[
            _BenefitPill(
              icon: Icons.verified_user_outlined,
              label: 'Verified pros',
            ),
            _BenefitPill(icon: Icons.bolt_rounded, label: 'Fast booking'),
            _BenefitPill(
              icon: Icons.payments_outlined,
              label: 'Transparent pricing',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _authCard(
            title: 'Password Login',
            subtitle: 'Use your account credentials to continue.',
            icon: Icons.lock_open_rounded,
            accent: const Color(0xFF1C63FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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
              ],
            ),
          ),
          const SizedBox(height: 14),
          _authCard(
            title: 'OTP Login',
            subtitle: 'Get one-time code on your mobile number.',
            icon: Icons.sms_outlined,
            accent: const Color(0xFF0F9D88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _authCard(
            title: 'Create Account',
            subtitle: 'Join as a customer or provider (test mode: no OTP).',
            icon: Icons.person_add_alt_1_rounded,
            accent: const Color(0xFF5B3DF5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(value: false, label: Text('Customer')),
                    ButtonSegment<bool>(value: true, label: Text('Provider')),
                  ],
                  selected: <bool>{_registerAsProvider},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _registerAsProvider = selection.first;
                    });
                    _maybeLoadProviderServices();
                  },
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 12),
                if (_registerAsProvider) ...<Widget>[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _providerCityController,
                    enabled: !_signupBusy,
                    decoration: _inputDecoration(
                      label: 'City',
                      hint: 'Where do you provide services?',
                      icon: Icons.location_city_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Select Services',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D2D50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (services.isEmpty)
                    const Text('No services loaded yet')
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
                          selectedColor: const Color(0xFFE5EDFF),
                          label: Text('$categoryName - ${service.name}'),
                          side: BorderSide(
                            color: selected
                                ? const Color(0xFF5B3DF5)
                                : const Color(0xFFD2DAF0),
                          ),
                          onSelected: _signupBusy
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value) {
                                      _selectedServiceIds.add(service.id);
                                    } else {
                                      _selectedServiceIds.remove(service.id);
                                    }
                                  });
                                },
                        );
                      }).toList(),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _signupBusy ? null : _submitSignup,
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: Text(
                    _registerAsProvider
                        ? 'Create Provider Account'
                        : 'Create Customer Account',
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: const Color(0xFFD4DDF2)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A15294C),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.14),
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
                          color: Color(0xFF122447),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF4E5F86),
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
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD0DBF2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: const Color(0xFF3659A8)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2C426B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
