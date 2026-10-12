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

  test('setOptions sends each setoption, then waits for readyok', () async {
    final engine = FakeUciEngine(onCommand: _replyToGo);
    final service = EngineService(() async => engine);

    await service.setOptions({'UCI_LimitStrength': 'true', 'UCI_Elo': '1400'});

    expect(engine.commands, [
      'setoption name UCI_LimitStrength value true',
      'setoption name UCI_Elo value 1400',
      'isready',
    ]);
  });

  test('setOptions stops a running search first', () async {
    final engine = FakeUciEngine(
      onCommand: (engine, command) {
        if (command == 'stop') engine.emit('bestmove e2e4');
        if (command == 'isready') engine.emit('readyok');
      },
    );
    final service = EngineService(() async => engine);

    final search = service.bestMove(_startFen);
    await service.setOptions({'Skill Level': '3'});

    expect((await search).bestMove, 'e2e4');
    expect(engine.commands, [
      'position fen $_startFen',
      'go movetime 500',
      'stop',
      'setoption name Skill Level value 3',
      'isready',
    ]);
  });

  test('bestMove can cap the depth as well as the time', () async {
    final engine = FakeUciEngine(onCommand: _replyToGo);
    final service = EngineService(() async => engine);

    await service.bestMove(
      _startFen,
      moveTime: const Duration(milliseconds: 150),
      depth: 2,
    );

    expect(engine.commands.last, 'go depth 2 movetime 150');
  });

  test('stop halts the running search; idle stop sends nothing', () async {
    final engine = FakeUciEngine(
      onCommand: (engine, command) {
        if (command == 'stop') engine.emit('bestmove g1f3');
      },
    );
    final service = EngineService(() async => engine);

    await service.stop();
    expect(engine.commands, isEmpty);

    final search = service.bestMove(_startFen);
    await Future<void>.delayed(Duration.zero);
    await service.stop();

    expect((await search).bestMove, 'g1f3');
    expect(engine.commands.last, 'stop');
  });

  group('candidates', () {
    /// Replies to `go` like Stockfish with MultiPV 3: two depths, three lines.
    void multiPv(FakeUciEngine engine, String command) {
      if (command == 'isready') engine.emit('readyok');
      if (command.startsWith('go')) {
        engine
          ..emit('info depth 1 multipv 1 score cp 50 pv e2e4')
          ..emit('info depth 1 multipv 2 score cp 40 pv d2d4')
          ..emit('info depth 2 multipv 1 score cp 35 pv d2d4 d7d5')
          ..emit('info depth 2 multipv 2 score cp 30 pv e2e4 e7e5')
          ..emit('info depth 2 multipv 3 score mate -4 pv f2f3')
          ..emit('bestmove d2d4 ponder d7d5');
      }
    }

    test('sets MultiPV and returns the latest line per index', () async {
      final engine = FakeUciEngine(onCommand: multiPv);
      final service = EngineService(() async => engine);

      final lines = await service.candidates(
        _startFen,
        count: 3,
        moveTime: const Duration(milliseconds: 200),
        depth: 2,
      );

      expect(lines.map((l) => l.pv.first), ['d2d4', 'e2e4', 'f2f3']);
      expect(lines.map((l) => l.cp), [35, 30, null]);
      expect(lines.last.mate, -4);
      expect(engine.commands, [
        'setoption name MultiPV value 3',
        'isready',
        'position fen $_startFen',
        'go depth 2 movetime 200',
      ]);
    });

    test('a later bestMove resets MultiPV to 1 first', () async {
      final engine = FakeUciEngine(onCommand: multiPv);
      final service = EngineService(() async => engine);

      await service.candidates(_startFen, count: 3);
      engine.commands.clear();
      await service.bestMove(_startFen);
      await service.bestMove(_startFen);

      expect(engine.commands, [
        'setoption name MultiPV value 1',
        'isready',
        'position fen $_startFen',
        'go movetime 500',
        'position fen $_startFen',
        'go movetime 500',
      ]);
    });

    test('a restarted engine starts again from MultiPV 1', () async {
      final engines = <FakeUciEngine>[];
      final service = EngineService(() async {
        final engine = FakeUciEngine(onCommand: multiPv);
        engines.add(engine);
        return engine;
      });

      await service.candidates(_startFen, count: 3);
      await service.dispose();
      await service.bestMove(_startFen);

      expect(engines.last.commands, [
        'position fen $_startFen',
        'go movetime 500',
      ]);
    });
  });

  group('analyse', () {
    test('searches each position in order and streams the results', () async {
      final engine = FakeUciEngine(onCommand: _replyToGo);
      final service = EngineService(() async => engine);

      final results = await service.analyse([
        _startFen,
        _afterE4,
      ], moveTime: const Duration(milliseconds: 250)).toList();

      expect(results.map((r) => r.index), [0, 1]);
      expect(results.first.result.bestMove, 'd2d4');
      expect(results.first.result.eval?.cp, 28);
      expect(engine.commands, [
        'position fen $_startFen',
        'go movetime 250',
        'position fen $_afterE4',
        'go movetime 250',
      ]);
    });

    test('cancelling stops before the next position', () async {
      final engine = FakeUciEngine(onCommand: _replyToGo);
      final service = EngineService(() async => engine);

      final first = await service.analyse([
        _startFen,
        _afterE4,
        _startFen,
      ], depth: 12).first;

      await Future<void>.delayed(Duration.zero);
      expect(first.index, 0);
      expect(engine.commands.where((c) => c.startsWith('go')), [
        'go depth 12 movetime 500',
      ]);
    });

    test('uses MultiPV 1 even after a candidate search', () async {
      final engine = FakeUciEngine(onCommand: _replyToGo);
      final service = EngineService(() async => engine);
      await service.candidates(_startFen, count: 4);
      engine.commands.clear();

      await service.analyse([_startFen]).toList();

      expect(engine.commands.first, 'setoption name MultiPV value 1');
    });
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
