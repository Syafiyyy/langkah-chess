import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../application/play_ai_providers.dart';
import '../domain/chess_clock.dart';

/// m:ss, or s.t under ten seconds (e.g. `0:09.3`).
String formatClock(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  final base = '$minutes:${seconds.toString().padLeft(2, '0')}';
  if (d >= const Duration(seconds: 10)) return base;
  return '$base.${(d.inMilliseconds % 1000) ~/ 100}';
}

/// One side's clock. While that side's time runs, a ticker repaints every
/// frame; the time itself always comes from the [ChessClock] and the
/// monotonic time source, never from counting ticks.
class ClockText extends ConsumerStatefulWidget {
  const ClockText({super.key, required this.clock, required this.side});

  final ChessClock clock;
  final Side side;

  @override
  ConsumerState<ClockText> createState() => _ClockTextState();
}

class _ClockTextState extends ConsumerState<ClockText>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  bool get _running =>
      widget.clock.running == widget.side && !widget.clock.isPaused;

  @override
  void initState() {
    super.initState();
    if (_running) _ticker.start();
  }

  @override
  void didUpdateWidget(ClockText old) {
    super.didUpdateWidget(old);
    if (_running && !_ticker.isActive) _ticker.start();
    if (!_running && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(timeSourceProvider).now();
    final left = widget.clock.remaining(widget.side, now);
    final low = left < const Duration(seconds: 20);
    final active = widget.clock.running == widget.side;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.surfaceRaised,
        borderRadius: const BorderRadius.all(AppRadius.sm),
      ),
      child: Text(
        formatClock(left),
        style: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: active
              ? (low ? AppColors.danger : AppColors.onAccent)
              : (low ? AppColors.danger : AppColors.textMuted),
        ),
      ),
    );
  }
}
