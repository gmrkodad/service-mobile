import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import 'common.dart';
import 'customer_shell.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({
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
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      AdminDashboardTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
      ),
      AdminBookingsTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
      ),
      AdminUsersTab(api: widget.api, onSessionExpired: widget.onSessionExpired),
      AdminServicesTab(
        api: widget.api,
        onSessionExpired: widget.onSessionExpired,
      ),
      AdminReviewsTab(
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
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.design_services_outlined),
            selectedIcon: Icon(Icons.design_services),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.reviews_outlined),
            selectedIcon: Icon(Icons.reviews),
            label: 'Reviews',
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

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  bool _loading = true;
  int _bookings = 0;
  int _users = 0;
  int _services = 0;
  int _reviews = 0;

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
      final results = await Future.wait([
        widget.api.fetchAdminBookings(),
        widget.api.fetchAdminUsers(),
        widget.api.fetchAdminServices(),
        widget.api.fetchAdminReviews(),
      ]);
      if (!mounted) return;
      setState(() {
        _bookings = (results[0] as List<BookingItem>).length;
        _users = (results[1] as List<AdminUser>).length;
        _services = (results[2] as List<AdminService>).length;
        _reviews = (results[3] as List<AdminReview>).length;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return loadingView();
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF1F3C8E), Color(0xFF2E6BD8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Admin Command Center',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live health view for bookings, users, services and reviews',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: sectionTitle(
              'Platform Snapshot',
              subtitle: 'Monitor demand and quality at a glance',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 126,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildListDelegate(<Widget>[
                _stat(
                  'Bookings',
                  _bookings,
                  Icons.assignment_outlined,
                  const Color(0xFF2A62D8),
                ),
                _stat(
                  'Users',
                  _users,
                  Icons.people_alt_outlined,
                  const Color(0xFF0A8D77),
                ),
                _stat(
                  'Services',
                  _services,
                  Icons.design_services_outlined,
                  const Color(0xFF7A54EA),
                ),
                _stat(
                  'Reviews',
                  _reviews,
                  Icons.reviews_outlined,
                  const Color(0xFFF08A24),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UiTone.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: UiTone.softText,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class AdminBookingsTab extends StatefulWidget {
  const AdminBookingsTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<AdminBookingsTab> createState() => _AdminBookingsTabState();
}

class _AdminBookingsTabState extends State<AdminBookingsTab> {
  bool _loading = true;
  List<BookingItem> _bookings = <BookingItem>[];
  List<ProviderItem> _providers = <ProviderItem>[];

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
      final results = await Future.wait([
        widget.api.fetchAdminBookings(),
        widget.api.fetchProvidersList(),
      ]);
      if (!mounted) return;
      setState(() {
        _bookings = results[0] as List<BookingItem>;
        _providers = results[1] as List<ProviderItem>;
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

  Future<void> _assignProvider(BookingItem booking) async {
    int? selectedProvider = _providers.isNotEmpty
        ? _providers.first.userId
        : null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Assign provider for #${booking.id}'),
              content: DropdownButtonFormField<int>(
                initialValue: selectedProvider,
                items: _providers
                    .map(
                      (provider) => DropdownMenuItem<int>(
                        value: provider.userId,
                        child: Text(provider.username),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setStateDialog(() {
                    selectedProvider = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Provider'),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selectedProvider == null) return;

    try {
      await widget.api.assignProvider(
        bookingId: booking.id,
        providerId: selectedProvider!,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return loadingView();
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: sectionTitle(
              'Bookings Control',
              subtitle: 'Assign providers and track status transitions',
            ),
          ),
          if (_bookings.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: emptyView('No bookings found'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final booking = _bookings[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '#${booking.id} ${booking.serviceLabel}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
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
                            const SizedBox(height: 8),
                            Text(
                              'Customer: ${booking.customerUsername}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Provider: ${booking.providerUsername.isEmpty ? '-' : booking.providerUsername}',
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Date: ${booking.scheduledDate} | ${prettyStatus(booking.timeSlot)}',
                            ),
                            const SizedBox(height: 6),
                            Text(
                              booking.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (booking.providerUsername.isEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              FilledButton.tonal(
                                onPressed: () => _assignProvider(booking),
                                child: const Text('Assign Provider'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: _bookings.length),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  bool _loading = true;
  List<AdminUser> _users = <AdminUser>[];
  List<AdminService> _services = <AdminService>[];
  final _searchController = TextEditingController();

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
      final results = await Future.wait([
        widget.api.fetchAdminUsers(),
        widget.api.fetchAdminServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<AdminUser>;
        _services = results[1] as List<AdminService>;
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

  Future<void> _toggleUser(AdminUser user) async {
    try {
      await widget.api.toggleAdminUser(user.id);
      await _load();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _deleteUser(AdminUser user) async {
    final confirm = await confirmDialog(
      context,
      title: 'Delete User',
      message: 'Delete ${user.username}? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirm) return;
    try {
      await widget.api.deleteAdminUser(user.id);
      await _load();
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    }
  }

  Future<void> _editProviderServices(AdminUser user) async {
    final selected = user.providerServices.map((e) => e.id).toSet();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Edit Services: ${user.username}'),
              content: SizedBox(
                width: 360,
                height: 320,
                child: ListView(
                  children: _services.map((service) {
                    final checked = selected.contains(service.id);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(service.name),
                      subtitle: Text(service.categoryName),
                      onChanged: (value) {
                        setStateDialog(() {
                          if (value == true) {
                            selected.add(service.id);
                          } else {
                            selected.remove(service.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      await widget.api.updateAdminProviderServices(
        userId: user.id,
        services: selected.toList(),
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

  Future<void> _editProviderPrices(AdminUser user) async {
    try {
      final prices = await widget.api.fetchAdminProviderServicePrices(user.id);
      if (!mounted) return;
      final controllers = <int, TextEditingController>{
        for (final p in prices)
          p.serviceId: TextEditingController(text: p.price.toStringAsFixed(0)),
      };

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Edit Prices: ${user.username}'),
            content: SizedBox(
              width: 360,
              height: 360,
              child: ListView(
                children: prices.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[p.serviceId],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: p.serviceName,
                        helperText: 'Base: ${p.basePrice.toStringAsFixed(0)}',
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (confirmed == true) {
        final payload = <Map<String, dynamic>>[];
        for (final p in prices) {
          final value = double.tryParse(
            controllers[p.serviceId]?.text.trim() ?? '',
          );
          if (value == null || value <= 0) {
            throw const ApiException('All prices must be greater than 0');
          }
          payload.add({'service_id': p.serviceId, 'price': value});
        }
        await widget.api.updateAdminProviderServicePrices(
          userId: user.id,
          prices: payload,
        );
        await _load();
      }

      for (final controller in controllers.values) {
        controller.dispose();
      }
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
    if (_loading) return loadingView();
    final q = _searchController.text.trim().toLowerCase();
    final filtered = _users.where((u) {
      return u.username.toLowerCase().contains(q) ||
          u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.role.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: sectionTitle(
              'Users Directory',
              subtitle: 'Search, activate, and manage provider capabilities',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search users',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: emptyView('No users found'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final user = filtered[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFE3EBFF),
                                  foregroundColor: const Color(0xFF1E4EA8),
                                  child: Text(
                                    user.username.isEmpty
                                        ? '?'
                                        : user.username
                                              .substring(0, 1)
                                              .toUpperCase(),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        user.username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        user.fullName.isEmpty
                                            ? '-'
                                            : user.fullName,
                                        style: const TextStyle(
                                          color: UiTone.softText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Chip(label: Text(user.role)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(user.email.isEmpty ? '-' : user.email),
                            Text(
                              'Phone: ${user.phone.isEmpty ? '-' : user.phone}',
                            ),
                            Text(
                              'City: ${user.city.isEmpty ? '-' : user.city}',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                FilledButton.tonal(
                                  onPressed: () => _toggleUser(user),
                                  child: Text(
                                    user.isActive ? 'Deactivate' : 'Activate',
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _deleteUser(user),
                                  child: const Text('Delete'),
                                ),
                                if (user.role == 'PROVIDER')
                                  OutlinedButton(
                                    onPressed: () =>
                                        _editProviderServices(user),
                                    child: const Text('Edit Services'),
                                  ),
                                if (user.role == 'PROVIDER')
                                  OutlinedButton(
                                    onPressed: () => _editProviderPrices(user),
                                    child: const Text('Edit Prices'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: filtered.length),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminServicesTab extends StatefulWidget {
  const AdminServicesTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<AdminServicesTab> createState() => _AdminServicesTabState();
}

class _AdminServicesTabState extends State<AdminServicesTab> {
  bool _loading = true;
  List<AdminCategory> _categories = <AdminCategory>[];
  List<AdminService> _services = <AdminService>[];

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
      final results = await Future.wait([
        widget.api.fetchAdminCategories(),
        widget.api.fetchAdminServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<AdminCategory>;
        _services = results[1] as List<AdminService>;
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

  Future<void> _createCategory() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final imageUrl = TextEditingController();
    bool isActive = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('New Category'),
              content: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    TextField(
                      controller: imageUrl,
                      decoration: const InputDecoration(labelText: 'Image URL'),
                    ),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (value) {
                        setStateDialog(() {
                          isActive = value;
                        });
                      },
                      title: const Text('Active'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      try {
        await widget.api.createAdminCategory({
          'name': name.text.trim(),
          'description': description.text.trim(),
          'image_url': imageUrl.text.trim(),
          'is_active': isActive,
        });
        await _load();
      } catch (error) {
        if (error is ApiException && error.statusCode == 401) {
          widget.onSessionExpired();
          return;
        }
        if (mounted) showApiError(context, error);
      }
    }
    name.dispose();
    description.dispose();
    imageUrl.dispose();
  }

  Future<void> _createService() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final imageUrl = TextEditingController();
    final price = TextEditingController();
    int? category = _categories.isNotEmpty ? _categories.first.id : null;
    bool isActive = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('New Service'),
              content: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    TextField(
                      controller: imageUrl,
                      decoration: const InputDecoration(labelText: 'Image URL'),
                    ),
                    TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Base Price',
                      ),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: category,
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          category = value;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (value) {
                        setStateDialog(() {
                          isActive = value;
                        });
                      },
                      title: const Text('Active'),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && category != null) {
      try {
        await widget.api.createAdminService({
          'name': name.text.trim(),
          'description': description.text.trim(),
          'image_url': imageUrl.text.trim(),
          'base_price': double.tryParse(price.text.trim()) ?? 0,
          'category': category,
          'is_active': isActive,
        });
        await _load();
      } catch (error) {
        if (error is ApiException && error.statusCode == 401) {
          widget.onSessionExpired();
          return;
        }
        if (mounted) showApiError(context, error);
      }
    }
    name.dispose();
    description.dispose();
    imageUrl.dispose();
    price.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return loadingView();
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: sectionTitle(
              'Services Studio',
              subtitle: 'Create and maintain your catalog',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    onPressed: _createCategory,
                    icon: const Icon(Icons.category_outlined),
                    tooltip: 'New category',
                  ),
                  IconButton(
                    onPressed: _createService,
                    icon: const Icon(Icons.add_business_outlined),
                    tooltip: 'New service',
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: sectionTitle(
              'Categories',
              subtitle: 'Toggle visibility and review category images',
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final category = _categories[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      leading: imageOrPlaceholder(
                        category.imageUrl,
                        width: 54,
                        height: 54,
                        fallbackIcon: Icons.category_outlined,
                      ),
                      title: Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        category.description.isEmpty
                            ? 'No description'
                            : category.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Switch(
                        value: category.isActive,
                        onChanged: (value) async {
                          try {
                            await widget.api.updateAdminCategory(category.id, {
                              'is_active': value,
                            });
                            await _load();
                          } catch (error) {
                            if (error is ApiException &&
                                error.statusCode == 401) {
                              widget.onSessionExpired();
                              return;
                            }
                            if (!context.mounted) return;
                            showApiError(context, error);
                          }
                        },
                      ),
                    ),
                  ),
                );
              }, childCount: _categories.length),
            ),
          ),
          SliverToBoxAdapter(
            child: sectionTitle(
              'Services',
              subtitle: 'Edit service states and pricing',
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final service = _services[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          imageOrPlaceholder(
                            service.imageUrl,
                            width: 64,
                            height: 64,
                            fallbackIcon: Icons.room_service_outlined,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        service.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: service.isActive,
                                      onChanged: (value) async {
                                        try {
                                          await widget.api.updateAdminService(
                                            service.id,
                                            {'is_active': value},
                                          );
                                          await _load();
                                        } catch (error) {
                                          if (error is ApiException &&
                                              error.statusCode == 401) {
                                            widget.onSessionExpired();
                                            return;
                                          }
                                          if (!context.mounted) return;
                                          showApiError(context, error);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  service.categoryName,
                                  style: const TextStyle(
                                    color: UiTone.softText,
                                  ),
                                ),
                                Text(
                                  'Base: INR ${service.basePrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton(
                                  onPressed: () async {
                                    final confirm = await confirmDialog(
                                      context,
                                      title: 'Delete Service',
                                      message: 'Delete ${service.name}?',
                                      confirmLabel: 'Delete',
                                    );
                                    if (!confirm) return;
                                    try {
                                      await widget.api.deleteAdminService(
                                        service.id,
                                      );
                                      await _load();
                                    } catch (error) {
                                      if (error is ApiException &&
                                          error.statusCode == 401) {
                                        widget.onSessionExpired();
                                        return;
                                      }
                                      if (!context.mounted) return;
                                      showApiError(context, error);
                                    }
                                  },
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }, childCount: _services.length),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminReviewsTab extends StatefulWidget {
  const AdminReviewsTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;

  @override
  State<AdminReviewsTab> createState() => _AdminReviewsTabState();
}

class _AdminReviewsTabState extends State<AdminReviewsTab> {
  bool _loading = true;
  List<AdminReview> _reviews = <AdminReview>[];
  String _rating = '';

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
      final reviews = await widget.api.fetchAdminReviews();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return loadingView();
    final filtered = _rating.isEmpty
        ? _reviews
        : _reviews.where((r) => r.rating.toString() == _rating).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: sectionTitle(
              'Reviews Monitor',
              subtitle: 'Filter by rating and inspect provider feedback',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: DropdownButtonFormField<String>(
                initialValue: _rating,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: '', child: Text('All ratings')),
                  DropdownMenuItem(value: '1', child: Text('1 star')),
                  DropdownMenuItem(value: '2', child: Text('2 stars')),
                  DropdownMenuItem(value: '3', child: Text('3 stars')),
                  DropdownMenuItem(value: '4', child: Text('4 stars')),
                  DropdownMenuItem(value: '5', child: Text('5 stars')),
                ],
                onChanged: (value) {
                  setState(() {
                    _rating = value ?? '';
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Filter by rating',
                  prefixIcon: Icon(Icons.filter_alt_outlined),
                ),
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: emptyView('No reviews found'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final review = filtered[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    review.serviceName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4E0),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 15,
                                        color: Color(0xFFF08A24),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${review.rating}/5',
                                        style: const TextStyle(
                                          color: Color(0xFFB45B00),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Booking #${review.bookingId} | Author: ${review.authorUsername}',
                              style: const TextStyle(
                                color: UiTone.softText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Provider: ${review.providerUsername.isEmpty ? '-' : review.providerUsername}',
                              style: const TextStyle(color: UiTone.softText),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              review.comment.trim().isEmpty
                                  ? 'No comment provided'
                                  : review.comment,
                              style: const TextStyle(height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }, childCount: filtered.length),
              ),
            ),
        ],
      ),
    );
  }
}
