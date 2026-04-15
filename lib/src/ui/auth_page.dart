import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

enum _AuthStep { phone, otp, profile }

class _NormalizedDigitsFormatter extends TextInputFormatter {
  const _NormalizedDigitsFormatter({this.maxLength});

  final int? maxLength;

  static const List<int> _zeroRunes = <int>[
    0x0660, // Arabic-Indic
    0x06F0, // Extended Arabic-Indic
    0x0966, // Devanagari
    0x09E6, // Bengali
    0x0A66, // Gurmukhi
    0x0AE6, // Gujarati
    0x0B66, // Oriya
    0x0BE6, // Tamil
    0x0C66, // Telugu
    0x0CE6, // Kannada
    0x0D66, // Malayalam
    0x0E50, // Thai
    0x0ED0, // Lao
    0x1040, // Myanmar
    0x17E0, // Khmer
    0xFF10, // Full-width
  ];

  static int? _digitForRune(int rune) {
    if (rune >= 0x30 && rune <= 0x39) {
      return rune - 0x30;
    }
    for (final zeroRune in _zeroRunes) {
      if (rune >= zeroRune && rune < zeroRune + 10) {
        return rune - zeroRune;
      }
    }
    return null;
  }

  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final digit = _digitForRune(rune);
      if (digit != null) {
        buffer.writeCharCode(0x30 + digit);
      }
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var normalized = normalize(newValue.text);
    if (maxLength != null && normalized.length > maxLength!) {
      normalized = normalized.substring(0, maxLength);
    }
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
      composing: TextRange.empty,
    );
  }
}

class _AuthPageState extends State<AuthPage> {
  static const int _otpLength = 4;

  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController(text: kDefaultFallbackCity);
  final _serviceSearchController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List<TextEditingController>.generate(
        _otpLength,
        (_) => TextEditingController(),
      );
  final List<FocusNode> _otpFocusNodes = List<FocusNode>.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  bool _sendingOtp = false;
  bool _resendingOtp = false;
  bool _verifying = false;
  bool _loadingServices = false;
  bool _syncingOtpInputs = false;
  int _resendSecondsRemaining = 0;
  Timer? _resendTimer;
  _AuthStep _step = _AuthStep.phone;

  String _gender = 'MALE';
  String _role = 'CUSTOMER';
  List<(String, ServiceItem)> _providerServices = <(String, ServiceItem)>[];
  final Set<int> _selectedServiceIds = <int>{};
  int? _selectedProviderServiceToAdd;

