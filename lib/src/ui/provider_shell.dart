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

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      ProviderDashboardTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
      ),
      ProviderServicesTab(
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
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Services',
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

class ProviderDashboardTab extends StatefulWidget {
  const ProviderDashboardTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<ProviderDashboardTab> createState() => _ProviderDashboardTabState();
}

class _ProviderDashboardTabState extends State<ProviderDashboardTab> {
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
      final bookings = await widget.api.fetchProviderDashboardBookings();
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
    try {
      await widget.api.providerUpdateStatus(
        bookingId: bookingId,
        status: status,
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
    if (booking.status == 'CONFIRMED') {
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

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return Container(
      width: 134,
      padding: const EdgeInsets.all(12),
      decoration: elevatedSurface(radius: 20),
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
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: UiTone.softText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _bookingCard(BookingItem booking) {
    return Container(
      decoration: elevatedSurface(radius: 24),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor(booking.status).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    prettyStatus(booking.status),
                    style: TextStyle(
                      color: statusColor(booking.status),
                      fontWeight: FontWeight.w700,
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
                _metaPill(Icons.calendar_today_outlined, booking.scheduledDate),
                _metaPill(Icons.schedule_outlined, prettyStatus(booking.timeSlot)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              booking.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: UiTone.softText,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            _actionButtons(booking),
          ],
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _bookings.length;
    final pending = _bookings.where((e) => e.status == 'PENDING').length;
    final confirmed = _bookings.where((e) => e.status == 'CONFIRMED').length;
    final inProgress = _bookings.where((e) => e.status == 'IN_PROGRESS').length;
    final completed = _bookings.where((e) => e.status == 'COMPLETED').length;

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
                color: const Color(0xFF16345C),
                radius: 28,
                border: const Color(0xFF214977),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Provider command center',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$total jobs flowing through your pipeline right now',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
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
                    'Total',
                    total,
                    Icons.dashboard_rounded,
                    const Color(0xFF345CE4),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'Pending',
                    pending,
                    Icons.pending_actions_rounded,
                    const Color(0xFFF08A24),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'Confirmed',
                    confirmed,
                    Icons.verified_rounded,
                    const Color(0xFF0F8A77),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'In Progress',
                    inProgress,
                    Icons.handyman_rounded,
                    const Color(0xFF6A4FE8),
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'Completed',
                    completed,
                    Icons.task_alt_rounded,
                    const Color(0xFF0A8D60),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final booking = _bookings[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _bookings.length - 1 ? 0 : 10,
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
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<ProviderServicesTab> createState() => _ProviderServicesTabState();
}

class _ProviderServicesTabState extends State<ProviderServicesTab> {
  bool _loading = true;
  List<ServiceCategory> _categories = <ServiceCategory>[];
  List<BasicService> _myServices = <BasicService>[];
  List<ProviderServicePrice> _prices = <ProviderServicePrice>[];

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
    final selectable = _allServices
        .where((s) => !_myServices.any((m) => m.id == s.id))
        .toList();
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
                radius: 28,
                color: const Color(0xFFFFF5E7),
                border: const Color(0xFFE6D5BE),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Your service catalog',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
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
                decoration: elevatedSurface(radius: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Add a new service',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedServiceToAdd,
                        items: selectable
                            .map(
                              (service) => DropdownMenuItem<int>(
                                value: service.id,
                                child: Text(service.name),
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
                      decoration: elevatedSurface(radius: 24),
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
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
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
