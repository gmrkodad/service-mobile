import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../api.dart';

class UiTone {
  static const Color shellBackground = Color(0xFFF5F7F6);
  static const Color shellAccent = Color(0xFFE6F5F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF4F6F5);
  static const Color surfaceBorder = Color(0xFFB4C5BC);
  static const Color ink = Color(0xFF1A2B23);
  static const Color softText = Color(0xFF5A6B63);
  static const Color primary = Color(0xFF0D7C66);
  static const Color primarySoft = Color(0xFFE6F5F0);
  static const Color secondary = Color(0xFF14A38B);
  static const Color success = Color(0xFF22C55E);
}

class UiSpace {
  static const EdgeInsets screen = EdgeInsets.fromLTRB(16, 12, 16, 20);
  static const EdgeInsets section = EdgeInsets.fromLTRB(16, 12, 16, 10);
}

/// A professional icon container — wraps an icon inside a tinted rounded box.
/// Used across menu tiles, booking meta rows, and feature cards for a branded look.
Widget iconBox(
  IconData icon, {
  Color background = const Color(0xFFE6F5F0),
  Color foreground = const Color(0xFF0D7C66),
  double size = 38,
  double iconSize = 20,
  double radius = 12,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(icon, size: iconSize, color: foreground),
  );
}

/// Pre-defined icon color pairs for consistent menu/feature icons.
class IconColors {
  static const (Color, Color) green = (Color(0xFFE6F5F0), Color(0xFF0D7C66));
  static const (Color, Color) blue = (Color(0xFFE8F2FE), Color(0xFF2563EB));
  static const (Color, Color) purple = (Color(0xFFF0EAFC), Color(0xFF7C3AED));
  static const (Color, Color) orange = (Color(0xFFFFF3E6), Color(0xFFE67E22));
  static const (Color, Color) red = (Color(0xFFFDE8E8), Color(0xFFDC2626));
  static const (Color, Color) teal = (Color(0xFFE0F7F3), Color(0xFF0D9488));
  static const (Color, Color) pink = (Color(0xFFFCE7F3), Color(0xFFDB2777));
  static const (Color, Color) slate = (Color(0xFFF1F5F9), Color(0xFF475569));
}

const String kDefaultFallbackCity = 'Hyderabad';

BoxDecoration elevatedSurface({
  Color color = UiTone.surface,
  double radius = 20,
  Color border = UiTone.surfaceBorder,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border.withValues(alpha: 0.5), width: 0.8),
    boxShadow: const <BoxShadow>[
      BoxShadow(
        color: Color(0x061A2B23),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
      BoxShadow(
        color: Color(0x0A1A2B23),
        blurRadius: 24,
        offset: Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration mutedSurface({double radius = 16}) {
  return BoxDecoration(
    color: UiTone.surfaceMuted,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: UiTone.surfaceBorder, width: 1.2),
  );
}

void showApiError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

// ---------------------------------------------------------------------------
// Shimmer loading placeholders
// ---------------------------------------------------------------------------

/// A single shimmer placeholder box used as a building block.
Widget _shimmerBox({
  double width = double.infinity,
  double height = 16,
  double radius = 8,
}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Full-screen shimmer loading that replaces the old CircularProgressIndicator
/// loading state. Looks like a skeleton of a typical content page.
Widget loadingView([String message = 'Loading...']) {
  return Shimmer.fromColors(
    baseColor: const Color(0xFFE8EDEA),
    highlightColor: const Color(0xFFF5F7F6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header skeleton
          Row(
            children: <Widget>[
              _shimmerBox(width: 180, height: 24, radius: 8),
              const Spacer(),
              _shimmerBox(width: 42, height: 42, radius: 12),
            ],
          ),
          const SizedBox(height: 20),
          // Search bar skeleton
          _shimmerBox(height: 50, radius: 14),
          const SizedBox(height: 24),
          // Banner skeleton
          _shimmerBox(height: 160, radius: 20),
          const SizedBox(height: 24),
          // Section title skeleton
          _shimmerBox(width: 140, height: 18, radius: 6),
          const SizedBox(height: 16),
          // Grid skeleton
          Row(
            children: <Widget>[
              Expanded(child: _shimmerBox(height: 180, radius: 16)),
              const SizedBox(width: 14),
              Expanded(child: _shimmerBox(height: 180, radius: 16)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(child: _shimmerBox(height: 180, radius: 16)),
              const SizedBox(width: 14),
              Expanded(child: _shimmerBox(height: 180, radius: 16)),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Shimmer card-list skeleton for list-based loading (bookings, tickets, etc.)
Widget loadingListView({int itemCount = 3}) {
  return Shimmer.fromColors(
    baseColor: const Color(0xFFE8EDEA),
    highlightColor: const Color(0xFFF5F7F6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(itemCount, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _shimmerBox(height: 18, radius: 6),
                      ),
                      const SizedBox(width: 40),
                      _shimmerBox(width: 80, height: 28, radius: 14),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _shimmerBox(width: 200, height: 14, radius: 6),
                  const SizedBox(height: 10),
                  _shimmerBox(height: 14, radius: 6),
                  const SizedBox(height: 14),
                  _shimmerBox(height: 42, radius: 12),
                ],
              ),
            ),
          );
        }),
      ),
    ),
  );
}

Widget emptyView(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F5F0),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              color: Color(0xFF0D7C66),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: UiTone.softText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

/// Smooth page route with a fade + upward slide transition.
Route<T> smoothPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
  );
}

Widget sectionTitle(
  String title, {
  String? subtitle,
  Widget? leading,
  Widget? trailing,
  EdgeInsetsGeometry padding = UiSpace.section,
}) {
  return Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (leading != null) ...<Widget>[leading, const SizedBox(width: 8)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: UiTone.ink,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: UiTone.softText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

Widget imageOrPlaceholder(
  String imageUrl, {
  double width = 72,
  double height = 72,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(14)),
  IconData fallbackIcon = Icons.image_outlined,
}) {
  final cacheWidth = width.isFinite && width > 0 ? (width * 2).round() : null;
  final cacheHeight = height.isFinite && height > 0
      ? (height * 2).round()
      : null;
  final fallback = Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE0EDE6),
      borderRadius: borderRadius,
    ),
    alignment: Alignment.center,
    child: Icon(fallbackIcon, color: const Color(0xFF5A8B73)),
  );
  if (imageUrl.trim().isEmpty) return fallback;
  return ClipRRect(
    borderRadius: borderRadius,
    child: Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => fallback,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: frame != null ? child : fallback,
        );
      },
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

String prettyStatus(String status) {
  return status.replaceAll('_', ' ');
}

Color statusColor(String status) {
  switch (status) {
    case 'PENDING':
      return const Color(0xFFF59E0B);
    case 'ASSIGNED':
      return const Color(0xFF38BDF8);
    case 'CONFIRMED':
      return const Color(0xFF0EA5E9);
    case 'ACCEPTED':
      return const Color(0xFF0EA5E9);
    case 'IN_PROGRESS':
      return const Color(0xFF8B5CF6);
    case 'COMPLETED':
      return const Color(0xFF059669);
    case 'CLOSED':
      return const Color(0xFF64748B);
    case 'CANCELLED':
      return const Color(0xFFEF4444);
    default:
      return Colors.grey;
  }
}
