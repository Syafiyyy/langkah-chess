import 'package:flutter_test/flutter_test.dart';
import 'package:skak/core/engine/uci_parser.dart';

void main() {
  group('parseInfoLine', () {
    test('reads depth, cp score and pv', () {
      final eval = parseInfoLine(
        'info depth 12 seldepth 18 multipv 1 score cp 34 nodes 120000 '
        'nps 900000 time 130 pv e2e4 e7e5 g1f3',
      );
      expect(eval, isNotNull);
      expect(eval!.depth, 12);
      expect(eval.cp, 34);
      expect(eval.mate, isNull);
      expect(eval.pv, ['e2e4', 'e7e5', 'g1f3']);
    });

    test('reads the multipv index, defaulting to 1', () {
      final line = parseInfoLine(
        'info depth 8 seldepth 10 multipv 3 score cp -42 nodes 900 pv g1f3 d7d5',
      );
      expect(line!.multipv, 3);
      expect(line.pv.first, 'g1f3');
      expect(parseInfoLine('info depth 8 score cp 5 pv e2e4')!.multipv, 1);
    });

    test('reads negative mate score', () {
      final eval = parseInfoLine('info depth 20 score mate -3 pv h7h8');
      expect(eval!.mate, -3);
      expect(eval.cp, isNull);
    });

    test('handles bound markers after the score', () {
      final eval = parseInfoLine(
        'info depth 9 score cp -15 upperbound nodes 1',
      );
      expect(eval!.cp, -15);
      expect(eval.depth, 9);
    });

    test('ignores lines without a score', () {
      expect(
        parseInfoLine('info depth 3 currmove e2e4 currmovenumber 1'),
        isNull,
      );
      expect(
        parseInfoLine('info string NNUE evaluation using nn.nnue'),
        isNull,
      );
      expect(parseInfoLine('readyok'), isNull);
      expect(parseInfoLine(''), isNull);
    });
  });

  group('parseBestMoveLine', () {
    test('reads the move and ignores ponder', () {
      expect(parseBestMoveLine('bestmove e2e4 ponder e7e5')?.uci, 'e2e4');
    });

    test('reads promotion moves', () {
      expect(parseBestMoveLine('bestmove e7e8q')?.uci, 'e7e8q');
    });

    test('maps (none) to a null move', () {
      final result = parseBestMoveLine('bestmove (none)');
      expect(result, isNotNull);
      expect(result!.uci, isNull);
    });

    test('returns null for other lines', () {
      expect(parseBestMoveLine('info depth 1 score cp 0'), isNull);
    });
  });
}
