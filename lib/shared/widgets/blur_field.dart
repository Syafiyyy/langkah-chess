import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A text field's state with blur-first validation (the forms rules): no
/// error while typing in an untouched field, checked when the field is left,
/// and the error clears on the next keystroke.
class BlurField {
  BlurField(this._validate);

  final String? Function(String value) _validate;
  final TextEditingController controller = TextEditingController();
  final FocusNode focus = FocusNode();
  String? _error;
  VoidCallback? _onChange;

  String get text => controller.text;
  String? get error => _error;

  /// Called when the field is left or its error changes.
  void attach(VoidCallback onChange) {
    _onChange = onChange;
    focus.addListener(() {
      if (!focus.hasFocus && controller.text.isNotEmpty) {
        _error = _validate(controller.text);
        onChange();
      }
    });
  }

  /// Checks now (on submit). True when valid.
  bool validateNow() {
    _error = _validate(controller.text);
    return _error == null;
  }

  /// Shows [message] (e.g. from the server) until the next keystroke.
  void showError(String? message) {
    _error = message;
    _onChange?.call();
  }

  void clearError() => _error = null;

  Widget build({
    required String label,
    String? helper,
    bool obscure = false,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization capitalization = TextCapitalization.none,
    TextStyle? style,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focus,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      textCapitalization: capitalization,
      autocorrect: false,
      style: style,
      decoration: InputDecoration(
        labelText: label,
        helperText: _error == null ? helper : null,
        errorText: _error,
      ),
      // Tapping elsewhere leaves the field (Android keeps focus otherwise),
      // which runs the blur check.
      onTapOutside: (_) => focus.unfocus(),
      onSubmitted: onSubmitted,
      onChanged: (value) {
        if (_error != null) {
          _error = null;
          _onChange?.call();
        }
        onChanged?.call(value);
      },
    );
  }

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}
