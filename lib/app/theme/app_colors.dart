import 'package:flutter/material.dart';

/// "Songket" shell colours: navy ground, layered surfaces, one gold accent.
///
/// Every text/background pair used in the app is checked in
/// test/app/theme/contrast_test.dart (>= 4.5:1). Never hard-code colours in
/// widgets; add a token here instead. Board colours live in board themes.
abstract final class AppColors {
  // Surfaces (L0 ground → L1 surface → L2 raised), separated by [border].
  static const Color ground = Color(0xFF101826);
  static const Color surface = Color(0xFF18233A);
  static const Color surfaceRaised = Color(0xFF1F2C48);
  static const Color border = Color(0xFF2C3B59);

  // Text.
  static const Color text = Color(0xFFF3EEE3);
  static const Color textMuted = Color(0xFFAFB8C9);

  /// Below 4.5:1 on surfaces: disabled controls and decoration only.
  static const Color textFaint = Color(0xFF7D879B);

  // Accent (single interactive hue).
  static const Color accent = Color(0xFFD9A93F);
  static const Color accentPressed = Color(0xFFEBC56B);
  static const Color onAccent = Color(0xFF101826);

  // Status.
  static const Color danger = Color(0xFFFF7B6E);
  static const Color success = Color(0xFF5ED39A);

  // Move judgements (review): lightness falls as severity rises
  // (inaccuracy L*86 > best 80 > mistake 71 > blunder 64), not hue only.
  static const Color labelBest = Color(0xFF8FD98A);
  static const Color labelInaccuracy = Color(0xFFF2D46B);
  static const Color labelMistake = Color(0xFFF39A4E);
  static const Color labelBlunder = Color(0xFFFF6B6B);

  // Eval bar / graph (shell, not board theme).
  static const Color evalWhite = text;
  static const Color evalBlack = Color(0xFF34425F);
}
