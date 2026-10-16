import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/server_clock.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../history/application/history_providers.dart';
import '../../play_ai/application/play_ai_providers.dart';
import '../../play_ai/domain/uci_move.dart';
import '../data/online_api.dart';
import '../domain/server_game.dart';
import 'online_game_over.dart';
import 'online_game_view.dart';
import 'online_providers.dart';
import 'online_sync.dart';
import 'timeout_claimer.dart';

part 'online_move_sending.dart';

/// One online game, by id. No automatic retry of the first load: the screen
/// offers "Try again".
final onlineGameProvider = AsyncNotifierProvider.autoDispose
    .family<OnlineGameNotifier, OnlineGameView, String>(
      OnlineGameNotifier.new,
      retry: (_, _) => null,
    );

/// Plays an online game against the server (ADR-0004, ADR-0005):
/// - a move shows at once and goes to `make_move` with one `client_move_id`
///   per attempt, reused on every retry (backoff 0.5/1/2/4 s, then a resync
///   and a retry every 5 s while the game is open);
/// - a rejected move rolls back to the server's state with a short message;
/// - Realtime events, (re)subscription, resume and a 20 s poll only trigger
///   a resync: fetch the game row and the moves after the last known ply.
///   The server always wins.
class OnlineGameNotifier extends AsyncNotifier<OnlineGameView> {
  OnlineGameNotifier(this.gameId);

  final String gameId;

  static const Duration pollEvery = Duration(seconds: 20);

  late OnlineApi _api;
  late ServerClock _clock;
  Subscription? _sub;
  Timer? _poll;
  late TimeoutClaimer _claimer;
  bool _disposed = false;
  bool _connected = false;
  Completer<void>? _sync;
  bool _syncAgain = false;
  bool _overHandled = false;
  final Completer<void> _recorded = Completer<void>();

  OnlineGameView? get _view => state.value;

  @override
  Future<OnlineGameView> build() async {
    _api = ref.read(onlineApiProvider)!;
    _clock = ref.read(serverClockProvider);
    _claimer = TimeoutClaimer(
      _clock,
      () => unawaited(_act(GameAction.claimTimeout)),
    );
    ref.onDispose(() {
      _disposed = true;
      _sub?.cancel();
      _poll?.cancel();
      _claimer.cancel();
    });
    _sub = _api.watchGame(
      gameId,
      onHint: _requestSync,
      onConnected: _onConnected,
    );
    _poll = Timer.periodic(pollEvery, (_) {
      if (_view?.game.isActive ?? false) _requestSync();
    });

    final game = await _api.fetchGame(gameId);
    final moves = await _api.fetchMoves(gameId);
    final players = await _api.players([game.whiteId, game.blackId].nonNulls);
    final view = OnlineGameView(
      game: game,
      moves: moves,
      mySide: game.sideOf(_api.userId) ?? Side.white,
      players: players,
      connected: _connected,
    );
    // After build: other providers may not be touched while it runs.
    scheduleMicrotask(() {
      if (_disposed) return;
      ref.invalidate(activeOnlineGameProvider);
      _afterChange(view);
    });
    return view;
  }

  // Player actions ----------------------------------------------------------

  Future<void> move(Move move) async {
    final v = _view;
    if (v == null || !v.isMyTurn || v.isBrowsing) return;
    final position = v.position;
    if (!position.isLegal(move)) return;
    final (_, san) = position.makeSan(move);
    final pending = PendingMove(
      ply: v.moves.length + 1,
      uci: standardUci(position, move),
      san: san,
      clientMoveId: const Uuid().v4(),
      madeAt: _clock.now(),
    );
    _set(v.copyWith(pending: pending, clearNotice: true));
    await _send(pending);
  }

  Future<void> resign() => _act(GameAction.resign);
  Future<void> offerDraw() => _act(GameAction.offerDraw);
  Future<void> acceptDraw() => _act(GameAction.acceptDraw);
  Future<void> declineDraw() => _act(GameAction.declineDraw);
  Future<void> abort() => _act(GameAction.abort);

  /// Offers a rematch (or accepts the opponent's). Returns the new game.
  Future<ServerGame?> rematch() async {
    try {
      final game = await _api.offerRematch(gameId);
      unawaited(_requestSync());
      return game;
    } on OnlineFailure catch (e) {
      _notice(
        e is OnlineUnavailable
            ? 'No connection. Try again in a moment.'
            : "The rematch couldn't be set up.",
      );
      return null;
    }
  }

