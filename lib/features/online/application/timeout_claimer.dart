import 'dart:async';

import 'package:dartchess/dartchess.dart';

import '../../../core/supabase/server_clock.dart';
import '../domain/online_clock.dart';
import '../domain/server_game.dart';

/// Claims the timeout when the opponent's clock (or first-move deadline)
/// runs out: once per ply, a little after the computed time so a small clock
/// offset doesn't claim too early. The server's minute sweep is the fallback.
class TimeoutClaimer {
  TimeoutClaimer(this._clock, this._claim);

  final ServerClock _clock;
  final void Function() _claim;
  Timer? _timer;
  int? _claimedAtPly;

  static const Duration margin = Duration(milliseconds: 300);

  /// Re-plans for [game], where the player plays [mySide].
  void update(ServerGame game, Side mySide) {
    _timer?.cancel();
    if (!game.isActive || game.turn == mySide || _claimedAtPly == game.ply) {
      return;
    }
    final left = timeUntilFlag(game, _clock.now());
    if (left == null) return;
    _timer = Timer(left + margin, () {
      final now = timeUntilFlag(game, _clock.now());
      if (now != null && now > Duration.zero) return update(game, mySide);
      _claimedAtPly = game.ply;
      _claim();
    });
  }

  void cancel() => _timer?.cancel();
}
