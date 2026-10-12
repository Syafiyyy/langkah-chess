import 'dart:async';

import 'package:dartchess/dartchess.dart';

import 'uci_engine.dart';
import 'uci_parser.dart';

export 'uci_parser.dart' show EngineEval;

/// Result of one search.
class EngineResult {
  const EngineResult({required this.bestMove, this.eval});

  /// Best move in UCI, or null when the position has no legal moves.
  final String? bestMove;

  /// Last scored `info` line seen during the search, if any.
  final EngineEval? eval;
}

/// The single gateway to the chess engine (see the chess-domain skill).
///
/// - The engine starts lazily on first use and is reused afterwards.
/// - stdout is subscribed once per engine; lines are routed to the current
///   request. Never listen to engine stdout anywhere else.
/// - A new search stops the previous one first. The superseded request
///   completes with the move the engine had found when it was stopped.
/// - Commands are serialised so concurrent callers can't interleave them.
class EngineService {
  EngineService(this._startEngine);

  final Future<UciEngine> Function() _startEngine;

  UciEngine? _engine;
  Future<UciEngine>? _starting;
  StreamSubscription<String>? _stdoutSub;
  _Search? _current;
  Completer<void>? _ready;
  Future<void> _queue = Future.value();

  /// Prepares the engine for a new game (`ucinewgame` then `isready`).
  Future<void> newGame() => _serial(() async {
    final engine = await _ensureEngine();
    await _stopCurrent(engine);
    engine.send('ucinewgame');
    await _isReady(engine);
  });

  /// Searches [fen] for [moveTime] and returns the best move.
  ///
  /// Throws if [fen] is not a legal standard-chess position. It is validated
  /// with dartchess before anything reaches the engine.
  Future<EngineResult> bestMove(
    String fen, {
    Duration moveTime = const Duration(milliseconds: 500),
  }) async {
    Chess.fromSetup(Setup.parseFen(fen));
    final search = await _serial(() async {
      final engine = await _ensureEngine();
      await _stopCurrent(engine);
      final search = _Search();
      _current = search;
      engine.send('position fen $fen');
      engine.send('go movetime ${moveTime.inMilliseconds}');
      return search;
    });
    return search.completer.future;
  }

  /// Quits the engine. Safe to call repeatedly; the next request restarts it.
  Future<void> dispose() async {
    final starting = _starting;
    if (starting != null) {
      try {
        await starting;
      } on Object {
        // Start failed, so there is nothing to dispose.
      }
    }
    final engine = _engine;
    _engine = null;
    await _stdoutSub?.cancel();
    _stdoutSub = null;
    _failPending(StateError('Engine disposed'));
    await engine?.dispose();
  }

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<UciEngine> _ensureEngine() {
    final engine = _engine;
    if (engine != null) return Future.value(engine);
    return _starting ??= _start();
  }

  Future<UciEngine> _start() async {
    try {
      final engine = await _startEngine();
      _stdoutSub = engine.stdout.listen(_onLine, onDone: _onEngineExit);
      _engine = engine;
      return engine;
    } finally {
      _starting = null;
    }
  }

  Future<void> _stopCurrent(UciEngine engine) async {
    final current = _current;
    if (current == null) return;
    engine.send('stop');
    try {
      await current.completer.future;
    } on Object {
      // The superseded caller handles its own error.
    }
  }

  Future<void> _isReady(UciEngine engine) {
    final ready = _ready ??= Completer<void>();
    engine.send('isready');
    return ready.future;
  }

  void _onLine(String line) {
    if (line.trim() == 'readyok') {
      _ready?.complete();
      _ready = null;
      return;
    }
    final search = _current;
    if (search == null) return;
    final eval = parseInfoLine(line);
    if (eval != null) {
      search.lastEval = eval;
      return;
    }
    final best = parseBestMoveLine(line);
    if (best != null) {
      _current = null;
      search.completer.complete(
        EngineResult(bestMove: best.uci, eval: search.lastEval),
      );
    }
  }

  void _onEngineExit() {
    _engine = null;
    _stdoutSub = null;
    _failPending(StateError('Engine exited'));
  }

  void _failPending(Object error) {
    final search = _current;
    _current = null;
    if (search != null && !search.completer.isCompleted) {
      search.completer.completeError(error);
    }
    final ready = _ready;
    _ready = null;
    if (ready != null && !ready.isCompleted) ready.completeError(error);
  }
}

class _Search {
  final Completer<EngineResult> completer = Completer<EngineResult>();
  EngineEval? lastEval;
}
