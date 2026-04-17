// ignore_for_file: unused_element, unused_field

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../api.dart';
import '../models.dart';
import '../session.dart';
import 'common.dart';

class _CustomerCartDraft {
  const _CustomerCartDraft({
    required this.service,
    required this.availableServices,
    required this.selectedServiceIds,
    this.preferredProviderId,
  });

  final ServiceItem service;
  final List<ServiceItem> availableServices;
  final List<int> selectedServiceIds;
  final int? preferredProviderId;
}

_CustomerCartDraft? _customerCartDraft;
VoidCallback? _customerGoHomeFromCart;

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    super.key,
    required this.api,
    required this.profile,
    required this.onRefreshProfile,
    required this.onLogout,
    required this.onSessionExpired,
  });

  final ApiService api;
  final UserProfile profile;
  final Future<void> Function() onRefreshProfile;
  final Future<void> Function() onLogout;
  final VoidCallback onSessionExpired;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _customerGoHomeFromCart = _openHomeTab;
  }

  @override
  void dispose() {
    if (_customerGoHomeFromCart == _openHomeTab) {
      _customerGoHomeFromCart = null;
    }
    super.dispose();
  }

  void _openBookingsTab() {
    setState(() {
      _index = 2;
    });
  }

  void _openServicesTab() {
    setState(() {
      _index = 1;
    });
  }

  void _openHomeTab() {
    setState(() {
      _index = 0;
    });
  }

  Future<void> _openCartFromHome() async {
    final draft = _customerCartDraft;
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty. Add services first.'),
        ),
      );
      return;
    }
    final currentCity = (await TokenStore.readCity())?.trim() ?? '';
    if (!mounted) return;
    await Navigator.of(context).push(
      smoothPageRoute<void>(
        CreateBookingPage(
          api: widget.api,
          service: draft.service,
          availableServices: draft.availableServices,
          preferredProviderId: draft.preferredProviderId,
          initialServiceIds: draft.selectedServiceIds,
          currentCity: currentCity,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      CustomerHomeTab(
        api: widget.api,
        profile: widget.profile,
        onRefreshProfile: widget.onRefreshProfile,
        onLogout: widget.onLogout,
        onSessionExpired: widget.onSessionExpired,
        onOpenBookings: _openBookingsTab,
      ),
      CustomerServicesTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
      ),
      CustomerBookingsTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
        onBack: _openHomeTab,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: ColoredBox(
        color: UiTone.shellBackground,
        child: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey<int>(_index),
              child: tabs[_index],
            ),
          ),
        ),
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _openCartFromHome,
              backgroundColor: const Color(0xFF10B766),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.shopping_cart_checkout_rounded),
              label: Text(
                _customerCartDraft == null
                    ? 'Cart'
                    : 'Cart (${_customerCartDraft!.selectedServiceIds.length})',
              ),
            )
          : null,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0F1A2B23),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) {
              setState(() {
                _index = value;
              });
            },
            height: 64,
            destinations: const <Widget>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined, size: 24),
                selectedIcon: Icon(Icons.home_rounded, size: 24),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined, size: 23),
                selectedIcon: Icon(Icons.grid_view_rounded, size: 23),
                label: 'Services',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined, size: 22),
                selectedIcon: Icon(Icons.calendar_today_rounded, size: 22),
                label: 'Bookings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerServicesTab extends StatefulWidget {
  const CustomerServicesTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<CustomerServicesTab> createState() => _CustomerServicesTabState();
}

