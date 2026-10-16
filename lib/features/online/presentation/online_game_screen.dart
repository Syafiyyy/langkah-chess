import 'dart:async';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/board/board_theme.dart';
import '../../../shared/widgets/board_frame.dart';
import '../../../shared/widgets/move_list.dart';
import '../../../shared/widgets/player_bar.dart';
import '../../play_ai/presentation/game_board.dart';
import '../../play_ai/presentation/game_over_sheet.dart';
import '../../play_ai/presentation/moves_sheet.dart';
import '../application/online_game_notifier.dart';
import '../application/online_game_view.dart';
import '../domain/online_result.dart';
import '../domain/server_game.dart';
import 'connection_title.dart';
import 'online_clock_text.dart';
import 'online_controls.dart';
import 'online_status_line.dart';

/// An online game. Renders [onlineGameProvider] and sends the player's
/// actions to it; holds only view state (board flipped).
class OnlineGameScreen extends ConsumerStatefulWidget {
  const OnlineGameScreen({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends ConsumerState<OnlineGameScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _flipped = false;

  OnlineGameNotifier get _notifier =>
      ref.read(onlineGameProvider(widget.gameId).notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _notifier.appResumed());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static const double _gap = AppSpacing.sm;
  static const double _chrome = 2 * PlayerBar.height + 2 * _gap;

  static double _boardSize(BoxConstraints c) => BoardFrame.boardSizeFor(
    (c.maxHeight - _chrome - OnlineStatusLine.height)
        .clamp(0, c.maxWidth)
        .toDouble(),
  );

  static double _topGap(BoxConstraints c, double boardSize) {
    final framed = boardSize + 2 * BoardTheme.frameWidth;
    final free = c.maxHeight - _chrome - framed;
    return math.max(0, math.min(free / 2, free - OnlineStatusLine.height));
  }

  GameOverInfo _info(OnlineGameView v) {
    final result = v.result;
    final moves = (v.moves.length + 1) ~/ 2;
    if (result == null) {
      return GameOverInfo(
        title: 'Game aborted',
        details: '${abortReason(v.game)} · not rated',
        aborted: true,
      );
    }
    final winner = result.outcome.winner;
    final won = winner == null ? null : winner == v.mySide;
    return GameOverInfo(
      title: switch (won) {
        true => 'You won',
        false => 'You lost',
        null => 'Draw',
      },
      won: won,
      details: '${result.reason} · $moves moves',
      ratingChange: v.ratingChange,
    );
  }

  Map<GameOverAction, String> _actions(OnlineGameView v) {
    final finished = v.game.status == GameStatus.finished;
    final canRematch =
        finished && v.player(v.mySide.opposite) != PlayerInfo.deleted;
    return {
      if (finished) GameOverAction.review: 'Review game',
      if (canRematch)
        GameOverAction.rematch: v.opponentOffersRematch
            ? 'Accept rematch'
            : 'Offer rematch',
      GameOverAction.home: 'Back to online',
    };
  }

  /// The result sheet follows the game: the rating change and a rematch
  /// offer arrive after it opens.
  Future<void> _showResult() async {
    final provider = onlineGameProvider(widget.gameId);
    final first = ref.read(provider).value;
    if (first == null || !mounted) return;
    final action = await showModalBottomSheet<GameOverAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final v = ref.watch(provider).value ?? first;
          return GameOverSheet(info: _info(v), actions: _actions(v));
        },
      ),
    );
    final v = ref.read(provider).value ?? first;
    if (!mounted) return;
    switch (action) {
      case GameOverAction.review:
        await _notifier.whenRecorded();
        if (mounted) await context.push('/review/${widget.gameId}');
      case GameOverAction.rematch:
        await _rematch(v);
      case GameOverAction.home:
        context.go('/online');
      case GameOverAction.newGame || null:
        break;
    }
  }

  Future<void> _rematch(OnlineGameView v) async {
    final game = await _notifier.rematch();
    if (game == null || !mounted) return;
    if (game.status == GameStatus.active) {
      context.go('/online/game/${game.id}');
    } else {
      // Wait on the invite screen (create_invite returns this invite).
      context.go(
        Uri(
          path: '/online/invite',
          queryParameters: {'tc': v.game.timeControl.label},
        ).toString(),
      );
    }
  }

  Future<void> _showMoves(OnlineGameView v, int ply) async {
    final picked = await showMovesSheet(
      context,
      sans: v.sans,
      selectedPly: ply,
    );
    if (picked != null) _notifier.viewPly(picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = onlineGameProvider(widget.gameId);
    ref.listen(provider, (prev, next) {
      final ended =
          (prev?.value?.game.isActive ?? false) &&
          (next.value?.game.isOver ?? false);
      if (ended) unawaited(_showResult());
    });
    return switch (ref.watch(provider)) {
      AsyncData(:final value) => _game(value),
      AsyncError() => _LoadFailed(onRetry: () => ref.invalidate(provider)),
      _ => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }

  Widget _game(OnlineGameView v) {
    final ply = v.viewedPly ?? v.positions.length - 1;
    final orientation = _flipped ? v.mySide.opposite : v.mySide;
    final last = ply == 0 ? null : Move.parse(_uciAt(v, ply));

    PlayerBar bar(Side side) {
      final p = v.player(side);
      return PlayerBar(
        name: side == v.mySide ? '${p.username} (you)' : p.username,
        subtitle: p.rating == null ? null : 'Rating ${p.rating}',
        toMove: v.game.isActive && v.position.turn == side,
        clock: OnlineClockText(view: v, side: side),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: ConnectionTitle(
          title: '${v.game.timeControl.label} · rated',
          reconnecting: v.reconnecting && !v.game.isOver,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = _boardSize(constraints);
                  return Column(
                    children: [
                      SizedBox(height: _topGap(constraints, size)),
                      bar(orientation.opposite),
                      const SizedBox(height: _gap),
                      GameBoard(
                        size: size,
                        position: v.positions[ply],
                        lastMove: last,
                        orientation: orientation,
                        interactiveSide: !v.isBrowsing && v.isMyTurn
                            ? v.mySide
                            : null,
                        onMove: (m) => unawaited(_notifier.move(m)),
                      ),
                      const SizedBox(height: _gap),
                      bar(orientation),
                      OnlineStatusLine(
                        view: v,
                        onBackToGame: () => _notifier.viewPly(null),
                        onDismissNotice: _notifier.clearNotice,
                        onAcceptDraw: _notifier.acceptDraw,
                        onDeclineDraw: _notifier.declineDraw,
                        onAcceptRematch: () => _rematch(v),
                        onShowResult: _showResult,
                      ),
                    ],
                  );
                },
              ),
            ),
            MoveList(
              sans: v.sans,
              selectedPly: ply,
              onSelect: _notifier.viewPly,
            ),
            const SizedBox(height: AppSpacing.sm),
            OnlineControls(
              view: v,
              onFlip: () => setState(() => _flipped = !_flipped),
              onMoves: () => _showMoves(v, ply),
              onOfferDraw: _notifier.offerDraw,
              onAcceptDraw: _notifier.acceptDraw,
              onAbort: _notifier.abort,
              onResign: _notifier.resign,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  static String _uciAt(OnlineGameView v, int ply) =>
      ply <= v.moves.length ? v.moves[ply - 1].uci : v.pending!.uci;
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "The game didn't load. Check your connection.",
                style: AppType.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
