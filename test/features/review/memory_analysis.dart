import 'package:langkah/features/review/data/analysis_repository.dart';
import 'package:langkah/features/review/domain/position_eval.dart';

/// In-memory analysis cache for tests (ignores the key).
class MemoryAnalysis implements AnalysisRepository {
  MemoryAnalysis([Map<String, List<PositionEval>>? saved])
    : saved = saved ?? {};

  final Map<String, List<PositionEval>> saved;

  @override
  Future<List<PositionEval>?> load(String gameId, AnalysisKey key) async =>
      saved[gameId];

  @override
  Future<void> save(String id, AnalysisKey key, List<PositionEval> e) async =>
      saved[id] = e;
}