  String get _otpCode => _otpControllers.map((c) => c.text.trim()).join();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_step == _AuthStep.phone) {
        _phoneFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _serviceSearchController.dispose();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() {
      _resendSecondsRemaining = 30;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _resendSecondsRemaining = 0;
        });
        return;
      }
      setState(() {
        _resendSecondsRemaining -= 1;
      });
    });
  }

  void _clearOtpInputs() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
    if (_otpFocusNodes.isNotEmpty) {
      _otpFocusNodes.first.requestFocus();
    }
  }

  void _onOtpChanged(int index, String value) {
    if (_syncingOtpInputs) return;
    final normalized = _NormalizedDigitsFormatter.normalize(value);
    _syncingOtpInputs = true;
    try {
      if (normalized.length > 1) {
        var cursor = index;
        for (var i = 0; i < normalized.length && cursor < _otpLength; i++) {
          _otpControllers[cursor].value = TextEditingValue(
            text: normalized[i],
            selection: const TextSelection.collapsed(offset: 1),
          );
          cursor += 1;
        }
        if (_otpCode.length < _otpLength && cursor < _otpLength) {
          _otpFocusNodes[cursor].requestFocus();
        }
      } else {
        if (normalized != value) {
          _otpControllers[index].value = TextEditingValue(
            text: normalized,
            selection: TextSelection.collapsed(offset: normalized.length),
          );
        }
        if (normalized.isNotEmpty && index < _otpLength - 1) {
          _otpFocusNodes[index + 1].requestFocus();
        } else if (normalized.isEmpty && index > 0) {
          _otpFocusNodes[index - 1].requestFocus();
        }
      }
    } finally {
      _syncingOtpInputs = false;
    }

    if (_otpCode.length == _otpLength && !_verifying) {
      FocusScope.of(context).unfocus();
      unawaited(_verifyOtp());
    }
  }

  Future<void> _loadProviderServices() async {
    if (_providerServices.isNotEmpty || _loadingServices) return;
    setState(() {
      _loadingServices = true;
    });
    try {
      final categories = await widget.api.fetchCategories(auth: false);
      if (!mounted) return;
      setState(() {
        _providerServices = categories
            .expand(
              (category) =>
                  category.services.map((service) => (category.name, service)),
            )
            .toList(growable: false);
        final available = _providerServices
            .where((row) => !_selectedServiceIds.contains(row.$2.id))
            .toList(growable: false);
        _selectedProviderServiceToAdd = available.isEmpty
            ? null
            : available.first.$2.id;
      });
    } catch (_) {
      // Keep flow usable; user can retry by toggling role.
    } finally {
      if (mounted) {
        setState(() {
          _loadingServices = false;
        });
      }
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      showApiError(context, const ApiException('Phone number is required'));
      return;
    }
    setState(() {
      _sendingOtp = true;
    });
    try {
      await widget.api.sendLoginOtp(phone);
      if (!mounted) return;
      setState(() {
        _step = _AuthStep.otp;
      });
      _clearOtpInputs();
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent. Use 1234 for now.')),
      );
    } catch (error) {
      if (!mounted) return;
      showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _sendingOtp = false;
        });
      }
    }
  }

  void _changePhoneNumber() {
    _resendTimer?.cancel();
    _clearOtpInputs();
    setState(() {
      _step = _AuthStep.phone;
      _resendSecondsRemaining = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _phoneFocusNode.requestFocus();
    });
  }

  Future<void> _resendOtp() async {
    if (_resendSecondsRemaining > 0 || _resendingOtp) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      showApiError(context, const ApiException('Phone number is required'));
      return;
    }
    setState(() {
      _resendingOtp = true;
    });
    try {
      await widget.api.sendLoginOtp(phone);
      if (!mounted) return;
      _clearOtpInputs();
      _startResendCountdown();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OTP resent')));
    } catch (error) {
      if (!mounted) return;
      showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _resendingOtp = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpCode;
    if (phone.isEmpty || otp.length != _otpLength) {
      showApiError(context, const ApiException('Enter phone and 4-digit OTP'));
      return;
    }

    setState(() {
      _verifying = true;
    });
    try {
      final result = await widget.api.verifyLoginOtp(phone: phone, otp: otp);
      if (!mounted) return;
      if (result.requiresProfile) {
        setState(() {
          _step = _AuthStep.profile;
        });
        await _loadProviderServices();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New user detected. Fill your basic details.'),
          ),
        );
        return;
      }
      await widget.onAuthenticated();
    } catch (error) {
      if (!mounted) return;
      showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _verifying = false;
        });
      }
    }
  }

  Future<void> _submitProfile() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      showApiError(
        context,
        const ApiException('Name and email are required for new users'),
      );
      return;
    }
    if (_role == 'PROVIDER' && _selectedServiceIds.isEmpty) {
      showApiError(
        context,
        const ApiException('Please select at least one provider service'),
      );
      return;
    }

    setState(() {
      _verifying = true;
    });
    try {
      final result = await widget.api.verifyLoginOtp(
        phone: _phoneController.text.trim(),
        otp: _otpCode,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        gender: _gender,
        role: _role,
        city: _role == 'PROVIDER' ? _cityController.text.trim() : null,
        services: _role == 'PROVIDER' ? _selectedServiceIds.toList() : null,
      );
      if (!mounted) return;
      if (result.requiresProfile) {
        showApiError(
          context,
          const ApiException('Please complete required fields'),
        );
        return;
      }
      await widget.onAuthenticated();
    } catch (error) {
      if (!mounted) return;
      showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _verifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedServiceQuery = _serviceSearchController.text
        .trim()
        .toLowerCase();
    final availableProviderServices = _providerServices
        .where((row) => !_selectedServiceIds.contains(row.$2.id))
        .where((row) {
          if (normalizedServiceQuery.isEmpty) return true;
          final label = '${row.$1} ${row.$2.name}'.toLowerCase();
          return label.contains(normalizedServiceQuery);
        })
        .toList(growable: false);
    final selectedProviderServiceValue =
        availableProviderServices.any(
          (row) => row.$2.id == _selectedProviderServiceToAdd,
        )
        ? _selectedProviderServiceToAdd
        : (availableProviderServices.isEmpty
              ? null
              : availableProviderServices.first.$2.id);

    String serviceLabelById(int id) {
      final match = _providerServices.where((row) => row.$2.id == id).toList();
      if (match.isEmpty) return 'Service';
      return '${match.first.$1} • ${match.first.$2.name}';
    }

    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: elevatedSurface(radius: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'ServiceApp',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: UiTone.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Login with your phone number',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: UiTone.softText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_step == _AuthStep.phone) ...<Widget>[
                      TextField(
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        inputFormatters: <TextInputFormatter>[
                          const _NormalizedDigitsFormatter(maxLength: 10),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          hintText: 'Enter mobile number',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _sendingOtp ? null : _sendOtp,
                        child: Text(_sendingOtp ? 'Sending...' : 'Send OTP'),
                      ),
                    ],
                    if (_step == _AuthStep.otp) ...<Widget>[
                      const Text(
                        'Enter OTP',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: UiTone.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _phoneController.text.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: UiTone.softText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(_otpLength, (index) {
                          return Container(
                            width: 56,
                            height: 62,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            child: TextField(
                              controller: _otpControllers[index],
                              focusNode: _otpFocusNodes[index],
                              keyboardType: TextInputType.number,
                              textInputAction: index == _otpLength - 1
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              enableSuggestions: false,
                              autocorrect: false,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                              inputFormatters: <TextInputFormatter>[
                                const _NormalizedDigitsFormatter(maxLength: 4),
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onChanged: (value) => _onOtpChanged(index, value),
                              onSubmitted: (_) {
                                if (index < _otpLength - 1) {
                                  _otpFocusNodes[index + 1].requestFocus();
                                } else if (_otpCode.length == _otpLength &&
                                    !_verifying) {
                                  unawaited(_verifyOtp());
                                }
                              },
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Verifies automatically after entering 4 digits',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: UiTone.softText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _changePhoneNumber,
                        child: const Text(
                          'Change number',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Center(
                        child: _resendSecondsRemaining > 0
                            ? Text(
                                'Resend OTP in 00:${_resendSecondsRemaining.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: UiTone.softText,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : TextButton(
                                onPressed: _resendingOtp ? null : _resendOtp,
                                child: Text(
                                  _resendingOtp ? 'Resending...' : 'Resend OTP',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      if (_verifying)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                    if (_step == _AuthStep.profile) ...<Widget>[
                      const Text(
                        'Complete Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: UiTone.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(
                          labelText: 'Account type',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'CUSTOMER',
                            child: Text('Customer'),
                          ),
                          DropdownMenuItem(
                            value: 'PROVIDER',
                            child: Text('Provider'),
                          ),
                        ],
                        onChanged: (value) async {
                          setState(() {
                            _role = value ?? 'CUSTOMER';
                            if (_role != 'PROVIDER') {
                              _selectedServiceIds.clear();
                              _serviceSearchController.clear();
                              _selectedProviderServiceToAdd = null;
                            }
                          });
                          if (_role == 'PROVIDER') {
                            await _loadProviderServices();
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          prefixIcon: Icon(Icons.wc_rounded),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(value: 'MALE', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'FEMALE',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(
                            value: 'OTHER',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _gender = value ?? 'MALE';
                          });
                        },
                      ),
                      if (_role == 'PROVIDER') ...<Widget>[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _cityController,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            prefixIcon: Icon(Icons.location_city_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Select services',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: UiTone.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingServices)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(),
                          )
                        else if (_providerServices.isEmpty)
                          const Text(
                            'No services available currently',
                            style: TextStyle(color: UiTone.softText),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              TextField(
                                controller: _serviceSearchController,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: 'Search service',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon:
                                      _serviceSearchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: () {
                                            _serviceSearchController.clear();
                                            setState(() {});
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                key: ValueKey<String>(
                                  'provider-signup-service-${selectedProviderServiceValue ?? -1}-${availableProviderServices.length}',
                                ),
                                initialValue: selectedProviderServiceValue,
                                isExpanded: true,
                                items: availableProviderServices
                                    .map(
                                      (row) => DropdownMenuItem<int>(
                                        value: row.$2.id,
                                        child: Text(
                                          row.$2.name,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedProviderServiceToAdd = value;
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Service',
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed:
                                    availableProviderServices.isEmpty ||
                                        _selectedProviderServiceToAdd == null
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedServiceIds.add(
                                            _selectedProviderServiceToAdd!,
                                          );
                                          final remaining =
                                              availableProviderServices
                                                  .where(
                                                    (row) =>
                                                        row.$2.id !=
                                                        _selectedProviderServiceToAdd,
                                                  )
                                                  .toList(growable: false);
                                          _selectedProviderServiceToAdd =
                                              remaining.isEmpty
                                              ? null
                                              : remaining.first.$2.id;
                                        });
                                      },
                                child: const Text('Add service'),
                              ),
                              if (_selectedServiceIds.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedServiceIds
                                      .map((id) {
                                        return InputChip(
                                          label: Text(serviceLabelById(id)),
                                          onDeleted: () {
                                            setState(() {
                                              _selectedServiceIds.remove(id);
                                            });
                                          },
                                        );
                                      })
                                      .toList(growable: false),
                                ),
                              ],
                            ],
                          ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _verifying ? null : _submitProfile,
                        child: Text(_verifying ? 'Submitting...' : 'Continue'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
