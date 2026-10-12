import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Asks before an action. Returns true only if [confirmLabel] was tapped.
/// Labels name the action ("Resign game", "Abandon game"), never "OK".
/// [destructive] colours the confirm button with the danger colour.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        TextButton(
          style: destructive
              ? TextButton.styleFrom(foregroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
