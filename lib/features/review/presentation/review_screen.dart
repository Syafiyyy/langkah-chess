import 'dart:math' as math;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/board/board_theme.dart';
import '../../../shared/widgets/board_frame.dart';
import '../../../shared/widgets/move_list.dart';
import '../../../shared/widgets/themed_board.dart';
import '../application/review_notifier.dart';
import '../application/review_state.dart';
import 'eval_bar.dart';
import 'eval_graph.dart';
import 'review_info_line.dart';
import 'review_style.dart';
import 'review_summary.dart';

/// Game review: summary, eval bar + board with the engine's best move,
/// current-move verdict, eval graph, move list and navigation.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _flipped = false;

  static const double _gap = AppSpacing.sm;

  /// Boards smaller than this get the compact graph instead.
  static const double _minBoard = 240;

  static double _graphHeight(BoxConstraints c) {
    final rest = c.maxHeight - ReviewInfoLine.height - 2 * _gap;
    return rest - EvalGraph.fullHeight >= _minBoard
        ? EvalGraph.fullHeight
        : EvalGraph.compactHeight;
  }

  /// Largest board that fits the width (16 px gutters, eval bar) and the
  /// height left after the verdict line and the graph.
  static double _boardSize(BoxConstraints c, double graph) {
    final width =
        c.maxWidth - 2 * AppSpacing.lg - EvalBar.width - AppSpacing.xs;
    final height = c.maxHeight - ReviewInfoLine.height - graph - 2 * _gap;
    return BoardFrame.boardSizeFor(math.max(0, math.min(width, height)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = reviewProvider(widget.gameId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final game = state.game;
    final line = state.line;
    if (state.notFound) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('This game is no longer saved.', style: AppType.body),
        ),
      );
    }
    if (game == null || line == null) return Scaffold(appBar: AppBar());

    final ply = state.ply;
    final orientation = _flipped ? game.playerSide.opposite : game.playerSide;
    final eval = ply < state.evals.length ? state.evals[ply] : null;
    final best = eval?.bestMove == null ? null : Move.parse(eval!.bestMove!);
    String name(Side side) => side == game.playerSide ? 'You' : 'Bot';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game review'),
        actions: [
          if (!state.analysing)
            IconButton(
              tooltip: 'Analyse again',
              onPressed: notifier.reanalyse,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ReviewSummary(
              whiteName: '${name(Side.white)} · White',
              blackName: '${name(Side.black)} · Black',
              white: state.summary(Side.white),
              black: state.summary(Side.black),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final graph = _graphHeight(c);
                  final size = _boardSize(c, graph);
                  final framed = size + 2 * BoardTheme.frameWidth;
                  final block =
                      framed + _gap + ReviewInfoLine.height + graph + _gap;
                  return Column(
                    children: [
                      SizedBox(height: math.max(0, (c.maxHeight - block) / 2)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          EvalBar(
                            whiteWin: eval?.whiteWin,
                            height: framed,
                            orientation: orientation,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ThemedBoard(
                            size: size,
                            orientation: orientation,
                            fen: line.positions[ply].fen,
                            lastMove: ply == 0
                                ? null
                                : Move.parse(line.moves[ply - 1].uci),
                            shapes: {
                              if (best is NormalMove)
                                Arrow(
                                  color: AppColors.labelBest.withValues(
                                    alpha: 0.85,
                                  ),
                                  orig: best.from,
                                  dest: best.to,
                                ),
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: _gap),
                      ReviewInfoLine(state: state, onRetry: notifier.reanalyse),
                      EvalGraph(
                        height: graph,
                        evals: state.evals,
                        reviews: state.reviews,
                        positions: state.total,
                        ply: ply,
                        onSelect: notifier.goTo,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: _gap),
            MoveList(
              sans: [for (final m in line.moves) m.san],
              selectedPly: ply,
              onSelect: notifier.goTo,
              marks: [for (final r in state.reviews) labelMark(r.label)],
            ),
            _Controls(
              state: state,
              notifier: notifier,
              onFlip: () => setState(() => _flipped = !_flipped),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.notifier,
    required this.onFlip,
  });

  final ReviewState state;
  final ReviewNotifier notifier;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final atStart = state.ply == 0;
    final atEnd = state.ply >= state.lastPly;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          tooltip: 'Flip board',
          onPressed: onFlip,
          icon: const Icon(Icons.swap_vert_rounded),
        ),
        IconButton(
          tooltip: 'Your previous mistake',
          onPressed: state.playerErrorBefore(state.ply) == null
              ? null
              : notifier.previousError,
          icon: const Icon(Icons.fast_rewind_rounded),
        ),
        IconButton(
          tooltip: 'Previous move',
          onPressed: atStart ? null : notifier.previous,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Next move',
          onPressed: atEnd ? null : notifier.next,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        IconButton(
          tooltip: 'Your next mistake',
          onPressed: state.playerErrorAfter(state.ply) == null
              ? null
              : notifier.nextError,
          icon: const Icon(Icons.fast_forward_rounded),
        ),
      ],
    );
  }
}
