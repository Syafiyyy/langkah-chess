import 'package:dartchess/dartchess.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/core/supabase/server_clock.dart';
import 'package:skak/core/supabase/supabase_providers.dart';
import 'package:skak/features/online/application/online_game_notifier.dart';
import 'package:skak/features/online/application/online_game_view.dart';
import 'package:skak/features/online/application/online_providers.dart';
import 'package:skak/features/online/data/online_api.dart';
import 'package:skak/features/online/domain/server_game.dart';
import 'package:skak/features/play_ai/application/play_ai_providers.dart';

import '../../history/memory_history.dart';
import '../fake_online_api.dart';

Move _m(String uci) => Move.parse(uci)!;

class _Setup {
  _Setup({Side mySide = Side.white}) {
    api.addGame(mySide: mySide);
    container = ProviderContainer.test(
      overrides: [
        onlineApiProvider.overrideWithValue(api),
        serverClockProvider.overrideWithValue(
          ServerClock(localNow: () => api.now),
        ),
        historyRepositoryProvider.overrideWithValue(history),
      ],
    );
  }

  final api = FakeOnlineApi();
  final history = MemoryHistory();
  late final ProviderContainer container;

  OnlineGameNotifier get notifier =>
      container.read(onlineGameProvider('g1').notifier);
  OnlineGameView get view => container.read(onlineGameProvider('g1')).value!;

  /// Starts the notifier (after the test has set up the server).
  Future<OnlineGameView> load() {
    container.listen(onlineGameProvider('g1'), (_, _) {});
    return container.read(onlineGameProvider('g1').future);
  }
}

/// Runs [body] in fake time, flushing microtasks between steps.
void fake(void Function(FakeAsync async) body) => fakeAsync(body);

