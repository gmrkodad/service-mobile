import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  void _openTab(int index) {
    setState(() {
      _index = index;
    });
  }

  void _openPrimaryTab() {
    setState(() {
      _index = 0;
    });
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
          onOpenBookings: () => _openTab(1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSupport = widget.profile.role == 'SUPPORT';
    final tabs = isSupport
        ? <Widget>[
            SupportDashboardTab(
              api: widget.api,
              onSessionExpired: widget.onSessionExpired,
              onOpenTab: _openTab,
              onOpenProfile: _openProfile,
            ),
            SupportTicketsTab(
              api: widget.api,
              onSessionExpired: widget.onSessionExpired,
              onBack: _openPrimaryTab,
            ),
            AdminBookingsTab(
              api: widget.api,
              onSessionExpired: widget.onSessionExpired,
              onBack: _openPrimaryTab,
            ),
          ]
        : <Widget>[
            AdminDashboardTab(
              api: widget.api,
              onSessionExpired: widget.onSessionExpired,
              onOpenTab: _openTab,
              onOpenProfile: _openProfile,
            ),
            AdminBookingsTab(
              api: widget.api,
              onSessionExpired: widget.onSessionExpired,
              onBack: _openPrimaryTab,
            ),
            AdminUsersTab(
              api: widget.api,
              onSessionExpired: widget.onSessionExpired,
              onBack: _openPrimaryTab,
            ),
            AdminServicesTab(
              api: widget.api,
              onSessionExpired: widget.onSessionExpired,
              onBack: _openPrimaryTab,
            ),
            AdminReviewsTab(
              api: widget.api,
              onSessionExpired: widget.onSessionExpired,
              onBack: _openPrimaryTab,
            ),
          ];

    final destinations = isSupport
        ? const <Widget>[
            NavigationDestination(
              icon: Icon(Icons.support_agent_outlined, size: 24),
              selectedIcon: Icon(Icons.support_agent_rounded, size: 24),
              label: 'Support',
            ),
            NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined, size: 23),
              selectedIcon: Icon(Icons.confirmation_number_rounded, size: 23),
              label: 'Tickets',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined, size: 23),
              selectedIcon: Icon(Icons.assignment_rounded, size: 23),
              label: 'Bookings',
            ),
          ]
        : const <Widget>[
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined, size: 24),
              selectedIcon: Icon(Icons.space_dashboard_rounded, size: 24),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined, size: 23),
              selectedIcon: Icon(Icons.assignment_rounded, size: 23),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, size: 24),
              selectedIcon: Icon(Icons.people_rounded, size: 24),
              label: 'Users',
            ),
            NavigationDestination(
              icon: Icon(Icons.design_services_outlined, size: 23),
              selectedIcon: Icon(Icons.design_services_rounded, size: 23),
              label: 'Services',
            ),
            NavigationDestination(
              icon: Icon(Icons.reviews_outlined, size: 23),
              selectedIcon: Icon(Icons.reviews_rounded, size: 23),
              label: 'Reviews',
            ),
          ];

    return Scaffold(
      body: ColoredBox(
        color: UiTone.shellBackground,
        child: SafeArea(child: tabs[_index]),
      ),
      bottomNavigationBar: destinations.length < 2
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) {
                setState(() {
                  _index = value;
                });
              },
              destinations: destinations,
            ),
    );
  }
}

class SupportDashboardTab extends StatefulWidget {
  const SupportDashboardTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
    required this.onOpenTab,
    required this.onOpenProfile,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final void Function(int index) onOpenTab;
  final Future<void> Function() onOpenProfile;

  @override
  State<SupportDashboardTab> createState() => _SupportDashboardTabState();
}

