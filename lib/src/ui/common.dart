import 'package:flutter/material.dart';

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

const String kDefaultFallbackCity = 'Hyderabad';

BoxDecoration elevatedSurface({
  Color color = UiTone.surface,
  double radius = 20,
  Color border = UiTone.surfaceBorder,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border, width: 1.2),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x081A2B23), blurRadius: 12, offset: Offset(0, 4)),
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

Widget loadingView([String message = 'Loading...']) {
  return Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UiTone.surfaceBorder, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}

Widget emptyView(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: mutedSurface(radius: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.inbox_outlined, color: Color(0xFF5A8B73)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: UiTone.softText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    ),
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
                    fontWeight: FontWeight.w500,
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
      filterQuality: FilterQuality.low,
      errorBuilder: (context, error, stackTrace) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
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
