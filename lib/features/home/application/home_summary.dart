import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/application/history_providers.dart';
import '../../history/data/history_repository.dart';
import '../../history/domain/finished_game.dart';
import '../../play_ai/application/play_ai_providers.dart';
import '../../review/application/review_notifier.dart';
import '../../review/data/analysis_repository.dart';
import '../../review/domain/game_line.dart';
import '../../review/domain/move_review.dart';

/// A recent game and, if it has been reviewed, the player's accuracy.
class RecentGame {
  const RecentGame(this.game, this.accuracy);

  final FinishedGame game;
  final double? accuracy;
}

/// What Home shows below the main actions.
class HomeSummary {
  const HomeSummary({
    required this.recent,
    required this.played,
    required this.wins,
    required this.bestAccuracy,
  });

  /// Up to three newest games.
  final List<RecentGame> recent;
  final int played;
  final int wins;

  /// Best player accuracy among reviewed games; null if none reviewed.
  final double? bestAccuracy;
}

/// Builds the Home summary from local history and cached reviews.
Future<HomeSummary> loadHomeSummary(
  HistoryRepository history,
  AnalysisRepository analysis,
) async {
  final games = await history.list();
  final accuracies = <String, double>{};
  for (final game in games) {
    final evals = await analysis.load(game.id, reviewAnalysisKey);
    if (evals == null) continue;
    final line = GameLine.fromPgn(game.pgn);
    if (evals.length != line.positions.length) continue;
    final reviews = reviewGame(
      positions: line.positions,
      moves: line.moves,
      evals: evals,
    );
    final accuracy = summarise(reviews, game.playerSide).accuracy;
    if (accuracy != null) accuracies[game.id] = accuracy;
  }
  return HomeSummary(
    recent: [for (final g in games.take(3)) RecentGame(g, accuracies[g.id])],
    played: games.length,
    wins: games.where((g) => g.playerResult == PlayerResult.win).length,
    bestAccuracy: accuracies.isEmpty
        ? null
        : accuracies.values.reduce((a, b) => a > b ? a : b),
  );
}

/// Home's summary; recomputed when history or a review changes.
final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) {
  ref.watch(historyRevisionProvider);
  return loadHomeSummary(
    ref.watch(historyRepositoryProvider),
    ref.watch(analysisRepositoryProvider),
  );
});