class _SupportDashboardTabState extends State<SupportDashboardTab> {
  bool _loading = true;
  List<SupportTicket> _tickets = <SupportTicket>[];
  int _bookings = 0;

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
        widget.api.fetchSupportTickets(),
        widget.api.fetchAdminBookings(),
      ]);
      if (!mounted) return;
      setState(() {
        _tickets = results[0] as List<SupportTicket>;
        _bookings = (results[1] as List<BookingItem>).length;
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
    final openCount = _tickets.where((t) => t.status == 'OPEN').length;
    final inProgressCount = _tickets
        .where((t) => t.status == 'IN_PROGRESS')
        .length;
    final resolvedCount = _tickets.where((t) => t.status == 'RESOLVED').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF0A4F8A), Color(0xFF0E7490)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Support Desk',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage customer and provider issues quickly',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onOpenProfile,
                    icon: const Icon(Icons.account_circle_rounded, size: 34),
                    color: Colors.white,
                    tooltip: 'Profile',
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: sectionTitle(
              'Ticket Snapshot',
              subtitle: 'Tap cards to open ticket queue',
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
                _supportStat(
                  'Open',
                  openCount,
                  Icons.mark_email_unread_outlined,
                  const Color(0xFFDC2626),
                  onTap: () => widget.onOpenTab(1),
                ),
                _supportStat(
                  'In Progress',
                  inProgressCount,
                  Icons.timelapse_rounded,
                  const Color(0xFFF59E0B),
                  onTap: () => widget.onOpenTab(1),
                ),
                _supportStat(
                  'Resolved',
                  resolvedCount,
                  Icons.verified_rounded,
                  const Color(0xFF059669),
                  onTap: () => widget.onOpenTab(1),
                ),
                _supportStat(
                  'Bookings',
                  _bookings,
                  Icons.assignment_outlined,
                  const Color(0xFF0D7C66),
                  onTap: () => widget.onOpenTab(2),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportStat(
    String label,
    int value,
    IconData icon,
    Color iconColor, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: UiTone.surfaceBorder, width: 0.5),
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
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class SupportTicketsTab extends StatefulWidget {
  const SupportTicketsTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
    this.onBack,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final VoidCallback? onBack;

  @override
  State<SupportTicketsTab> createState() => _SupportTicketsTabState();
}

class _SupportTicketsTabState extends State<SupportTicketsTab> {
  bool _loading = true;
  List<SupportTicket> _tickets = <SupportTicket>[];
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
      final results = await Future.wait<dynamic>([
        widget.api.fetchSupportTickets(),
        widget.api.fetchAdminBookings(),
      ]);
      if (!mounted) return;
      setState(() {
        _tickets = results[0] as List<SupportTicket>;
        _bookings = results[1] as List<BookingItem>;
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

  BookingItem? _bookingForTicket(SupportTicket ticket) {
    if (ticket.bookingId == null) return null;
    for (final booking in _bookings) {
      if (booking.id == ticket.bookingId) return booking;
    }
    return null;
  }

  Future<void> _openTicketDetail(SupportTicket ticket) async {
    final booking = _bookingForTicket(ticket);
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _SupportTicketDetailPage(
          api: widget.api,
          onSessionExpired: widget.onSessionExpired,
          ticket: ticket,
          booking: booking,
        ),
      ),
    );
    if (updated == true) {
      await _load();
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
              'Support Tickets',
              subtitle: 'All user issues linked with bookings',
              leading: widget.onBack == null
                  ? null
                  : IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
            ),
          ),
          if (_tickets.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: emptyView('No support tickets yet'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final ticket = _tickets[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => _openTicketDetail(ticket),
                      borderRadius: BorderRadius.circular(16),
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
                                      '#${ticket.id} ${ticket.issueType}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(prettyStatus(ticket.status)),
                                    backgroundColor: statusColor(
                                      ticket.status,
                                    ).withValues(alpha: 0.15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'User: ${ticket.requesterUsername.isEmpty ? '-' : ticket.requesterUsername} (${ticket.requesterRole.isEmpty ? 'USER' : ticket.requesterRole})',
                                style: const TextStyle(
                                  color: UiTone.softText,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if (ticket.bookingLabel.trim().isNotEmpty)
                                Text(
                                  'Booking: ${ticket.bookingLabel}',
                                  style: const TextStyle(
                                    color: UiTone.softText,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                ticket.message,
                                style: const TextStyle(
                                  color: UiTone.ink,
                                  fontWeight: FontWeight.w400,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: <Widget>[
                                  Spacer(),
                                  Text(
                                    'Open ticket',
                                    style: TextStyle(
                                      color: UiTone.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: UiTone.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }, childCount: _tickets.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _SupportTicketDetailPage extends StatefulWidget {
  const _SupportTicketDetailPage({
    required this.api,
    required this.onSessionExpired,
    required this.ticket,
    required this.booking,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final SupportTicket ticket;
  final BookingItem? booking;

  @override
  State<_SupportTicketDetailPage> createState() =>
      _SupportTicketDetailPageState();
}

class _SupportTicketDetailPageState extends State<_SupportTicketDetailPage> {
  static const List<String> _statusValues = <String>[
    'OPEN',
    'IN_PROGRESS',
    'RESOLVED',
    'CLOSED',
  ];

  late String _status = widget.ticket.status;
  bool _updatingStatus = false;

  SupportTicket get ticket => widget.ticket;
  BookingItem? get booking => widget.booking;

  double _amountFor(BookingItem row) {
    final count = row.serviceNames.isEmpty ? 1 : row.serviceNames.length;
    return count * 25 + 2.52;
  }

  Future<void> _updateStatus() async {
    setState(() {
      _updatingStatus = true;
    });
    try {
      await widget.api.updateSupportTicketStatus(
        ticketId: ticket.id,
        status: _status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ticket status updated')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _updatingStatus = false;
        });
      }
    }
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
        title: Text('Ticket #${ticket.id}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: <Widget>[
          Container(
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
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Chip(label: Text(prettyStatus(ticket.status))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Raised by: ${ticket.requesterUsername} (${ticket.requesterRole})',
                  style: const TextStyle(
                    color: UiTone.softText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (ticket.bookingLabel.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Linked booking: ${ticket.bookingLabel}',
                    style: const TextStyle(
                      color: UiTone.softText,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  ticket.message,
                  style: const TextStyle(
                    color: UiTone.ink,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _statusValues.contains(_status)
                      ? _status
                      : 'OPEN',
                  items: _statusValues
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(prettyStatus(value)),
                        ),
                      )
                      .toList(),
                  onChanged: _updatingStatus
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _status = value;
                          });
                        },
                  decoration: const InputDecoration(labelText: 'Ticket status'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _updatingStatus ? null : _updateStatus,
                  child: Text(
                    _updatingStatus ? 'Updating...' : 'Update status',
                  ),
                ),
              ],
            ),
          ),
          if (booking != null) ...<Widget>[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BookingSummaryPage(
                      booking: booking!,
                      amountPaid: _amountFor(booking!),
                      supportApi: widget.api,
                      onSessionExpired: widget.onSessionExpired,
                      supportRole: 'ADMIN',
                      preselectedBookingId: booking!.id,
                    ),
                  ),
                );
              },
              child: const Text('Open linked booking summary'),
            ),
          ],
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
    required this.onOpenTab,
    required this.onOpenProfile,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final void Function(int index) onOpenTab;
  final Future<void> Function() onOpenProfile;

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
                  colors: <Color>[Color(0xFF0F3D32), Color(0xFF14A38B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Admin Command Center',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onOpenProfile,
                        icon: const Icon(
                          Icons.account_circle_rounded,
                          size: 34,
                        ),
                        color: Colors.white,
                        tooltip: 'Profile',
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
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
                  const Color(0xFF0D7C66),
                  onTap: () => widget.onOpenTab(1),
                ),
                _stat(
                  'Users',
                  _users,
                  Icons.people_alt_outlined,
                  const Color(0xFF14A38B),
                  onTap: () => widget.onOpenTab(2),
                ),
                _stat(
                  'Services',
                  _services,
                  Icons.design_services_outlined,
                  const Color(0xFF059669),
                  onTap: () => widget.onOpenTab(3),
                ),
                _stat(
                  'Reviews',
                  _reviews,
                  Icons.reviews_outlined,
                  const Color(0xFFF59E0B),
                  onTap: () => widget.onOpenTab(4),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    int value,
    IconData icon,
    Color iconColor, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: UiTone.surfaceBorder, width: 0.5),
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
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminBookingsTab extends StatefulWidget {
  const AdminBookingsTab({
    super.key,
    required this.api,
    required this.onSessionExpired,
    this.onBack,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final VoidCallback? onBack;

  @override
  State<AdminBookingsTab> createState() => _AdminBookingsTabState();
}

class _AdminBookingsTabState extends State<AdminBookingsTab> {
  bool _loading = true;
  List<BookingItem> _bookings = <BookingItem>[];
  List<ProviderItem> _providers = <ProviderItem>[];

  double _amountFor(BookingItem booking) {
    final count = booking.serviceNames.isEmpty
        ? 1
        : booking.serviceNames.length;
    return count * 25 + 2.52;
  }

  Future<void> _openBookingSummary(BookingItem booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingSummaryPage(
          booking: booking,
          amountPaid: _amountFor(booking),
          supportApi: widget.api,
          onSessionExpired: widget.onSessionExpired,
          supportRole: 'ADMIN',
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
              leading: widget.onBack == null
                  ? null
                  : IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
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
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => _openBookingSummary(booking),
                      borderRadius: BorderRadius.circular(16),
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
                                        fontWeight: FontWeight.w700,
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
                              const SizedBox(height: 10),
                              if (booking.providerUsername.isEmpty) ...<Widget>[
                                FilledButton.tonal(
                                  onPressed: () => _assignProvider(booking),
                                  child: const Text('Assign Provider'),
                                ),
                                const SizedBox(height: 8),
                              ],
                              FilledButton(
                                onPressed: () => _openBookingSummary(booking),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                                child: const Text('Booking summary'),
                              ),
                            ],
                          ),
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
    this.onBack,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final VoidCallback? onBack;

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

  Future<void> _createUser() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final city = TextEditingController(text: kDefaultFallbackCity);
    String role = 'CUSTOMER';
    String gender = 'OTHER';
    final selectedServices = <int>{};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isProvider = role == 'PROVIDER';
            return AlertDialog(
              title: const Text('Create User'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'CUSTOMER',
                            child: Text('Customer'),
                          ),
                          DropdownMenuItem(
                            value: 'PROVIDER',
                            child: Text('Provider'),
                          ),
                          DropdownMenuItem(
                            value: 'SUPPORT',
                            child: Text('Support'),
                          ),
                        ],
                        onChanged: (value) {
                          setStateDialog(() {
                            role = value ?? 'CUSTOMER';
                            if (role != 'PROVIDER') {
                              selectedServices.clear();
                            }
                          });
                        },
                      ),
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                      ),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
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
                          setStateDialog(() {
                            gender = value ?? 'OTHER';
                          });
                        },
                      ),
                      if (isProvider) ...<Widget>[
                        TextField(
                          controller: city,
                          decoration: const InputDecoration(labelText: 'City'),
                        ),
                        const SizedBox(height: 10),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Provider services',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: mutedSurface(radius: 12),
                          child: _services.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('No services available'),
                                  ),
                                )
                              : ListView(
                                  shrinkWrap: true,
                                  children: _services
                                      .map((service) {
                                        final checked = selectedServices
                                            .contains(service.id);
                                        return CheckboxListTile(
                                          value: checked,
                                          title: Text(service.name),
                                          subtitle: Text(service.categoryName),
                                          onChanged: (value) {
                                            setStateDialog(() {
                                              if (value == true) {
                                                selectedServices.add(
                                                  service.id,
                                                );
                                              } else {
                                                selectedServices.remove(
                                                  service.id,
                                                );
                                              }
                                            });
                                          },
                                        );
                                      })
                                      .toList(growable: false),
                                ),
                        ),
                      ],
                    ],
                  ),
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

    if (confirmed != true) {
      name.dispose();
      email.dispose();
      phone.dispose();
      city.dispose();
      return;
    }

    try {
      await widget.api.createAdminUser(<String, dynamic>{
        'role': role,
        'full_name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'gender': gender,
        'city': role == 'PROVIDER' ? city.text.trim() : '',
        'services': role == 'PROVIDER'
            ? selectedServices.toList(growable: false)
            : <int>[],
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User created')));
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (mounted) showApiError(context, error);
    } finally {
      name.dispose();
      email.dispose();
      phone.dispose();
      city.dispose();
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
                    padding: const EdgeInsets.only(bottom: 12),
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
              leading: widget.onBack == null
                  ? null
                  : IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
              trailing: IconButton(
                onPressed: _createUser,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                tooltip: 'Create user',
              ),
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
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                CircleAvatar(
                                  backgroundColor: const Color(0xFFE6F5F0),
                                  foregroundColor: const Color(0xFF0D7C66),
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
                                          fontWeight: FontWeight.w700,
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
    this.onBack,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final VoidCallback? onBack;

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
    bool uploadingImage = false;

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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: uploadingImage
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (file == null || !context.mounted) return;
                                setStateDialog(() {
                                  uploadingImage = true;
                                });
                                try {
                                  final uploadedUrl = await widget.api
                                      .uploadAdminIcon(file.path);
                                  if (!context.mounted) return;
                                  imageUrl.text = uploadedUrl;
                                } catch (error) {
                                  if (!context.mounted) return;
                                  showApiError(context, error);
                                } finally {
                                  if (context.mounted) {
                                    setStateDialog(() {
                                      uploadingImage = false;
                                    });
                                  }
                                }
                              },
                        icon: uploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(
                          uploadingImage
                              ? 'Uploading image...'
                              : 'Upload image',
                        ),
                      ),
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
    bool uploadingImage = false;

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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: uploadingImage
                            ? null
                            : () async {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (file == null || !context.mounted) return;
                                setStateDialog(() {
                                  uploadingImage = true;
                                });
                                try {
                                  final uploadedUrl = await widget.api
                                      .uploadAdminIcon(file.path);
                                  if (!context.mounted) return;
                                  imageUrl.text = uploadedUrl;
                                } catch (error) {
                                  if (!context.mounted) return;
                                  showApiError(context, error);
                                } finally {
                                  if (context.mounted) {
                                    setStateDialog(() {
                                      uploadingImage = false;
                                    });
                                  }
                                }
                              },
                        icon: uploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(
                          uploadingImage
                              ? 'Uploading image...'
                              : 'Upload image',
                        ),
                      ),
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

  Future<void> _changeCategoryIcon(AdminCategory category) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      final uploadedUrl = await widget.api.uploadAdminIcon(file.path);
      await widget.api.updateAdminCategory(category.id, <String, dynamic>{
        'image_url': uploadedUrl,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Category image updated')));
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (!mounted) return;
      showApiError(context, error);
    }
  }

  Future<void> _changeServiceIcon(AdminService service) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file == null) return;
      final uploadedUrl = await widget.api.uploadAdminIcon(file.path);
      await widget.api.updateAdminService(service.id, <String, dynamic>{
        'image_url': uploadedUrl,
      });
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service image updated')));
    } catch (error) {
      if (error is ApiException && error.statusCode == 401) {
        widget.onSessionExpired();
        return;
      }
      if (!mounted) return;
      showApiError(context, error);
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
              'Services Studio',
              subtitle: 'Create and maintain your catalog',
              leading: widget.onBack == null
                  ? null
                  : IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
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
              subtitle: 'Toggle visibility and update category images',
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final category = _categories[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          imageOrPlaceholder(
                            category.imageUrl,
                            width: 54,
                            height: 54,
                            fallbackIcon: Icons.category_outlined,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  category.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  category.description.isEmpty
                                      ? 'No description'
                                      : category.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                onPressed: () => _changeCategoryIcon(category),
                                icon: const Icon(Icons.upload_file_rounded),
                                tooltip: 'Change image',
                              ),
                              Switch(
                                value: category.isActive,
                                onChanged: (value) async {
                                  try {
                                    await widget.api.updateAdminCategory(
                                      category.id,
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
                        ],
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
              subtitle: 'Edit service states, pricing, and images',
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final service = _services[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                                          fontWeight: FontWeight.w700,
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
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _changeServiceIcon(service),
                                      icon: const Icon(
                                        Icons.upload_file_rounded,
                                      ),
                                      label: const Text('Change image'),
                                    ),
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
    this.onBack,
  });

  final ApiService api;
  final VoidCallback onSessionExpired;
  final VoidCallback? onBack;

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
                    padding: const EdgeInsets.only(bottom: 12),
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
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8E7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 15,
                                        color: Color(0xFFF59E0B),
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
