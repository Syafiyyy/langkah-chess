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

  test('approximate ratings strictly increase', () {
    final ratings = BotLevel.all.map((l) => l.approxRating).toList();
    for (var i = 1; i < ratings.length; i++) {
      expect(ratings[i], greaterThan(ratings[i - 1]));
    }
  });

  test('levels below UCI_Elo minimum use Skill Level and a depth cap', () {
    for (final level in BotLevel.all.where((l) => l.approxRating < _minElo)) {
      expect(level.engineOptions['UCI_LimitStrength'], 'false');
      expect(level.engineOptions.containsKey('UCI_Elo'), isFalse);
      final skill = int.parse(level.engineOptions['Skill Level']!);
      expect(skill, inInclusiveRange(0, 20));
      expect(level.depth, isNotNull);
    }
  });

  test('Elo levels set UCI_LimitStrength with an in-range UCI_Elo', () {
    final eloLevels = BotLevel.all.where(
      (l) => l.engineOptions['UCI_LimitStrength'] == 'true',
    );
    expect(eloLevels, isNotEmpty);
    for (final level in eloLevels) {
      final elo = int.parse(level.engineOptions['UCI_Elo']!);
      expect(elo, inInclusiveRange(_minElo, _maxElo));
      expect(elo, level.approxRating);
      expect(level.depth, isNull);
    }
  });

  test('the top level plays at full strength', () {
    final top = BotLevel.all.last;
    expect(top.engineOptions['UCI_LimitStrength'], 'false');
    expect(top.engineOptions['Skill Level'], '20');
    expect(top.depth, isNull);
  });

  test('every level sets the same option names, so switching resets them', () {
    for (final level in BotLevel.all) {
      expect(
        level.engineOptions.keys,
        containsAll(['UCI_LimitStrength', 'Skill Level']),
      );
    }
  });

  test('label names level and rating', () {
    expect(BotLevel.of(4).label, 'Level 4 · ~1400');
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
