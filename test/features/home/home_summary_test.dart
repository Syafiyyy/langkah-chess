import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/home/application/home_summary.dart';
import 'package:skak/features/review/domain/position_eval.dart';

import '../play_ai/presentation/game_test_harness.dart';
import '../review/memory_analysis.dart';
import 'finished_games.dart';

void main() {
  test('recent games (newest 3), totals and best reviewed accuracy', () async {
    final history = MemoryHistory();
    for (final g in [
      finishedGame('a', day: 1, kind: 'win'),
      finishedGame('b', day: 2, kind: 'loss'),
      finishedGame('c', day: 3, kind: 'draw'),
      finishedGame('d', day: 4, kind: 'win'),
    ]) {
      await history.save(g);
    }
    // Game "a" (5 positions) has a cached review; the player (black) was
    // perfect, so accuracy is 100.
    final analysis = MemoryAnalysis({
      'a': [
        const PositionEval(cp: 0),
        const PositionEval(cp: 0),
        const PositionEval(cp: 0),
        const PositionEval(mate: -1),
        PositionEval.gameOver(Outcome.blackWins),
      ],
    });

    final summary = await loadHomeSummary(history, analysis);

    expect(summary.recent.map((r) => r.game.id), ['d', 'c', 'b']);
    expect(summary.recent.every((r) => r.accuracy == null), isTrue);
    expect(summary.played, 4);
    expect(summary.wins, 2);
    expect(summary.bestAccuracy, closeTo(100, 1e-9));
  });

  test('an empty history gives an empty summary', () async {
    final summary = await loadHomeSummary(MemoryHistory(), MemoryAnalysis());
    expect(summary.recent, isEmpty);
    expect(summary.played, 0);
    expect(summary.bestAccuracy, isNull);
  });

  test('accuracy of a recent reviewed game is shown', () async {
    final history = MemoryHistory();
    await history.save(finishedGame('only', day: 5, kind: 'win'));
    final analysis = MemoryAnalysis({
      'only': [
        const PositionEval(cp: 0),
        const PositionEval(cp: 0),
        const PositionEval(cp: 0),
        const PositionEval(mate: -1),
        PositionEval.gameOver(Outcome.blackWins),
      ],
    });
    final summary = await loadHomeSummary(history, analysis);
    expect(summary.recent.single.accuracy, closeTo(100, 1e-9));
  });
}
