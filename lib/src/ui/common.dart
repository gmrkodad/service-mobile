import 'package:flutter/material.dart';

import '../api.dart';

void showApiError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : error.toString();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Widget loadingView([String message = 'Loading...']) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(message),
      ],
    ),
  );
}

Widget emptyView(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
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