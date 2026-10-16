import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/widgets/clock_chip.dart';
import '../../play_ai/presentation/clock_text.dart';
import '../application/online_game_view.dart';
import '../domain/online_clock.dart';

/// One side's online clock: the server's stored time minus the time since
/// the last move (server-time corrected). While the player's own move is on
/// its way, their clock stops at the moment they moved.
class OnlineClockText extends ConsumerStatefulWidget {
  const OnlineClockText({super.key, required this.view, required this.side});

  final OnlineGameView view;
  final Side side;

  @override
  ConsumerState<OnlineClockText> createState() => _OnlineClockTextState();
}

class _OnlineClockTextState extends ConsumerState<OnlineClockText>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  bool get _running {
    final v = widget.view;
    return v.game.clocksRunning &&
        v.pending == null &&
        v.game.turn == widget.side;
  }

  @override
  void initState() {
    super.initState();
    if (_running) _ticker.start();
  }

  @override
  void didUpdateWidget(OnlineClockText old) {
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
    final v = widget.view;
    final at = v.pending?.madeAt ?? ref.watch(serverClockProvider).now();
    final left = remainingTime(v.game, widget.side, at);
    return ClockChip(
      text: formatClock(left),
      active: v.game.isActive && v.position.turn == widget.side,
      low: left < const Duration(seconds: 20),
    );
  }
}
