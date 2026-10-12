import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';

// Stockfish 19 ranges, read from its `uci` output on 2026-10-12.
const _minElo = 1320;
const _maxElo = 3190;

void main() {
  test('there are 8 levels numbered 1 to 8', () {
    expect(BotLevel.all.map((l) => l.number), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(BotLevel.of(3).number, 3);
  });

  test('levels have human names', () {
    expect(BotLevel.all.map((l) => l.name), [
      'Newcomer',
      'Beginner',
      'Casual',
      'Improving',
      'Club',
      'Strong club',
      'Expert',
      'Full strength',
    ]);
  });

  test('only the UCI_Elo levels carry a rating number', () {
    // Bot-vs-bot calibration only shows relative strength, so the
    // human-style levels are named, not rated (see docs/STATE.md).
    expect(BotLevel.all.map((l) => l.approxRating), [
      null,
      null,
      null,
      null,
      1400,
      1800,
      2200,
      null,
    ]);
  });

  test('human-style levels search at full strength and pick themselves', () {
    for (final level in BotLevel.all.where((l) => l.style != null)) {
      expect(level.engineOptions['UCI_LimitStrength'], 'false');
      expect(level.engineOptions['Skill Level'], '20');
      expect(level.engineOptions.containsKey('UCI_Elo'), isFalse);
    }
  });

  test('Elo levels set UCI_LimitStrength with an in-range UCI_Elo', () {
    for (final n in [5, 6, 7]) {
      final level = BotLevel.of(n);
      expect(level.engineOptions['UCI_LimitStrength'], 'true');
      final elo = int.parse(level.engineOptions['UCI_Elo']!);
      expect(elo, inInclusiveRange(_minElo, _maxElo));
      expect(elo, level.approxRating);
    }
  });

  test('the top level plays at full strength', () {
    final top = BotLevel.all.last;
    expect(top.style, isNull);
    expect(top.engineOptions['UCI_LimitStrength'], 'false');
    expect(top.engineOptions['Skill Level'], '20');
  });

  test('every level sets the same option names, so switching resets them', () {
    for (final level in BotLevel.all) {
      expect(
        level.engineOptions.keys,
        containsAll(['UCI_LimitStrength', 'Skill Level']),
      );
    }
  });

  test('label and rating hint', () {
    expect(BotLevel.of(1).label, 'Level 1 · Newcomer');
    expect(BotLevel.of(1).ratingHint, isNull);
    expect(BotLevel.of(5).ratingHint, '~1400');
    expect(BotLevel.of(8).ratingHint, 'Max');
  });

  test('safe think budget: 1/30 of the clock plus half the increment', () {
    expect(
      safeThinkBudget(
        remaining: const Duration(seconds: 60),
        increment: const Duration(seconds: 2),
      ),
      const Duration(seconds: 3),
    );
    expect(
      safeThinkBudget(remaining: Duration.zero, increment: Duration.zero),
      const Duration(milliseconds: 50),
    );
  });

  group('botThinkTime', () {
    final level = BotLevel.of(8);

    test('untimed games use the level move time', () {
      expect(
        botThinkTime(level, remaining: null, increment: Duration.zero),
        level.moveTime,
      );
    });

    test('never exceeds a safe fraction of the remaining clock', () {
      final time = botThinkTime(
        level,
        remaining: const Duration(seconds: 6),
        increment: Duration.zero,
      );
      expect(time, const Duration(milliseconds: 200));
    });

    test('adds half the increment to the budget', () {
      final time = botThinkTime(
        level,
        remaining: const Duration(seconds: 6),
        increment: const Duration(seconds: 2),
      );
      expect(time, const Duration(milliseconds: 1200));
    });

    test('has a floor so the engine always gets some time', () {
      final time = botThinkTime(
        level,
        remaining: const Duration(milliseconds: 300),
        increment: Duration.zero,
      );
      expect(time, const Duration(milliseconds: 50));
    });
  });
}
