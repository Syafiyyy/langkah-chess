import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/core/chess/win_percent.dart';
import 'package:langkah/features/play_ai/domain/game_state.dart';
import 'package:langkah/features/review/domain/move_review.dart';
import 'package:langkah/features/review/domain/position_eval.dart';

void main() {
  group('PositionEval', () {
    test(
      'engine scores are flipped to White\'s view when Black is to move',
      () {
        final black = PositionEval.fromSideToMove(
          turn: Side.black,
          cp: 50,
          bestMove: 'e7e5',
        );
        expect(black.cp, -50);
        final mate = PositionEval.fromSideToMove(turn: Side.black, mate: 3);
        expect(mate.mate, -3);
        final white = PositionEval.fromSideToMove(turn: Side.white, cp: 50);
        expect(white.cp, 50);
      },
    );

    test('white win% from cp, mate and finished games', () {
      expect(const PositionEval(cp: 0).whiteWin, closeTo(50, 1e-9));
      expect(const PositionEval(mate: 2).whiteWin, 100);
      expect(const PositionEval(mate: -1).whiteWin, 0);
      expect(PositionEval.gameOver(Outcome.whiteWins).whiteWin, 100);
      expect(PositionEval.gameOver(Outcome.blackWins).whiteWin, 0);
      expect(PositionEval.gameOver(Outcome.draw).whiteWin, 50);
    });

    test('round-trips through JSON', () {
      const e = PositionEval(cp: -37, bestMove: 'g1f3', pv: ['g1f3', 'd7d5']);
      final back = PositionEval.fromJson(e.toJson());
      expect(back.cp, -37);
      expect(back.bestMove, 'g1f3');
      expect(back.pv, ['g1f3', 'd7d5']);
      final over = PositionEval.fromJson(
        PositionEval.gameOver(Outcome.blackWins).toJson(),
      );
      expect(over.whiteWin, 0);
    });
  });

  group('labelFor (mover win% before/after)', () {
    test('thresholds 15 / 10 / 5', () {
      expect(labelFor(60, 45, playedBest: false), MoveLabel.blunder);
      expect(labelFor(60, 45.01, playedBest: false), MoveLabel.mistake);
      expect(labelFor(60, 50, playedBest: false), MoveLabel.mistake);
      expect(labelFor(60, 50.01, playedBest: false), MoveLabel.inaccuracy);
      expect(labelFor(60, 55, playedBest: false), MoveLabel.inaccuracy);
      expect(labelFor(60, 55.01, playedBest: false), isNull);
    });

    test('the engine\'s move is "best" whatever the drop', () {
      expect(labelFor(60, 40, playedBest: true), MoveLabel.best);
    });

    test('no error label when the game was already decided', () {
      expect(labelFor(99, 90.5, playedBest: false), isNull); // still winning
      expect(labelFor(99, 89, playedBest: false), MoveLabel.mistake);
      expect(labelFor(8, 1, playedBest: false), isNull); // already lost
      expect(labelFor(12, 1, playedBest: false), MoveLabel.mistake);
    });
  });

  group('moveAccuracy (lila AccuracyPercent)', () {
    test('no drop (or a gain) is 100', () {
      expect(moveAccuracy(50, 50), 100);
      expect(moveAccuracy(40, 55), 100);
    });

    test('matches the formula with the +1 bonus', () {
      expect(moveAccuracy(60, 50), closeTo(64.58, 0.01));
      expect(moveAccuracy(70, 20), closeTo(9.53, 0.01));
    });

    test('is clamped at 0', () => expect(moveAccuracy(100, 0), 0));
  });

  group('reviewGame', () {
    // Fool's mate: 1. f3 e5 2. g4?? Qh4#
    final ucis = ['f2f3', 'e7e5', 'g2g4', 'd8h4'];
    final positions = <Position>[Chess.initial];
    final moves = <MoveRecord>[];
    for (final uci in ucis) {
      final (next, san) = positions.last.makeSan(Move.parse(uci)!);
      positions.add(next);
      moves.add(MoveRecord(uci: uci, san: san));
    }
    final evals = [
      const PositionEval(cp: 20, bestMove: 'e2e4'),
      const PositionEval(cp: -60, bestMove: 'e7e5'),
      const PositionEval(cp: -50, bestMove: 'd2d4'),
      const PositionEval(mate: -1, bestMove: 'd8h4'),
      PositionEval.gameOver(Outcome.blackWins),
    ];

    test('labels each move from the mover\'s view', () {
      final reviews = reviewGame(
        positions: positions,
        moves: moves,
        evals: evals,
      );
      expect(reviews.map((r) => r.label), [
        MoveLabel.inaccuracy, // f3: 53.7% -> 44.5%
        MoveLabel.best, // e5 = engine move
        MoveLabel.blunder, // g4 allows mate
        MoveLabel.best, // Qh4#
      ]);
      expect(reviews[2].mover, Side.white);
      expect(reviews[2].winBefore, closeTo(winPercent(cp: -50), 1e-9));
      expect(reviews[2].winAfter, 0);
      expect(reviews[0].bestMove, 'e2e4');
      expect(reviews[2].bestSan, 'd4');
    });

    test('summary: accuracy and error counts per side', () {
      final reviews = reviewGame(
        positions: positions,
        moves: moves,
        evals: evals,
      );
      final white = summarise(reviews, Side.white);
      final black = summarise(reviews, Side.black);
      expect(white.inaccuracies, 1);
      expect(white.mistakes, 0);
      expect(white.blunders, 1);
      expect(black.blunders, 0);
      final expected =
          (moveAccuracy(winPercent(cp: 20), winPercent(cp: -60)) +
              moveAccuracy(winPercent(cp: -50), 0)) /
          2;
      expect(white.accuracy, closeTo(expected, 1e-9));
      expect(black.accuracy, greaterThan(95));
    });

    test('with partial analysis only reviews moves whose evals are known', () {
      final reviews = reviewGame(
        positions: positions,
        moves: moves,
        evals: evals.sublist(0, 3),
      );
      expect(reviews, hasLength(2));
      expect(summarise(const [], Side.white).accuracy, isNull);
    });
  });
}
