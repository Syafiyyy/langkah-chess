import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';

/// Named confirmation: the player types their username to enable
/// "Delete account". Returns true when confirmed.
Future<bool> showDeleteAccountDialog(BuildContext context, String username) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _DeleteAccountDialog(username: username),
  );
  return result ?? false;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.username});

  final String username;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  bool get _matches => _controller.text.trim().toLowerCase() == widget.username;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete your account?'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your profile and rating are removed for good. Games in '
            'progress are resigned. Opponents keep their games with '
            '"Deleted player". Games against the bot stay on this phone.',
            style: AppType.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Type ${widget.username} to confirm', style: AppType.secondary),
          TextField(
            controller: _controller,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep account'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}
