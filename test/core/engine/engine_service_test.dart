import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/core/engine/engine_service.dart';

import 'fake_uci_engine.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

/// Replies to `go` with an info line and a bestmove, like Stockfish.
void _replyToGo(FakeUciEngine engine, String command) {
  if (command == 'isready') engine.emit('readyok');
  if (command.startsWith('go')) {
    engine
      ..emit('info depth 10 score cp 31 nodes 5000 pv e2e4 e7e5')
      ..emit('info depth 11 score cp 28 nodes 9000 pv d2d4 d7d5')
      ..emit('bestmove d2d4 ponder d7d5');
  }
}

void main() {
  test('returns bestmove with the last scored info line', () async {
    final engine = FakeUciEngine(onCommand: _replyToGo);
    final service = EngineService(() async => engine);

    final result = await service.bestMove(_startFen);

    expect(result.bestMove, 'd2d4');
    expect(result.eval?.cp, 28);
    expect(result.eval?.depth, 11);
    expect(engine.commands, ['position fen $_startFen', 'go movetime 500']);
  });

  test('starts the engine once and listens to stdout once', () async {
    var starts = 0;
    final engine = FakeUciEngine(onCommand: _replyToGo);
    final service = EngineService(() async {
      starts++;
      return engine;
    });

    final first = await service.bestMove(_startFen);
    final second = await service.bestMove(_afterE4);

    // A second stdout.listen on the single-subscription stream would throw.
    expect(starts, 1);
    expect(first.bestMove, 'd2d4');
    expect(second.bestMove, 'd2d4');
  });

  test('stops a running search before starting the next', () async {
    final engine = FakeUciEngine(
      onCommand: (engine, command) {
        if (command == 'stop') engine.emit('bestmove e2e4');
        if (command == 'go movetime 2000') {
          engine.emit('info depth 5 score cp 10 pv g1f3');
        }
        if (command == 'go movetime 100') engine.emit('bestmove e7e5');
      },
    );
    final service = EngineService(() async => engine);

    final slow = service.bestMove(
      _startFen,
      moveTime: const Duration(seconds: 2),
    );
    final fast = service.bestMove(
      _afterE4,
      moveTime: const Duration(milliseconds: 100),
    );

    expect((await slow).bestMove, 'e2e4');
    expect((await fast).bestMove, 'e7e5');
    expect(engine.commands, [
      'position fen $_startFen',
      'go movetime 2000',
      'stop',
      'position fen $_afterE4',
      'go movetime 100',
    ]);
  });

  test('newGame sends ucinewgame and waits for readyok', () async {
    final engine = FakeUciEngine(onCommand: _replyToGo);
    final service = EngineService(() async => engine);

    await service.newGame();

    expect(engine.commands, ['ucinewgame', 'isready']);
  });

  test('maps bestmove (none) to a null move', () async {
    final engine = FakeUciEngine(
      onCommand: (engine, command) {
        if (command.startsWith('go')) {
          engine
            ..emit('info depth 0 score mate 0')
            ..emit('bestmove (none)');
        }
      },
    );
    final service = EngineService(() async => engine);

    // Fool's mate: white is checkmated.
    final result = await service.bestMove(
      'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3',
    );

    expect(result.bestMove, isNull);
    expect(result.eval?.mate, 0);
  });

  test('rejects an invalid FEN without touching the engine', () async {
    var starts = 0;
    final service = EngineService(() async {
      starts++;
      return FakeUciEngine();
    });

    await expectLater(
      service.bestMove('8/8/8/8/8/8/8/8 w - - 0 1'),
      throwsA(isA<PositionSetupException>()),
    );
    await expectLater(service.bestMove('not a fen'), throwsA(anything));
    expect(starts, 0);
  });

  test('dispose fails the pending search and quits the engine', () async {
    final engine = FakeUciEngine();
    final service = EngineService(() async => engine);

    final pending = expectLater(service.bestMove(_startFen), throwsStateError);
    await Future<void>.delayed(Duration.zero);
    await service.dispose();

    await pending;
    expect(engine.disposed, isTrue);
  });

  test('restarts the engine after dispose', () async {
    final engines = <FakeUciEngine>[];
    final service = EngineService(() async {
      final engine = FakeUciEngine(onCommand: _replyToGo);
      engines.add(engine);
      return engine;
    });

    await service.bestMove(_startFen);
    await service.dispose();
    final result = await service.bestMove(_startFen);

    expect(engines, hasLength(2));
    expect(result.bestMove, 'd2d4');
  });
}
