import 'package:flutter/material.dart';

/// Dark-first colour tokens. Minimal set for F0; the full system comes in F3.
abstract final class AppColors {
  static const Color background = Color(0xFF101413);
  static const Color surface = Color(0xFF181E1C);
  static const Color surfaceRaised = Color(0xFF222A27);
  static const Color line = Color(0xFF2E3833);
  static const Color text = Color(0xFFE8EDE9);
  static const Color textMuted = Color(0xFF9AA6A0);
  static const Color accent = Color(0xFFD4A84B);
  static const Color onAccent = Color(0xFF1A1405);
  static const Color danger = Color(0xFFE5675C);

  // Move judgements (game review). Blunders use [danger].
  static const Color best = Color(0xFF7DBB6E);
  static const Color inaccuracy = Color(0xFFE2C25B);
  static const Color mistake = Color(0xFFE59A4C);
}
