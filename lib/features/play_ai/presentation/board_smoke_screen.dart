import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_info.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/engine/engine_provider.dart';
import '../../../core/engine/engine_service.dart';

/// F0 smoke test: a chessground board driven by a dartchess position, where
/// both sides can move, plus an "Engine move" button backed by EngineService.
class BoardSmokeScreen extends ConsumerStatefulWidget {
  const BoardSmokeScreen({super.key});

  @override
  ConsumerState<BoardSmokeScreen> createState() => _BoardSmokeScreenState();
}

class _BoardSmokeScreenState extends ConsumerState<BoardSmokeScreen> {
  Position _position = Chess.initial;
  Move? _lastMove;
  late final ChessboardController _board;
  bool _thinking = false;
  bool _firstReplyDone = false;
  String _status = 'Make a move, or ask the engine.';

  @override
  void initState() {
    super.initState();
    _board = ChessboardController(game: _gameData());
  }

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  GameData _gameData() => GameData(
    fen: _position.fen,
    lastMove: _lastMove,
    playerSide: _position.isGameOver || _thinking
        ? PlayerSide.none
        : PlayerSide.both,
    sideToMove: _position.turn,
    validMoves: makeLegalMoves(_position),
    kingSquareInCheck: _position.isCheck
        ? _position.board.kingOf(_position.turn)
        : null,
  );

  void _play(Move move) {
    if (!_position.isLegal(move)) return;
    setState(() {
      _position = _position.playUnchecked(move);
      _lastMove = move;
      if (_position.isGameOver) _status = 'Game over.';
    });
    _board.updatePosition(_gameData());
  }

  Future<void> _engineMove() async {
    if (_thinking || _position.isGameOver) return;
    setState(() => _thinking = true);
    _board.updatePosition(_gameData(), animate: false);
    final watch = Stopwatch()..start();
    try {
      final result = await ref
          .read(engineServiceProvider)
          .bestMove(_position.fen);
      watch.stop();
      final uci = result.bestMove;
      final move = uci == null ? null : Move.parse(uci);
      final label = _firstReplyDone ? 'reply' : 'first reply (incl. start-up)';
      _firstReplyDone = true;
      debugPrint('[engine] $label ${watch.elapsedMilliseconds} ms: $uci');
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _status =
            'Engine: ${uci ?? 'no move'} · ${_scoreText(result.eval)} · '
            '$label ${watch.elapsedMilliseconds} ms';
      });
      if (move != null) {
        _play(move);
      } else {
        _board.updatePosition(_gameData(), animate: false);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _status = 'The engine did not answer: $e';
      });
      _board.updatePosition(_gameData(), animate: false);
    }
  }

  String _scoreText(EngineEval? eval) {
    if (eval == null) return 'no eval';
    final mate = eval.mate;
    if (mate != null) return 'mate in $mate';
    return '${((eval.cp ?? 0) / 100).toStringAsFixed(2)} (depth ${eval.depth})';
  }

  void _reset() {
    setState(() {
      _position = Chess.initial;
      _lastMove = null;
      _status = 'New game.';
    });
    _board.updatePosition(_gameData(), animate: false);
    ref.read(engineServiceProvider).newGame().ignore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(kAppName)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: Chessboard(
                    size: constraints.biggest.shortestSide,
                    controller: _board,
                    orientation: Side.white,
                    onMove: (move, {viaDragAndDrop}) => _play(move),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(_status, style: AppType.caption),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _thinking || _position.isGameOver
                          ? null
                          : _engineMove,
                      child: Text(_thinking ? 'Thinking…' : 'Engine move'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  OutlinedButton(
                    onPressed: _thinking ? null : _reset,
                    child: const Text('New game'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
