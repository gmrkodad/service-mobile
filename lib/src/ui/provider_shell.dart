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
      body: SafeArea(child: tabs[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const <Widget>[
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: 'Services'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
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
      await widget.api.providerUpdateStatus(bookingId: bookingId, status: status);
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
          const SizedBox(width: 8),
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

  @override
  Widget build(BuildContext context) {
    final total = _bookings.length;
    final pending = _bookings.where((e) => e.status == 'PENDING').length;
    final confirmed = _bookings.where((e) => e.status == 'CONFIRMED').length;
    final inProgress = _bookings.where((e) => e.status == 'IN_PROGRESS').length;
    final completed = _bookings.where((e) => e.status == 'COMPLETED').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Provider Dashboard')),
      body: _loading
          ? loadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _statCard('Total', total),
                      _statCard('Pending', pending),
                      _statCard('Confirmed', confirmed),
                      _statCard('In Progress', inProgress),
                      _statCard('Completed', completed),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_bookings.isEmpty)
                    emptyView('No provider bookings yet')
                  else
                    ..._bookings.map((booking) {
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
                                    backgroundColor: statusColor(booking.status).withValues(alpha: 0.15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Customer: ${booking.customerUsername}'),
                              Text('Date: ${booking.scheduledDate}  •  ${prettyStatus(booking.timeSlot)}'),
                              Text('Address: ${booking.address}'),
                              const SizedBox(height: 10),
                              _actionButtons(booking),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, int value) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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

  final Map<int, TextEditingController> _priceControllers = <int, TextEditingController>{};
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

      final selectable = _allServices.where((s) => !_myServices.any((m) => m.id == s.id)).toList();
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
        list.add(BasicService(id: service.id, name: '${category.name} - ${service.name}'));
      }
    }
    return list;
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
    final ids = _myServices.map((e) => e.id).where((id) => id != serviceId).toList();
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
        showApiError(context, ApiException('Invalid price for ${service.name}'));
        return;
      }
      payload.add({'service_id': service.id, 'price': value});
    }
    try {
      await widget.api.updateProviderMyServicePrices(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prices updated')));
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
    final selectable = _allServices.where((s) => !_myServices.any((m) => m.id == s.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Services')),
      body: _loading
          ? loadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text('Add service', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: selectable.isEmpty ? null : _addService,
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_myServices.isEmpty)
                    emptyView('No services added yet')
                  else
                    ..._myServices.map((service) {
                      final controller = _priceControllers.putIfAbsent(service.id, () {
                        final found = _prices.where((p) => p.serviceId == service.id).toList();
                        final price = found.isEmpty ? 0 : found.first.price;
                        return TextEditingController(text: price.toStringAsFixed(0));
                      });
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    onPressed: () => _removeService(service.id),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              TextField(
                                controller: controller,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Price'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _myServices.isEmpty ? null : _savePrices,
                    child: const Text('Save Prices'),
                  ),
                ],
              ),
            ),
    );
  }
}
