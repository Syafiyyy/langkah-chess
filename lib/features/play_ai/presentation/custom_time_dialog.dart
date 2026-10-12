import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/time_control.dart';

/// Asks for minutes per side (1–180) and increment seconds (0–60).
Future<TimeControl?> showCustomTimeDialog(
  BuildContext context,
  TimeControl initial,
) {
  return showDialog<TimeControl>(
    context: context,
    builder: (context) => _CustomTimeDialog(initial: initial),
  );
}

class _CustomTimeDialog extends StatefulWidget {
  const _CustomTimeDialog({required this.initial});

  final TimeControl initial;

  @override
  State<_CustomTimeDialog> createState() => _CustomTimeDialogState();
}

class _CustomTimeDialogState extends State<_CustomTimeDialog> {
  late final _minutes = TextEditingController(
    text: widget.initial.isTimed ? '${widget.initial.minutes}' : '10',
  );
  late final _increment = TextEditingController(
    text: '${widget.initial.incrementSeconds}',
  );

  TimeControl? get _value {
    final minutes = int.tryParse(_minutes.text);
    final increment = int.tryParse(_increment.text);
    if (minutes == null || minutes < 1 || minutes > 180) return null;
    if (increment == null || increment < 0 || increment > 60) return null;
    return TimeControl.minutes(minutes, increment);
  }

  @override
  void dispose() {
    _minutes.dispose();
    _increment.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label, String help) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, helperText: help),
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return AlertDialog(
      title: const Text('Custom time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(_minutes, 'Minutes per side', '1 to 180'),
          _field(_increment, 'Increment (seconds)', '0 to 60'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: value == null ? null : () => Navigator.pop(context, value),
          child: const Text('Use this time'),
        ),
      ],
    );
  }
}
