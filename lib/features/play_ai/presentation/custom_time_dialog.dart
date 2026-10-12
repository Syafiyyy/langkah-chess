import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/time_control.dart';

/// Asks for minutes per side (1–180) and increment seconds (0–60).
///
/// Validation follows the forms rules: no error while typing in an untouched
/// field; a field is checked when you leave it; its error clears on the next
/// keystroke; "Use this time" is always tappable and shows what to fix.
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
  late final _minutes = _Field(
    text: widget.initial.isTimed ? '${widget.initial.minutes}' : '10',
    min: 1,
    max: 180,
    error: 'Enter 1 to 180 minutes',
  );
  late final _increment = _Field(
    text: '${widget.initial.incrementSeconds}',
    min: 0,
    max: 60,
    error: 'Enter 0 to 60 seconds',
  );

  @override
  void initState() {
    super.initState();
    for (final f in [_minutes, _increment]) {
      f.focus.addListener(() {
        // Leaving a field checks it.
        if (!f.focus.hasFocus) setState(() => f.showError = !f.isValid);
      });
    }
  }

  @override
  void dispose() {
    _minutes.dispose();
    _increment.dispose();
    super.dispose();
  }

  void _submit() {
    if (_minutes.isValid && _increment.isValid) {
      Navigator.pop(
        context,
        TimeControl.minutes(_minutes.value!, _increment.value!),
      );
      return;
    }
    setState(() {
      _minutes.showError = !_minutes.isValid;
      _increment.showError = !_increment.isValid;
    });
    (_minutes.isValid ? _increment : _minutes).focus.requestFocus();
  }

  Widget _input(_Field f, String label, String help) {
    return TextField(
      controller: f.controller,
      focusNode: f.focus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        helperText: f.showError ? null : help,
        errorText: f.showError ? f.error : null,
      ),
      // The first corrective keystroke clears the error.
      onChanged: (_) {
        if (f.showError) setState(() => f.showError = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _input(_minutes, 'Minutes per side', '1 to 180'),
          _input(_increment, 'Increment (seconds)', '0 to 60'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Use this time')),
      ],
    );
  }
}

class _Field {
  _Field({
    required String text,
    required this.min,
    required this.max,
    required this.error,
  }) : controller = TextEditingController(text: text);

  final TextEditingController controller;
  final FocusNode focus = FocusNode();
  final int min;
  final int max;
  final String error;
  bool showError = false;

  int? get value => int.tryParse(controller.text);
  bool get isValid {
    final v = value;
    return v != null && v >= min && v <= max;
  }

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}
