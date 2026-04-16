import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import 'common.dart';
import 'customer_shell.dart';

class ProviderShell extends StatefulWidget {
  const ProviderShell({
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
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _index = 0;

  void _openDashboardBookings() {
    setState(() {
      _index = 0;
    });
  }

  void _openDashboardHome() {
    setState(() {
      _index = 0;
    });
  }

  void _openAlertsTab() {
    setState(() {
      _index = 2;
    });
  }

  void _openProfileTab() {
    setState(() {
      _index = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      ProviderDashboardTab(
        api: widget.api,
        profile: widget.profile,
        onSessionExpired: widget.onSessionExpired,
        onOpenAlerts: _openAlertsTab,
        onOpenProfile: _openProfileTab,
      ),
      ProviderServicesTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
        onBack: _openDashboardHome,
      ),
      NotificationsTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
        onBack: _openDashboardHome,
      ),
      AccountTab(
        api: widget.api,
        profile: widget.profile,
        onRefreshProfile: widget.onRefreshProfile,
        onLogout: widget.onLogout,
        onSessionExpired: widget.onSessionExpired,
        onOpenBookings: _openDashboardBookings,
        onBack: _openDashboardHome,
      ),
    ];

    return Scaffold(
      body: ColoredBox(
        color: UiTone.shellBackground,
        child: SafeArea(child: tabs[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index > 1 ? 0 : _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, size: 24),
            selectedIcon: Icon(Icons.dashboard_rounded, size: 24),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined, size: 23),
            selectedIcon: Icon(Icons.build_rounded, size: 23),
            label: 'Services',
          ),
        ],
      ),
    );
  }
}

class ProviderDashboardTab extends StatefulWidget {
  const ProviderDashboardTab({
    super.key,
    required this.api,
    required this.profile,
    required this.onSessionExpired,
    required this.onOpenAlerts,
    required this.onOpenProfile,
  });

  final ApiService api;
  final UserProfile profile;
  final VoidCallback onSessionExpired;
  final VoidCallback onOpenAlerts;
  final VoidCallback onOpenProfile;

  @override
  State<ProviderDashboardTab> createState() => _ProviderDashboardTabState();
}

class _ProviderDashboardTabState extends State<ProviderDashboardTab> {
  bool _loading = true;
  List<BookingItem> _bookings = <BookingItem>[];
  Map<String, double> _priceByServiceName = <String, double>{};

  String _serviceKey(String name) => name.trim().toLowerCase();

  double _amountFor(BookingItem booking) {
    final names = booking.serviceNames.isNotEmpty
        ? booking.serviceNames
        : <String>[booking.serviceName];
    var total = 0.0;
    var matchedAny = false;
    for (final raw in names) {
      final matched = _priceByServiceName[_serviceKey(raw)];
      if (matched != null && matched > 0) {
        total += matched;
        matchedAny = true;
      } else {
        total += 25;
      }
    }
    if (!matchedAny && names.length > 1) {
      total = names.length * 25;
    }
    return total + 2.52;
  }

  double _earningForBooking(BookingItem booking) {
    final names = booking.serviceNames.isNotEmpty
        ? booking.serviceNames
        : <String>[booking.serviceName];
    var total = 0.0;
    for (final raw in names) {
      final matched = _priceByServiceName[_serviceKey(raw)];
      total += matched != null && matched > 0 ? matched : 25;
    }
    return total;
  }