class _CustomerServicesTabState extends State<CustomerServicesTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String _city = kDefaultFallbackCity;
  List<ServiceCategory> _categories = <ServiceCategory>[];
  List<({ServiceCategory category, ServiceItem service})> _rows =
      <({ServiceCategory category, ServiceItem service})>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final savedCity = await TokenStore.readCity();
      final categories = await widget.api.fetchCategories();
      if (!mounted) return;
      _city = (savedCity ?? '').trim().isEmpty
          ? kDefaultFallbackCity
          : savedCity!.trim();
      setState(() {
        _categories = categories;
        _applyFilter();
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    final rows = <({ServiceCategory category, ServiceItem service})>[];
    for (final category in _categories) {
      for (final service in category.services) {
        if (q.isNotEmpty &&
            !category.name.toLowerCase().contains(q) &&
            !service.name.toLowerCase().contains(q)) {
          continue;
        }
        rows.add((category: category, service: service));
      }
    }
    setState(() {
      _rows = rows;
    });
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '\u20B9${value.toStringAsFixed(0)}';
    }
    return '\u20B9${value.toStringAsFixed(2)}';
  }

  Future<void> _openCategory(ServiceCategory category) async {
    await Navigator.of(context).push(
      smoothPageRoute<void>(
        CategoryDetailsPage(
          api: widget.api,
          category: category,
          currentCity: _city,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
  }

  Widget _serviceCard({
    required ServiceCategory category,
    required ServiceItem service,
  }) {
    final price = service.startsFrom ?? service.basePrice;
    return InkWell(
      onTap: () => _openCategory(category),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: elevatedSurface(radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: imageOrPlaceholder(
                service.imageUrl,
                width: double.infinity,
                height: 110,
                borderRadius: BorderRadius.zero,
                fallbackIcon: Icons.cleaning_services_outlined,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    service.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: UiTone.ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: UiTone.softText,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _formatPrice(price),
                    style: const TextStyle(
                      color: Color(0xFF0FA467),
                      fontWeight: FontWeight.w800,
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: UiSpace.screen,
        children: <Widget>[
          const SizedBox(height: 4),
          const Text(
            'All services',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Search and explore all services in your city',
            style: const TextStyle(
              color: UiTone.softText,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilter(),
                  decoration: InputDecoration(
                    hintText: 'Search services',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _applyFilter,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Icon(Icons.search_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(
                child: Text(
                  'No services found',
                  style: TextStyle(
                    color: UiTone.softText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rows.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 220,
              ),
              itemBuilder: (context, index) {
                final row = _rows[index];
                return _serviceCard(
                  category: row.category,
                  service: row.service,
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class CustomerHomeTab extends StatefulWidget {
  const CustomerHomeTab({
    super.key,
    required this.api,
    required this.profile,
    required this.onRefreshProfile,
    required this.onLogout,
    required this.onSessionExpired,
    required this.onOpenBookings,
  });

  final ApiService api;
  final UserProfile profile;
  final Future<void> Function() onRefreshProfile;
  final Future<void> Function() onLogout;
  final VoidCallback onSessionExpired;
  final VoidCallback onOpenBookings;

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();

  bool _loading = true;
  bool _locating = false;
  List<ServiceCategory> _categories = <ServiceCategory>[];
  String _searchQuery = '';
  List<ServiceCategory> _filteredCategories = <ServiceCategory>[];
  List<_HomeSpotlight> _spotlight = <_HomeSpotlight>[];
  int _unreadNotificationCount = 0;
  static const Color _homeBorder = Color(0xFFA9DCC1);

  bool _looksLikeHtml(String value) {
    final lower = value.toLowerCase();
    return lower.contains('<!doctype html') ||
        lower.contains('<html') ||
        lower.contains('</html>') ||
        lower.contains('<body') ||
        value.contains('<') ||
        value.contains('>');
  }

  String _normalizeCity(String raw) {
    final city = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (city.isEmpty) return '';
    if (_looksLikeHtml(city)) return '';
    if (city.length > 64) return '';
    return city;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCity();
    _loadCategories();
    _refreshUnreadNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCity() async {
    final savedCity = await TokenStore.readCity();
    final normalized = _normalizeCity(savedCity ?? '');
    final city = normalized.isEmpty ? kDefaultFallbackCity : normalized;
    if (savedCity == null || city != savedCity.trim()) {
      await TokenStore.saveCity(city);
    }
    if (!mounted) return;
    _cityController.text = city;
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
    });

    try {
      final categories = await widget.api.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _rebuildCollections();
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) {
        showApiError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshUnreadNotifications() async {
    try {
      final notifications = await widget.api.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = notifications.where((n) => !n.isRead).length;
      });
    } catch (_) {
      // Notification badge should fail silently to avoid blocking home screen.
    }
  }

  Future<void> _saveCity() async {
    final city = _normalizeCity(_cityController.text);
    if (city.isEmpty) {
      showApiError(context, const ApiException('Enter a valid city name'));
      return;
    }
    _cityController.text = city;
    await _saveCityValue(city);
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
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
        throw const ApiException('Could not determine your city from location');
      }

      _cityController.text = resolvedCity;
      await _saveCityValue(resolvedCity);
    } catch (error) {
      if (!mounted) return;
      _cityController.text = kDefaultFallbackCity;
      await _saveCityValue(kDefaultFallbackCity, showMessage: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Using default city: $kDefaultFallbackCity (location unavailable)',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _locating = false;
        });
      }
    }
  }

  Future<void> _saveCityValue(String city, {bool showMessage = true}) async {
    final normalizedCity = _normalizeCity(city);
    if (normalizedCity.isEmpty) {
      if (showMessage && mounted) {
        showApiError(context, const ApiException('Enter a valid city name'));
      }
      return;
    }

    try {
      await widget.api.saveCustomerCity(normalizedCity);
      if (!mounted) return;
      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('City saved')));
      }
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _openCategory(ServiceCategory category) async {
    await Navigator.of(context).push(
      smoothPageRoute<void>(
        CategoryDetailsPage(
          api: widget.api,
          category: category,
          currentCity: _normalizeCity(_cityController.text),
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
  }

  void _rebuildCollections([String? query]) {
    final normalizedQuery = (query ?? _searchController.text)
        .trim()
        .toLowerCase();
    _searchQuery = normalizedQuery;
    _filteredCategories = _categories
        .where((category) {
          if (category.name.toLowerCase().contains(normalizedQuery)) {
            return true;
          }
          return category.services.any(
            (svc) => svc.name.toLowerCase().contains(normalizedQuery),
          );
        })
        .toList(growable: false);
    _spotlight = _spotlightsFor(_filteredCategories);
  }

  List<_HomeSpotlight> _spotlightsFor(List<ServiceCategory> categories) {
    final spotlight = <_HomeSpotlight>[];
    for (final category in categories) {
      for (final service in category.services) {
        spotlight.add(_HomeSpotlight(category: category, service: service));
      }
    }
    spotlight.sort((a, b) {
      final aPrice = a.service.startsFrom ?? a.service.basePrice;
      final bPrice = b.service.startsFrom ?? b.service.basePrice;
      return aPrice.compareTo(bPrice);
    });
    return spotlight.take(10).toList();
  }

  double? _lowestPrice(ServiceCategory category) {
    final prices = category.services
        .map<double?>((service) {
          final startsFrom = service.startsFrom;
          if (startsFrom != null && startsFrom > 0) return startsFrom;
          return service.basePrice > 0 ? service.basePrice : null;
        })
        .whereType<double>()
        .toList();
    if (prices.isEmpty) return null;
    prices.sort();
    return prices.first;
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '\u20B9${value.toStringAsFixed(0)}';
    }
    return '\u20B9${value.toStringAsFixed(2)}';
  }

  List<({ServiceCategory category, ServiceItem service})> _allServices(
    List<ServiceCategory> categories,
  ) {
    final rows = <({ServiceCategory category, ServiceItem service})>[];
    for (final category in categories) {
      for (final service in category.services) {
        rows.add((category: category, service: service));
      }
    }
    return rows;
  }

  Widget _serviceGridCard({
    required ServiceCategory category,
    required ServiceItem service,
  }) {
    final salePrice = service.startsFrom != null && service.startsFrom! > 0
        ? service.startsFrom!
        : service.basePrice;
    final oldPrice = service.basePrice > salePrice ? service.basePrice : null;

    return InkWell(
      onTap: () => _openCategory(category),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _homeBorder, width: 1.2),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _buildImage(
                      service.imageUrl,
                      height: double.infinity,
                      width: double.infinity,
                      fallbackIcon: Icons.cleaning_services_outlined,
                      fit: BoxFit.contain,
                      padding: const EdgeInsets.all(14),
                      backgroundColor: const Color(0xFFF2F5F7),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: UiTone.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      service.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: Color(0xFF1A1F36),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        Text(
                          _formatPrice(salePrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: UiTone.primary,
                          ),
                        ),
                        if (oldPrice != null) ...<Widget>[
                          const SizedBox(width: 6),
                          Text(
                            _formatPrice(oldPrice),
                            style: const TextStyle(
                              color: Color(0xFFAEB5BC),
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(
    String url, {
    required double height,
    required double width,
    BorderRadius? borderRadius,
    IconData fallbackIcon = Icons.handyman_outlined,
    BoxFit fit = BoxFit.cover,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    Color backgroundColor = const Color(0xFFE9EEF4),
  }) {
    final cacheWidth = width.isFinite && width > 0 ? (width * 2).round() : null;
    final cacheHeight = height.isFinite && height > 0
        ? (height * 2).round()
        : null;
    final fallback = Container(
      height: height,
      width: width,
      color: backgroundColor,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: const Color(0xFF58738D)),
    );

    final image = url.isEmpty
        ? fallback
        : Container(
            height: height,
            width: width,
            color: backgroundColor,
            padding: padding,
            child: Image.network(
              url,
              fit: fit,
              cacheWidth: cacheWidth,
              cacheHeight: cacheHeight,
              filterQuality: FilterQuality.low,
              errorBuilder: (context, error, stackTrace) => fallback,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return fallback;
              },
            ),
          );
    if (borderRadius == null) {
      return image;
    }
    return ClipRRect(borderRadius: borderRadius, child: image);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildHeader() {
    final city = _normalizeCity(_cityController.text);
    final firstName = widget.profile.fullName.split(' ').first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0D7C66), Color(0xFF14A38B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x280D7C66),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${_greeting()},',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  firstName.isEmpty ? 'there' : firstName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                if (city.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openNotifications,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_unreadNotificationCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _unreadNotificationCount > 9
                              ? '9+'
                              : '$_unreadNotificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openProfile,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      smoothPageRoute<void>(
        NotificationsTab(
          api: widget.api,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
    await _refreshUnreadNotifications();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      smoothPageRoute<void>(
        AccountTab(
          api: widget.api,
          profile: widget.profile,
          onRefreshProfile: widget.onRefreshProfile,
          onLogout: widget.onLogout,
          onSessionExpired: widget.onSessionExpired,
          onOpenBookings: widget.onOpenBookings,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A1A2B23),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _rebuildCollections(value);
            });
          },
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search services...',
            hintStyle: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 14, right: 10),
              child: Icon(
                Icons.search_rounded,
                color: Color(0xFF0D7C66),
                size: 22,
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 44),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
            filled: false,
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBar() {
    final city = _normalizeCity(_cityController.text);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _showCitySheet(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _homeBorder, width: 1.2),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: UiTone.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.place_outlined,
                  color: UiTone.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Service location',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: UiTone.softText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      city.isEmpty ? 'Set your city' : city,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: city.isEmpty
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF1A1F36),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: UiTone.softText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(List<ServiceCategory> categories) {
    final city = _normalizeCity(_cityController.text);
    final firstCategory = categories.isNotEmpty ? categories.first : null;
    final firstService =
        firstCategory != null && firstCategory.services.isNotEmpty
        ? firstCategory.services.first
        : null;
    final promoPrice = firstService == null
        ? '₹99/hr*'
        : '${_formatPrice(firstService.startsFrom ?? firstService.basePrice)}/hr*';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF16A267), Color(0xFF0E784D)],
        ),
        border: Border.all(color: const Color(0xFF0B6D44), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: GestureDetector(
                          onTap: _showCitySheet,
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      city.isEmpty ? 'Set location' : city,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Service location',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFFDFF7EA),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: IconButton(
                          onPressed: _openNotifications,
                          icon: const Icon(
                            Icons.notifications_outlined,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: IconButton(
                          onPressed: _openProfile,
                          icon: const Icon(
                            Icons.account_circle_outlined,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _rebuildCollections(value);
                        });
                      },
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: "Search for 'Kitchen cleaning'",
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Color(0xFF99A1AA),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'InstaHelp',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try at $promoPrice →',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '*Valid for first 3 bookings',
                    style: TextStyle(
                      color: Color(0xFFDFF7EA),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
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

  void _showCitySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE0E4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Set your city',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'We\'ll show providers available in your area.',
                style: TextStyle(fontSize: 14, color: UiTone.softText),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Enter city name',
                  prefixIcon: const Icon(Icons.place_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5EBE8)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _locating
                          ? null
                          : () {
                              _useCurrentLocation();
                              Navigator.pop(sheetContext);
                            },
                      icon: _locating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Use current'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _saveCity();
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Save city'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bookLaterCard({
    required String title,
    required String offer,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _homeBorder, width: 1.2),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: Color(0xFF1A1F36),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: UiTone.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                offer,
                style: const TextStyle(
                  color: UiTone.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(icon, size: 30, color: UiTone.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partnerSlotCard(String duration, String price, String saveLabel) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _homeBorder, width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Next slot at 9:30 AM',
            style: TextStyle(fontSize: 11, color: UiTone.softText),
          ),
          const SizedBox(height: 8),
          Text(
            duration,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 0.95,
              color: Color(0xFF1A1F36),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            price,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F36),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            saveLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: UiTone.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategories(List<ServiceCategory> categories) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 128,
        ),
        itemBuilder: (context, index) {
          final category = categories[index];
          return InkWell(
            onTap: () => _openCategory(category),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _homeBorder, width: 1.2),
              ),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildImage(
                        category.imageUrl,
                        height: 68,
                        width: 76,
                        fallbackIcon: Icons.miscellaneous_services_outlined,
                        fit: BoxFit.contain,
                        padding: const EdgeInsets.all(6),
                        backgroundColor: const Color(0xFFF2F5F7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.2,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGreenBanner(List<ServiceCategory> categories) {
    final firstCategory = categories.isNotEmpty ? categories.first : null;
    final firstService =
        firstCategory != null && firstCategory.services.isNotEmpty
        ? firstCategory.services.first
        : null;
    final imageUrl = firstService?.imageUrl ?? firstCategory?.imageUrl ?? '';

    return InkWell(
      onTap: firstCategory == null ? null : () => _openCategory(firstCategory),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        height: 162,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF13B76A), Color(0xFF0D8A57)],
          ),
          border: Border.all(color: const Color(0xFF0B7D4D), width: 1.2),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'InstaHelp',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Try services from',
                      style: TextStyle(
                        color: Color(0xFFE7FFF2),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      firstService == null
                          ? '₹99/hr'
                          : _formatPrice(
                              firstService.startsFrom ?? firstService.basePrice,
                            ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '*Valid for first 3 bookings',
                      style: TextStyle(
                        color: Color(0xFFD2F8E4),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 130,
              height: 162,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                child: _buildImage(
                  imageUrl,
                  height: 162,
                  width: 130,
                  fallbackIcon: Icons.cleaning_services_outlined,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(List<ServiceCategory> categories) {
    final actions = categories.take(4).toList();
    if (actions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = actions[index];
          final price = _lowestPrice(category);
          return InkWell(
            onTap: () => _openCategory(category),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: category.imageUrl.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(category.imageUrl),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                      ),
                color: const Color(0xFFE0E4E8),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[
                      Color(0xE6111318),
                      Color(0x55111318),
                      Color(0x00111318),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (price != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'From ${_formatPrice(price)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: UiTone.primary,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${category.services.length} services',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpotlightStrip(List<_HomeSpotlight> spotlight) {
    if (spotlight.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: spotlight.length > 6 ? 6 : spotlight.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = spotlight[index];
          final price = item.service.startsFrom ?? item.service.basePrice;
          return InkWell(
            onTap: () => _openCategory(item.category),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _homeBorder, width: 1.2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: _buildImage(
                      item.service.imageUrl,
                      height: 110,
                      width: 160,
                      fallbackIcon: Icons.self_improvement_outlined,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: UiTone.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.service.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: Color(0xFF1A1F36),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatPrice(price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: UiTone.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(ServiceCategory category) {
    final description = category.description.trim().isEmpty
        ? '${category.services.length} services available'
        : category.description.trim();
    final price = _lowestPrice(category);

    return InkWell(
      onTap: () => _openCategory(category),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _homeBorder, width: 1.2),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: _buildImage(
                    category.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fallbackIcon: Icons.cleaning_services_outlined,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 80,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: <Color>[Color(0xCC000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 14,
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: UiTone.softText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          price == null
                              ? '${category.services.length} services'
                              : 'From ${_formatPrice(price)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: UiTone.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Color(0xFF3D4A5C),
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCategories;
    final services = _allServices(filtered);

    if (_loading) {
      return loadingView();
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      color: UiTone.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(child: _buildHeroBanner(filtered)),

          // Categories section
          if (filtered.isNotEmpty) ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'Explore all services',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1F36),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildTopCategories(filtered)),
          ],

          // Services grid section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Popular services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${services.length} services available',
                    style: const TextStyle(
                      color: UiTone.softText,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (services.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: emptyView('No services found.'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final row = services[index];
                  return _serviceGridCard(
                    category: row.category,
                    service: row.service,
                  );
                }, childCount: services.length),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.78,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeSpotlight {
  const _HomeSpotlight({required this.category, required this.service});

  final ServiceCategory category;
  final ServiceItem service;
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// Hides booking OTP codes behind a tap-to-reveal interaction to prevent
/// shoulder-surfing and accidental exposure in screenshots.
class _OtpRevealRow extends StatefulWidget {
  const _OtpRevealRow({required this.startOtp, required this.endOtp});

  final String startOtp;
  final String endOtp;

  @override
  State<_OtpRevealRow> createState() => _OtpRevealRowState();
}

class _OtpRevealRowState extends State<_OtpRevealRow> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.startOtp.isEmpty && widget.endOtp.isEmpty) {
      return const Text(
        'OTP not available yet',
        style: TextStyle(color: Color(0xFF737B87), fontSize: 13),
      );
    }

    if (!_revealed) {
      return GestureDetector(
        onTap: () => setState(() => _revealed = true),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F5F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.visibility_outlined,
                size: 16,
                color: Color(0xFF0D7C66),
              ),
              SizedBox(width: 6),
              Text(
                'Tap to reveal OTPs',
                style: TextStyle(
                  color: Color(0xFF0D7C66),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Text(
      'Start: ${widget.startOtp.isEmpty ? '-' : widget.startOtp}  •  End: ${widget.endOtp.isEmpty ? '-' : widget.endOtp}',
      style: const TextStyle(
        color: Color(0xFF0D7C66),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class CategoryDetailsPage extends StatefulWidget {
  const CategoryDetailsPage({
    super.key,
    required this.api,
    required this.category,
    required this.currentCity,
    required this.onSessionExpired,
  });

  final ApiService api;
  final ServiceCategory category;
  final String currentCity;
  final VoidCallback onSessionExpired;

  @override
  State<CategoryDetailsPage> createState() => _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends State<CategoryDetailsPage> {
  ServiceItem? _selectedService;
  List<ProviderItem> _providers = <ProviderItem>[];
  bool _loadingProviders = false;

  @override
  void initState() {
    super.initState();
    _selectedService = widget.category.services.isNotEmpty
        ? widget.category.services.first
        : null;
  }

  Future<void> _openProviders(ServiceItem service) async {
    await Navigator.of(context).push(
      smoothPageRoute<void>(
        ServiceProvidersPage(
          api: widget.api,
          category: widget.category,
          service: service,
          currentCity: widget.currentCity,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
  }

  Future<void> _loadProviders(ServiceItem service) async {
    setState(() {
      _loadingProviders = true;
    });
    try {
      final providers = await widget.api.fetchProviders(
        serviceId: service.id,
        city: widget.currentCity.trim().isEmpty ? null : widget.currentCity,
      );
      if (!mounted) return;
      setState(() {
        _providers = providers;
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingProviders = false;
        });
      }
    }
  }

  Widget _benefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_outline,
              size: 16,
              color: Color(0xFF13B76A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: UiTone.ink,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _offerChip(String title, String subtitle) {
    return Container(
      width: 172,
      padding: const EdgeInsets.all(12),
      decoration: elevatedSurface(radius: 18, color: UiTone.surface),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sell_rounded, color: UiTone.success),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF676B73),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '\u20B9${value.toStringAsFixed(0)}';
    }
    return '\u20B9${value.toStringAsFixed(2)}';
  }

  String _serviceHeroFallback(ServiceItem service) {
    final text = '${widget.category.name} ${service.name}'.toLowerCase();
    if (text.contains('bathroom') || text.contains('toilet')) {
      return 'https://images.pexels.com/photos/6585759/pexels-photo-6585759.jpeg?auto=compress&cs=tinysrgb&w=1600';
    }
    if (text.contains('kitchen') || text.contains('utensil')) {
      return 'https://images.pexels.com/photos/5824519/pexels-photo-5824519.jpeg?auto=compress&cs=tinysrgb&w=1600';
    }
    if (text.contains('sofa') ||
        text.contains('carpet') ||
        text.contains('clean')) {
      return 'https://images.pexels.com/photos/4107129/pexels-photo-4107129.jpeg?auto=compress&cs=tinysrgb&w=1600';
    }
    if (text.contains('ac') ||
        text.contains('repair') ||
        text.contains('electric')) {
      return 'https://images.pexels.com/photos/5691644/pexels-photo-5691644.jpeg?auto=compress&cs=tinysrgb&w=1600';
    }
    return 'https://images.pexels.com/photos/6197047/pexels-photo-6197047.jpeg?auto=compress&cs=tinysrgb&w=1600';
  }

  Widget _buildServiceHeroImage(ServiceItem service) {
    final primary = service.imageUrl.trim();
    final fallback = _serviceHeroFallback(service);
    return Image.network(
      primary.isNotEmpty ? primary : fallback,
      width: double.infinity,
      height: 290,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) => Image.network(
        fallback,
        width: double.infinity,
        height: 290,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (context, error, stackTrace) => Container(
          width: double.infinity,
          height: 290,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Color(0xFFB9E4D6), Color(0xFF9ECFBF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _providerCard(ProviderItem provider, ServiceItem service) {
    final price = provider.price ?? service.startsFrom ?? service.basePrice;
    final providerName = provider.fullName.isEmpty
        ? provider.username
        : provider.fullName;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: elevatedSurface(
        radius: 20,
        color: Colors.white,
        border: const Color(0xFFC2CED8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF109B63),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        providerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: UiTone.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Experienced home service professional',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: UiTone.softText,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _providerMeta(
                            Icons.star_rounded,
                            '${provider.rating.toStringAsFixed(1)} rated',
                          ),
                          _providerMeta(
                            Icons.location_on_outlined,
                            provider.city.isEmpty ? 'Nearby' : provider.city,
                          ),
                          _providerMeta(Icons.schedule_outlined, 'Fast slots'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Starts at',
                        style: TextStyle(
                          color: UiTone.softText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPrice(price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      smoothPageRoute<void>(
                        CreateBookingPage(
                          api: widget.api,
                          service: service,
                          availableServices: widget.category.services,
                          preferredProviderId: provider.id,
                          currentCity: widget.currentCity,
                          onSessionExpired: widget.onSessionExpired,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF12B46B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(128, 42),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerMeta(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: UiTone.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: UiTone.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: UiTone.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceChoiceChip(ServiceItem service, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedService = service;
        });
        _loadProviders(service);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF10B981) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF10B981) : const Color(0xFFC6D0DA),
          ),
        ),
        child: Text(
          service.name,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF2E3135),
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.category.services.isEmpty) {
      return Scaffold(
        backgroundColor: UiTone.shellBackground,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(widget.category.name),
        ),
        body: emptyView('No services available in this category yet'),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.category.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: elevatedSurface(radius: 16),
            child: Text(
              widget.category.description.trim().isEmpty
                  ? 'Choose a service to see available professionals and their other offerings.'
                  : widget.category.description.trim(),
              style: const TextStyle(
                color: UiTone.softText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...widget.category.services.map((service) {
            final price = service.startsFrom ?? service.basePrice;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: elevatedSurface(radius: 18, color: Colors.white),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        imageOrPlaceholder(
                          service.imageUrl,
                          width: 88,
                          height: 88,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(14),
                          ),
                          fallbackIcon: Icons.cleaning_services_outlined,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                service.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: UiTone.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                service.description.trim().isEmpty
                                    ? 'Professional doorstep service with verified partners.'
                                    : service.description.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: UiTone.softText,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatPrice(price),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: UiTone.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _openProviders(service),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('View Providers'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ServiceProvidersPage extends StatefulWidget {
  const ServiceProvidersPage({
    super.key,
    required this.api,
    required this.category,
    required this.service,
    required this.currentCity,
    required this.onSessionExpired,
  });

  final ApiService api;
  final ServiceCategory category;
  final ServiceItem service;
  final String currentCity;
  final VoidCallback onSessionExpired;

  @override
  State<ServiceProvidersPage> createState() => _ServiceProvidersPageState();
}

class _ServiceProvidersPageState extends State<ServiceProvidersPage> {
  final Map<int, List<ServiceItem>> _providerServices =
      <int, List<ServiceItem>>{};
  final Set<int> _loadingProviderServiceIds = <int>{};
  final Set<int> _selectedServiceIds = <int>{};
  List<ProviderItem> _providers = <ProviderItem>[];
  bool _loadingProviders = false;
  int? _selectedProviderId;

  @override
  void initState() {
    super.initState();
    _selectedServiceIds.add(widget.service.id);
    _loadProviders();
  }

  void _syncCartDraft() {
    final providerId = _selectedProviderId;
    final providerCatalog = providerId == null
        ? widget.category.services
        : (_providerServices[providerId] ?? widget.category.services);
    _customerCartDraft = _CustomerCartDraft(
      service: widget.service,
      availableServices: providerCatalog,
      selectedServiceIds: _selectedServiceIds.toList(growable: false),
      preferredProviderId: providerId,
    );
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '\u20B9${value.toStringAsFixed(0)}';
    }
    return '\u20B9${value.toStringAsFixed(2)}';
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loadingProviders = true;
    });
    try {
      final providers = await widget.api.fetchProviders(
        serviceId: widget.service.id,
        city: widget.currentCity.trim().isEmpty ? null : widget.currentCity,
      );
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _selectedProviderId = providers.isEmpty ? null : providers.first.id;
      });
      if (_selectedProviderId != null) {
        await _ensureProviderServicesLoaded(_selectedProviderId!);
      }
      _syncCartDraft();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingProviders = false;
        });
      }
    }
  }

  Future<void> _ensureProviderServicesLoaded(int providerId) async {
    if (_providerServices.containsKey(providerId) ||
        _loadingProviderServiceIds.contains(providerId)) {
      return;
    }
    setState(() {
      _loadingProviderServiceIds.add(providerId);
    });
    try {
      final services = await widget.api.fetchProviderServicesForBooking(
        providerId,
      );
      if (!mounted) return;
      setState(() {
        _providerServices[providerId] = services;
      });
      _syncCartDraft();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingProviderServiceIds.remove(providerId);
        });
      }
    }
  }

  Future<void> _selectProvider(int providerId) async {
    setState(() {
      _selectedProviderId = providerId;
      _selectedServiceIds
        ..clear()
        ..add(widget.service.id);
    });
    _syncCartDraft();
    await _ensureProviderServicesLoaded(providerId);
    _syncCartDraft();
  }

  Future<void> _openCart() async {
    final providerId = _selectedProviderId;
    if (providerId == null) {
      showApiError(context, const ApiException('Please select a provider'));
      return;
    }
    final providerCatalog =
        _providerServices[providerId] ?? widget.category.services;
    _syncCartDraft();
    await Navigator.of(context).push(
      smoothPageRoute<void>(
        CreateBookingPage(
          api: widget.api,
          service: widget.service,
          availableServices: providerCatalog,
          preferredProviderId: providerId,
          initialServiceIds: _selectedServiceIds.toList(),
          currentCity: widget.currentCity,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
  }

  Widget _providerTile(ProviderItem provider) {
    final selected = provider.id == _selectedProviderId;
    final providerName = provider.fullName.isEmpty
        ? provider.username
        : provider.fullName;
    final price =
        provider.price ?? widget.service.startsFrom ?? widget.service.basePrice;
    return InkWell(
      onTap: () => _selectProvider(provider.id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF9F1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF10B981) : const Color(0xFFC6D0DA),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            iconBox(
              Icons.person_rounded,
              background: const Color(0xFFDDF5E8),
              foreground: const Color(0xFF119962),
              size: 44,
              iconSize: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    providerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: UiTone.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${provider.rating.toStringAsFixed(1)}★ • ${provider.city.isEmpty ? 'Nearby' : provider.city}',
                    style: const TextStyle(
                      color: UiTone.softText,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatPrice(price),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addonCard(ServiceItem service) {
    final isPrimary = service.id == widget.service.id;
    final selected = _selectedServiceIds.contains(service.id);
    final price = service.startsFrom ?? service.basePrice;
    return Container(
      width: 154,
      margin: const EdgeInsets.only(right: 10, bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: elevatedSurface(radius: 14, color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          imageOrPlaceholder(
            service.imageUrl,
            width: 134,
            height: 82,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            fallbackIcon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: 8),
          Text(
            service.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            _formatPrice(price),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: UiTone.ink,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isPrimary
                  ? null
                  : () {
                      setState(() {
                        if (selected) {
                          _selectedServiceIds.remove(service.id);
                        } else {
                          _selectedServiceIds.add(service.id);
                        }
                      });
                      _syncCartDraft();
                    },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(34),
                backgroundColor: selected || isPrimary
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEAF9F1),
                foregroundColor: selected || isPrimary
                    ? Colors.white
                    : const Color(0xFF0D7C66),
                elevation: 0,
              ),
              child: Text(isPrimary ? 'Primary' : (selected ? 'Added' : 'Add')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedProviderId = _selectedProviderId;
    final hasProviders = _providers.isNotEmpty;
    final currentCity = widget.currentCity.trim().isEmpty
        ? 'your city'
        : widget.currentCity.trim().split(',').first.trim();
    ProviderItem? selectedProvider;
    for (final provider in _providers) {
      if (provider.id == selectedProviderId) {
        selectedProvider = provider;
        break;
      }
    }
    final selectedProviderServices = selectedProviderId == null
        ? <ServiceItem>[]
        : (_providerServices[selectedProviderId] ?? <ServiceItem>[]);
    final loadingSelectedProviderServices =
        selectedProviderId != null &&
        _loadingProviderServiceIds.contains(selectedProviderId);
    final providerName = selectedProvider == null
        ? ''
        : (selectedProvider.fullName.trim().isEmpty
              ? selectedProvider.username
              : selectedProvider.fullName);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(widget.service.name),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: FilledButton(
          onPressed: selectedProviderId == null ? null : _openCart,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: const Color(0xFF10B766),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            selectedProviderId == null
                ? 'Select a provider'
                : 'Continue to cart • ${_selectedServiceIds.length} services',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: elevatedSurface(radius: 16),
            child: Row(
              children: <Widget>[
                imageOrPlaceholder(
                  widget.service.imageUrl,
                  width: 70,
                  height: 70,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  fallbackIcon: Icons.cleaning_services_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.service.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.service.description.trim().isEmpty
                            ? 'Choose a provider and add more services from the same provider.'
                            : widget.service.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: UiTone.softText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: elevatedSurface(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Available providers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (_loadingProviders)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_providers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F7F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC8D8D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        iconBox(
                          Icons.location_city_rounded,
                          size: 42,
                          iconSize: 20,
                          background: const Color(0xFFE1F3EA),
                          foreground: const Color(0xFF129160),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'No providers found in your city',
                                style: TextStyle(
                                  color: UiTone.ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try changing city from Home location bar. Current city: $currentCity',
                                style: const TextStyle(
                                  color: UiTone.softText,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(children: _providers.map(_providerTile).toList()),
              ],
            ),
          ),
          if (hasProviders) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: elevatedSurface(radius: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    providerName.isEmpty
                        ? 'Other services by selected provider'
                        : 'Other services by $providerName',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (selectedProviderId == null)
                    const Text(
                      'Select a provider to see their services.',
                      style: TextStyle(
                        color: UiTone.softText,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (loadingSelectedProviderServices)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (selectedProviderServices.isEmpty)
                    const Text(
                      'No extra services available from this provider.',
                      style: TextStyle(
                        color: UiTone.softText,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    SizedBox(
                      height: 214,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: selectedProviderServices
                            .map(_addonCard)
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CreateBookingPage extends StatefulWidget {
  const CreateBookingPage({
    super.key,
    required this.api,
    required this.service,
    required this.availableServices,
    this.preferredProviderId,
    this.initialServiceIds,
    this.currentCity = '',
    required this.onSessionExpired,
  });

  final ApiService api;
  final ServiceItem service;
  final List<ServiceItem> availableServices;
  final int? preferredProviderId;
  final List<int>? initialServiceIds;
  final String currentCity;
  final VoidCallback onSessionExpired;

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  final _addressController = TextEditingController();
  final _locationController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _notesController = TextEditingController();

  bool _submitting = false;
  bool _detectingAddress = false;
  bool _loadingProviders = false;
  bool _providerLockedByPreviousStep = false;
  final Set<int> _selectedServiceIds = <int>{};
  final List<ServiceItem> _serviceCatalog = <ServiceItem>[];
  List<ProviderItem> _providers = <ProviderItem>[];
  int? _selectedProviderId;

  String _timeSlot = '09:00-11:00';
  DateTime _date = DateTime.now();
  final bool _avoidCalls = true;
  final bool _sendOffers = true;
  static const List<String> _timeSlots = <String>[
    '07:00-09:00',
    '09:00-11:00',
    '11:00-13:00',
    '14:00-16:00',
    '16:00-18:00',
    '18:00-20:00',
  ];

  String _normalizeCityQuery(String raw) {
    final compact = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) return '';
    final primary = compact.split(',').first.trim();
    return primary;
  }

  Future<String?> _resolveCityForProviderFilter() async {
    final fromWidget = _normalizeCityQuery(widget.currentCity);
    if (fromWidget.isNotEmpty) return fromWidget;

    final fromLocation = _normalizeCityQuery(_locationController.text);
    if (fromLocation.isNotEmpty) return fromLocation;

    final savedCity = _normalizeCityQuery((await TokenStore.readCity()) ?? '');
    if (savedCity.isNotEmpty) return savedCity;
    return null;
  }

  void _mergeServiceCatalog(Iterable<ServiceItem> services) {
    final byId = <int, ServiceItem>{
      for (final service in _serviceCatalog) service.id: service,
    };
    for (final service in services) {
      byId[service.id] = service;
    }
    _serviceCatalog
      ..clear()
      ..addAll(byId.values);
  }

  void _syncCartDraft() {
    if (_selectedServiceIds.isEmpty) {
      _customerCartDraft = null;
      return;
    }
    _customerCartDraft = _CustomerCartDraft(
      service: widget.service,
      availableServices: List<ServiceItem>.from(_serviceCatalog),
      selectedServiceIds: _selectedServiceIds.toList(growable: false),
      preferredProviderId: _selectedProviderId,
    );
  }

  Future<void> _loadProviderServiceCatalog(int providerId) async {
    try {
      final providerServices = await widget.api.fetchProviderServicesForBooking(
        providerId,
      );
      if (!mounted) return;
      setState(() {
        _mergeServiceCatalog(providerServices);
      });
      _syncCartDraft();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  @override
  void initState() {
    super.initState();
    _mergeServiceCatalog(<ServiceItem>[
      widget.service,
      ...widget.availableServices,
    ]);
    _selectedServiceIds.add(widget.service.id);
    if (widget.initialServiceIds != null) {
      _selectedServiceIds.addAll(widget.initialServiceIds!);
    }
    _syncCartDraft();
    _loadProviders();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _locationController.dispose();
    _landmarkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loadingProviders = true;
    });
    try {
      final city = await _resolveCityForProviderFilter();
      final providers = await widget.api.fetchProviders(
        serviceId: widget.service.id,
        city: city,
      );
      if (!mounted) return;
      final preferredExists = providers.any(
        (p) => p.id == widget.preferredProviderId,
      );
      setState(() {
        _providers = providers;
        _providerLockedByPreviousStep = preferredExists;
        _selectedProviderId = preferredExists
            ? widget.preferredProviderId
            : (providers.isNotEmpty ? providers.first.id : null);
      });
      final providerId = _selectedProviderId;
      if (providerId != null) {
        await _loadProviderServiceCatalog(providerId);
      }
      _syncCartDraft();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _loadingProviders = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _submit() async {
    if (_addressController.text.trim().isEmpty) {
      showApiError(context, const ApiException('Address is required'));
      return;
    }
    final selectedServices = _selectedServices();
    if (selectedServices.isEmpty) {
      showApiError(context, const ApiException('Select at least one service'));
      return;
    }
    if (_selectedProviderId == null) {
      showApiError(context, const ApiException('Please select a provider'));
      return;
    }

    final lines = <String>[_addressController.text.trim()];
    if (_locationController.text.trim().isNotEmpty) {
      lines.add('Customer location: ${_locationController.text.trim()}');
    }
    if (_landmarkController.text.trim().isNotEmpty) {
      lines.add('Landmark: ${_landmarkController.text.trim()}');
    }
    if (_notesController.text.trim().isNotEmpty) {
      lines.add('Notes: ${_notesController.text.trim()}');
    }

    setState(() {
      _submitting = true;
    });
    try {
      final providerServices = await widget.api.fetchProviderServicesForBooking(
        _selectedProviderId!,
      );
      final providerServiceIds = providerServices.map((e) => e.id).toSet();
      final primaryService = selectedServices.first;
      final required = Set<int>.from(_selectedServiceIds)
        ..add(primaryService.id);
      if (!required.every(providerServiceIds.contains)) {
        throw const ApiException(
          'Selected provider does not support all services in cart',
        );
      }

      final bookingId = await widget.api.createBooking(
        service: primaryService.id,
        provider: _selectedProviderId,
        scheduledDate:
            '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
        timeSlot: _timeSlot,
        address: lines.join('\n'),
        serviceIds: _selectedServiceIds.toList(),
      );
      if (!mounted) return;
      _customerCartDraft = null;
      await Navigator.of(context).push(
        smoothPageRoute<void>(_BookingCreatedSuccessPage(bookingId: bookingId)),
      );
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _useCurrentAddress() async {
    setState(() {
      _detectingAddress = true;
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

      final addressParts = <String>[
        place?.name ?? '',
        place?.thoroughfare ?? '',
        place?.subLocality ?? '',
        place?.locality ?? '',
        place?.administrativeArea ?? '',
        place?.postalCode ?? '',
      ].where((value) => value.trim().isNotEmpty).toList();

      final address = addressParts.join(', ');
      final cityState = <String>[
        place?.locality ?? '',
        place?.administrativeArea ?? '',
      ].where((value) => value.trim().isNotEmpty).join(', ');
      final location = cityState.isNotEmpty
          ? cityState
          : (place?.locality ?? place?.administrativeArea ?? '').trim();
      final landmark = (place?.subLocality ?? place?.locality ?? '').trim();

      if (address.isEmpty) {
        throw const ApiException(
          'Could not resolve address from your location',
        );
      }

      _addressController.text = address;
      _locationController.text = location;
      if (landmark.isNotEmpty) {
        _landmarkController.text = landmark;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location added to booking')),
      );
    } catch (error) {
      if (!mounted) return;
      _locationController.text = '$kDefaultFallbackCity, Telangana';
      if (_addressController.text.trim().isEmpty) {
        _addressController.text = '$kDefaultFallbackCity, Telangana, India';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Using default location: $kDefaultFallbackCity (location unavailable)',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _detectingAddress = false;
        });
      }
    }
  }

  double _servicePrice(ServiceItem service) {
    return service.startsFrom ?? service.basePrice;
  }

  List<ServiceItem> _selectedServices() {
    return _serviceCatalog
        .where((service) => _selectedServiceIds.contains(service.id))
        .toList();
  }

  double _subtotal() {
    return _selectedServices().fold<double>(
      0,
      (sum, service) => sum + _servicePrice(service),
    );
  }

  double _taxesAndFees() {
    final subtotal = _subtotal();
    if (subtotal <= 0) return 0;
    return double.parse((subtotal * 0.033).toStringAsFixed(0));
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return '\u20B9${value.toStringAsFixed(0)}';
    }
    return '\u20B9${value.toStringAsFixed(2)}';
  }

  Widget _summaryRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: strong ? 16 : 14,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: strong ? 16 : 14,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _addonCard(ServiceItem service) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: elevatedSurface(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          imageOrPlaceholder(
            service.imageUrl,
            width: 112,
            height: 72,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            fallbackIcon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: 8),
          Text(
            service.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            _formatPrice(_servicePrice(service)),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () {
              setState(() {
                _selectedServiceIds.add(service.id);
              });
              _syncCartDraft();
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _summaryBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: const Color(0xFFA8E6CF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotChip(String slot) {
    final selected = _timeSlot == slot;
    return ChoiceChip(
      label: Text(slot),
      selected: selected,
      onSelected: (_) => setState(() => _timeSlot = slot),
      selectedColor: const Color(0xFFDBF5E8),
      backgroundColor: const Color(0xFFF3F5F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? const Color(0xFF10B981) : const Color(0xFFC6D0DA),
        ),
      ),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0E8B62) : const Color(0xFF4E5561),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _providerSelectionCard(ProviderItem provider, {bool enabled = true}) {
    final selected = _selectedProviderId == provider.id;
    final name = provider.fullName.isEmpty
        ? provider.username
        : provider.fullName;
    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              setState(() => _selectedProviderId = provider.id);
              _syncCartDraft();
              await _loadProviderServiceCatalog(provider.id);
            },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF9F1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF10B981) : const Color(0xFFC6D0DA),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            iconBox(
              Icons.person_rounded,
              background: const Color(0xFFDDF5E8),
              foreground: const Color(0xFF119962),
              size: 38,
              iconSize: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A2F34),
                    ),
                  ),
                  Text(
                    '${provider.rating.toStringAsFixed(1)}★ • ${provider.city.isEmpty ? 'Nearby' : provider.city}',
                    style: const TextStyle(
                      color: UiTone.softText,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle
                  : (enabled
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle_outline),
              color: selected
                  ? const Color(0xFF0FA467)
                  : const Color(0xFFB0B8C4),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedServices = _selectedServices();
    final subtotal = _subtotal();
    final fees = _taxesAndFees();
    final total = subtotal + fees;
    ProviderItem? selectedProvider;
    for (final provider in _providers) {
      if (provider.id == _selectedProviderId) {
        selectedProvider = provider;
        break;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F7),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('My Cart'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: const Color(0xFF10B766),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            _submitting ? 'Processing...' : 'Proceed • ${_formatPrice(total)}',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC2CED8), width: 1.2),
            ),
            child: const Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: UiTone.softText,
                ),
                SizedBox(width: 8),
                Text(
                  'Scheduled booking',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: UiTone.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: elevatedSurface(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text(
                      'Review booking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${selectedServices.length} ${selectedServices.length == 1 ? 'service' : 'services'}',
                      style: const TextStyle(
                        color: UiTone.softText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...selectedServices.map((service) {
                  final price = service.startsFrom ?? service.basePrice;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: <Widget>[
                        imageOrPlaceholder(
                          service.imageUrl,
                          width: 54,
                          height: 54,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                          fallbackIcon: Icons.cleaning_services_outlined,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                service.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _formatPrice(price),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final deletingPrimaryService =
                                service.id == widget.service.id;
                            final shouldCloseCart =
                                deletingPrimaryService ||
                                selectedServices.length <= 1;
                            setState(() {
                              if (shouldCloseCart) {
                                _selectedServiceIds.clear();
                              } else {
                                _selectedServiceIds.remove(service.id);
                              }
                            });
                            _syncCartDraft();
                            if (shouldCloseCart) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cart is empty. Returning to home.',
                                  ),
                                ),
                              );
                              _customerGoHomeFromCart?.call();
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                              return;
                            }
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: UiTone.softText,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                const Text(
                  'Missed something? Add more services.',
                  style: TextStyle(
                    color: Color(0xFF13B76A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final addable = _serviceCatalog
                        .where(
                          (service) =>
                              !_selectedServiceIds.contains(service.id),
                        )
                        .toList();
                    if (addable.isEmpty) {
                      return const Text(
                        'All available services are already added.',
                        style: TextStyle(
                          color: UiTone.softText,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }
                    return SizedBox(
                      height: 190,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: addable.map(_addonCard).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: elevatedSurface(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _providerLockedByPreviousStep
                      ? 'Assigned professional'
                      : 'Select professional',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (_loadingProviders)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_providerLockedByPreviousStep &&
                    selectedProvider != null)
                  _providerSelectionCard(selectedProvider, enabled: false)
                else
                  Column(
                    children: _providers.map(_providerSelectionCard).toList(),
                  ),
                if (!_loadingProviders && _providers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No providers available for this service.',
                      style: TextStyle(
                        color: UiTone.softText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: elevatedSurface(radius: 14),
            child: const Row(
              children: <Widget>[
                Text(
                  'View all coupons',
                  style: TextStyle(
                    color: UiTone.softText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Spacer(),
                Icon(Icons.chevron_right_rounded, color: UiTone.softText),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: elevatedSurface(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Booking details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    iconBox(
                      Icons.location_on_rounded,
                      background: IconColors.teal.$1,
                      foreground: IconColors.teal.$2,
                      size: 36,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _detectingAddress ? null : _useCurrentAddress,
                      icon: _detectingAddress
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_outlined),
                    ),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  children: <Widget>[
                    iconBox(
                      Icons.event_rounded,
                      background: IconColors.blue.$1,
                      foreground: IconColors.blue.$2,
                      size: 36,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Date: ${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDate,
                      child: const Text('Change'),
                    ),
                  ],
                ),
                const Divider(height: 12),
                const Text(
                  'Time slot',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _timeSlots.map(_slotChip).toList(),
                ),
                const Divider(height: 12),
                Row(
                  children: <Widget>[
                    iconBox(
                      Icons.phone_rounded,
                      background: IconColors.green.$1,
                      foreground: IconColors.green.$2,
                      size: 36,
                      iconSize: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Customer',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: elevatedSurface(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Bill details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'To pay ${_formatPrice(total)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '₹101 saved on the total!',
                  style: TextStyle(
                    color: Color(0xFF0D7C66),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _summaryRow('Item total', _formatPrice(subtotal)),
                _summaryRow('Taxes and fees', _formatPrice(fees)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCreatedSuccessPage extends StatefulWidget {
  const _BookingCreatedSuccessPage({required this.bookingId});

  final int bookingId;

  @override
  State<_BookingCreatedSuccessPage> createState() =>
      _BookingCreatedSuccessPageState();
}

class _BookingCreatedSuccessPageState
    extends State<_BookingCreatedSuccessPage> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(const Duration(seconds: 2), _finishFlow);
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  void _finishFlow() {
    if (!mounted) return;
    _customerGoHomeFromCart?.call();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F3),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFBFE3CD), width: 1.2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x140A5A31),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F8EE),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF74D39C),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 46,
                      color: Color(0xFF109B61),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Booking Created',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF122018),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your booking #${widget.bookingId} is confirmed.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: UiTone.softText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Color(0xFF10B766),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Redirecting to home...',
                    style: TextStyle(
                      color: UiTone.softText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerBookingsTab extends StatefulWidget {
  const CustomerBookingsTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
    required this.onBack,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final VoidCallback onBack;

  @override
  State<CustomerBookingsTab> createState() => _CustomerBookingsTabState();
}

class _CustomerBookingsTabState extends State<CustomerBookingsTab> {
  bool _loading = true;
  List<BookingItem> _bookings = <BookingItem>[];
  bool _showUpcoming = true;
  static const Color _bookingBorder = Color(0xFFB9CBBF);
  static const Color _bookingDivider = Color(0xFFD9E4DD);

  Widget _statusPill(String status) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        prettyStatus(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final bookings = await widget.api.fetchCustomerBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openReviewDialog(BookingItem booking) async {
    int rating = 5;
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Review booking #${booking.id}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<int>(
                    initialValue: rating,
                    items: List.generate(
                      5,
                      (index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text(
                          '${index + 1} star${index == 0 ? '' : 's'}',
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setStateDialog(() {
                          rating = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Rating'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Comment'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      commentController.dispose();
      return;
    }

    try {
      await widget.api.submitReview(
        bookingId: booking.id,
        rating: rating,
        comment: commentController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully')),
      );
      await _load();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      commentController.dispose();
    }
  }

  double _amountFor(BookingItem booking) {
    if (booking.totalAmount > 0) return booking.totalAmount;
    final count = math.max(
      1,
      booking.serviceNames.isEmpty ? 1 : booking.serviceNames.length,
    );
    return count * 25 + 2.52;
  }

  Future<void> _openBookingSummary(BookingItem booking) async {
    await Navigator.of(context).push(
      smoothPageRoute<void>(
        BookingSummaryPage(
          booking: booking,
          amountPaid: _amountFor(booking),
          supportApi: widget.api,
          onSessionExpired: widget.onSessionExpired,
          supportRole: 'CUSTOMER',
          preselectedBookingId: booking.id,
        ),
      ),
    );
  }

  Widget _bookingTabs() {
    Widget item({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 3,
                  color: selected
                      ? const Color(0xFF10B981)
                      : Colors.transparent,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? const Color(0xFF2E3135)
                    : const Color(0xFF858D97),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        item(
          label: 'Upcoming',
          selected: _showUpcoming,
          onTap: () => setState(() => _showUpcoming = true),
        ),
        item(
          label: 'Past',
          selected: !_showUpcoming,
          onTap: () => setState(() => _showUpcoming = false),
        ),
      ],
    );
  }

  Widget _bookingCard(BookingItem booking) {
    final amount = _amountFor(booking);
    final completed = booking.status == 'COMPLETED';
    final headerTitle = completed
        ? 'Booking completed'
        : '${prettyStatus(booking.status)} booking';

    return InkWell(
      onTap: () => _openBookingSummary(booking),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _bookingBorder, width: 1.3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDFF5E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF10B981),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          headerTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E3135),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Booking id: ${booking.id}',
                          style: const TextStyle(
                            color: Color(0xFF737B87),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${booking.timeSlot} ${booking.scheduledDate}',
                          style: const TextStyle(
                            color: Color(0xFF737B87),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!completed) ...<Widget>[
                          const SizedBox(height: 6),
                          _OtpRevealRow(
                            startOtp: booking.startOtp,
                            endOtp: booking.endOtp,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: _bookingDivider),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Amount paid',
                      style: TextStyle(
                        color: Color(0xFF6C7480),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF2E3135),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: _bookingDivider),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: <Widget>[
                  Spacer(),
                  Text(
                    'Booking summary',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleBookings = _bookings.where((booking) {
      final isPast =
          booking.status == 'COMPLETED' || booking.status == 'CANCELLED';
      if (_showUpcoming && isPast) return false;
      if (!_showUpcoming && !isPast) return false;
      return true;
    }).toList();

    final children = <Widget>[
      const SizedBox(height: 10),
      Row(
        children: <Widget>[
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
          const SizedBox(width: 2),
          const Text(
            'Your bookings',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E3135),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Track upcoming and past services',
        style: TextStyle(color: UiTone.softText, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      _bookingTabs(),
      const SizedBox(height: 14),
    ];

    if (_loading) {
      children.add(
        const Padding(
          padding: EdgeInsets.only(top: 120),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (visibleBookings.isEmpty) {
      children.addAll(<Widget>[
        const SizedBox(height: 120),
        const Center(
          child: Icon(
            Icons.event_note_rounded,
            size: 72,
            color: Color(0xFFA7B0BC),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _showUpcoming ? 'No upcoming bookings' : 'No past bookings',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E3135),
            ),
          ),
        ),
      ]);
    } else {
      children.addAll(visibleBookings.map(_bookingCard));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: UiSpace.screen, children: children),
    );
  }
}

class BookingSummaryPage extends StatelessWidget {
  const BookingSummaryPage({
    super.key,
    required this.booking,
    required this.amountPaid,
    this.supportApi,
    this.onSessionExpired,
    this.supportRole = 'CUSTOMER',
    this.preselectedBookingId,
  });

  final BookingItem booking;
  final double amountPaid;
  final ApiService? supportApi;
  final VoidCallback? onSessionExpired;
  final String supportRole;
  final int? preselectedBookingId;

  List<String> get _serviceNames {
    if (booking.serviceNames.isNotEmpty) return booking.serviceNames;
    if (booking.serviceName.trim().isNotEmpty) {
      return <String>[booking.serviceName];
    }
    return const <String>['Service'];
  }

  String get _cleanAddress {
    if (booking.address.trim().isEmpty) return '-';
    final lines = booking.address
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final coordinatePattern = RegExp(r'-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+');
    final exactCoordinatePattern = RegExp(
      r'^-?\d{1,3}\.\d+\s*,\s*-?\d{1,3}\.\d+$',
    );
    final cleaned = <String>[];
    for (final line in lines) {
      if (line.toLowerCase().startsWith('customer location:')) {
        // Hide raw coordinates from booking summary.
        if (coordinatePattern.hasMatch(line)) continue;
      }
      if (exactCoordinatePattern.hasMatch(line)) continue;
      cleaned.add(line);
    }
    return cleaned.isEmpty ? '-' : cleaned.join('\n');
  }

  String get _dateLabel {
    final value = booking.scheduledDate.trim();
    return value.isEmpty ? '-' : value;
  }

  String get _timeSlotLabel {
    final slot = booking.timeSlot.trim();
    if (slot.isEmpty) return '-';
    if (slot.toUpperCase() == 'MORNING') return 'Scheduled';
    return prettyStatus(slot);
  }

  ({Color primary, Color soft, IconData icon}) _statusTone(String status) {
    switch (status) {
      case 'COMPLETED':
        return (
          primary: const Color(0xFF109A5F),
          soft: const Color(0xFFE8F8EF),
          icon: Icons.check_circle_rounded,
        );
      case 'CANCELLED':
        return (
          primary: const Color(0xFFE11D48),
          soft: const Color(0xFFFDECF0),
          icon: Icons.cancel_rounded,
        );
      case 'IN_PROGRESS':
        return (
          primary: const Color(0xFF2563EB),
          soft: const Color(0xFFEAF1FF),
          icon: Icons.timelapse_rounded,
        );
      default:
        return (
          primary: const Color(0xFF0D7C66),
          soft: const Color(0xFFE7F5F1),
          icon: Icons.schedule_rounded,
        );
    }
  }

  IconData _serviceIcon(String name) {
    final text = name.toLowerCase();
    if (text.contains('bathroom')) return Icons.bathtub_outlined;
    if (text.contains('kitchen')) return Icons.kitchen_outlined;
    if (text.contains('clean')) return Icons.cleaning_services_outlined;
    if (text.contains('ac')) return Icons.ac_unit_rounded;
    if (text.contains('repair')) return Icons.build_circle_outlined;
    if (text.contains('salon') || text.contains('hair')) {
      return Icons.content_cut_rounded;
    }
    if (text.contains('plumber')) return Icons.plumbing_outlined;
    if (text.contains('electric')) return Icons.electrical_services_outlined;
    return Icons.home_repair_service_outlined;
  }

  Widget _detailBlock({
    required String label,
    required String value,
    Color valueColor = const Color(0xFF2E3135),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7B8390),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w700,
              height: 1.25,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1E232D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceNames = _serviceNames;
    const gst = 2.52;
    final itemTotal = (amountPaid - gst).clamp(0, double.infinity);
    final each = serviceNames.isEmpty
        ? itemTotal
        : itemTotal / serviceNames.length;
    final statusTone = _statusTone(booking.status);
    final statusLabel = prettyStatus(booking.status);
    final bookingTitle = booking.status == 'COMPLETED'
        ? 'Booking completed'
        : 'Booking ${statusLabel.toLowerCase()}';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5F8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2E3135)),
        ),
        title: const Text(
          'Booking summary',
          style: TextStyle(
            color: Color(0xFF2E3135),
            fontWeight: FontWeight.w700,
            fontSize: 15.5,
          ),
        ),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.more_vert_rounded, color: Color(0xFF5F6672)),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFC2D4CA),
                      width: 1.2,
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFFFFFFFF), Color(0xFFF6FAF8)],
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x09000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: statusTone.soft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: statusTone.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          statusTone.icon,
                          color: statusTone.primary,
                          size: 29,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              bookingTitle,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF121417),
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$_dateLabel • $_timeSlotLabel',
                              style: const TextStyle(
                                color: Color(0xFF667180),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusTone.soft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusTone.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Booking #${booking.id}',
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _sectionHeading('Services in this booking'),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Text(
                            '${serviceNames.length} ${serviceNames.length == 1 ? 'service' : 'services'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF57616F),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F3),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFC6D4CC),
                              ),
                            ),
                            child: Text(
                              _timeSlotLabel,
                              style: const TextStyle(
                                color: Color(0xFF4B5663),
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...serviceNames.asMap().entries.map((entry) {
                        final index = entry.key;
                        final name = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == serviceNames.length - 1 ? 0 : 12,
                          ),
                          child: Column(
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF3F7),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(
                                      _serviceIcon(name),
                                      color: const Color(0xFF6B7482),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2E3135),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${each.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Color(0xFF485160),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (index != serviceNames.length - 1)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFE3EAF0),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _sectionHeading('Bill details'),
                      const SizedBox(height: 12),
                      _billRow(
                        'Item total',
                        '₹${itemTotal.toStringAsFixed(0)}',
                      ),
                      _billRow('Discount', '₹0'),
                      _billRow(
                        'GST & Service Fees',
                        '₹${gst.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFFAF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFB7DFC7)),
                        ),
                        child: _billRow(
                          'Bill total',
                          '₹${amountPaid.toStringAsFixed(2)}',
                          bold: true,
                          isTight: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _sectionHeading('Booking details'),
                      const SizedBox(height: 14),
                      _detailBlock(
                        label: 'Booking id',
                        value: '#${booking.id}',
                      ),
                      if (booking.status != 'COMPLETED' &&
                          booking.status != 'CANCELLED') ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Service OTPs',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF737B87),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _OtpRevealRow(
                                startOtp: booking.startOtp,
                                endOtp: booking.endOtp,
                              ),
                            ],
                          ),
                        ),
                      ],
                      _detailBlock(
                        label: 'Payment',
                        value: 'Paid using: Online Payment',
                      ),
                      _detailBlock(label: 'Address', value: _cleanAddress),
                      _detailBlock(label: 'Booking placed', value: _dateLabel),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (supportApi == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Support is not available here yet'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        smoothPageRoute<void>(
                          SupportCenterPage(
                            api: supportApi!,
                            role: supportRole,
                            onSessionExpired: onSessionExpired ?? () {},
                            initialBookingId:
                                preselectedBookingId ?? booking.id,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF4F1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFC5D8CE),
                          width: 1.2,
                        ),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(
                            Icons.support_agent_rounded,
                            color: Color(0xFF8A93A0),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Need help with your booking?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E3135),
                                    fontSize: 17,
                                  ),
                                ),
                                Text(
                                  'Support is here to help',
                                  style: TextStyle(
                                    color: Color(0xFF7D8591),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF8A93A0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'View booking details',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC8D6CF), width: 1.2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  static Widget _billRow(
    String label,
    String value, {
    bool bold = false,
    bool isTight = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isTight ? 0 : 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: const Color(0xFF2A3340),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: const Color(0xFF2A3340),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
    this.onBack,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final VoidCallback? onBack;

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  bool _loading = true;
  bool _showUnreadOnly = false;
  bool _markingAll = false;
  List<AppNotification> _items = <AppNotification>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final data = await widget.api.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _items = data;
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _markRead(int id) async {
    try {
      await widget.api.markNotificationRead(id);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (item) => item.id == id
                  ? AppNotification(
                      id: item.id,
                      message: item.message,
                      isRead: true,
                      createdAt: item.createdAt,
                    )
                  : item,
            )
            .toList();
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  int? _extractBookingId(AppNotification item) {
    final match = RegExp(r'#(\d+)').firstMatch(item.message);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  double _amountForBooking(BookingItem booking) {
    final count = booking.serviceNames.isEmpty
        ? 1
        : booking.serviceNames.length;
    return count * 25 + 2.52;
  }

  Future<BookingItem?> _findBookingById(int bookingId) async {
    Future<List<BookingItem>> attempt(
      Future<List<BookingItem>> Function() call,
    ) async {
      try {
        return await call();
      } catch (_) {
        return <BookingItem>[];
      }
    }

    final sources = await Future.wait<List<BookingItem>>([
      attempt(() => widget.api.fetchCustomerBookings()),
      attempt(() => widget.api.fetchProviderDashboardBookings()),
      attempt(() => widget.api.fetchAdminBookings()),
    ]);

    for (final list in sources) {
      for (final booking in list) {
        if (booking.id == bookingId) return booking;
      }
    }
    return null;
  }

  Future<void> _openNotification(AppNotification item) async {
    final bookingId = _extractBookingId(item);

    if (!item.isRead) {
      await _markRead(item.id);
    }

    if (bookingId == null) return;
    final booking = await _findBookingById(bookingId);
    if (!mounted || booking == null) return;

    await Navigator.of(context).push(
      smoothPageRoute<void>(
        BookingSummaryPage(
          booking: booking,
          amountPaid: _amountForBooking(booking),
          supportApi: widget.api,
          onSessionExpired: widget.onSessionExpired,
          supportRole: 'CUSTOMER',
          preselectedBookingId: booking.id,
        ),
      ),
    );
  }

  Future<void> _markAll() async {
    setState(() {
      _markingAll = true;
    });
    try {
      await widget.api.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (item) => AppNotification(
                id: item.id,
                message: item.message,
                isRead: true,
                createdAt: item.createdAt,
              ),
            )
            .toList();
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _markingAll = false;
        });
      }
    }
  }

  DateTime? _parseDate(String raw) {
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  List<AppNotification> get _sortedItems {
    final copy = List<AppNotification>.from(_items);
    copy.sort((a, b) {
      final aDate = _parseDate(a.createdAt);
      final bDate = _parseDate(b.createdAt);
      if (aDate == null && bDate == null) return b.id.compareTo(a.id);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return copy;
  }

  int get _unreadCount => _items.where((item) => !item.isRead).length;

  List<AppNotification> get _displayedItems => _showUnreadOnly
      ? _sortedItems.where((item) => !item.isRead).toList()
      : _sortedItems;

  String _sectionLabel(AppNotification item) {
    final date = _parseDate(item.createdAt);
    if (date == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return 'Earlier';
  }

  String _timeLabel(AppNotification item) {
    final date = _parseDate(item.createdAt);
    if (date == null) return item.createdAt;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  _NotificationStyle _styleFor(AppNotification item) {
    final message = item.message.toLowerCase();
    if (message.contains('completed') || message.contains('success')) {
      return const _NotificationStyle(
        icon: Icons.verified_rounded,
        color: Color(0xFF16A34A),
      );
    }
    if (message.contains('cancel') || message.contains('failed')) {
      return const _NotificationStyle(
        icon: Icons.cancel_outlined,
        color: Color(0xFFDC2626),
      );
    }
    if (message.contains('book') ||
        message.contains('provider') ||
        message.contains('assigned')) {
      return const _NotificationStyle(
        icon: Icons.calendar_month_rounded,
        color: UiTone.primary,
      );
    }
    return const _NotificationStyle(
      icon: Icons.notifications_active_rounded,
      color: Color(0xFF2563EB),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayedItems;
    final navigator = Navigator.of(context);

    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            if (navigator.canPop()) {
              await navigator.maybePop();
            } else {
              widget.onBack?.call();
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              _unreadCount == 0
                  ? 'You are all caught up'
                  : '$_unreadCount unread update${_unreadCount == 1 ? '' : 's'}',
              style: const TextStyle(
                color: UiTone.softText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _items.isEmpty || _markingAll || _unreadCount == 0
                ? null
                : _markAll,
            icon: _markingAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.done_all),
            tooltip: 'Mark all read',
          ),
        ],
      ),
      body: _loading
          ? loadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: elevatedSurface(
                      radius: 22,
                      color: const Color(0xFFE8F6F1),
                      border: const Color(0xFFCBE7DB),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Stay on top of every booking',
                          style: TextStyle(
                            color: UiTone.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Service confirmations, provider updates, and important reminders appear here.',
                          style: TextStyle(
                            color: UiTone.softText,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: UiTone.surfaceBorder),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _showUnreadOnly = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _showUnreadOnly
                                    ? Colors.transparent
                                    : UiTone.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'All (${_items.length})',
                                style: TextStyle(
                                  color: _showUnreadOnly
                                      ? UiTone.softText
                                      : UiTone.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _showUnreadOnly = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _showUnreadOnly
                                    ? UiTone.primarySoft
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Unread ($_unreadCount)',
                                style: TextStyle(
                                  color: _showUnreadOnly
                                      ? UiTone.primary
                                      : UiTone.softText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (displayed.isEmpty)
                    emptyView(
                      _showUnreadOnly
                          ? 'No unread notifications'
                          : 'No notifications yet',
                    )
                  else
                    ..._buildNotificationSections(displayed),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildNotificationSections(List<AppNotification> items) {
    final widgets = <Widget>[];
    String? previousSection;
    for (final item in items) {
      final section = _sectionLabel(item);
      if (previousSection != section) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
            child: Text(
              section,
              style: const TextStyle(
                color: UiTone.softText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        );
        previousSection = section;
      }

      final style = _styleFor(item);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openNotification(item),
              child: Ink(
                decoration: elevatedSurface(
                  radius: 18,
                  color: item.isRead ? UiTone.surface : const Color(0xFFF5FFFA),
                  border: item.isRead
                      ? UiTone.surfaceBorder
                      : const Color(0xFFCFEBDD),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: style.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(style.icon, color: style.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.message,
                              style: const TextStyle(
                                color: UiTone.ink,
                                fontWeight: FontWeight.w700,
                                height: 1.28,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _timeLabel(item),
                              style: const TextStyle(
                                color: UiTone.softText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!item.isRead)
                        TextButton(
                          onPressed: () => _openNotification(item),
                          child: const Text(
                            'Open',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        )
                      else
                        const Icon(
                          Icons.check_circle_rounded,
                          color: UiTone.success,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }
}

class _NotificationStyle {
  const _NotificationStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

class SupportCenterPage extends StatefulWidget {
  const SupportCenterPage({
    super.key,
    required this.api,
    required this.role,
    required this.onSessionExpired,
    this.initialBookingId,
  });

  final ApiService api;
  final String role;
  final VoidCallback onSessionExpired;
  final int? initialBookingId;

  @override
  State<SupportCenterPage> createState() => _SupportCenterPageState();
}

class _SupportCenterPageState extends State<SupportCenterPage> {
  static const List<String> _issueTypes = <String>[
    'Booking issue',
    'Payment issue',
    'Provider behavior',
    'Reschedule / cancellation',
    'App technical issue',
    'Other',
  ];

  bool _loading = true;
  bool _submitting = false;
  List<BookingItem> _bookings = <BookingItem>[];
  List<SupportTicket> _tickets = <SupportTicket>[];
  String _selectedIssue = _issueTypes.first;
  int? _selectedBookingId;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedBookingId = widget.initialBookingId;
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final futures = <Future<dynamic>>[
        widget.api.fetchSupportTickets(),
        widget.role == 'PROVIDER'
            ? widget.api.fetchProviderDashboardBookings()
            : widget.api.fetchCustomerBookings(),
      ];
      final results = await Future.wait<dynamic>(futures);
      if (!mounted) return;
      final tickets = results[0] as List<SupportTicket>;
      final bookings = results[1] as List<BookingItem>;
      setState(() {
        _tickets = tickets;
        _bookings = bookings;
        final valid = _bookings.any(
          (booking) => booking.id == _selectedBookingId,
        );
        if (!valid) _selectedBookingId = null;
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _submitTicket() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      showApiError(
        context,
        const ApiException('Please enter your support message'),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });
    try {
      await widget.api.createSupportTicket(
        issueType: _selectedIssue,
        bookingId: _selectedBookingId,
        message: message,
      );
      _messageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Support ticket submitted')));
      await _load();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _bookingLabel(BookingItem booking) {
    final serviceName = booking.serviceName.isNotEmpty
        ? booking.serviceName
        : (booking.serviceNames.isEmpty
              ? 'Service'
              : booking.serviceNames.first);
    return '#${booking.id} · $serviceName · ${booking.scheduledDate}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Help & support'),
      ),
      body: _loading
          ? loadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: elevatedSurface(
                      radius: 20,
                      color: const Color(0xFFE8F6F1),
                      border: const Color(0xFFCFEBDD),
                    ),
                    child: const Text(
                      'Tell us your issue and choose the related booking. Our support team will follow up quickly.',
                      style: TextStyle(
                        color: UiTone.ink,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: elevatedSurface(radius: 18),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Raise a support ticket',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedIssue,
                          items: _issueTypes
                              .map(
                                (issue) => DropdownMenuItem<String>(
                                  value: issue,
                                  child: Text(issue),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedIssue = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Issue type',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int?>(
                          key: ValueKey<String>(
                            'support-booking-${_selectedBookingId ?? -1}-${_bookings.length}',
                          ),
                          initialValue: _selectedBookingId,
                          isExpanded: true,
                          items: <DropdownMenuItem<int?>>[
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('No specific booking'),
                            ),
                            ..._bookings.map(
                              (booking) => DropdownMenuItem<int?>(
                                value: booking.id,
                                child: Text(
                                  _bookingLabel(booking),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedBookingId = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Booking',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _messageController,
                          minLines: 4,
                          maxLines: 7,
                          decoration: const InputDecoration(
                            labelText: 'Describe your issue',
                            hintText: 'Write the problem in detail',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submitTicket,
                          icon: const Icon(Icons.send_rounded),
                          label: Text(
                            _submitting ? 'Submitting...' : 'Send to support',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  sectionTitle(
                    'Your issues',
                    subtitle: _tickets.isEmpty
                        ? 'No previous support tickets'
                        : '${_tickets.length} ticket${_tickets.length == 1 ? '' : 's'}',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  if (_tickets.isEmpty)
                    emptyView('No support tickets raised yet')
                  else
                    ..._tickets.map((ticket) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: elevatedSurface(radius: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    ticket.issueType,
                                    style: const TextStyle(
                                      color: UiTone.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(prettyStatus(ticket.status)),
                                  visualDensity: VisualDensity.compact,
                                  labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            if (ticket.bookingLabel
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                ticket.bookingLabel,
                                style: const TextStyle(
                                  color: UiTone.softText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              ticket.message,
                              style: const TextStyle(
                                color: UiTone.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class AccountTab extends StatefulWidget {
  const AccountTab({
    super.key,
    required this.api,
    required this.profile,
    required this.onRefreshProfile,
    required this.onLogout,
    required this.onSessionExpired,
    this.onOpenBookings,
    this.onBack,
  });

  final ApiService api;
  final UserProfile profile;
  final Future<void> Function() onRefreshProfile;
  final Future<void> Function() onLogout;
  final VoidCallback onSessionExpired;
  final VoidCallback? onOpenBookings;
  final VoidCallback? onBack;

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _cityController;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late String _displayName;
  late String _displayEmail;
  bool _updatingProfile = false;
  bool _changingPassword = false;
  bool _savingCity = false;
  bool _detectingCity = false;

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    widget.onBack?.call();
  }

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _emailController = TextEditingController(text: widget.profile.email);
    _cityController = TextEditingController();
    _displayName = widget.profile.fullName;
    _displayEmail = widget.profile.email;
    _loadSavedCity();
  }

  Future<void> _loadSavedCity() async {
    final city = (await TokenStore.readCity())?.trim() ?? '';
    if (!mounted) return;
    if (city.isEmpty) {
      _cityController.text = kDefaultFallbackCity;
      await TokenStore.saveCity(kDefaultFallbackCity);
    } else {
      _cityController.text = city;
    }
  }

  @override
  void didUpdateWidget(covariant AccountTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.fullName != widget.profile.fullName) {
      _fullNameController.text = widget.profile.fullName;
      _displayName = widget.profile.fullName;
    }
    if (oldWidget.profile.email != widget.profile.email) {
      _emailController.text = widget.profile.email;
      _displayEmail = widget.profile.email;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<bool> _updateProfile() async {
    if (_fullNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      showApiError(
        context,
        const ApiException('Full name and email are required'),
      );
      return false;
    }

    setState(() {
      _updatingProfile = true;
    });
    try {
      await widget.api.updateProfile(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
      );
      await widget.onRefreshProfile();
      if (!mounted) return false;
      setState(() {
        _displayName = _fullNameController.text.trim();
        _displayEmail = _emailController.text.trim();
      });
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      return true;
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return false;
      }
      if (mounted) showApiError(context, error);
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _updatingProfile = false;
        });
      }
    }
  }

  Future<void> _saveCity() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      showApiError(context, const ApiException('City is required'));
      return;
    }
    setState(() {
      _savingCity = true;
    });
    try {
      await widget.api.saveCustomerCity(city);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Service city updated to $city')));
      Navigator.of(context).pop();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _savingCity = false;
        });
      }
    }
  }

  Future<void> _detectCity() async {
    setState(() {
      _detectingCity = true;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ApiException('Location permission denied');
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
      final placemark = places.isEmpty ? null : places.first;
      String? resolved;
      for (final value in <String?>[
        placemark?.locality,
        placemark?.subAdministrativeArea,
        placemark?.administrativeArea,
      ]) {
        if (value != null && value.trim().isNotEmpty) {
          resolved = value.trim();
          break;
        }
      }
      if (resolved == null) {
        throw const ApiException('Unable to detect city from location');
      }
      _cityController.text = resolved.trim();
    } catch (error) {
      if (!mounted) return;
      _cityController.text = kDefaultFallbackCity;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Using default city: $kDefaultFallbackCity (location unavailable)',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _detectingCity = false;
        });
      }
    }
  }

  void _openAddressBook() {
    Navigator.of(context).push(smoothPageRoute<void>(const AddressBookPage()));
  }

  void _openSupportCenter() {
    Navigator.of(context).push(
      smoothPageRoute<void>(
        SupportCenterPage(
          api: widget.api,
          role: widget.profile.role,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
  }

  void _showInfoSheet({required String title, required String message}) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestDeletion() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Request account deletion',
      message:
          'This will submit a deletion request to support. Do you want to continue?',
      confirmLabel: 'Request',
    );
    if (!confirmed || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Deletion request recorded. Support will contact you shortly.',
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      showApiError(
        context,
        const ApiException('All password fields are required'),
      );
      return;
    }

    if (newPass.length < 8) {
      showApiError(
        context,
        const ApiException('New password must be at least 8 characters'),
      );
      return;
    }

    if (newPass == current) {
      showApiError(
        context,
        const ApiException(
          'New password must be different from current password',
        ),
      );
      return;
    }

    if (newPass != confirm) {
      showApiError(
        context,
        const ApiException('New password and confirm password do not match'),
      );
      return;
    }

    setState(() {
      _changingPassword = true;
    });
    try {
      await widget.api.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed. Please login again.')),
      );
      await widget.onLogout();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _changingPassword = false;
        });
      }
    }
  }

  void _openEditProfile() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE0E4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _updatingProfile
                      ? null
                      : () async {
                          final saved = await _updateProfile();
                          if (saved && sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        },
                  child: Text(_updatingProfile ? 'Saving...' : 'Save changes'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openChangePassword() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE0E4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Change password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F36),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _changingPassword
                      ? null
                      : () {
                          _changePassword();
                        },
                  child: Text(
                    _changingPassword ? 'Updating...' : 'Update password',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName.isEmpty
        ? widget.profile.username
        : _displayName;
    final phone = widget.profile.phone.isEmpty ? '' : widget.profile.phone;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: Column(
        children: <Widget>[
          // Dark green header
          Container(
            color: const Color(0xFF1B4332),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: _handleBack,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D6A4F),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(
                                  0xFF52B788,
                                ).withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (phone.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      color: Color(0xFFB7BFB8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                                if (_displayEmail.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    _displayEmail,
                                    style: const TextStyle(
                                      color: Color(0xFFB7BFB8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: _openEditProfile,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        'Edit profile',
                                        style: TextStyle(
                                          color: Color(0xFF52B788),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: Color(0xFF52B788),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Menu list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: <Widget>[
                // First card group
                _menuCard(
                  children: <Widget>[
                    _menuTile(
                      icon: Icons.calendar_today_rounded,
                      label: 'Your bookings',
                      colors: IconColors.blue,
                      onTap: () {
                        widget.onOpenBookings?.call();
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const _MenuDivider(),
                    _menuTile(
                      icon: Icons.location_on_rounded,
                      label: 'Address book',
                      colors: IconColors.teal,
                      onTap: _openAddressBook,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Second card group
                _menuCard(
                  children: <Widget>[
                    _menuTile(
                      icon: Icons.info_rounded,
                      label: 'About us',
                      colors: IconColors.green,
                      onTap: () => _showInfoSheet(
                        title: 'About us',
                        message:
                            'ServiceApp helps you book trusted home services with transparent pricing and quick scheduling.',
                      ),
                    ),
                    const _MenuDivider(),
                    _menuTile(
                      icon: Icons.description_rounded,
                      label: 'Terms & conditions',
                      colors: IconColors.slate,
                      onTap: () => _showInfoSheet(
                        title: 'Terms & conditions',
                        message:
                            'Using this app means you agree to booking, cancellation, and payment terms as displayed during checkout.',
                      ),
                    ),
                    const _MenuDivider(),
                    _menuTile(
                      icon: Icons.shield_rounded,
                      label: 'Privacy policy',
                      colors: IconColors.purple,
                      onTap: () => _showInfoSheet(
                        title: 'Privacy policy',
                        message:
                            'We use your profile, city, and booking details only to provide service fulfillment and support.',
                      ),
                    ),
                    const _MenuDivider(),
                    _menuTile(
                      icon: Icons.headset_mic_rounded,
                      label: 'Help & support',
                      colors: IconColors.orange,
                      onTap: _openSupportCenter,
                    ),
                    const _MenuDivider(),
                    _menuTile(
                      icon: Icons.lock_rounded,
                      label: 'Change password',
                      colors: IconColors.blue,
                      onTap: _openChangePassword,
                    ),
                    const _MenuDivider(),
                    _menuTile(
                      icon: Icons.delete_rounded,
                      label: 'Request account deletion',
                      colors: IconColors.red,
                      onTap: _requestDeletion,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1FA971),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x221FA971),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1FA971),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        final confirmed = await confirmDialog(
                          context,
                          title: 'Logout',
                          message: 'Do you want to logout from this device?',
                          confirmLabel: 'Logout',
                        );
                        if (!confirmed) return;
                        await widget.onLogout();
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log out'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'APP VERSION: 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    (Color, Color) colors = IconColors.green,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: <Widget>[
            iconBox(icon, background: colors.$1, foreground: colors.$2),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A2B23),
                    ),
                  ),
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: 10),
                    trailing,
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFFC0C8C4),
            ),
          ],
        ),
      ),
    );
  }
}

class AddressBookPage extends StatefulWidget {
  const AddressBookPage({super.key});

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  bool _loading = true;
  List<_SavedAddress> _items = <_SavedAddress>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final raw = await TokenStore.readAddressBook();
    if (!mounted) return;
    setState(() {
      _items = raw.map(_SavedAddress.fromJson).toList();
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await TokenStore.saveAddressBook(_items.map((e) => e.toJson()).toList());
  }

  Future<void> _setDefault(String id) async {
    setState(() {
      _items = _items.map((e) => e.copyWith(isDefault: e.id == id)).toList();
    });
    await _persist();
  }

  Future<void> _deleteAddress(_SavedAddress entry) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete address',
      message: 'Remove "${entry.label}" from your address book?',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    setState(() {
      _items = _items.where((e) => e.id != entry.id).toList();
      if (_items.isNotEmpty && !_items.any((e) => e.isDefault)) {
        _items[0] = _items[0].copyWith(isDefault: true);
      }
    });
    await _persist();
  }

  Future<void> _openAddressEditor([_SavedAddress? existing]) async {
    final existingLabel = (existing?.label ?? 'Home').trim();
    String labelType = switch (existingLabel.toLowerCase()) {
      'home' => 'Home',
      'work' => 'Work',
      _ => 'Other',
    };
    final customLabel = TextEditingController(
      text: labelType == 'Other' ? existingLabel : '',
    );
    final address = TextEditingController(text: existing?.addressLine ?? '');
    final landmark = TextEditingController(text: existing?.landmark ?? '');
    final city = TextEditingController(text: existing?.city ?? '');
    bool setDefault = existing?.isDefault ?? _items.isEmpty;
    bool detecting = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> detectCurrent() async {
              setStateDialog(() {
                detecting = true;
              });
              try {
                final serviceEnabled =
                    await Geolocator.isLocationServiceEnabled();
                if (!serviceEnabled) {
                  throw const ApiException(
                    'Location services are turned off on this device',
                  );
                }

                LocationPermission permission =
                    await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                }
                if (permission == LocationPermission.denied ||
                    permission == LocationPermission.deniedForever) {
                  throw const ApiException('Location permission denied');
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
                if (places.isEmpty) {
                  throw const ApiException(
                    'Could not resolve address from your current location',
                  );
                }

                final p = places.first;
                final components = <String>[
                  p.name ?? '',
                  p.subThoroughfare ?? '',
                  p.thoroughfare ?? '',
                  p.subLocality ?? '',
                  p.locality ?? '',
                  p.subAdministrativeArea ?? '',
                  p.administrativeArea ?? '',
                  p.postalCode ?? '',
                ];
                final uniqueParts = <String>[];
                final seen = <String>{};
                for (final raw in components) {
                  final value = raw.trim();
                  if (value.isEmpty) continue;
                  final key = value.toLowerCase();
                  if (seen.add(key)) uniqueParts.add(value);
                }
                final resolvedAddress = uniqueParts.join(', ');
                if (resolvedAddress.isEmpty) {
                  throw const ApiException(
                    'Unable to detect a valid address from location',
                  );
                }

                address.text = resolvedAddress;

                final detectedCity =
                    <String>[
                      p.locality ?? '',
                      p.subAdministrativeArea ?? '',
                      p.administrativeArea ?? '',
                    ].firstWhere(
                      (value) => value.trim().isNotEmpty,
                      orElse: () => '',
                    );
                if (detectedCity.isNotEmpty) {
                  city.text = detectedCity.trim();
                }

                if (landmark.text.trim().isEmpty) {
                  final detectedLandmark =
                      <String>[
                        p.subLocality ?? '',
                        p.thoroughfare ?? '',
                        p.name ?? '',
                      ].firstWhere(
                        (value) => value.trim().isNotEmpty,
                        orElse: () => '',
                      );
                  if (detectedLandmark.isNotEmpty) {
                    landmark.text = detectedLandmark.trim();
                  }
                }

                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    const SnackBar(
                      content: Text('Current location added successfully'),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) showApiError(context, error);
              } finally {
                if (sheetContext.mounted) {
                  setStateDialog(() {
                    detecting = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    existing == null ? 'Add address' : 'Edit address',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: labelType,
                    decoration: const InputDecoration(
                      labelText: 'Address label',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'Home',
                        child: Text('Home'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Work',
                        child: Text('Work'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() {
                        labelType = value;
                      });
                    },
                  ),
                  if (labelType == 'Other') ...<Widget>[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customLabel,
                      decoration: const InputDecoration(
                        labelText: 'Custom label name',
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: address,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: landmark,
                    decoration: const InputDecoration(
                      labelText: 'Landmark (optional)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: 'City'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: detecting ? null : detectCurrent,
                    icon: detecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(
                      detecting ? 'Detecting...' : 'Use current location',
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    value: setDefault,
                    onChanged: (value) {
                      setStateDialog(() {
                        setDefault = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as default address'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final resolvedLabel = labelType == 'Other'
                            ? customLabel.text.trim()
                            : labelType;
                        if (resolvedLabel.isEmpty ||
                            address.text.trim().isEmpty ||
                            city.text.trim().isEmpty) {
                          showApiError(
                            context,
                            const ApiException(
                              'Label, address and city are required',
                            ),
                          );
                          return;
                        }
                        Navigator.of(sheetContext).pop(true);
                      },
                      child: const Text('Save address'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      final selectedLabel = labelType == 'Other'
          ? customLabel.text.trim()
          : labelType;
      final next = _SavedAddress(
        id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        label: selectedLabel,
        addressLine: address.text.trim(),
        landmark: landmark.text.trim(),
        city: city.text.trim(),
        isDefault: setDefault,
      );
      setState(() {
        if (existing == null) {
          _items = <_SavedAddress>[..._items, next];
        } else {
          _items = _items.map((e) => e.id == existing.id ? next : e).toList();
        }
        if (_items.length == 1) {
          _items[0] = _items[0].copyWith(isDefault: true);
        } else if (setDefault) {
          _items = _items
              .map((e) => e.copyWith(isDefault: e.id == next.id))
              .toList();
        }
      });
      await _persist();
    }

    customLabel.dispose();
    address.dispose();
    landmark.dispose();
    city.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Address book'),
      ),
      body: _loading
          ? loadingView()
          : _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.location_on_outlined,
                      size: 70,
                      color: Color(0xFF93A1AE),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No saved addresses yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your home or work address for faster booking.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _openAddressEditor,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Add new address'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: UiSpace.screen,
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: elevatedSurface(radius: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: UiTone.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  color: UiTone.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => _openAddressEditor(item),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            onPressed: () => _deleteAddress(item),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.addressLine,
                        style: const TextStyle(height: 1.25),
                      ),
                      if (item.landmark.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text('Landmark: ${item.landmark}'),
                      ],
                      const SizedBox(height: 2),
                      Text(item.city),
                      if (!item.isDefault) ...<Widget>[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _setDefault(item.id),
                          child: const Text('Set as default'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: FilledButton.icon(
          onPressed: _openAddressEditor,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add new address'),
        ),
      ),
    );
  }
}

class _SavedAddress {
  const _SavedAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.landmark,
    required this.city,
    required this.isDefault,
  });

  final String id;
  final String label;
  final String addressLine;
  final String landmark;
  final String city;
  final bool isDefault;

  factory _SavedAddress.fromJson(Map<String, dynamic> json) {
    return _SavedAddress(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Address',
      addressLine: json['address_line']?.toString() ?? '',
      landmark: json['landmark']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      isDefault: json['is_default'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'address_line': addressLine,
      'landmark': landmark,
      'city': city,
      'is_default': isDefault,
    };
  }

  _SavedAddress copyWith({
    String? id,
    String? label,
    String? addressLine,
    String? landmark,
    String? city,
    bool? isDefault,
  }) {
    return _SavedAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      addressLine: addressLine ?? this.addressLine,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, thickness: 0.5, color: Color(0xFFF0F2F1)),
    );
  }
}
