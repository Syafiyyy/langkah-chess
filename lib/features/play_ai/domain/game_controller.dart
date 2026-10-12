import 'package:dartchess/dartchess.dart';

import 'game_result.dart';
import 'game_state.dart';
import 'time_source.dart';
import 'uci_move.dart';

/// Applies the rules of an offline game. Pure Dart; owns no timers.
///
/// Clock rule (same as Lichess): nothing runs before White's first move.
/// That move starts Black's clock and earns no increment; every later move
/// banks the mover's time, adds the increment and starts the opponent.
///
/// [onFinished] is called exactly once, when the game ends. It is the only
/// place a finished game is reported (history is saved from there).
class GameController {
  GameController({
    required this._state,
    required this._time,
    this._wallClock = DateTime.now,
    this._onFinished,
  });

  final TimeSource _time;
  final DateTime Function() _wallClock;
  final void Function(GameState finished)? _onFinished;
  GameState _state;

  GameState get state => _state;

  /// Plays [move] for the side to move. Returns false if the move is illegal,
  /// the game is over, or the mover's flag fell first (the game then ends).
  bool play(Move move) {
    if (_state.isOver || checkFlag()) return false;
    final position = _state.position;
    if (!position.isLegal(move)) return false;

    final uci = standardUci(position, move);
    final (next, san) = position.makeSan(move);
    final now = _time.now();
    final clock = _state.clock;
    final nextClock = clock == null
        ? null
        : clock.running == null
        ? clock.start(next.turn, now)
        : clock.moved(now);

    _state = _state.copyWith(
      positions: [..._state.positions, next],
      moves: [..._state.moves, MoveRecord(uci: uci, san: san)],
      clock: nextClock,
    );
    final result = resultAfterMove(next, repetitions: _state.repetitions);
    if (result != null) _finish(result);
    return true;
  }

  /// Undoes moves back to the player's previous turn: the bot's reply (if
  /// any) and the player's last move. Refused when the game is over or the
  /// player has not moved yet. Clocks keep their current times.
  bool takeback() {
    if (_state.isOver) return false;
    final player = _state.playerSide;
    final count = _state.position.turn == player ? 2 : 1;
    final keep = _state.moves.length - count;
    // The undone moves must include one of the player's.
    if (keep < 0 || _state.positions[keep].turn != player) return false;

    final now = _time.now();
    final clock = _state.clock;
    final nextClock = clock == null
        ? null
        : keep == 0 && player == Side.white
        ? clock.stop(now) // back before White's first move: no clock yet
        : clock.handOver(player, now);
    _state = _state.copyWith(
      positions: _state.positions.sublist(0, keep + 1),
      moves: _state.moves.sublist(0, keep),
      clock: nextClock,
    );
    return true;
  }

  /// The player resigns.
  void resign() {
    if (_state.isOver) return;
    _finish(
      GameResult(Outcome(winner: _state.botSide), Termination.resignation),
    );
  }

  /// Ends the game if the running side's time is up. Returns true if it did.
  bool checkFlag() {
    if (_state.isOver) return false;
    final flagged = _state.clock?.flagged(_time.now());
    if (flagged == null) return false;
    _finish(timeoutResult(_state.position, flagged));
    return true;
  }

  /// Freezes the clock (app in background).
  void pause() {
    final clock = _state.clock;
    if (_state.isOver || clock == null) return;
    _state = _state.copyWith(clock: clock.pause(_time.now()));
  }

  /// Continues a paused clock.
  void resume() {
    final clock = _state.clock;
    if (_state.isOver || clock == null) return;
    _state = _state.copyWith(clock: clock.resume(_time.now()));
  }

  void _finish(GameResult result) {
    final clock = _state.clock;
    _state = _state.copyWith(
      clock: clock?.stop(_time.now()),
      result: result,
      endedAt: _wallClock(),
    );
    _onFinished?.call(_state);
  }
}
