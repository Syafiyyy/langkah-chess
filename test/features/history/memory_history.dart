import 'package:skak/features/history/data/history_repository.dart';
import 'package:skak/features/history/domain/finished_game.dart';

/// In-memory history; saving an id twice keeps one game (like sqflite).
class MemoryHistory implements HistoryRepository {
  final saved = <FinishedGame>[];

  @override
  Future<void> save(FinishedGame game) async {
    if (saved.every((g) => g.id != game.id)) saved.add(game);
  }

  @override
  Future<List<FinishedGame>> list({
    HistoryFilter filter = HistoryFilter.all,
  }) async => saved;

  @override
  Future<FinishedGame?> byId(String id) async =>
      saved.where((g) => g.id == id).firstOrNull;
}
