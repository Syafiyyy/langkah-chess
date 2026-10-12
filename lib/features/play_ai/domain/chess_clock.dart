import 'package:dartchess/dartchess.dart';

import 'time_control.dart';

/// Immutable two-sided chess clock.
///
/// Time is measured, never counted down: each side has a banked remaining
/// time, and the running side loses `now - since`, where `now` comes from a
/// monotonic [TimeSource]. A UI ticker only repaints; it never changes time.
class ChessClock {
  const ChessClock._({
    required this.white,
    required this.black,
    required this.increment,
    this.running,
    this.since,
  });

  /// Both sides at the starting time; nothing running yet.
  factory ChessClock.initial(TimeControl control) => ChessClock._(
    white: control.initial,
    black: control.initial,
    increment: control.increment,
  );

  /// Rebuilds a running clock (e.g. a resumed game) from banked times.
  factory ChessClock.restore({
    required Duration white,
    required Duration black,
    required Duration increment,
    required Side? running,
    required Duration now,
  }) => ChessClock._(
    white: white,
    black: black,
    increment: increment,
    running: running,
    since: running == null ? null : now,
  );

  /// Banked time per side, as of [since] for the running side.
  final Duration white;
  final Duration black;
  final Duration increment;

  /// The side whose turn it is on the clock; null before start or after stop.
  final Side? running;

  /// Monotonic time the running side's segment started; null when paused.
  final Duration? since;

  bool get isPaused => running != null && since == null;

  Duration _banked(Side side) => side == Side.white ? white : black;

  Duration _elapsed(Duration now) => since == null ? Duration.zero : now - since!;

  /// Time left for [side] at [now], never negative.
  Duration remaining(Side side, Duration now) {
    final left = side == running
        ? _banked(side) - _elapsed(now)
        : _banked(side);
    return left.isNegative ? Duration.zero : left;
  }

  /// The running side if its time is up at [now].
  Side? flagged(Duration now) {
    final side = running;
    if (side == null || isPaused) return null;
    return remaining(side, now) == Duration.zero ? side : null;
  }

  /// How long until the running side flags; null if nothing is ticking.
  Duration? timeToFlag(Duration now) {
    final side = running;
    if (side == null || isPaused) return null;
    return remaining(side, now);
  }

  /// Starts [side]'s clock at [now].
  ChessClock start(Side side, Duration now) => _copy(running: side, since: now);

  /// The running side completed a move at [now]: bank its time, add the
  /// increment, start the other side. A paused clock stays paused.
  ChessClock moved(Duration now) {
    final side = running!;
    final left = remaining(side, now) + increment;
    return ChessClock._(
      white: side == Side.white ? left : white,
      black: side == Side.black ? left : black,
      increment: increment,
      running: side.opposite,
      since: isPaused ? null : now,
    );
  }

  /// Banks the running side's time and runs [side] instead, with no
  /// increment (used by takeback). A paused clock stays paused.
  ChessClock handOver(Side side, Duration now) =>
      _bank(now)._copy(running: side, since: isPaused ? null : now);

  ChessClock pause(Duration now) {
    if (running == null || isPaused) return this;
    return _bank(now)._copy(running: running, since: null);
  }

  ChessClock resume(Duration now) {
    if (!isPaused) return this;
    return _copy(running: running, since: now);
  }

  /// Banks the running side's time and stops both clocks.
  ChessClock stop(Duration now) => _bank(now)._copy(running: null, since: null);

  ChessClock _bank(Duration now) {
    final side = running;
    if (side == null) return this;
    final left = remaining(side, now);
    return ChessClock._(
      white: side == Side.white ? left : white,
      black: side == Side.black ? left : black,
      increment: increment,
      running: running,
      since: since == null ? null : now,
    );
  }

  ChessClock _copy({required Side? running, required Duration? since}) =>
      ChessClock._(
        white: white,
        black: black,
        increment: increment,
        running: running,
        since: since,
      );
}
