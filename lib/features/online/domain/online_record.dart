import 'package:dartchess/dartchess.dart';

import '../../history/domain/finished_game.dart';
import 'online_result.dart';
import 'server_game.dart';

/// A finished online game as a local history record (so History, Replay and
/// Review work offline), or null when [game] has no result (running or
/// aborted) or [moves] are incomplete.
FinishedGame? onlineFinishedGame({
  required ServerGame game,
  required List<ServerMove> moves,
  required Side mySide,
  required String white,
  required String black,
  int? ratingChange,
}) {
  final result = serverResult(game);
  if (result == null || moves.length != game.ply) return null;
  final ended = game.finishedAt ?? game.lastMoveAt ?? DateTime.now().toUtc();
  final started = game.createdAt ?? ended;
  return FinishedGame(
    id: game.id,
    endedAt: ended,
    playerSide: mySide,
    botLevel: 0,
    timeControl: game.timeControl,
    result: result,
    pgn: _pgn(game, moves, white: white, black: black),
    finalFen: moves.isEmpty ? Chess.initial.fen : moves.last.fenAfter,
    plies: moves.length,
    duration: ended.difference(started),
    opponent: mySide == Side.white ? black : white,
    ratingChange: ratingChange,
  );
}

String _pgn(
  ServerGame game,
  List<ServerMove> moves, {
  required String white,
  required String black,
}) {
  final date = (game.createdAt ?? DateTime.now()).toUtc();
  final result = serverResult(game)!;
  final headers = <String, String>{
    'Event': 'Skak online',
    'Site': 'Skak',
    'Date': '${date.year}.${_two(date.month)}.${_two(date.day)}',
    'Round': '-',
    'White': white,
    'Black': black,
    'Result': Outcome.toPgnString(result.outcome),
    'TimeControl': '${game.timeBaseMs ~/ 1000}+${game.incrementMs ~/ 1000}',
    'Termination': result.reason,
  };
  final root = PgnNode<PgnNodeData>();
  PgnNode<PgnNodeData> node = root;
  for (final m in moves) {
    final child = PgnChildNode(PgnNodeData(san: m.san));
    node.children.add(child);
    node = child;
  }
  return PgnGame(headers: headers, moves: root, comments: const []).makePgn();
}

String _two(int n) => n.toString().padLeft(2, '0');
