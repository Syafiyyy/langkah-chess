import 'package:dartchess/dartchess.dart';

import 'game_state.dart';

/// PGN of [state] with standard headers. Unfinished games get result `*`.
String gamePgn(GameState state) {
  final bot = 'Stockfish level ${state.level.number}';
  final white = state.playerSide == Side.white ? 'You' : bot;
  final black = state.playerSide == Side.black ? 'You' : bot;
  final date = state.startedAt;
  final tc = state.timeControl;
  final result = state.result;
  final initial = state.initialPosition;

  final headers = <String, String>{
    'Event': 'Skak vs Bot',
    'Site': 'Skak',
    'Date': '${date.year}.${_two(date.month)}.${_two(date.day)}',
    'Round': '-',
    'White': white,
    'Black': black,
    'Result': Outcome.toPgnString(result?.outcome),
    'TimeControl': tc.isTimed
        ? '${tc.initial.inSeconds}+${tc.increment.inSeconds}'
        : '-',
    if (result != null) 'Termination': result.reason,
    if (initial.fen != Chess.initial.fen) ...{'SetUp': '1', 'FEN': initial.fen},
  };

  final root = PgnNode<PgnNodeData>();
  PgnNode<PgnNodeData> node = root;
  for (final move in state.moves) {
    final child = PgnChildNode(PgnNodeData(san: move.san));
    node.children.add(child);
    node = child;
  }
  return PgnGame(headers: headers, moves: root, comments: const []).makePgn();
}

String _two(int n) => n.toString().padLeft(2, '0');
