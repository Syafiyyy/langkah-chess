// Bot strength calibration: level N vs level N+1, plus level 1 vs a random
// mover. Prints `[calib]` lines; results go into docs/STATE.md.
// Run: flutter test integration_test/bot_calibration_test.dart -d <device>
//      (--dart-define=CALIB_GAMES=10 --dart-define=CALIB_PAIRS=1-2,2-3)
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:langkah/core/engine/engine_service.dart';
import 'package:langkah/core/engine/uci_engine.dart';
import 'package:langkah/features/play_ai/application/bot_mover.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/game_controller.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';
import 'package:langkah/features/play_ai/domain/time_source.dart';

const _games = int.fromEnvironment('CALIB_GAMES', defaultValue: 10);
const _pairs = String.fromEnvironment(
  'CALIB_PAIRS',
  defaultValue: '0-1,1-2,2-3,3-4,4-5,5-6,6-7,7-8',
);

/// A player: a bot level, or null for a random legal mover ("level 0").
typedef _Player = BotMover?;

Future<String> _move(_Player player, Position p, Random rng) async {
  if (player == null) {
    final moves = [
      for (final e in p.legalMoves.entries)
        for (final to in e.value.squares) NormalMove(from: e.key, to: to),
    ];
    var m = moves[rng.nextInt(moves.length)];
    if (p.board.roleAt(m.from) == Role.pawn &&
        (m.to.rank == Rank.first || m.to.rank == Rank.eighth)) {
      m = m.withPromotion(Role.queen);
    }
    return m.uci;
  }
  final level = player.level;
  final uci = await player.move(
    p,
    // The same search time the app uses (untimed game).
    searchTime: level.style?.searchTime ?? level.moveTime,
    stillWanted: () => true,
  );
  return uci!;
}

/// One game; returns the score for [white] (1, 0.5, 0) and the ply count.
Future<(double, int)> _game(_Player white, _Player black, Random rng) async {
  final c = GameController(
    state: GameState.start(
      id: 'calib',
      level: BotLevel.of(1),
      timeControl: TimeControl.unlimited,
      playerSide: Side.white,
      startedAt: DateTime.now(),
    ),
    time: MonotonicTimeSource(),
  );
  while (!c.state.isOver && c.state.moves.length < 300) {
    final p = c.state.position;
    final mover = p.turn == Side.white ? white : black;
    final uci = await _move(mover, p, rng);
    expect(c.play(Move.parse(uci)!), isTrue, reason: 'illegal $uci');
  }
  final winner = c.state.result?.outcome.winner;
  final score = c.state.isOver
      ? (winner == null ? 0.5 : (winner == Side.white ? 1.0 : 0.0))
      : 0.5; // 300 plies: adjudicated draw
  return (score, c.state.moves.length);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bot calibration', (tester) async {
    final engine = EngineService(StockfishUciEngine.start);
    final rng = Random(42);
    _Player player(int n) => n == 0
        ? null
        : BotMover(
            engine: engine,
            level: BotLevel.of(n),
            random: rng,
            pause: (_) async {},
          );

    for (final pair in _pairs.split(',')) {
      final [lo, hi] = pair.split('-').map(int.parse).toList();
      var hiScore = 0.0;
      var plies = 0;
      final watch = Stopwatch()..start();
      for (var g = 0; g < _games; g++) {
        // Fresh players per game (each picker remembers its last blunder).
        final a = player(lo);
        final b = player(hi);
        final hiWhite = g.isEven;
        final (whiteScore, n) = hiWhite
            ? await _game(b, a, rng)
            : await _game(a, b, rng);
        hiScore += hiWhite ? whiteScore : 1 - whiteScore;
        plies += n;
      }
      debugPrint(
        '[calib] L$hi vs L$lo: L$hi scored $hiScore/$_games '
        '(${(100 * hiScore / _games).round()}%), '
        'avg ${plies ~/ _games} plies, ${watch.elapsed.inSeconds}s',
      );
    }
    await engine.dispose();
  }, timeout: const Timeout(Duration(minutes: 90)));
}
