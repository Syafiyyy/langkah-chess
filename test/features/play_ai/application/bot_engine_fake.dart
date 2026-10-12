import 'package:dartchess/dartchess.dart';

import '../../../core/engine/fake_uci_engine.dart';

/// A fake Stockfish that answers `go` with a legal move for the last
/// `position fen`: the next [script] move if any, else the first legal move.
///
/// With [holdUntilStop], it answers only when sent `stop` (a long search);
/// [holdFirstOnly] does that for the first search only.
FakeUciEngine botEngine({
  List<String> script = const [],
  bool holdUntilStop = false,
  bool holdFirstOnly = false,
}) {
  var goes = 0;
  final queue = [...script];
  String? fen;
  var searching = false;

  String reply() {
    if (queue.isNotEmpty) return queue.removeAt(0);
    final position = Chess.fromSetup(Setup.parseFen(fen!));
    final from = position.legalMoves.entries.firstWhere(
      (e) => e.value.isNotEmpty,
    );
    return NormalMove(from: from.key, to: from.value.first!).uci;
  }

  return FakeUciEngine(
    onCommand: (engine, command) {
      if (command == 'isready') engine.emit('readyok');
      if (command.startsWith('position fen ')) {
        fen = command.substring('position fen '.length);
      }
      if (command.startsWith('go')) {
        searching = true;
        goes++;
        final hold = holdUntilStop || (holdFirstOnly && goes == 1);
        if (!hold) {
          searching = false;
          _answer(engine, reply());
        }
      }
      if (command == 'stop' && searching) {
        searching = false;
        _answer(engine, reply());
      }
    },
  );
}

/// One scored line (so MultiPV candidate searches see it) and the bestmove.
void _answer(FakeUciEngine engine, String uci) {
  engine
    ..emit('info depth 1 multipv 1 score cp 0 pv $uci')
    ..emit('bestmove $uci');
}
