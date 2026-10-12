import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/app/theme/app_colors.dart';

/// WCAG 2.x relative luminance and contrast ratio.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

/// CIE L* (perceived lightness), for "differ in lightness, not hue only".
double _lightness(Color c) {
  final y = _luminance(c);
  return y > 0.008856 ? 116 * pow(y, 1 / 3) - 16 : 903.3 * y;
}

void main() {
  const surfaces = {
    'ground': AppColors.ground,
    'surface': AppColors.surface,
    'raised': AppColors.surfaceRaised,
  };
  const readable = {
    'text': AppColors.text,
    'textMuted': AppColors.textMuted,
    'accent': AppColors.accent,
    'danger': AppColors.danger,
    'success': AppColors.success,
    'labelBest': AppColors.labelBest,
    'labelInaccuracy': AppColors.labelInaccuracy,
    'labelMistake': AppColors.labelMistake,
    'labelBlunder': AppColors.labelBlunder,
  };

  for (final fg in readable.entries) {
    for (final bg in surfaces.entries) {
      test('${fg.key} on ${bg.key} is at least 4.5:1', () {
        expect(contrast(fg.value, bg.value), greaterThanOrEqualTo(4.5));
      });
    }
  }

  test('text on the gold accent is at least 4.5:1, also when pressed', () {
    expect(contrast(AppColors.onAccent, AppColors.accent), greaterThan(4.5));
    expect(
      contrast(AppColors.onAccent, AppColors.accentPressed),
      greaterThan(4.5),
    );
  });

  test('faint text only reaches 4.5:1 on the ground (disabled/decor only)', () {
    expect(contrast(AppColors.textFaint, AppColors.ground), greaterThan(4.5));
    expect(contrast(AppColors.textFaint, AppColors.surface), lessThan(4.5));
  });

  test('review labels differ in lightness by at least 5 L* steps', () {
    final l = [
      AppColors.labelInaccuracy,
      AppColors.labelBest,
      AppColors.labelMistake,
      AppColors.labelBlunder,
    ].map(_lightness).toList();
    for (var i = 1; i < l.length; i++) {
      expect(l[i - 1] - l[i], greaterThanOrEqualTo(5), reason: '$l');
    }
  });
}
