import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/online/domain/online_clock.dart';
import 'package:skak/features/online/domain/server_game.dart';

final _t0 = DateTime.utc(2026, 10, 16, 12);

ServerGame _game({
  int ply = 10,
  GameStatus status = GameStatus.active,
  int whiteMs = 60000,
  int blackMs = 50000,
  DateTime? deadline,
}) => ServerGame(
  id: 'g',
  status: status,
  mode: 'invite',
  timeBaseMs: 300000,
  incrementMs: 0,
  fen: '',
  ply: ply,
  whiteMs: whiteMs,
  blackMs: blackMs,
  lastMoveAt: _t0,
  firstMoveDeadline: deadline,
);

void main() {
  test('side to move loses the time since the last move', () {
    final g = _game(); // ply 10: White to move.
    final now = _t0.add(const Duration(seconds: 7, milliseconds: 250));
    expect(
      remainingTime(g, Side.white, now),
      const Duration(milliseconds: 52750),
    );
    expect(remainingTime(g, Side.black, now), const Duration(seconds: 50));
  });

  test('never below zero', () {
    final g = _game(ply: 11); // Black to move.
    expect(
      remainingTime(g, Side.black, _t0.add(const Duration(minutes: 5))),
      Duration.zero,
    );
  });

  test('frozen before both first moves and after the end', () {
    final later = _t0.add(const Duration(seconds: 20));
    expect(
      remainingTime(_game(ply: 1), Side.black, later),
      const Duration(seconds: 50),
    );
    expect(
      remainingTime(_game(status: GameStatus.finished), Side.white, later),
      const Duration(seconds: 60),
    );
  });

  test('first-move countdown only while a first move is due', () {
    final deadline = _t0.add(const Duration(seconds: 30));
    final now = _t0.add(const Duration(seconds: 12));
    expect(
      firstMoveTimeLeft(_game(ply: 0, deadline: deadline), now),
      const Duration(seconds: 18),
    );
    expect(firstMoveTimeLeft(_game(ply: 2, deadline: deadline), now), isNull);
    expect(
      firstMoveTimeLeft(
        _game(ply: 1, deadline: deadline),
        _t0.add(const Duration(minutes: 1)),
      ),
      Duration.zero,
    );
  });

  test('time until the side to move flags', () {
    // White to move with 60 s at _t0; 10 s later 50 s remain.
    final now = _t0.add(const Duration(seconds: 10));
    expect(timeUntilFlag(_game(), now), const Duration(seconds: 50));
    expect(
      timeUntilFlag(
        _game(ply: 1, deadline: _t0.add(const Duration(seconds: 30))),
        now,
      ),
      const Duration(seconds: 20),
    );
    expect(timeUntilFlag(_game(status: GameStatus.finished), now), isNull);
  });
}
