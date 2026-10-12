import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../play_ai/application/play_ai_providers.dart';
import '../domain/finished_game.dart';

/// Bumped whenever a game is saved to history or a review is cached, so
/// screens that summarise history (Home, History) refresh.
final historyRevisionProvider = NotifierProvider<HistoryRevision, int>(
  HistoryRevision.new,
);

class HistoryRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Finished games for a filter, newest first. Refetched each time a screen
/// starts watching it.
final historyListProvider = FutureProvider.autoDispose
    .family<List<FinishedGame>, HistoryFilter>((ref, filter) {
      ref.watch(historyRevisionProvider);
      return ref.watch(historyRepositoryProvider).list(filter: filter);
    });

/// One finished game by id.
final finishedGameProvider = FutureProvider.autoDispose
    .family<FinishedGame?, String>(
      (ref, id) => ref.watch(historyRepositoryProvider).byId(id),
    );
