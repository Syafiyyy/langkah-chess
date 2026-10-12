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
import '../../../shared/widgets/wordmark.dart';
import '../application/play_ai_notifier.dart';
import '../domain/game_setup.dart';
import '../domain/game_state.dart';
import 'clock_text.dart';
import 'game_board.dart';
import 'game_controls.dart';
import 'game_over_sheet.dart';
import 'game_status_line.dart';
import 'moves_sheet.dart';
import 'new_game_sheet.dart';

/// The offline game against the bot. Renders [playAiProvider] and sends the
/// player's actions to it; holds only view state (board flipped).
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late final PlayAiNotifier _notifier = ref.read(playAiProvider.notifier);
  late final AppLifecycleListener _lifecycle;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: _notifier.appPaused,
      onShow: _notifier.appResumed,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // Leaving the screen pauses the game (it stays saved for "Resume").
    // Deferred: providers must not change while the tree is finalising.
    final notifier = _notifier;
    scheduleMicrotask(notifier.suspend);
    super.dispose();
  }

  /// Gap between each player bar and the board.
  static const double _gap = AppSpacing.sm;

  /// Height of bars + gaps around the framed board.
  static const double _chrome = 2 * PlayerBar.height + 2 * _gap;

  /// Largest framed board that leaves room for both bars and the status
  /// line (reserved even when empty, so the board never jumps).
  static double _boardSize(BoxConstraints c) => BoardFrame.boardSizeFor(
    (c.maxHeight - _chrome - GameStatusLine.height)
        .clamp(0, c.maxWidth)
        .toDouble(),
  );

  /// Space above the block: half of what is left, but never so much that
  /// the status line below the block runs out of room.
  static double _topGap(BoxConstraints c, double boardSize) {
    final framed = boardSize + 2 * BoardTheme.frameWidth;
    final free = c.maxHeight - _chrome - framed;
    return math.max(0, math.min(free / 2, free - GameStatusLine.height));
  }

  Future<void> _onGameOver(GameState game) async {
    final action = await GameOverSheet.show(context, game);
    if (!mounted) return;
    switch (action) {
      case GameOverAction.review:
        await _notifier.whenSaved();
        if (mounted) await context.push('/review/${game.id}');
      case GameOverAction.rematch:
        final swapped = game.playerSide == Side.white
            ? ColorChoice.black
            : ColorChoice.white;
        setState(() => _flipped = false);
        await _notifier.start(
          GameSetup(
            level: game.level,
            color: swapped,
            timeControl: game.timeControl,
            botSpeed: game.botSpeed,
          ),
        );
      case GameOverAction.newGame:
        final setup = await showNewGameSheet(context, ref);
        if (setup == null) return;
        setState(() => _flipped = false);
        await _notifier.start(setup);
      case GameOverAction.home:
        context.go('/');
      case null:
        break;
    }
  }

  /// Settings from the game: the clock is paused while it is open.
  Future<void> _openSettings() async {
    _notifier.appPaused();
    await context.push('/settings');
    if (mounted) _notifier.appResumed();
  }

  Future<void> _showMoves(GameState game, int ply) async {
    final picked = await showMovesSheet(
      context,
      sans: [for (final m in game.moves) m.san],
      selectedPly: ply,
    );
    if (picked != null) _notifier.viewPly(picked);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playAiProvider, (prev, next) {
      final ended =
          next != null &&
          next.game.isOver &&
          prev != null &&
          prev.game.id == next.game.id &&
          !prev.game.isOver;
      if (ended) _onGameOver(next.game);
    });
    final view = ref.watch(playAiProvider);
    if (view == null) return const _NoGame();
    final game = view.game;
    final ply = view.viewedPly ?? game.moves.length;
    final orientation = _flipped ? game.playerSide.opposite : game.playerSide;
    final level = game.level;
    final clock = game.clock;

    PlayerBar bar(Side side) {
      final isBot = side == game.botSide;
      return PlayerBar(
        name: isBot ? level.name : 'You',
        subtitle: isBot
            ? 'Level ${level.number} · Bot'
            : game.timeControl.label,
        isBot: isBot,
        thinking: isBot && view.botThinking,
        toMove: !game.isOver && game.position.turn == side,
        clock: clock == null ? null : ClockText(clock: clock, side: side),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Wordmark(),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Game menu',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => switch (value) {
              'settings' => _openSettings(),
              _ => null,
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('Open settings')),
            ],
          ),
        ],
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
                        position: game.positions[ply],
                        lastMove: ply == 0
                            ? null
                            : Move.parse(game.moves[ply - 1].uci),
                        orientation: orientation,
                        interactiveSide:
                            !view.isBrowsing &&
                                game.isPlayerTurn &&
                                !view.botThinking
                            ? game.playerSide
                            : null,
                        onMove: _notifier.move,
                      ),
                      const SizedBox(height: _gap),
                      bar(orientation),
                      GameStatusLine(
                        view: view,
                        onBackToGame: () => _notifier.viewPly(null),
                        onRetry: _notifier.retryBot,
                        onShowResult: () => _onGameOver(game),
                      ),
                    ],
                  );
                },
              ),
            ),
            MoveList(
              sans: [for (final m in game.moves) m.san],
              selectedPly: ply,
              onSelect: _notifier.viewPly,
            ),
            const SizedBox(height: AppSpacing.sm),
            GameControls(
              onTakeback: view.canTakeback ? _notifier.takeback : null,
              onFlip: () => setState(() => _flipped = !_flipped),
              onMoves: () => _showMoves(game, ply),
              onResign: game.isOver ? null : _notifier.resign,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _NoGame extends StatelessWidget {
  const _NoGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No game in progress.', style: AppType.body),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}
