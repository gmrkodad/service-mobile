import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';
import '../session.dart';
import 'common.dart';

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
        onSessionExpired: widget.onSessionExpired,
      ),
      CustomerBookingsTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
      ),
      NotificationsTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
      ),
      AccountTab(
        api: widget.api,
        profile: widget.profile,
        onRefreshProfile: widget.onRefreshProfile,
        onLogout: widget.onLogout,
        onSessionExpired: widget.onSessionExpired,
      ),
    ];

    return Scaffold(
      body: SafeArea(child: tabs[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
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
    required this.onSessionExpired,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();

  bool _loading = true;
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFF7ED), Color(0xFFF5E4CD)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3D3BC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.home_repair_service_rounded,
                  color: Color(0xFF1F232B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  city.isEmpty ? 'Home Services' : city,
                  style: TextStyle(
                    color: const Color(0xFF191B1F),
                    fontSize: city.isEmpty ? 19 : 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.search_rounded, color: Color(0xFF282C33)),
              const SizedBox(width: 14),
              const Icon(Icons.share_outlined, color: Color(0xFF282C33)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            city.isEmpty
                ? 'Discover polished at-home services and book in minutes.'
                : 'Serving $city right now with curated, top-rated professionals.',
            style: TextStyle(
              color: const Color(0xFF44474E),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _heroTag(Icons.check_circle_outline, 'Experienced professionals'),
              _heroTag(Icons.sell_outlined, 'Affordable prices'),
              _heroTag(Icons.flash_on_outlined, 'Mess-free service'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: const Color(0xFF23262B)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF23262B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAndSearchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4E7EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.place_outlined, color: Color(0xFF3E434C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _normalizeCity(_cityController.text).isEmpty
                      ? 'Set your service city'
                      : _normalizeCity(_cityController.text),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton(onPressed: _saveCity, child: const Text('Update')),
            ],
          ),
          const SizedBox(height: 10),
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
                _smallFilter('Instant slots'),
                _smallFilter('4.5+ rated'),
                _smallFilter('Top offers'),
                _smallFilter('At-home'),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTopCategories(List<ServiceCategory> categories) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length > 8 ? 8 : categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openCategory(category),
            child: Container(
              width: 92,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: <Widget>[
                  _buildImage(
                    category.imageUrl,
                    height: 58,
                    width: 58,
                    borderRadius: BorderRadius.circular(14),
                    fallbackIcon: Icons.miscellaneous_services_outlined,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.2,
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
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = actions[index];
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openCategory(category),
            child: Container(
              width: 230,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: category.imageUrl.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(category.imageUrl),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                      ),
                color: const Color(0xFFE9EDF3),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Spacer(),
                    Text(
                      category.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description.trim().isEmpty
                          ? 'Fresh looks and easy at-home bookings'
                          : category.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Book now',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: spotlight.length > 6 ? 6 : spotlight.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = spotlight[index];
          final price = item.service.startsFrom ?? item.service.basePrice;
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openCategory(item.category),
            child: SizedBox(
              width: 132,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildImage(
                    item.service.imageUrl,
                    height: 112,
                    width: 132,
                    borderRadius: BorderRadius.circular(16),
                    fallbackIcon: Icons.self_improvement_outlined,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.service.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openCategory(category),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE7E8EC)),
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
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    fallbackIcon: Icons.cleaning_services_outlined,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: <Color>[
                            Color(0xD8171A1F),
                            Color(0x40171A1F),
                            Color(0x10171A1F),
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
                        Text(
                          category.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        price == null
                            ? '${category.services.length} curated services'
                            : 'Starts at ${_formatPrice(price)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF5F6470),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Text(
                      'Explore',
                      style: TextStyle(
                        color: Color(0xFF6E26FF),
                        fontWeight: FontWeight.w700,
                      ),
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
    final query = _searchQuery;
    final filtered = _filteredCategories;
    final spotlight = _spotlight;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    if (_loading) {
      return loadingView();
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      child: ColoredBox(
        color: const Color(0xFFF6F8FB),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: <Widget>[
            if (!keyboardVisible)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildHeroSection(),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  keyboardVisible ? 12 : 12,
                  16,
                  0,
                ),
                child: _buildLocationAndSearchCard(),
              ),
            ),
            if (!keyboardVisible && filtered.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Quick Book',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildQuickActions(filtered),
                    ],
                  ),
                ),
              ),
            if (!keyboardVisible && filtered.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Top Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Popular choices for your home',
                        style: TextStyle(
                          color: Color(0xFF5D6E7D),
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildTopCategories(filtered),
                    ],
                  ),
                ),
              ),
            if (!keyboardVisible && spotlight.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Text(
                          'Most Booked Services',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _buildSpotlightStrip(spotlight),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      keyboardVisible
                          ? 'Search Results'
                          : filtered.isEmpty
                          ? 'Services'
                          : 'All Services',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!keyboardVisible && filtered.isNotEmpty)
                      Text(
                        '${filtered.length} categories near you',
                        style: const TextStyle(
                          color: Color(0xFF5D6E7D),
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: emptyView(
                  query.isEmpty
                      ? 'No services found.'
                      : 'No services found for "$query".',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final category = filtered[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == filtered.length - 1 ? 0 : 12,
                      ),
                      child: _buildCategoryCard(category),
                    );
                  }, childCount: filtered.length),
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
            child: Icon(Icons.check_circle_outline, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EC)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.sell_rounded, color: Color(0xFF13A05F)),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          imageOrPlaceholder(
            service.imageUrl,
            width: 84,
            height: 84,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            fallbackIcon: Icons.content_cut_rounded,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  service.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  service.description.trim().isEmpty
                      ? 'Delivered by ${provider.fullName.isEmpty ? provider.username : provider.fullName}'
                      : service.description.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF666B74),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${provider.rating.toStringAsFixed(1)} (786K) | 55 mins',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666B74),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatPrice(price),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: <Widget>[
              FilledButton(
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
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2CFF),
                  minimumSize: const Size(76, 42),
                ),
                child: const Text('Add'),
              ),
              const SizedBox(height: 8),
              const Text(
                'View details',
                style: TextStyle(
                  color: Color(0xFF7B2CFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedService ?? widget.category.services.first;
    final selectedPrice = selected.startsFrom ?? selected.basePrice;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      appBar: AppBar(
        title: Text(widget.category.name),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5E4CD),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _benefitRow(
                          selected.description.trim().isEmpty
                              ? 'For a brighter at-home experience'
                              : selected.description.trim(),
                        ),
                        _benefitRow('Top-rated professionals'),
                        _benefitRow('Transparent pricing and quick slots'),
                      ],
                    ),
                  ),
                ),
                imageOrPlaceholder(
                  selected.imageUrl,
                  width: 162,
                  height: 188,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  fallbackIcon: Icons.spa_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            selected.name,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            '4.80 (3.4 M bookings)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                _offerChip('20% off on Kotak', 'Cashback up to INR 350'),
                const SizedBox(width: 10),
                _offerChip('CRED Cashback', 'Cashback up to INR 200'),
                const SizedBox(width: 10),
                _offerChip('Flat 15% off', 'Selected payment methods'),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Service menu',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.category.services.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final service = widget.category.services[index];
                final isSelected = selected.id == service.id;
                final price = service.startsFrom ?? service.basePrice;
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() {
                      _selectedService = service;
                    });
                    _loadProviders();
                  },
                  child: Container(
                    width: 108,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF4ECFF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF8F3DFF)
                            : const Color(0xFFE7E8ED),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        imageOrPlaceholder(
                          service.imageUrl,
                          width: 92,
                          height: 72,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12),
                          ),
                          fallbackIcon: Icons.face_retouching_natural_outlined,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          service.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.2,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatPrice(price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2228),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Professionals available',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'From ${_formatPrice(selectedPrice)}',
                style: const TextStyle(
                  color: Color(0xFF7B2CFF),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator()
          else if (_providers.isEmpty)
            emptyView('No professionals found in selected city')
          else
            ..._providers.map((provider) => _providerCard(provider, selected)),
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
  List<ServiceItem> _providerServices = <ServiceItem>[];
  final Set<int> _selectedServiceIds = <int>{};

  String _timeSlot = 'MORNING';
  DateTime _date = DateTime.now();
  bool _avoidCalls = true;
  bool _sendOffers = true;

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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
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
              backgroundColor: const Color(0xFF7B2CFF),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minDate = DateTime.now();
    final selectedServices = _selectedServices();
    final subtotal = _subtotal();
    final fees = _taxesAndFees();
    final total = subtotal + fees;
    final addonServices = _providerServices
        .where((service) => !_selectedServiceIds.contains(service.id))
        .take(4)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F7),
      appBar: AppBar(title: const Text('Summary')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7B2CFF),
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(
            _submitting
                ? 'Processing...'
                : total <= 0
                ? 'Make Payment'
                : 'Make Payment ${_formatPrice(total)}',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE6E8EE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: selectedServices.map((service) {
                final isCore = service.id == widget.service.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              service.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            if (isCore)
                              const Text(
                                'Primary service',
                                style: TextStyle(
                                  color: Color(0xFF6B707A),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isCore)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E4FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: <Widget>[
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedServiceIds.remove(service.id);
                                  });
                                },
                                icon: const Icon(Icons.remove, size: 16),
                                visualDensity: VisualDensity.compact,
                              ),
                              const Text('1'),
                              IconButton(
                                onPressed: null,
                                icon: const Icon(Icons.add, size: 16),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 12),
                      Text(
                        _formatPrice(_servicePrice(service)),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          if (!_loadingServices && addonServices.isNotEmpty) ...<Widget>[
            const Text(
              'Frequently added together',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 206,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: addonServices.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _addonCard(addonServices[index]),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE6E8EE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Service preferences',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                CheckboxListTile(
                  value: _avoidCalls,
                  onChanged: (value) {
                    setState(() {
                      _avoidCalls = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Avoid calling before reaching the location',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  value: _sendOffers,
                  onChanged: (value) {
                    setState(() {
                      _sendOffers = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Coupons and offers'),
                  secondary: const Text(
                    '7 offers',
                    style: TextStyle(
                      color: Color(0xFF7B2CFF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE6E8EE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Address and schedule',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Customer location (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _landmarkController,
                  decoration: const InputDecoration(
                    labelText: 'Landmark (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: minDate,
                            lastDate: minDate.add(const Duration(days: 365)),
                            initialDate: _date.isBefore(minDate)
                                ? minDate
                                : _date,
                          );
                          if (picked != null) {
                            setState(() {
                              _date = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          '${_date.day}/${_date.month}/${_date.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _timeSlot,
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'MORNING',
                            child: Text('Morning'),
                          ),
                          DropdownMenuItem(
                            value: 'AFTERNOON',
                            child: Text('Afternoon'),
                          ),
                          DropdownMenuItem(
                            value: 'EVENING',
                            child: Text('Evening'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _timeSlot = value;
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Time slot',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE6E8EE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Payment summary',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                _summaryRow('Item total', _formatPrice(subtotal)),
                _summaryRow('Taxes and fee', _formatPrice(fees)),
                const Divider(height: 20),
                _summaryRow('Total', _formatPrice(total), strong: true),
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
    if (_loading) {
      return loadingView();
    }
    if (_bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: <Widget>[emptyView('No bookings yet')]),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '#${booking.id} ${booking.serviceLabel}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        label: Text(prettyStatus(booking.status)),
                        backgroundColor: statusColor(
                          booking.status,
                        ).withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Date: ${booking.scheduledDate}  •  ${prettyStatus(booking.timeSlot)}',
                  ),
                  Text(
                    'Provider: ${booking.providerFullName.isEmpty ? booking.providerUsername : booking.providerFullName}',
                  ),
                  const SizedBox(height: 6),
                  Text('Address: ${booking.address}'),
                  const SizedBox(height: 10),
                  if (booking.hasReview)
                    Text(
                      'Review: ${booking.reviewRating ?? '-'} / 5 • ${booking.reviewComment}',
                    )
                  else if (booking.status == 'COMPLETED')
                    FilledButton.tonal(
                      onPressed: () => _openReviewDialog(booking),
                      child: const Text('Add Review'),
                    ),
                ],
              ),
            ),
          );
        },
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
                  ? ListView(children: <Widget>[emptyView('No notifications')])
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          leading: Icon(
                            item.isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                          ),
                          title: Text(item.message),
                          subtitle: Text(item.createdAt),
                          trailing: item.isRead
                              ? null
                              : TextButton(
                                  onPressed: () => _markRead(item.id),
                                  child: const Text('Mark read'),
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
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Profile',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Username: ${widget.profile.username}'),
                  Text('Phone: ${widget.profile.phone}'),
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
                    child: Text(
                      _updatingProfile ? 'Saving...' : 'Update Profile',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Change Password',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                    ),
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
                      _changingPassword ? 'Updating...' : 'Change Password',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
}
