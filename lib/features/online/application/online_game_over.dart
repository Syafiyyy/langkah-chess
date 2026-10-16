import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../history/data/history_repository.dart';
import '../data/online_api.dart';
import '../domain/online_record.dart';
import 'online_game_view.dart';

/// After a rated game: the player's rating change (null if unknown) and the
/// game saved to local history (saving the same id twice is a no-op).
Future<int?> recordFinishedGame(
  OnlineGameView Function() view,
  OnlineApi api,
  HistoryRepository history,
) async {
  int? change;
  try {
    change = await api.ratingChange(view().game.id);
  } on OnlineFailure {
    // Shown without the rating change.
  }
  final v = view();
  final record = onlineFinishedGame(
    game: v.game,
    moves: v.moves,
    mySide: v.mySide,
    white: v.player(Side.white).username,
    black: v.player(Side.black).username,
    ratingChange: change,
  );
  if (record != null) {
    try {
      await history.save(record);
    } on Exception catch (e) {
      debugPrint('Saving online game failed: $e');
    }
  }
  return change;
}
