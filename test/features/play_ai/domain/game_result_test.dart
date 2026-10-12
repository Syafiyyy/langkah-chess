import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/features/play_ai/domain/game_result.dart';

Position _pos(String fen) => Chess.fromSetup(Setup.parseFen(fen));

Position _play(Position position, String uci) =>
    position.play(Move.parse(uci)!);

void main() {
  group('resultAfterMove', () {
    test('checkmate: the side that mated wins', () {
      Position p = Chess.initial;
      for (final m in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
        p = _play(p, m);
      }
      final result = resultAfterMove(p, repetitions: 1)!;
      expect(result.outcome, Outcome.blackWins);
      expect(result.termination, Termination.checkmate);
    });

    test('stalemate is a draw', () {
      final p = _play(_pos('k7/8/8/2Q5/8/8/8/7K w - - 0 1'), 'c5b6');
      final result = resultAfterMove(p, repetitions: 1)!;
      expect(result.outcome, Outcome.draw);
      expect(result.termination, Termination.stalemate);
    });

    test('insufficient material is a draw', () {
      final p = _play(_pos('7k/8/8/8/8/8/2r5/1B5K w - - 0 1'), 'b1c2');
      final result = resultAfterMove(p, repetitions: 1)!;
      expect(result.outcome, Outcome.draw);
      expect(result.termination, Termination.insufficientMaterial);
    });

    test('75-move rule draws at 150 halfmoves', () {
      final p = _play(_pos('7k/8/8/8/8/8/R7/7K w - - 149 100'), 'a2a3');
      final result = resultAfterMove(p, repetitions: 1)!;
      expect(result.outcome, Outcome.draw);
      expect(result.termination, Termination.seventyFiveMoveRule);
    });

    test('checkmate on the 150th halfmove still wins', () {
      final p = _play(_pos('7k/R7/8/8/8/8/8/1R5K w - - 149 100'), 'b1b8');
      final result = resultAfterMove(p, repetitions: 1)!;
      expect(result.outcome, Outcome.whiteWins);
      expect(result.termination, Termination.checkmate);
    });

    test('third repetition is a draw, second is not', () {
      expect(resultAfterMove(Chess.initial, repetitions: 2), isNull);
      final result = resultAfterMove(Chess.initial, repetitions: 3)!;
      expect(result.outcome, Outcome.draw);
      expect(result.termination, Termination.threefoldRepetition);
    });

    test('an ongoing position has no result', () {
      expect(
        resultAfterMove(_play(Chess.initial, 'e2e4'), repetitions: 1),
        isNull,
      );
    });
  });

  group('timeoutResult', () {
    test('white flags, black has mating material: black wins', () {
      final p = _pos('7k/8/8/8/8/8/8/q6K w - - 0 1');
      final result = timeoutResult(p, Side.white);
      expect(result.outcome, Outcome.blackWins);
      expect(result.termination, Termination.timeout);
    });

    test('white flags, black has a lone king: draw', () {
      final p = _pos('7k/8/8/8/8/8/Q7/7K w - - 0 1');
      final result = timeoutResult(p, Side.white);
      expect(result.outcome, Outcome.draw);
      expect(result.termination, Termination.timeout);
    });

    test('black flags, white has only king and bishop: draw', () {
      final p = _pos('r6k/8/8/8/8/8/8/B6K b - - 0 1');
      expect(timeoutResult(p, Side.black).outcome, Outcome.draw);
    });

    test('black flags, white has a rook: white wins', () {
      final p = _pos('7k/8/8/8/8/8/8/R6K b - - 0 1');
      expect(timeoutResult(p, Side.black).outcome, Outcome.whiteWins);
    });

    test('the flagged side having little material does not save it', () {
      // White flags with a lone king; black still has a queen.
      final p = _pos('q6k/8/8/8/8/8/8/7K w - - 0 1');
      expect(timeoutResult(p, Side.white).outcome, Outcome.blackWins);
    });
  });

  group('positionKey', () {
    test('ignores halfmove and fullmove counters', () {
      final a = _pos('7k/8/8/8/8/8/R7/7K w - - 0 1');
      final b = _pos('7k/8/8/8/8/8/R7/7K w - - 37 60');
      expect(positionKey(a), positionKey(b));
    });

    test('includes side to move and castling rights', () {
      final white = _pos('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final black = _pos('r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1');
      final noCastle = _pos('r3k2r/8/8/8/8/8/8/R3K2R w kq - 0 1');
      expect(positionKey(white), isNot(positionKey(black)));
      expect(positionKey(white), isNot(positionKey(noCastle)));
    });

    test('counts an en-passant square only when a capture is legal', () {
      const placement = 'rnbqkbnr/ppp1pppp/8/8/3pP3/8/PPPP1PPP/RNBQKBNR b KQkq';
      final legalEp = _pos('$placement e3 0 1');
      final noEp = _pos('$placement - 0 1');
      expect(positionKey(legalEp), isNot(positionKey(noEp)));

      const quiet = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq';
      expect(
        positionKey(_pos('$quiet e3 0 1')),
        positionKey(_pos('$quiet - 0 1')),
      );
    });
  });
}
