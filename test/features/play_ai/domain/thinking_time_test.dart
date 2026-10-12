import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/features/play_ai/domain/bot_level.dart';
import 'package:langkah/features/play_ai/domain/thinking_time.dart';

Position _pos(String fen) => Chess.fromSetup(Setup.parseFen(fen));

const _ms = Duration(milliseconds: 1);

Matcher _between(int lo, int hi) =>
    allOf(greaterThanOrEqualTo(_ms * lo), lessThanOrEqualTo(_ms * hi));

void main() {
  final weak = BotLevel.of(2);

  test('human levels think 0.6 to 2.5 s in normal positions', () {
    for (var seed = 0; seed < 300; seed++) {
      final t = naturalThinkTime(weak, Chess.initial, null, Random(seed));
      expect(t, _between(600, 2500), reason: 'seed $seed');
    }
  });

  test('a forced move is quick', () {
    // Black king in check from a rook with exactly one escape.
    final forced = _pos('k7/8/1K6/8/8/8/8/R7 b - - 0 1');
    expect(forced.legalMoves.values.fold(0, (n, s) => n + s.size), 1);
    for (var seed = 0; seed < 50; seed++) {
      final t = naturalThinkTime(weak, forced, null, Random(seed));
      expect(t, _between(300, 500));
    }
  });

  test('busier positions take longer than quiet ones (same luck)', () {
    // Many legal moves and captures available vs a sparse endgame.
    final busy = _pos(
      'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
    );
    final quiet = _pos('8/8/4k3/8/8/4K3/4P3/8 w - - 0 1');
    for (var seed = 0; seed < 50; seed++) {
      expect(
        naturalThinkTime(weak, busy, null, Random(seed)),
        greaterThan(naturalThinkTime(weak, quiet, null, Random(seed))),
      );
    }
  });

  test('a recapture is quicker than the same position otherwise', () {
    // White just took on d5 (exd5); black can take back with the knight.
    final p = _pos(
      'r1bqkb1r/ppp2ppp/2n5/3Pp3/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 4',
    );
    final capture = Move.parse('e4d5')!;
    final other = Move.parse('g1f3')!;
    for (var seed = 0; seed < 50; seed++) {
      expect(
        naturalThinkTime(weak, p, capture, Random(seed)),
        lessThan(naturalThinkTime(weak, p, other, Random(seed))),
      );
    }
  });

  test('strong levels only pad to a short minimum', () {
    for (var seed = 0; seed < 100; seed++) {
      final t = naturalThinkTime(
        BotLevel.of(7),
        Chess.initial,
        null,
        Random(seed),
      );
      expect(t, _between(600, 1200));
    }
  });

  group('pauseAfterSearch', () {
    test('waits the rest of the natural time', () {
      expect(
        pauseAfterSearch(target: _ms * 1500, searched: _ms * 400, budget: null),
        _ms * 1100,
      );
    });

    test('no pause when the search already took longer', () {
      expect(
        pauseAfterSearch(target: _ms * 900, searched: _ms * 1200, budget: null),
        Duration.zero,
      );
    });

    test('never goes past the clock budget', () {
      expect(
        pauseAfterSearch(
          target: _ms * 2000,
          searched: _ms * 300,
          budget: _ms * 800,
        ),
        _ms * 500,
      );
      expect(
        pauseAfterSearch(
          target: _ms * 2000,
          searched: _ms * 900,
          budget: _ms * 800,
        ),
        Duration.zero,
      );
    });
  });
}