void main() {
  test('loads the game, moves and players, and listens for hints', () async {
    final s = _Setup(mySide: Side.black);
    s.api.serverMove('g1', 'e2e4');
    final v = await s.load();
    expect(v.mySide, Side.black);
    expect(v.sans, ['e4']);
    expect(v.player(Side.white).username, 'opponent');
    expect(v.isMyTurn, isTrue);
    expect(s.api.watchers('g1'), 1);
    s.container.dispose();
    expect(s.api.watchers('g1'), 0);
  });

  test('a move shows at once and is confirmed by the server', () async {
    final s = _Setup();
    await s.load();
    final sending = s.notifier.move(_m('e2e4'));
    expect(s.view.pending?.uci, 'e2e4');
    expect(s.view.sans, ['e4']);
    expect(s.view.isMyTurn, isFalse);
    await sending;
    expect(s.view.pending, isNull);
    expect(s.view.moves.single.san, 'e4');
    expect(s.api.count('makeMove 1 e2e4'), 1);
  });

  test('castling onto the rook is sent as the king move', () async {
    final s = _Setup();
    for (final uci in ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6']) {
      s.api.serverMove('g1', uci);
    }
    await s.load();
    await s.notifier.move(_m('e1h1'));
    expect(s.api.count('makeMove 7 e1g1'), 1);
  });

  test('a second tap while a move is on its way is ignored', () async {
    final s = _Setup();
    await s.load();
    final first = s.notifier.move(_m('e2e4'));
    await s.notifier.move(_m('d2d4'));
    await first;
    expect(s.api.count('makeMove'), 1);
    expect(s.api.moves['g1'], hasLength(1));
  });

  test("no move when it is not the player's turn", () async {
    final s = _Setup(mySide: Side.black);
    await s.load();
    await s.notifier.move(_m('e2e4'));
    expect(s.api.count('makeMove'), 0);
    expect(s.view.pending, isNull);
  });

  test('network errors: retried with the same id until it lands, once', () {
    fake((async) {
      final s = _Setup();
      s.load();
      async.flushMicrotasks();
      s.api.failures['makeMove'] = List.filled(4, const OnlineUnavailable());
      s.notifier.move(_m('e2e4'));
      async.flushMicrotasks();
      expect(s.view.reconnecting, isTrue);
      expect(s.view.pending, isNotNull);
      async.elapse(const Duration(seconds: 8));
      final ids = s.api.calls
          .where((c) => c.startsWith('makeMove'))
          .map((c) => c.split(' ').last)
          .toSet();
      expect(s.api.count('makeMove'), 5);
      expect(ids, hasLength(1));
      expect(s.api.moves['g1'], hasLength(1));
      expect(s.view.pending, isNull);
      expect(s.view.moves, hasLength(1));
      expect(s.view.requestFailing, isFalse);
    });
  });

  test('lost responses: the retry is recognised, the move is not doubled', () {
    fake((async) {
      final s = _Setup();
      s.load();
      async.flushMicrotasks();
      s.api.applyThenFail = true;
      s.api.failures['makeMove'] = [const OnlineUnavailable()];
      s.notifier.move(_m('e2e4'));
      async.elapse(const Duration(seconds: 2));
      expect(s.api.count('makeMove'), 2);
      expect(s.api.moves['g1'], hasLength(1));
      expect(s.view.moves.single.uci, 'e2e4');
      expect(s.view.pending, isNull);
    });
  });

  test('a long outage: keeps trying with the same id, and a resync that '
      'finds the move ends the retries', () {
    fake((async) {
      final s = _Setup();
      s.load();
      async.flushMicrotasks();
      // 20 s without network: every request fails.
      s.api.failures['makeMove'] = List.filled(50, const OnlineUnavailable());
      s.api.failures['fetch'] = List.filled(50, const OnlineUnavailable());
      s.notifier.move(_m('e2e4'));
      async.elapse(const Duration(seconds: 20));
      expect(s.view.pending?.uci, 'e2e4');
      expect(s.view.reconnecting, isTrue);
      final ids = s.api.calls
          .where((c) => c.startsWith('makeMove'))
          .map((c) => c.split(' ').last)
          .toSet();
      expect(ids, hasLength(1));

      // Network back.
      s.api.failures.clear();
      async.elapse(const Duration(seconds: 6));
      expect(s.api.moves['g1'], hasLength(1));
      expect(s.view.moves.single.uci, 'e2e4');
      expect(s.view.pending, isNull);
      expect(s.view.requestFailing, isFalse);
    });
  });

  test('a rejected move rolls back to the server and says so', () async {
    final s = _Setup();
    await s.load();
    s.api.failures['makeMove'] = [const OnlineRejected('STALE')];
    await s.notifier.move(_m('e2e4'));
    await pumpEventQueue();
    expect(s.view.pending, isNull);
    expect(s.view.moves, isEmpty);
    expect(s.view.notice, contains('back in sync'));
  });

  test('a hint fetches only the new moves', () async {
    final s = _Setup(mySide: Side.black);
    s.api.serverMove('g1', 'e2e4');
    await s.load();
    s.api.calls.clear();
    s.api.serverMove('g1', 'e7e5');
    s.api.serverMove('g1', 'g1f3');
    s.api.hint('g1');
    await pumpEventQueue();
    expect(s.api.calls, contains('fetchMoves 1'));
    expect(s.view.sans, ['e4', 'e5', 'Nf3']);
  });

  test('a hint during a send keeps the move on the board', () async {
    final s = _Setup();
    await s.load();
    s.api.failures['makeMove'] = [const OnlineUnavailable()];
    final sending = s.notifier.move(_m('e2e4'));
    s.api.hint('g1');
    await pumpEventQueue();
    expect(s.view.sans, ['e4']);
    await sending;
  });

  test('channel drops show Reconnecting; resubscribing resyncs', () async {
    final s = _Setup();
    await s.load();
    s.api.setConnected('g1', true);
    await pumpEventQueue();
    expect(s.view.reconnecting, isFalse);
    s.api.setConnected('g1', false);
    expect(s.view.reconnecting, isTrue);
    s.api.calls.clear();
    s.api.serverMove('g1', 'e2e4');
    s.api.setConnected('g1', true);
    await pumpEventQueue();
    expect(s.api.calls, contains('fetchGame'));
    expect(s.view.sans, ['e4']);
    expect(s.view.reconnecting, isFalse);
  });

  test('resume resyncs', () async {
    final s = _Setup();
    await s.load();
    s.api.serverMove('g1', 'e2e4');
    s.notifier.appResumed();
    await pumpEventQueue();
    expect(s.view.sans, ['e4']);
  });

  test('a finished game loads the rating change and is saved once', () async {
    final s = _Setup(mySide: Side.black);
    await s.load();
    for (final uci in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      s.api.serverMove('g1', uci);
    }
    s.api.hint('g1');
    await pumpEventQueue();
    s.api.hint('g1');
    await pumpEventQueue();
    expect(s.view.result?.reason, 'Checkmate');
    expect(s.view.ratingChange, 12);
    expect(s.history.saved, hasLength(1));
    expect(s.history.saved.single.opponent, 'opponent');
    expect(s.api.count('ratingChange'), 1);
  });

  test("claims the timeout once when the opponent's clock runs out", () {
    fake((async) {
      final s = _Setup();
      for (final uci in ['e2e4', 'e7e5', 'g1f3']) {
        s.api.serverMove('g1', uci);
      }
      // Black to move with 5 s left.
      s.api.setGame(s.api.copy(s.api.games['g1']!, blackMs: 5000));
      s.load();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 4));
      expect(s.api.count('act claimTimeout'), 0);
      s.api.now = s.api.now.add(const Duration(seconds: 6));
      async.elapse(const Duration(seconds: 2));
      expect(s.api.count('act claimTimeout'), 1);
      async.elapse(const Duration(seconds: 10));
      expect(s.api.count('act claimTimeout'), 1);
    });
  });

  test('game actions go to the server and the view follows', () async {
    final s = _Setup();
    await s.load();
    await s.notifier.offerDraw();
    expect(s.view.iOfferDraw, isTrue);
    await s.notifier.abort();
    expect(s.view.game.status, GameStatus.aborted);
    expect(s.api.calls, containsAll(['act offerDraw', 'act abort']));
  });

  test('resign ends the game', () async {
    final s = _Setup();
    await s.load();
    await s.notifier.resign();
    expect(s.view.result?.reason, 'Resignation');
  });

  test('an action without network leaves the game and says so', () async {
    final s = _Setup();
    await s.load();
    s.api.failures['rpc'] = [const OnlineUnavailable()];
    await s.notifier.resign();
    expect(s.view.game.isActive, isTrue);
    expect(s.view.notice, contains('No connection'));
  });
}
