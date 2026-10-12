import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/move_list.dart';
import '../application/play_ai_notifier.dart';
import '../application/play_ai_view.dart';
import '../domain/game_setup.dart';
import '../domain/game_state.dart';
import 'game_board.dart';
import 'game_controls.dart';
import 'game_over_sheet.dart';
import 'new_game_sheet.dart';
import 'player_bar.dart';

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

  Future<void> _onGameOver(GameState game) async {
    final action = await GameOverSheet.show(context, game);
    if (!mounted) return;
    switch (action) {
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

    PlayerBar bar(Side side) {
      final isBot = side == game.botSide;
      return PlayerBar(
        name: isBot
            ? 'Bot · level ${level.number} · ~${level.approxRating}'
            : 'You',
        side: side,
        clock: game.clock,
        status: isBot && view.botThinking ? 'Thinking…' : null,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Level ${level.number} · ${game.timeControl.label}'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            bar(orientation.opposite),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: GameBoard(
                    size: constraints.biggest.shortestSide,
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
                ),
              ),
            ),
            bar(orientation),
            _StatusLine(
              view: view,
              onBackToGame: () => _notifier.viewPly(null),
              onRetry: _notifier.retryBot,
              onShowResult: () => _onGameOver(game),
            ),
            MoveList(
              sans: [for (final m in game.moves) m.san],
              selectedPly: ply,
              onSelect: _notifier.viewPly,
            ),
            GameControls(
              onFlip: () => setState(() => _flipped = !_flipped),
              onTakeback: view.canTakeback ? _notifier.takeback : null,
              onResign: game.isOver ? null : _notifier.resign,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// One line between board and move list: browsing, engine trouble, result.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.view,
    required this.onBackToGame,
    required this.onRetry,
    required this.onShowResult,
  });

  final PlayAiView view;
  final VoidCallback onBackToGame;
  final VoidCallback onRetry;
  final VoidCallback onShowResult;

  @override
  Widget build(BuildContext context) {
    final (
      String text,
      String? action,
      VoidCallback? onAction,
    ) = switch (view) {
      PlayAiView(isBrowsing: true) => (
        'Viewing an earlier position',
        'Back to game',
        onBackToGame,
      ),
      PlayAiView(engineFailed: true) => (
        'The bot did not answer.',
        'Retry',
        onRetry,
      ),
      PlayAiView(game: GameState(isOver: true, :final result?)) => (
        result.reason,
        'Show result',
        onShowResult,
      ),
      _ => ('', null, null),
    };
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Expanded(child: Text(text, style: AppType.caption)),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action)),
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
