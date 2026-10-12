import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/position_eval.dart';

/// What a cached analysis depends on: the analysis settings (e.g. move time)
/// and the engine build. A change in either makes old results a miss.
class AnalysisKey {
  const AnalysisKey({required this.settings, required this.engine});

  final String settings;
  final String engine;
}

/// Cached engine results per finished game.
abstract interface class AnalysisRepository {
  /// One eval per position (start position first), or null if not cached.
  Future<List<PositionEval>?> load(String gameId, AnalysisKey key);

  /// Stores (or replaces) the full analysis of a game.
  Future<void> save(String gameId, AnalysisKey key, List<PositionEval> evals);
}

/// sqflite implementation on the app database's `analysis` table.
class SqfliteAnalysisRepository implements AnalysisRepository {
  SqfliteAnalysisRepository(this._db);

  final Database _db;

  @override
  Future<List<PositionEval>?> load(String gameId, AnalysisKey key) async {
    final rows = await _db.query(
      'analysis',
      columns: ['evals'],
      where: 'game_id = ? AND settings = ? AND engine = ?',
      whereArgs: [gameId, key.settings, key.engine],
    );
    if (rows.isEmpty) return null;
    final list = jsonDecode(rows.single['evals']! as String) as List<Object?>;
    return [
      for (final e in list) PositionEval.fromJson(e! as Map<String, Object?>),
    ];
  }

  @override
  Future<void> save(
    String gameId,
    AnalysisKey key,
    List<PositionEval> evals,
  ) async {
    await _db.insert('analysis', {
      'game_id': gameId,
      'settings': key.settings,
      'engine': key.engine,
      'evals': jsonEncode([for (final e in evals) e.toJson()]),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
