import 'package:flutter/material.dart';

import '../api.dart';

class UiTone {
  static const Color shellBackground = Color(0xFFF5F4EE);
  static const Color shellAccent = Color(0xFFF0E6D7);
  static const Color surface = Color(0xFFFFFCF7);
  static const Color surfaceMuted = Color(0xFFF4EEE4);
  static const Color surfaceBorder = Color(0xFFE0D5C4);
  static const Color ink = Color(0xFF1E2430);
  static const Color softText = Color(0xFF6E6A63);
  static const Color primary = Color(0xFF123B6D);
  static const Color primarySoft = Color(0xFFDCEBFF);
  static const Color secondary = Color(0xFFC86A3B);
  static const Color success = Color(0xFF1F7A5C);
}

BoxDecoration elevatedSurface({
  Color color = UiTone.surface,
  double radius = 24,
  Color border = UiTone.surfaceBorder,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border),
    boxShadow: const <BoxShadow>[
      BoxShadow(
        color: Color(0x140F172A),
        blurRadius: 28,
        offset: Offset(0, 16),
      ),
    ],
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UiTone.surfaceBorder),
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
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: UiTone.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.inbox_outlined, color: Color(0xFF6077A0)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
  Widget? trailing,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 6, 16, 8),
}) {
  return Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
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
      color: const Color(0xFFE9EFF8),
      borderRadius: borderRadius,
    ),
    alignment: Alignment.center,
    child: Icon(fallbackIcon, color: const Color(0xFF6077A0)),
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
      return Colors.orange;
    case 'ASSIGNED':
      return Colors.lightBlue;
    case 'CONFIRMED':
      return Colors.green;
    case 'IN_PROGRESS':
      return Colors.indigo;
    case 'COMPLETED':
      return Colors.teal;
    case 'CANCELLED':
      return Colors.redAccent;
    default:
      return Colors.grey;
  }
}
