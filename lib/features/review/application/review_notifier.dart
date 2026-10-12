import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/engine/engine_provider.dart';
import '../../play_ai/application/play_ai_providers.dart';
import '../data/analysis_repository.dart';
import '../domain/game_line.dart';
import '../domain/move_review.dart';
import '../domain/position_eval.dart';
import 'review_state.dart';

/// Search time per position. Tuned on the emulator (see docs/STATE.md).
const reviewMoveTime = Duration(milliseconds: 350);

/// Cache key: analysis settings + engine build. Change either and old
/// cached analyses are ignored.
const reviewAnalysisKey = AnalysisKey(
  settings: 'movetime350',
  engine: 'stockfish19-light/multistockfish-0.6.1',
);

/// Review runs Stockfish at full strength (a bot level may have left it
/// weakened).
const _fullStrength = {'UCI_LimitStrength': 'false', 'Skill Level': '20'};

final analysisRepositoryProvider = Provider<AnalysisRepository>(
  (ref) => SqfliteAnalysisRepository(ref.watch(appDatabaseProvider)),
);

/// Review of one finished game (by id). Disposed with the screen, which
/// stops any running analysis.
final reviewProvider = NotifierProvider.autoDispose
    .family<ReviewNotifier, ReviewState, String>(ReviewNotifier.new);

class ReviewNotifier extends Notifier<ReviewState> {
  ReviewNotifier(this.gameId);

  final String gameId;
  StreamSubscription<Object?>? _analysis;

  @override
  ReviewState build() {
    final engine = ref.read(engineServiceProvider);
    ref.onDispose(() {
      final running = _analysis;
      _analysis = null;
      if (running != null) {
        unawaited(running.cancel());
        unawaited(engine.stop().catchError((Object _) {}));
      }
    });
    unawaited(_load());
    return const ReviewState();
  }

  Future<void> _load() async {
    final game = await ref.read(historyRepositoryProvider).byId(gameId);
    if (!ref.mounted) return;
    if (game == null) {
      state = state.copyWith(notFound: true);
      return;
    }
    final line = GameLine.fromPgn(game.pgn);
    state = state.copyWith(game: game, line: line);
    final cached = await ref
        .read(analysisRepositoryProvider)
        .load(gameId, reviewAnalysisKey);
    if (!ref.mounted) return;
    if (cached != null && cached.length == line.positions.length) {
      _setEvals(cached);
      return;
    }
    await _analyse();
  }

  /// Runs the analysis again from scratch (ignores the cache).
  Future<void> reanalyse() async {
    await _analysis?.cancel();
    _analysis = null;
    if (state.line == null) return;
    state = state.copyWith(evals: const [], reviews: const [], failed: false);
    await _analyse();
  }

  Future<void> _analyse() async {
    final line = state.line!;
    final engine = ref.read(engineServiceProvider);
    state = state.copyWith(analysing: true, failed: false);
    // Finished positions are scored directly; the rest go to the engine.
    final toEngine = [
      for (var i = 0; i < line.positions.length; i++)
        if (!line.positions[i].isGameOver) i,
    ];
    final evals = List<PositionEval?>.filled(line.positions.length, null);
    for (var i = 0; i < line.positions.length; i++) {
      final outcome = line.positions[i].outcome;
      if (line.positions[i].isGameOver && outcome != null) {
        evals[i] = PositionEval.gameOver(outcome);
      }
    }
    try {
      await engine.setOptions(_fullStrength);
    } on Object catch (e) {
      _fail(e);
      return;
    }
    if (!ref.mounted) return;
    _analysis = engine
        .analyse([
          for (final i in toEngine) line.positions[i].fen,
        ], moveTime: reviewMoveTime)
        .listen(
          (analysed) {
            final i = toEngine[analysed.index];
            final r = analysed.result;
            evals[i] = PositionEval.fromSideToMove(
              turn: line.positions[i].turn,
              cp: r.eval?.cp,
              mate: r.eval?.mate,
              bestMove: r.bestMove,
              pv: r.eval?.pv ?? const [],
            );
            _setEvals(_knownPrefix(evals));
          },
          onError: _fail,
          onDone: () {
            _analysis = null;
            final all = _knownPrefix(evals);
            _setEvals(all, analysing: false);
            unawaited(
              ref
                  .read(analysisRepositoryProvider)
                  .save(gameId, reviewAnalysisKey, all)
                  .catchError((Object e) => debugPrint('[review] cache: $e')),
            );
          },
        );
  }

  /// Evals from the start up to the first position not analysed yet.
  List<PositionEval> _knownPrefix(List<PositionEval?> evals) => [
    for (final e in evals.takeWhile((e) => e != null)) e!,
  ];

  void _setEvals(List<PositionEval> evals, {bool? analysing}) {
    if (!ref.mounted) return;
    final line = state.line!;
    state = state.copyWith(
      evals: evals,
      reviews: reviewGame(
        positions: line.positions,
        moves: line.moves,
        evals: evals,
      ),
      analysing: analysing,
    );
  }

  void _fail(Object error) {
    debugPrint('[review] analysis failed: $error');
    _analysis = null;
    if (ref.mounted) state = state.copyWith(analysing: false, failed: true);
  }

  void goTo(int ply) =>
      state = state.copyWith(ply: ply.clamp(0, state.lastPly));

  void next() => goTo(state.ply + 1);
  void previous() => goTo(state.ply - 1);

  /// Jumps to the player's next inaccuracy, mistake or blunder.
  void nextError() {
    final hit = _playerErrors().where((r) => r.ply > state.ply).firstOrNull;
    if (hit != null) goTo(hit.ply);
  }

  void previousError() {
    final hit = _playerErrors().where((r) => r.ply < state.ply).lastOrNull;
    if (hit != null) goTo(hit.ply);
  }

  Iterable<MoveReview> _playerErrors() {
    final player = state.game?.playerSide;
    return state.reviews.where(
      (r) => r.mover == player && (r.label?.isError ?? false),
    );
  }
}
