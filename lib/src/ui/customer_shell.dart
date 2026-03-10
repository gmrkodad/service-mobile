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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
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
    final city = await TokenStore.readCity();
    if (!mounted) return;
    _cityController.text = city ?? '';
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
    final city = _cityController.text.trim();
    if (city.isEmpty) {
      showApiError(context, const ApiException('City cannot be empty'));
      return;
    }

    try {
      await widget.api.saveCustomerCity(city);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('City saved')),
      );
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
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _categories.where((category) {
      if (category.name.toLowerCase().contains(query)) return true;
      return category.services.any((svc) => svc.name.toLowerCase().contains(query));
    }).toList();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Services', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _saveCity,
                    child: const Text('Save'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search service/category',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? loadingView()
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: filtered.isEmpty
                      ? ListView(
                          children: <Widget>[emptyView('No services found')],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final category = filtered[index];
                            return Card(
                              child: ListTile(
                                title: Text(category.name),
                                subtitle: Text(
                                  category.description.isEmpty
                                      ? '${category.services.length} services'
                                      : category.description,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => CategoryDetailsPage(
                                        api: widget.api,
                                        category: category,
                                        currentCity: _cityController.text.trim(),
                                        onSessionExpired: widget.onSessionExpired,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
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

  @override
  void initState() {
    super.initState();
    _selectedService = widget.category.services.isNotEmpty ? widget.category.services.first : null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final service = widget.category.services[index];
                final selected = _selectedService?.id == service.id;
                return ChoiceChip(
                  selected: selected,
                  label: Text(service.name),
                  onSelected: (_) {
                    setState(() {
                      _selectedService = service;
                    });
                    _loadProviders();
                  },
                );
              },
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemCount: widget.category.services.length,
            ),
          ),
          Expanded(
            child: _loading
                ? loadingView()
                : _providers.isEmpty
                    ? emptyView('No providers found for this service in selected city')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _providers.length,
                        itemBuilder: (context, index) {
                          final provider = _providers[index];
                          return Card(
                            child: ListTile(
                              title: Text(provider.fullName.isEmpty ? provider.username : provider.fullName),
                              subtitle: Text(
                                'Rating: ${provider.rating.toStringAsFixed(1)}  •  '
                                'Price: ${provider.price?.toStringAsFixed(2) ?? 'N/A'}\n'
                                '${provider.city.isEmpty ? 'Local provider' : provider.city}',
                              ),
                              isThreeLine: true,
                              trailing: FilledButton(
                                onPressed: () async {
                                  final service = _selectedService;
                                  if (service == null) return;
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
                                child: const Text('Book'),
                              ),
                            ),
                          );
                        },
                      ),
          ),
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
      final services = await widget.api.fetchProviderServicesForBooking(widget.provider.userId);
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

  @override
  Widget build(BuildContext context) {
    final minDate = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Create Booking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              child: ListTile(
                title: Text(widget.service.name),
                subtitle: Text(widget.provider.fullName.isEmpty ? widget.provider.username : widget.provider.fullName),
              ),
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
              decoration: const InputDecoration(labelText: 'Customer location (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _landmarkController,
              decoration: const InputDecoration(labelText: 'Landmark (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
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
                        initialDate: _date.isBefore(minDate) ? minDate : _date,
                      );
                      if (picked != null) {
                        setState(() {
                          _date = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text('${_date.day}/${_date.month}/${_date.year}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _timeSlot,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'MORNING', child: Text('Morning')),
                      DropdownMenuItem(value: 'AFTERNOON', child: Text('Afternoon')),
                      DropdownMenuItem(value: 'EVENING', child: Text('Evening')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _timeSlot = value;
                        });
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Time slot'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Select services', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_loadingServices)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _providerServices.map((service) {
                  final selected = _selectedServiceIds.contains(service.id);
                  return FilterChip(
                    selected: selected,
                    label: Text(service.name),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedServiceIds.add(service.id);
                        } else if (service.id != widget.service.id) {
                          _selectedServiceIds.remove(service.id);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Booking...' : 'Confirm Booking'),
            ),
          ],
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
                        child: Text('${index + 1} star${index == 0 ? '' : 's'}'),
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
                        backgroundColor: statusColor(booking.status).withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Date: ${booking.scheduledDate}  •  ${prettyStatus(booking.timeSlot)}'),
                  Text('Provider: ${booking.providerFullName.isEmpty ? booking.providerUsername : booking.providerFullName}'),
                  const SizedBox(height: 6),
                  Text('Address: ${booking.address}'),
                  const SizedBox(height: 10),
                  if (booking.hasReview)
                    Text('Review: ${booking.reviewRating ?? '-'} / 5 • ${booking.reviewComment}')
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
                          leading: Icon(item.isRead ? Icons.notifications_none : Icons.notifications_active),
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
    if (_fullNameController.text.trim().isEmpty || _emailController.text.trim().isEmpty) {
      showApiError(context, const ApiException('Full name and email are required'));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
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
          _updatingProfile = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      showApiError(context, const ApiException('All password fields are required'));
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
                  const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    child: Text(_updatingProfile ? 'Saving...' : 'Update Profile'),
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
                  const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Current Password'),
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
                    decoration: const InputDecoration(labelText: 'Confirm Password'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _changingPassword ? null : _changePassword,
                    child: Text(_changingPassword ? 'Updating...' : 'Change Password'),
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
