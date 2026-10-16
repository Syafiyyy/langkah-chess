import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/application/history_providers.dart';
import '../../history/data/history_repository.dart';
import '../../play_ai/application/play_ai_providers.dart';
import '../data/online_api.dart';
import '../domain/online_record.dart';
import '../domain/server_game.dart';
import 'online_providers.dart';

/// Copies the player's finished online games that are not in local history
/// yet (finished on another device or while the app was closed). Returns how
/// many were added; offline it adds none and does not throw.
Future<int> syncOnlineHistory(OnlineApi api, HistoryRepository history) async {
  try {
    var added = 0;
    for (final game in await api.finishedGames()) {
      if (await history.byId(game.id) != null) continue;
      final mySide = game.sideOf(api.userId);
      if (mySide == null) continue;
      final moves = await api.fetchMoves(game.id);
      final players = await api.players([game.whiteId, game.blackId].nonNulls);
      String name(Side side) =>
          players[game.playerId(side)]?.username ?? PlayerInfo.deleted.username;
      final record = onlineFinishedGame(
        game: game,
        moves: moves,
        mySide: mySide,
        white: name(Side.white),
        black: name(Side.black),
        ratingChange: await api.ratingChange(game.id),
      );
      if (record == null) continue;
      await history.save(record);
      added++;
    }
    return added;
  } on OnlineFailure {
    return 0;
  }
}

/// Runs the sync once per watch (History opens it) and refreshes the lists
/// when something was added.
final onlineHistorySyncProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ref.watch(onlineApiProvider);
  if (api == null) return 0;
  final added = await syncOnlineHistory(
    api,
    ref.read(historyRepositoryProvider),
  );
  if (added > 0) ref.read(historyRevisionProvider.notifier).bump();
  return added;
});
