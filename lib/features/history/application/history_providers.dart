import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../play_ai/application/play_ai_providers.dart';
import '../domain/finished_game.dart';

/// Finished games for a filter, newest first. Refetched each time a screen
/// starts watching it.
final historyListProvider = FutureProvider.autoDispose
    .family<List<FinishedGame>, HistoryFilter>(
      (ref, filter) =>
          ref.watch(historyRepositoryProvider).list(filter: filter),
    );

/// One finished game by id.
final finishedGameProvider = FutureProvider.autoDispose
    .family<FinishedGame?, String>(
      (ref, id) => ref.watch(historyRepositoryProvider).byId(id),
    );