  Future<void> _openBookingSummary(BookingItem booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingSummaryPage(
          booking: booking,
          amountPaid: _amountFor(booking),
          supportApi: widget.api,
          onSessionExpired: widget.onSessionExpired,
          supportRole: 'PROVIDER',
          preselectedBookingId: booking.id,
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
      final results = await Future.wait<dynamic>([
        widget.api.fetchProviderDashboardBookings(),
        widget.api.fetchProviderMyServicePrices(),
      ]);
      final bookings = results[0] as List<BookingItem>;
      final prices = results[1] as List<ProviderServicePrice>;
      final map = <String, double>{};
      for (final row in prices) {
        map[_serviceKey(row.serviceName)] = row.price;
      }
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _priceByServiceName = map;
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

  Future<void> _providerAction(int bookingId, String action) async {
    try {
      await widget.api.providerAction(bookingId: bookingId, action: action);
      await _load();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _providerStatus(int bookingId, String status) async {
    String? otp;
    if (status == 'IN_PROGRESS' || status == 'COMPLETED') {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              status == 'IN_PROGRESS' ? 'Enter Start OTP' : 'Enter End OTP',
            ),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: '4-digit OTP',
                counterText: '',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Verify'),
              ),
            ],
          );
        },
      );
      otp = controller.text.trim();
      controller.dispose();
      if (confirmed != true) return;
      if (otp.length != 4) {
        if (!mounted) return;
        showApiError(context, const ApiException('Enter valid 4-digit OTP'));
        return;
      }
    }
    try {
      await widget.api.providerUpdateStatus(
        bookingId: bookingId,
        status: status,
        otp: otp,
      );
      await _load();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  Widget _actionButtons(BookingItem booking) {
    if (booking.status == 'PENDING') {
      return Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.tonal(
              onPressed: () => _providerAction(booking.id, 'accept'),
              child: const Text('Accept'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _providerAction(booking.id, 'reject'),
              child: const Text('Reject'),
            ),
          ),
        ],
      );
    }
    if (booking.status == 'ASSIGNED') {
      return FilledButton(
        onPressed: () => _providerStatus(booking.id, 'IN_PROGRESS'),
        child: const Text('Start Job'),
      );
    }
    if (booking.status == 'ACCEPTED' || booking.status == 'CONFIRMED') {
      return FilledButton(
        onPressed: () => _providerStatus(booking.id, 'IN_PROGRESS'),
        child: const Text('Start Job'),
      );
    }
    if (booking.status == 'IN_PROGRESS') {
      return FilledButton(
        onPressed: () => _providerStatus(booking.id, 'COMPLETED'),
        child: const Text('Complete Job'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 134,
      padding: const EdgeInsets.all(12),
      decoration: elevatedSurface(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: UiTone.softText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(BookingItem booking) {
    return InkWell(
      onTap: () => _openBookingSummary(booking),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: elevatedSurface(radius: 20),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: UiTone.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Booking #${booking.id}',
                          style: const TextStyle(
                            color: UiTone.softText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor(
                        booking.status,
                      ).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      prettyStatus(booking.status),
                      style: TextStyle(
                        color: statusColor(booking.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _metaPill(Icons.person_outline, booking.customerUsername),
                  _metaPill(
                    Icons.calendar_today_outlined,
                    booking.scheduledDate,
                  ),
                  _metaPill(
                    Icons.schedule_outlined,
                    prettyStatus(booking.timeSlot),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                booking.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: UiTone.softText, height: 1.35),
              ),
              const SizedBox(height: 14),
              if (booking.status == 'COMPLETED') ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Earnings: ₹${_earningForBooking(booking).toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF0D7C66),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _actionButtons(booking),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaPill(IconData icon, String text) {
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
            text,
            style: const TextStyle(
              color: UiTone.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _providerLocationLabel() {
    final city = widget.profile.city.trim();
    if (city.isNotEmpty) return city;
    return 'Location not set';
  }

  @override
  Widget build(BuildContext context) {
    final total = _bookings.length;
    final pending = _bookings
        .where((e) => e.status == 'PENDING' || e.status == 'ASSIGNED')
        .length;
    final confirmed = _bookings
        .where((e) => e.status == 'ACCEPTED' || e.status == 'CONFIRMED')
        .length;
    final inProgress = _bookings.where((e) => e.status == 'IN_PROGRESS').length;
    final completed = _bookings.where((e) => e.status == 'COMPLETED').length;
    final totalEarnings = _bookings
        .where((e) => e.status == 'COMPLETED')
        .fold<double>(0, (sum, booking) => sum + _earningForBooking(booking));

    if (_loading) return loadingView();

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: elevatedSurface(
                color: const Color(0xFF0F3D32),
                radius: 24,
                border: const Color(0xFF1A5E4A),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Provider command center',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onOpenAlerts,
                        tooltip: 'Alerts',
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onOpenProfile,
                        tooltip: 'Profile',
                        icon: const Icon(
                          Icons.account_circle_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.96),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _providerLocationLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.96),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$total jobs flowing through your pipeline right now',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total earnings: ₹${totalEarnings.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFFA8E6CF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const <Widget>[
                      _ProviderHeroPill(
                        icon: Icons.bolt_rounded,
                        label: 'Fast actions',
                      ),
                      _ProviderHeroPill(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Premium workflow',
                      ),
                      _ProviderHeroPill(
                        icon: Icons.task_alt_outlined,
                        label: 'Clear status tracking',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 132,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                children: <Widget>[
                  _statCard(
                    'Earnings',
                    '₹${totalEarnings.toStringAsFixed(0)}',
                    Icons.currency_rupee_rounded,
                    const Color(0xFF0D7C66),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'Total',
                    '$total',
                    Icons.dashboard_rounded,
                    const Color(0xFF0D7C66),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'Pending',
                    '$pending',
                    Icons.pending_actions_rounded,
                    const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'Confirmed',
                    '$confirmed',
                    Icons.verified_rounded,
                    const Color(0xFF0EA5E9),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'In Progress',
                    '$inProgress',
                    Icons.handyman_rounded,
                    const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'Completed',
                    '$completed',
                    Icons.task_alt_rounded,
                    const Color(0xFF059669),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: sectionTitle(
              'Incoming Jobs',
              subtitle: 'Manage actions and update statuses quickly',
            ),
          ),
          if (_bookings.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: emptyView('No provider bookings yet'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final booking = _bookings[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _bookings.length - 1 ? 0 : 12,
                    ),
                    child: _bookingCard(booking),
                  );
                }, childCount: _bookings.length),
              ),
            ),
        ],
      ),
    );
  }
}

class ProviderServicesTab extends StatefulWidget {
  const ProviderServicesTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
    this.onBack,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final VoidCallback? onBack;

  @override
  State<ProviderServicesTab> createState() => _ProviderServicesTabState();
}

class _ProviderServicesTabState extends State<ProviderServicesTab> {
  bool _loading = true;
  List<ServiceCategory> _categories = <ServiceCategory>[];
  List<BasicService> _myServices = <BasicService>[];
  List<ProviderServicePrice> _prices = <ProviderServicePrice>[];
  final TextEditingController _serviceSearchController =
      TextEditingController();
  String _serviceSearchQuery = '';

  final Map<int, TextEditingController> _priceControllers =
      <int, TextEditingController>{};
  int? _selectedServiceToAdd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _serviceSearchController.dispose();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      final results = await Future.wait([
        widget.api.fetchCategories(),
        widget.api.fetchProviderMyServices(),
        widget.api.fetchProviderMyServicePrices(),
      ]);
      if (!mounted) return;

      _categories = results[0] as List<ServiceCategory>;
      _myServices = results[1] as List<BasicService>;
      _prices = results[2] as List<ProviderServicePrice>;

      for (final price in _prices) {
        _priceControllers.putIfAbsent(
          price.serviceId,
          () => TextEditingController(text: price.price.toStringAsFixed(0)),
        );
      }

      final selectable = _allServices
          .where((s) => !_myServices.any((m) => m.id == s.id))
          .toList();
      _selectedServiceToAdd = selectable.isEmpty ? null : selectable.first.id;

      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<BasicService> get _allServices {
    final list = <BasicService>[];
    for (final category in _categories) {
      for (final service in category.services) {
        list.add(
          BasicService(
            id: service.id,
            name: '${category.name} - ${service.name}',
          ),
        );
      }
    }
    return list;
  }

  ServiceItem? _serviceItemById(int id) {
    for (final category in _categories) {
      for (final service in category.services) {
        if (service.id == id) {
          return service;
        }
      }
    }
    return null;
  }

  Future<void> _addService() async {
    final selected = _selectedServiceToAdd;
    if (selected == null) return;
    final ids = _myServices.map((e) => e.id).toSet()..add(selected);
    try {
      await widget.api.updateProviderMyServices(ids.toList());
      await _load();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _removeService(int serviceId) async {
    final ids = _myServices
        .map((e) => e.id)
        .where((id) => id != serviceId)
        .toList();
    try {
      await widget.api.updateProviderMyServices(ids);
      await _load();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _savePrices() async {
    final payload = <Map<String, dynamic>>[];
    for (final service in _myServices) {
      final raw = _priceControllers[service.id]?.text.trim() ?? '';
      final value = double.tryParse(raw);
      if (value == null || value <= 0) {
        showApiError(
          context,
          ApiException('Invalid price for ${service.name}'),
        );
        return;
      }
      payload.add({'service_id': service.id, 'price': value});
    }
    try {
      await widget.api.updateProviderMyServicePrices(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prices updated')));
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
    final selectableBase = _allServices
        .where((s) => !_myServices.any((m) => m.id == s.id))
        .toList();
    final normalizedQuery = _serviceSearchQuery.trim().toLowerCase();
    final selectable = normalizedQuery.isEmpty
        ? selectableBase
        : selectableBase
              .where((s) => s.name.toLowerCase().contains(normalizedQuery))
              .toList();
    final selectedServiceValue =
        selectable.any((service) => service.id == _selectedServiceToAdd)
        ? _selectedServiceToAdd
        : (selectable.isEmpty ? null : selectable.first.id);
    if (_loading) return loadingView();

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: sectionTitle(
              'Provider Services',
              subtitle: 'Manage your catalog and pricing',
              leading: widget.onBack == null
                  ? null
                  : IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: elevatedSurface(
                radius: 24,
                color: UiTone.primarySoft,
                border: UiTone.surfaceBorder,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Your service catalog',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_myServices.length} active services configured for your provider profile',
                    style: const TextStyle(color: UiTone.softText),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: elevatedSurface(radius: 20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Add a new service',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _serviceSearchController,
                        onChanged: (value) {
                          setState(() {
                            _serviceSearchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Search service',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _serviceSearchQuery.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _serviceSearchController.clear();
                                    setState(() {
                                      _serviceSearchQuery = '';
                                    });
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                  tooltip: 'Clear search',
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        key: ValueKey<String>(
                          'provider-service-${selectedServiceValue ?? -1}-${selectable.length}',
                        ),
                        initialValue: selectedServiceValue,
                        isExpanded: true,
                        items: selectable
                            .map(
                              (service) => DropdownMenuItem<int>(
                                value: service.id,
                                child: Text(
                                  service.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedServiceToAdd = value;
                          });
                        },
                        decoration: const InputDecoration(labelText: 'Service'),
                      ),
                      if (selectable.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'No matching services found',
                            style: TextStyle(
                              color: UiTone.softText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      FilledButton.tonal(
                        onPressed: selectable.isEmpty ? null : _addService,
                        child: const Text('Add to catalog'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: sectionTitle(
              'Pricing Setup',
              subtitle: 'Set what you charge for each service',
            ),
          ),
          if (_myServices.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: emptyView('No services added yet'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final service = _myServices[index];
                  final serviceItem = _serviceItemById(service.id);
                  final controller = _priceControllers.putIfAbsent(
                    service.id,
                    () {
                      final found = _prices
                          .where((p) => p.serviceId == service.id)
                          .toList();
                      final price = found.isEmpty ? 0 : found.first.price;
                      return TextEditingController(
                        text: price.toStringAsFixed(0),
                      );
                    },
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: elevatedSurface(radius: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            imageOrPlaceholder(
                              serviceItem?.imageUrl ?? '',
                              width: 78,
                              height: 78,
                              fallbackIcon: Icons.handyman_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    service.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: controller,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Price',
                                      prefixText: 'INR ',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: () => _removeService(service.id),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: _myServices.length),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              child: FilledButton(
                onPressed: _myServices.isEmpty ? null : _savePrices,
                child: const Text('Save Prices'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderHeroPill extends StatelessWidget {
  const _ProviderHeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
