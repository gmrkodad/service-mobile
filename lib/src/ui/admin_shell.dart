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
      AdminDashboardTab(api: widget.api, onSessionExpired: widget.onSessionExpired),
      AdminBookingsTab(api: widget.api, onSessionExpired: widget.onSessionExpired),
      AdminUsersTab(api: widget.api, onSessionExpired: widget.onSessionExpired),
      AdminServicesTab(api: widget.api, onSessionExpired: widget.onSessionExpired),
      AdminReviewsTab(api: widget.api, onSessionExpired: widget.onSessionExpired),
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
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.design_services_outlined), selectedIcon: Icon(Icons.design_services), label: 'Services'),
          NavigationDestination(icon: Icon(Icons.reviews_outlined), selectedIcon: Icon(Icons.reviews), label: 'Reviews'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text('Admin Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _stat('Bookings', _bookings),
              _stat('Users', _users),
              _stat('Services', _services),
              _stat('Reviews', _reviews),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
    int? selectedProvider = _providers.isNotEmpty ? _providers.first.userId : null;
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
      await widget.api.assignProvider(bookingId: booking.id, providerId: selectedProvider!);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Bookings')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _bookings.isEmpty
            ? ListView(children: <Widget>[emptyView('No bookings found')])
            : ListView.builder(
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
                                backgroundColor: statusColor(booking.status).withValues(alpha: 0.15),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Customer: ${booking.customerUsername}'),
                          Text('Provider: ${booking.providerUsername.isEmpty ? '-' : booking.providerUsername}'),
                          const SizedBox(height: 4),
                          Text('Date: ${booking.scheduledDate}  •  ${prettyStatus(booking.timeSlot)}'),
                          const SizedBox(height: 6),
                          Text(booking.address),
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
                  );
                },
              ),
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
      await widget.api.updateAdminProviderServices(userId: user.id, services: selected.toList());
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
        for (final p in prices) p.serviceId: TextEditingController(text: p.price.toStringAsFixed(0)),
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          final value = double.tryParse(controllers[p.serviceId]?.text.trim() ?? '');
          if (value == null || value <= 0) {
            throw const ApiException('All prices must be greater than 0');
          }
          payload.add({'service_id': p.serviceId, 'price': value});
        }
        await widget.api.updateAdminProviderServicePrices(userId: user.id, prices: payload);
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

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Users')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search users',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: filtered.isEmpty
                  ? ListView(children: <Widget>[emptyView('No users found')])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final user = filtered[index];
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
                                        user.username,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Chip(label: Text(user.role)),
                                  ],
                                ),
                                Text(user.fullName.isEmpty ? '-' : user.fullName),
                                Text(user.email.isEmpty ? '-' : user.email),
                                Text('Phone: ${user.phone.isEmpty ? '-' : user.phone}'),
                                Text('City: ${user.city.isEmpty ? '-' : user.city}'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    FilledButton.tonal(
                                      onPressed: () => _toggleUser(user),
                                      child: Text(user.isActive ? 'Deactivate' : 'Activate'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _deleteUser(user),
                                      child: const Text('Delete'),
                                    ),
                                    if (user.role == 'PROVIDER')
                                      OutlinedButton(
                                        onPressed: () => _editProviderServices(user),
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
                        );
                      },
                    ),
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
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                    TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
                    TextField(controller: imageUrl, decoration: const InputDecoration(labelText: 'Image URL')),
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
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
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
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                    TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
                    TextField(controller: imageUrl, decoration: const InputDecoration(labelText: 'Image URL')),
                    TextField(
                      controller: price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Base Price'),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: category,
                      items: _categories
                          .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
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
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Services'),
        actions: <Widget>[
          IconButton(onPressed: _createCategory, icon: const Icon(Icons.category_outlined), tooltip: 'New category'),
          IconButton(onPressed: _createService, icon: const Icon(Icons.add_business_outlined), tooltip: 'New service'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._categories.map((category) {
              return Card(
                child: ListTile(
                  title: Text(category.name),
                  subtitle: Text(category.description.isEmpty ? 'No description' : category.description),
                  trailing: Switch(
                    value: category.isActive,
                    onChanged: (value) async {
                      try {
                        await widget.api.updateAdminCategory(category.id, {'is_active': value});
                        await _load();
                      } catch (error) {
                        if (error is ApiException && error.statusCode == 401) {
                          widget.onSessionExpired();
                          return;
                        }
                        if (!context.mounted) return;
                        showApiError(context, error);
                      }
                    },
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            const Text('Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._services.map((service) {
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
                          Switch(
                            value: service.isActive,
                            onChanged: (value) async {
                              try {
                                await widget.api.updateAdminService(service.id, {'is_active': value});
                                await _load();
                              } catch (error) {
                                if (error is ApiException && error.statusCode == 401) {
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
                      Text(service.categoryName),
                      Text('Base: ${service.basePrice.toStringAsFixed(0)}'),
                      Row(
                        children: <Widget>[
                          TextButton(
                            onPressed: () async {
                              final confirm = await confirmDialog(
                                context,
                                title: 'Delete Service',
                                message: 'Delete ${service.name}?',
                                confirmLabel: 'Delete',
                              );
                              if (!confirm) return;
                              try {
                                await widget.api.deleteAdminService(service.id);
                                await _load();
                              } catch (error) {
                                if (error is ApiException && error.statusCode == 401) {
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
    final filtered = _rating.isEmpty ? _reviews : _reviews.where((r) => r.rating.toString() == _rating).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Reviews')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
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
              decoration: const InputDecoration(labelText: 'Filter by rating'),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: filtered.isEmpty
                  ? ListView(children: <Widget>[emptyView('No reviews found')])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final review = filtered[index];
                        return Card(
                          child: ListTile(
                            title: Text('${review.serviceName} • ${review.rating}/5'),
                            subtitle: Text(
                              'Booking #${review.bookingId}\n'
                              'Provider: ${review.providerUsername.isEmpty ? '-' : review.providerUsername}\n'
                              'Author: ${review.authorUsername}\n'
                              '${review.comment}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
