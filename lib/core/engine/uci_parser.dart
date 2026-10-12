/// Pure parsers for the UCI lines EngineService cares about.
library;

final RegExp _spaces = RegExp(r'\s+');

/// An evaluation from an `info` line.
///
/// Scores are from the point of view of the side to move (UCI convention).
class EngineEval {
  const EngineEval({
    required this.depth,
    this.multipv = 1,
    this.cp,
    this.mate,
    this.pv = const [],
  });

  final int depth;

  /// Line index in a MultiPV search (1 = best). 1 when not given.
  final int multipv;

  /// Centipawns. Null when the score is a mate score.
  final int? cp;

  /// Moves to mate (negative: the side to move gets mated). Null for cp scores.
  final int? mate;

  /// Principal variation as UCI moves.
  final List<String> pv;
}

/// Parses an `info ... score cp|mate N ... pv ...` line.
///
/// Returns null for lines that are not `info` lines or carry no score
/// (for example `info string ...` or `info currmove ...`).
EngineEval? parseInfoLine(String line) {
  final tokens = line.trim().split(_spaces);
  if (tokens.first != 'info') return null;

  int? depth;
  var multipv = 1;
  int? cp;
  int? mate;
  var pv = const <String>[];
  for (var i = 1; i < tokens.length; i++) {
    switch (tokens[i]) {
      case 'string':
        return null;
      case 'depth' when i + 1 < tokens.length:
        depth = int.tryParse(tokens[++i]);
      case 'multipv' when i + 1 < tokens.length:
        multipv = int.tryParse(tokens[++i]) ?? 1;
      case 'score' when i + 2 < tokens.length:
        final kind = tokens[i + 1];
        final value = int.tryParse(tokens[i + 2]);
        if (kind == 'cp') cp = value;
        if (kind == 'mate') mate = value;
        i += 2;
      case 'pv':
        pv = List.unmodifiable(tokens.sublist(i + 1));
        i = tokens.length;
    }
  }
  if (cp == null && mate == null) return null;
  return EngineEval(
    depth: depth ?? 0,
    multipv: multipv,
    cp: cp,
    mate: mate,
    pv: pv,
  );
}

/// Parses a `bestmove <uci> [ponder <uci>]` line.
///
/// Returns null if [line] is not a bestmove line. Returns a record with a null
/// `uci` for `bestmove (none)`, which means the position has no legal moves.
({String? uci})? parseBestMoveLine(String line) {
  final tokens = line.trim().split(_spaces);
  if (tokens.first != 'bestmove') return null;
  final move = tokens.length > 1 ? tokens[1] : null;
  return (uci: move == null || move == '(none)' ? null : move);
}