  void appResumed() => _requestSync();

  /// Completes once a finished game is in local history (for Review).
  Future<void> whenRecorded() => _recorded.future;

  void viewPly(int? ply) {
    final v = _view;
    if (v == null) return;
    final live = ply == null || ply >= v.positions.length - 1;
    _set(live ? v.copyWith(clearViewedPly: true) : v.copyWith(viewedPly: ply));
  }

  void clearNotice() {
    final v = _view;
    if (v?.notice != null) _set(v!.copyWith(clearNotice: true));
  }

  // Game actions -------------------------------------------------------------

  Future<void> _act(GameAction action) async {
    try {
      final game = await _api.act(action, gameId);
      final v = _view;
      if (v == null) return;
      if (game.ply == v.moves.length) {
        _applyServer(game, v.moves);
      } else {
        await _requestSync();
      }
    } on OnlineUnavailable {
      _failing(true);
      if (action != GameAction.claimTimeout) {
        _notice('No connection. Try again in a moment.');
      }
    } on OnlineRejected catch (e) {
      debugPrint('Online action ${action.name} rejected: ${e.code}');
      if (e.code == 'CANNOT_ABORT') {
        _notice('Both players have moved: resign instead.');
      }
      await _requestSync();
    }
  }

  // Resync -------------------------------------------------------------------

  void _onConnected(bool up) {
    _connected = up;
    final v = _view;
    if (v != null && v.connected != up) _set(v.copyWith(connected: up));
    if (up) _requestSync();
  }

  /// One resync at a time; a request during one runs another after it.
  Future<void> _requestSync() {
    final running = _sync;
    if (running != null) {
      _syncAgain = true;
      return running.future;
    }
    final done = _sync = Completer<void>();
    () async {
      try {
        do {
          _syncAgain = false;
          await _resync();
        } while (_syncAgain && !_disposed);
      } finally {
        _sync = null;
        done.complete();
      }
    }();
    return done.future;
  }

  Future<void> _resync() async {
    final v = _view;
    if (v == null || _disposed) return;
    try {
      final (game, moves) = await fetchSnapshot(_api, gameId, v.moves);
      _applyServer(game, moves);
    } on OnlineUnavailable {
      _failing(true);
    } on OnlineRejected catch (e) {
      debugPrint('Resync of $gameId rejected: ${e.code}');
    }
  }

  /// Takes the server's [game] and [moves] (consistent: one move per ply)
  /// and settles the optimistic move against them.
  void _applyServer(ServerGame game, List<ServerMove> moves, {String? notice}) {
    final v = _view;
    if (v == null || _disposed) return;
    // The server's ply never goes back: an older snapshot lost a race.
    if (game.ply < v.game.ply) return;
    var pending = v.pending;
    var message = notice;
    if (pending != null) {
      if (moves.length >= pending.ply) {
        if (moves[pending.ply - 1].uci != pending.uci) {
          message ??= lostMoveNotice;
        }
        pending = null;
      } else if (!game.isActive) {
        pending = null;
      }
    }
    _set(
      v.copyWith(
        game: game,
        moves: moves,
        pending: pending,
        clearPending: pending == null,
        requestFailing: false,
        notice: message,
      ),
    );
  }

  // State and follow-ups -----------------------------------------------------

  void _set(OnlineGameView v) {
    if (_disposed) return;
    state = AsyncData(v);
    _afterChange(v);
  }

  void _failing(bool failing) {
    final v = _view;
    if (v != null && v.requestFailing != failing) {
      _set(v.copyWith(requestFailing: failing));
    }
  }

  void _notice(String message) {
    final v = _view;
    if (v != null) _set(v.copyWith(notice: message));
  }

  void _afterChange(OnlineGameView v) {
    _claimer.update(v.game, v.mySide);
    if (v.game.isOver && !_overHandled) {
      _overHandled = true;
      unawaited(_onGameOver(v));
    }
  }

  Future<void> _onGameOver(OnlineGameView v) async {
    _claimer.cancel();
    ref
      ..invalidate(activeOnlineGameProvider)
      ..invalidate(myProfileProvider);
    if (v.game.status != GameStatus.finished) return;
    final change = await recordFinishedGame(
      () => _view ?? v,
      _api,
      ref.read(historyRepositoryProvider),
    );
    _recorded.complete();
    if (_disposed) return;
    ref.read(historyRevisionProvider.notifier).bump();
    final now = _view;
    if (change != null && now != null) _set(now.copyWith(ratingChange: change));
  }
}
