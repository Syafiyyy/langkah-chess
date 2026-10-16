part of 'online_game_notifier.dart';

/// Sending the player's move: one `client_move_id` per attempt, retried on
/// network errors (backoff, then a resync and a retry every 5 s while the
/// game is open), rolled back on a rejection.
/// Waits before retries 1–4; later retries wait [_slowRetry].
const List<Duration> _backoff = [
  Duration(milliseconds: 500),
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
];
const Duration _slowRetry = Duration(seconds: 5);

extension _MoveSending on OnlineGameNotifier {
  bool _stillPending(PendingMove p) =>
      !_disposed && _view?.pending?.clientMoveId == p.clientMoveId;

  Future<void> _send(PendingMove p) async {
    var attempt = 0;
    while (_stillPending(p)) {
      try {
        final watch = Stopwatch()..start();
        final response = await _api.makeMove(
          gameId: gameId,
          ply: p.ply,
          uci: p.uci,
          clientMoveId: p.clientMoveId,
        );
        // Round trip incl. the Edge Function hop (ADR-0004 asks to measure).
        debugPrint('make_move ply ${p.ply}: ${watch.elapsedMilliseconds} ms');
        _onMoveResponse(p, response);
        return;
      } on OnlineRejected catch (e) {
        final v = _view;
        if (v != null && _stillPending(p)) {
          _set(
            v.copyWith(clearPending: true, notice: rejectedMoveNotice(e.code)),
          );
        }
        await _requestSync();
        return;
      } on OnlineUnavailable {
        _failing(true);
        attempt++;
        // After the quick tries the move may have landed: resync to see.
        if (attempt == _backoff.length + 1) unawaited(_requestSync());
        await Future<void>.delayed(
          attempt <= _backoff.length ? _backoff[attempt - 1] : _slowRetry,
        );
      }
    }
  }

  void _onMoveResponse(PendingMove p, MoveResponse r) {
    final v = _view;
    if (v == null || _disposed) return;
    if (!r.applied) {
      // The mover's clock had run out: the game ended on time.
      _applyServer(
        r.game,
        v.moves,
        notice: 'Your time ran out before the move arrived.',
      );
      unawaited(_requestSync());
      return;
    }
    if (r.game.ply == p.ply && v.moves.length == p.ply - 1) {
      _applyServer(r.game, [
        ...v.moves,
        ServerMove(ply: p.ply, uci: p.uci, san: p.san, fenAfter: r.game.fen),
      ]);
    } else {
      unawaited(_requestSync());
    }
  }
}
