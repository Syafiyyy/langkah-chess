import 'package:flutter/widgets.dart';

/// Corner radius tokens: 8 / 10 / 14 / pill.
abstract final class AppRadius {
  /// Chips, small tiles, clock chips.
  static const Radius sm = Radius.circular(8);

  /// Buttons, inputs, tile buttons.
  static const Radius md = Radius.circular(10);

  /// Cards, sheets, dialogs.
  static const Radius lg = Radius.circular(14);

  /// Pills (current move, badges).
  static const Radius pill = Radius.circular(999);
}
