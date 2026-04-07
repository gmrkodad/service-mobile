// ignore_for_file: unused_element, unused_field

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../api.dart';
import '../models.dart';
import '../session.dart';
import 'common.dart';
import 'icon_pack.dart';

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
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      CustomerHomeTab(
        api: widget.api,
        profile: widget.profile,
        onRefreshProfile: widget.onRefreshProfile,
        onLogout: widget.onLogout,
        onSessionExpired: widget.onSessionExpired,
      ),
      CustomerBookingsTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
      ),
    ];

    return Scaffold(
      body: ColoredBox(
        color: UiTone.shellBackground,
        child: SafeArea(child: tabs[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const <Widget>[
          NavigationDestination(
            icon: AppGlyphIcon(glyph: AppGlyph.home, size: 20),
            selectedIcon: AppGlyphIcon(glyph: AppGlyph.home, size: 20),
            label: 'Home',
          ),
          NavigationDestination(
            icon: AppGlyphIcon(glyph: AppGlyph.bookings, size: 20),
            selectedIcon: AppGlyphIcon(glyph: AppGlyph.bookings, size: 20),
            label: 'Bookings',
          ),
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
  });

  final ApiService api;
  final UserProfile profile;
  final Future<void> Function() onRefreshProfile;
  final Future<void> Function() onLogout;
  final VoidCallback onSessionExpired;

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCity() async {
    final savedCity = await TokenStore.readCity();
    final city = _normalizeCity(savedCity ?? '');
    if (savedCity != null && city != savedCity.trim()) {
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
      showApiError(context, error);
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
      MaterialPageRoute<void>(
        builder: (_) => CategoryDetailsPage(
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
    final rating = 4.7 + ((service.id % 4) * 0.1);
    final ratingCount =
        '${(service.id * 7) % 25 + 2}.${(service.id * 3) % 10}k';
    const cardTints = <Color>[
      Color(0xFFEAF7EF),
      Color(0xFFEFF3FF),
      Color(0xFFFFF2E7),
      Color(0xFFEAF7F7),
    ];
    final tint = cardTints[service.id % cardTints.length];
    final isNew = service.id % 7 == 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openCategory(category),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E8EE)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  height: 76,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '⭐ ${rating.toStringAsFixed(1)} ($ratingCount)',
                            style: const TextStyle(
                              fontSize: 10,
                              color: UiTone.softText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (isNew)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2F2F),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      Center(
                        child: _buildImage(
                          service.imageUrl,
                          height: 60,
                          width: 72,
                          borderRadius: BorderRadius.circular(8),
                          fallbackIcon: Icons.cleaning_services_outlined,
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: const Color(0xFF12B76A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const AppGlyphIcon(
                            glyph: AppGlyph.plus,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  service.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: Color(0xFF242834),
                  ),
                ),
                const SizedBox(height: 4),
                const Spacer(),
                Row(
                  children: <Widget>[
                    Text(
                      _formatPrice(salePrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    if (oldPrice != null) ...<Widget>[
                      const SizedBox(width: 6),
                      Text(
                        _formatPrice(oldPrice),
                        style: const TextStyle(
                          color: UiTone.softText,
                          fontSize: 10,
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
      ),
    );
  }

  Widget _buildImage(
    String url, {
    required double height,
    required double width,
    BorderRadius? borderRadius,
    IconData fallbackIcon = Icons.handyman_outlined,
  }) {
    final cacheWidth = width.isFinite && width > 0 ? (width * 2).round() : null;
    final cacheHeight = height.isFinite && height > 0
        ? (height * 2).round()
        : null;
    final fallback = Container(
      height: height,
      width: width,
      color: const Color(0xFFE9EEF4),
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: const Color(0xFF58738D)),
    );

    final image = url.isEmpty
        ? fallback
        : Image.network(
            url,
            height: height,
            width: width,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: FilterQuality.low,
            errorBuilder: (context, error, stackTrace) => fallback,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return fallback;
            },
          );
    if (borderRadius == null) {
      return image;
    }
    return ClipRRect(borderRadius: borderRadius, child: image);
  }

  Widget _buildHeroSection() {
    final city = _normalizeCity(_cityController.text);
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.expand_more, size: 18, color: UiTone.softText),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  city.isEmpty ? '403, Floor 4 th floor, Beside ...' : city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: UiTone.softText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: _openNotifications,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFE8F4EC),
              minimumSize: const Size(42, 42),
            ),
            icon: const AppGlyphIcon(
              glyph: AppGlyph.bell,
              size: 18,
              color: Color(0xFF2E6F4E),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _openProfile,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF2B2B2B),
              minimumSize: const Size(42, 42),
              side: const BorderSide(color: Color(0xFF3A3A3A)),
            ),
            icon: const AppGlyphIcon(
              glyph: AppGlyph.user,
              size: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsTab(
          api: widget.api,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountTab(
          api: widget.api,
          profile: widget.profile,
          onRefreshProfile: widget.onRefreshProfile,
          onLogout: widget.onLogout,
          onSessionExpired: widget.onSessionExpired,
        ),
      ),
    );
  }

  Widget _buildLocationAndSearchCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: elevatedSurface(
        radius: 30,
        color: const Color(0xFFFFFBF6),
        border: const Color(0xFFE6DCCD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'What would you like help with today?',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose your city, search for a service, and book in a few calm steps.',
            style: TextStyle(
              color: UiTone.softText,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: UiTone.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.place_outlined, color: UiTone.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _normalizeCity(_cityController.text).isEmpty
                      ? 'Set your service city'
                      : _normalizeCity(_cityController.text),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: const Text('Use current'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saveCity,
                  child: const Text('Update city'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _rebuildCollections(value);
              });
            },
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search for "Waxing" or "Bathroom cleaning"',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _smallFilter('Deep cleaning'),
                _smallFilter('Beauty at home'),
                _smallFilter('Instant slots'),
                _smallFilter('4.5+ rated'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallFilter(String text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F1E6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6D8C4)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: UiTone.ink,
        ),
      ),
    );
  }

  Widget _bookLaterCard({
    required String title,
    required String offer,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6EF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC7E8D3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD8ECFF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                offer,
                style: const TextStyle(
                  color: Color(0xFF2D8AE3),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(icon, size: 34, color: const Color(0xFF18A356)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partnerSlotCard(String duration, String price, String saveLabel) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7E8D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Next slot at 9:30 AM',
            style: TextStyle(fontSize: 11.5, color: UiTone.softText),
          ),
          const SizedBox(height: 6),
          Text(
            duration,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 0.92,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            price,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            saveLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B9AE8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategories(List<ServiceCategory> categories) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length > 8 ? 8 : categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _openCategory(category),
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(10),
              decoration: elevatedSurface(
                radius: 24,
                color: const Color(0xFFFFFBF6),
                border: const Color(0xFFE6DCCD),
              ),
              child: Column(
                children: <Widget>[
                  _buildImage(
                    category.imageUrl,
                    height: 72,
                    width: 90,
                    borderRadius: BorderRadius.circular(18),
                    fallbackIcon: Icons.miscellaneous_services_outlined,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      height: 1.2,
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

  Widget _buildQuickActions(List<ServiceCategory> categories) {
    final actions = categories.take(5).toList();
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 248,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = actions[index];
          final price = _lowestPrice(category);
          return InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _openCategory(category),
            child: Container(
              width: 268,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                image: category.imageUrl.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(category.imageUrl),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                      ),
                color: const Color(0xFFE9DFD2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[
                      Color(0xD915171B),
                      Color(0x6015171B),
                      Color(0x1015171B),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            category.name.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFFFE6CD),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (price != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'From ${_formatPrice(price)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: UiTone.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      category.description.trim().isEmpty
                          ? category.name
                          : category.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.02,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${category.services.length} carefully packaged services with professionals, pricing, and support handled for you.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5E8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Explore service',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
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
    return SizedBox(
      height: 244,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: spotlight.length > 6 ? 6 : spotlight.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final item = spotlight[index];
          final price = item.service.startsFrom ?? item.service.basePrice;
          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => _openCategory(item.category),
            child: Container(
              width: 164,
              padding: const EdgeInsets.all(10),
              decoration: elevatedSurface(
                radius: 24,
                color: const Color(0xFFFFFBF6),
                border: const Color(0xFFE6DCCD),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildImage(
                    item.service.imageUrl,
                    height: 114,
                    width: 144,
                    borderRadius: BorderRadius.circular(18),
                    fallbackIcon: Icons.self_improvement_outlined,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EEE4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: UiTone.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.service.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    item.service.description.trim().isEmpty
                        ? item.category.name
                        : item.service.description.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF676B73),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
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

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => _openCategory(category),
        child: Ink(
          decoration: elevatedSurface(
            radius: 30,
            color: const Color(0xFFFFFBF7),
            border: const Color(0xFFE6DCCD),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  _buildImage(
                    category.imageUrl,
                    height: 196,
                    width: double.infinity,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    fallbackIcon: Icons.cleaning_services_outlined,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: <Color>[
                            Color(0xD112223A),
                            Color(0x5012223A),
                            Color(0x1012223A),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            category.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      price == null
                          ? '${category.services.length} curated services'
                          : 'Starts at ${_formatPrice(price)}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF5F6470),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            '${category.services.length} bookable services',
                            style: const TextStyle(
                              fontSize: 13,
                              color: UiTone.softText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Text(
                          'View details',
                          style: TextStyle(
                            color: UiTone.secondary,
                            fontWeight: FontWeight.w800,
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
      child: ColoredBox(
        color: const Color(0xFFF3F4F6),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: _buildHeroSection(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'All house help services',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Schedule & book for later',
                      style: TextStyle(
                        color: UiTone.softText,
                        fontWeight: FontWeight.w600,
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
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final row = services[index];
                    return _serviceGridCard(
                      category: row.category,
                      service: row.service,
                    );
                  }, childCount: services.length),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.72,
                  ),
                ),
              ),
          ],
        ),
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
  bool _loading = true;
  int _minutes = 30;

  @override
  void initState() {
    super.initState();
    _selectedService = widget.category.services.isNotEmpty
        ? widget.category.services.first
        : null;
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final service = _selectedService;
    if (service == null) {
      setState(() {
        _providers = <ProviderItem>[];
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final providers = await widget.api.fetchProviders(
        serviceId: service.id,
        city: widget.currentCity,
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
          _loading = false;
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

  Widget _providerCard(ProviderItem provider, ServiceItem service) {
    final price = provider.price ?? service.startsFrom ?? service.basePrice;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: elevatedSurface(radius: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                imageOrPlaceholder(
                  service.imageUrl,
                  width: 88,
                  height: 88,
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                  fallbackIcon: Icons.content_cut_rounded,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        provider.fullName.isEmpty
                            ? provider.username
                            : provider.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: UiTone.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service.description.trim().isEmpty
                            ? 'Delivered by a trusted pro for polished at-home service.'
                            : service.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: UiTone.softText,
                          fontSize: 12.5,
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
                        'Starting from',
                        style: TextStyle(
                          color: UiTone.softText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPrice(price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CreateBookingPage(
                          api: widget.api,
                          service: service,
                          provider: provider,
                          onSessionExpired: widget.onSessionExpired,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Book Now'),
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

  @override
  Widget build(BuildContext context) {
    if (widget.category.services.isEmpty) {
      return Scaffold(
        backgroundColor: UiTone.shellBackground,
        appBar: AppBar(title: Text(widget.category.name)),
        body: emptyView('No services available in this category yet'),
      );
    }

    final selected = _selectedService ?? widget.category.services.first;
    final selectedPrice = selected.startsFrom ?? selected.basePrice;
    final partnerServices = widget.category.services
        .where((service) => service.id != selected.id)
        .take(6)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: <Widget>[
              Stack(
                children: <Widget>[
                  imageOrPlaceholder(
                    selected.imageUrl,
                    width: double.infinity,
                    height: 290,
                    borderRadius: BorderRadius.zero,
                    fallbackIcon: Icons.cleaning_services_outlined,
                  ),
                  Positioned(
                    left: 14,
                    top: 44,
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 14,
                    top: 44,
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: Icon(Icons.share_outlined, color: Colors.white),
                    ),
                  ),
                ],
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                selected.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: <Widget>[
                                  Text(
                                    _formatPrice(selectedPrice),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatPrice(selected.basePrice),
                                    style: const TextStyle(
                                      color: UiTone.softText,
                                      decoration: TextDecoration.lineThrough,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF25B36E)),
                          ),
                          child: Row(
                            children: <Widget>[
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _minutes = (_minutes - 15).clamp(15, 180);
                                  });
                                },
                                icon: const Icon(Icons.remove),
                                visualDensity: VisualDensity.compact,
                              ),
                              Text(
                                '$_minutes',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF17A85E),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _minutes = (_minutes + 15).clamp(15, 180);
                                  });
                                },
                                icon: const Icon(Icons.add),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: <Widget>[
                        Text(
                          '⭐ 4.9 (19.4k ratings)',
                          style: TextStyle(
                            color: UiTone.softText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Frequently added together',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 184,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: partnerServices.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final service = partnerServices[index];
                          final price = service.startsFrom ?? service.basePrice;
                          return Container(
                            width: 142,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE7E9EE),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                imageOrPlaceholder(
                                  service.imageUrl,
                                  width: 124,
                                  height: 84,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                  fallbackIcon:
                                      Icons.cleaning_services_outlined,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  service.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _formatPrice(price),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Includes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _benefitRow(
                      selected.description.trim().isEmpty
                          ? 'Deep cleaning designed for spotless finish'
                          : selected.description.trim(),
                    ),
                    _benefitRow(
                      'Experienced and background-verified professionals',
                    ),
                    _benefitRow('All tools and products included'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E5EB)),
          ),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '1 services',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    if (_providers.isEmpty) {
                      showApiError(
                        context,
                        const ApiException(
                          'No providers found in selected city',
                        ),
                      );
                      return;
                    }
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CreateBookingPage(
                          api: widget.api,
                          service: selected,
                          provider: _providers.first,
                          onSessionExpired: widget.onSessionExpired,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B766),
                  ),
                  child: const Text('Go to cart'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateBookingPage extends StatefulWidget {
  const CreateBookingPage({
    super.key,
    required this.api,
    required this.service,
    required this.provider,
    required this.onSessionExpired,
  });

  final ApiService api;
  final ServiceItem service;
  final ProviderItem provider;
  final VoidCallback onSessionExpired;

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  final _addressController = TextEditingController();
  final _locationController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _notesController = TextEditingController();

  bool _loadingServices = true;
  bool _submitting = false;
  bool _detectingAddress = false;
  List<ServiceItem> _providerServices = <ServiceItem>[];
  final Set<int> _selectedServiceIds = <int>{};

  final String _timeSlot = 'MORNING';
  final DateTime _date = DateTime.now();
  final bool _avoidCalls = true;
  final bool _sendOffers = true;
  int _cartMode = 1;

  @override
  void initState() {
    super.initState();
    _selectedServiceIds.add(widget.service.id);
    _loadProviderServices();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _locationController.dispose();
    _landmarkController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProviderServices() async {
    try {
      final services = await widget.api.fetchProviderServicesForBooking(
        widget.provider.userId,
      );
      if (!mounted) return;
      setState(() {
        _providerServices = services;
        _loadingServices = false;
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (!mounted) return;
      showApiError(context, error);
      setState(() {
        _loadingServices = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_addressController.text.trim().isEmpty) {
      showApiError(context, const ApiException('Address is required'));
      return;
    }
    if (_selectedServiceIds.isEmpty) {
      showApiError(context, const ApiException('Select at least one service'));
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
      final bookingId = await widget.api.createBooking(
        service: widget.service.id,
        provider: widget.provider.userId,
        scheduledDate:
            '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
        timeSlot: _timeSlot,
        address: lines.join('\n'),
        serviceIds: _selectedServiceIds.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking created. ID #$bookingId')),
      );
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
      final location =
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}'
          '${cityState.isEmpty ? '' : ' ($cityState)'}';
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
      showApiError(context, error);
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
    final allServices = <ServiceItem>[widget.service, ..._providerServices];
    final seen = <int>{};
    final unique = allServices
        .where((service) => seen.add(service.id))
        .toList();
    return unique
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
          Icon(icon, size: 14, color: const Color(0xFFFFE2C7)),
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

  @override
  Widget build(BuildContext context) {
    final selectedServices = _selectedServices();
    final subtotal = _subtotal();
    final fees = _taxesAndFees();
    final total = subtotal + fees;
    final selected = selectedServices.isEmpty
        ? widget.service
        : selectedServices.first;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F7),
      appBar: AppBar(title: const Text('My Cart')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: const Color(0xFF10B766),
          ),
          child: Text(_submitting ? 'Processing...' : 'Select time slot'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE1E5EB)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () => setState(() => _cartMode = 0),
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _cartMode == 0
                          ? const Color(0xFF154A30)
                          : Colors.transparent,
                      foregroundColor: _cartMode == 0
                          ? Colors.white
                          : UiTone.softText,
                    ),
                    child: const Text('Instant'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => setState(() => _cartMode = 1),
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _cartMode == 1
                          ? const Color(0xFF154A30)
                          : Colors.transparent,
                      foregroundColor: _cartMode == 1
                          ? Colors.white
                          : UiTone.softText,
                    ),
                    child: const Text('Scheduled'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => setState(() => _cartMode = 2),
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _cartMode == 2
                          ? const Color(0xFF154A30)
                          : Colors.transparent,
                      foregroundColor: _cartMode == 2
                          ? Colors.white
                          : UiTone.softText,
                    ),
                    child: const Text('Recurring'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${selectedServices.length} service',
                      style: const TextStyle(
                        color: UiTone.softText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    imageOrPlaceholder(
                      selected.imageUrl,
                      width: 54,
                      height: 54,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      fallbackIcon: Icons.cleaning_services_outlined,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            selected.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            _formatPrice(
                              selected.startsFrom ?? selected.basePrice,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1FB96C)),
                      ),
                      child: const Row(
                        children: <Widget>[
                          Icon(
                            Icons.remove,
                            size: 16,
                            color: Color(0xFF1FB96C),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '30',
                            style: TextStyle(
                              color: Color(0xFF1FB96C),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.add, size: 16, color: Color(0xFF1FB96C)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Center(
                  child: Text(
                    'Missed something? Add more services.',
                    style: TextStyle(
                      color: Color(0xFF13B76A),
                      fontWeight: FontWeight.w700,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.location_on_outlined,
                      color: UiTone.softText,
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
                const Row(
                  children: <Widget>[
                    Icon(Icons.phone_outlined, color: UiTone.softText),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'To pay ${_formatPrice(total)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '₹101 saved on the total!',
                  style: TextStyle(
                    color: Color(0xFF1F77E0),
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

class CustomerBookingsTab extends StatefulWidget {
  const CustomerBookingsTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<CustomerBookingsTab> createState() => _CustomerBookingsTabState();
}

class _CustomerBookingsTabState extends State<CustomerBookingsTab> {
  bool _loading = true;
  List<BookingItem> _bookings = <BookingItem>[];
  bool _showUpcoming = true;
  bool _showOneTime = true;

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

  @override
  Widget build(BuildContext context) {
    final visibleBookings = _bookings.where((booking) {
      final isPast =
          booking.status == 'COMPLETED' || booking.status == 'CANCELLED';
      if (_showUpcoming && isPast) return false;
      if (!_showUpcoming && !isPast) return false;
      if (!_showOneTime && booking.timeSlot == 'MORNING') return false;
      return true;
    }).toList();

    if (_loading) {
      return loadingView();
    }
    if (visibleBookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 22),
          children: <Widget>[
            const Text(
              'Your bookings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showUpcoming = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 3,
                            color: _showUpcoming
                                ? const Color(0xFF13B76A)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Text(
                        'Upcoming',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _showUpcoming ? UiTone.ink : UiTone.softText,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showUpcoming = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 3,
                            color: !_showUpcoming
                                ? const Color(0xFF13B76A)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Text(
                        'Past',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: !_showUpcoming ? UiTone.ink : UiTone.softText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE0E5EB)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _showOneTime = true;
                        });
                      },
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: _showOneTime
                            ? const Color(0xFF13B76A)
                            : Colors.transparent,
                        foregroundColor: _showOneTime
                            ? Colors.white
                            : UiTone.softText,
                      ),
                      child: const Text('One-time'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _showOneTime = false;
                        });
                      },
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: !_showOneTime
                            ? const Color(0xFF13B76A)
                            : Colors.transparent,
                        foregroundColor: !_showOneTime
                            ? Colors.white
                            : UiTone.softText,
                      ),
                      child: const Text('Recurring'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 120),
            const Center(
              child: Icon(
                Icons.event_note_rounded,
                size: 70,
                color: Color(0xFF9CB7A2),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _showUpcoming ? 'No upcoming bookings' : 'No past bookings',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: visibleBookings.length,
        itemBuilder: (context, index) {
          final booking = visibleBookings[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: elevatedSurface(radius: 26),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              booking.serviceLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: UiTone.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Booking #${booking.id}',
                              style: const TextStyle(
                                color: UiTone.softText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusPill(booking.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _bookingMeta(
                        Icons.calendar_today_outlined,
                        booking.scheduledDate,
                      ),
                      _bookingMeta(
                        Icons.schedule_outlined,
                        prettyStatus(booking.timeSlot),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Provider: ${booking.providerFullName.isEmpty ? booking.providerUsername : booking.providerFullName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: UiTone.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    booking.address,
                    style: const TextStyle(
                      color: UiTone.softText,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (booking.hasReview)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: UiTone.surfaceMuted,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Review: ${booking.reviewRating ?? '-'} / 5 • ${booking.reviewComment}',
                        style: const TextStyle(
                          color: UiTone.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (booking.status == 'COMPLETED')
                    FilledButton.tonalIcon(
                      onPressed: () => _openReviewDialog(booking),
                      icon: const Icon(Icons.reviews_outlined),
                      label: const Text('Add Review'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _bookingMeta(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: UiTone.ink,
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
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  bool _loading = true;
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
      await _load();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _markAll() async {
    try {
      await widget.api.markAllNotificationsRead();
      await _load();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          IconButton(
            onPressed: _items.isEmpty ? null : _markAll,
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all read',
          ),
        ],
      ),
      body: _loading
          ? loadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: elevatedSurface(
                            radius: 28,
                            color: const Color(0xFFFFF5E7),
                            border: const Color(0xFFE6D5BE),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Updates from your bookings appear here.',
                                style: TextStyle(
                                  color: UiTone.ink,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'You will see provider confirmations, booking changes, and review reminders in one calm inbox.',
                                style: TextStyle(
                                  color: UiTone.softText,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        emptyView('No notifications'),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: elevatedSurface(radius: 22),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: item.isRead
                                    ? UiTone.surfaceMuted
                                    : UiTone.primarySoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                item.isRead
                                    ? Icons.notifications_none
                                    : Icons.notifications_active,
                                color: item.isRead
                                    ? UiTone.softText
                                    : UiTone.primary,
                              ),
                            ),
                            title: Text(
                              item.message,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: UiTone.ink,
                              ),
                            ),
                            subtitle: Text(item.createdAt),
                            trailing: item.isRead
                                ? null
                                : TextButton(
                                    onPressed: () => _markRead(item.id),
                                    child: const Text('Mark read'),
                                  ),
                          ),
                        );
                      },
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
  });

  final ApiService api;
  final UserProfile profile;
  final Future<void> Function() onRefreshProfile;
  final Future<void> Function() onLogout;
  final VoidCallback onSessionExpired;

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _updatingProfile = false;
  bool _changingPassword = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _emailController = TextEditingController(text: widget.profile.email);
  }

  @override
  void didUpdateWidget(covariant AccountTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.fullName != widget.profile.fullName) {
      _fullNameController.text = widget.profile.fullName;
    }
    if (oldWidget.profile.email != widget.profile.email) {
      _emailController.text = widget.profile.email;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_fullNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      showApiError(
        context,
        const ApiException('Full name and email are required'),
      );
      return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _updatingProfile = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      showApiError(
        context,
        const ApiException('All password fields are required'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTone.shellBackground,
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: elevatedSurface(
              radius: 28,
              color: const Color(0xFF16345C),
              border: const Color(0xFF214977),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Your account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.profile.fullName.isEmpty
                      ? widget.profile.username
                      : widget.profile.fullName,
                  style: const TextStyle(
                    color: Color(0xFFD5E3F8),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _accountChip(
                      Icons.alternate_email_rounded,
                      widget.profile.username,
                    ),
                    _accountChip(
                      Icons.call_outlined,
                      widget.profile.phone.isEmpty
                          ? 'No phone'
                          : widget.profile.phone,
                    ),
                    _accountChip(
                      Icons.verified_user_outlined,
                      widget.profile.role,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: elevatedSurface(radius: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Profile details',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _updatingProfile ? null : _updateProfile,
                  child: Text(_updatingProfile ? 'Saving...' : 'Save Changes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: elevatedSurface(radius: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Security',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _changingPassword ? null : _changePassword,
                  child: Text(
                    _changingPassword ? 'Updating...' : 'Update Password',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
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
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _accountChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: const Color(0xFFFFE2C7)),
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
