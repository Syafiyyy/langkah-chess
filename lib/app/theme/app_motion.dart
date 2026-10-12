import 'package:flutter/widgets.dart';

/// Motion tokens. One easing; three durations.
///
/// Respect reduced motion: when the platform asks to disable animations
/// ([MediaQuery.disableAnimations]), movement becomes instant (use
/// [AppMotion.of]); opacity-only fades may stay at [fast].
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve curve = Curves.easeOutCubic;

  /// [duration], or zero when the user prefers reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
