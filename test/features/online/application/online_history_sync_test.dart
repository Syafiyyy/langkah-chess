import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/online/application/online_history_sync.dart';
import 'package:skak/features/online/data/online_api.dart';
import 'package:skak/features/online/domain/server_game.dart';

import '../../history/memory_history.dart';
import '../fake_online_api.dart';

void main() {
  FakeOnlineApi finishedGame(String id) {
    final api = FakeOnlineApi()..addGame(id: id, mySide: Side.black);
    for (final uci in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      api.serverMove(id, uci);
    }
    return api;
  }

  test('caches finished server games that are not in local history', () async {
    final api = finishedGame('g1');
    api.addGame(id: 'running');
    final history = MemoryHistory();

    expect(await syncOnlineHistory(api, history), 1);
    final saved = history.saved.single;
    expect(saved.id, 'g1');
    expect(saved.opponent, 'opponent');
    expect(saved.ratingChange, 12);
    expect(saved.plies, 4);

    api.calls.clear();
    expect(await syncOnlineHistory(api, history), 0);
    expect(api.calls, [
      'finishedGames',
    ], reason: 'known games are not refetched');
  });

  test('a deleted opponent is named as such', () async {
    final api = finishedGame('g1');
    api.profiles.remove('opp');
    final g = api.games['g1']!;
    api.games['g1'] = ServerGame(
      id: g.id,
      status: g.status,
      mode: g.mode,
      timeBaseMs: g.timeBaseMs,
      incrementMs: g.incrementMs,
      fen: g.fen,
      ply: g.ply,
      whiteMs: g.whiteMs,
      blackMs: g.blackMs,
      blackId: 'me',
      result: g.result,
      termination: g.termination,
    );
    final history = MemoryHistory();
    await syncOnlineHistory(api, history);
    expect(history.saved.single.opponent, 'Deleted player');
  });

  test('offline: nothing happens, no error', () async {
    final history = MemoryHistory();
    expect(await syncOnlineHistory(_Offline(finishedGame('g1')), history), 0);
    expect(history.saved, isEmpty);
  });
}

class _Offline extends FakeOnlineApi {
  _Offline(FakeOnlineApi from) {
    games.addAll(from.games);
  }

  @override
  Future<List<ServerGame>> finishedGames({int limit = 50}) =>
      Future.error(const OnlineUnavailable());
}
