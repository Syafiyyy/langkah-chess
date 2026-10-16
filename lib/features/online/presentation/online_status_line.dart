import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../application/online_game_view.dart';
import '../domain/online_clock.dart';
import '../domain/online_result.dart';

/// One line under the board, most important first: browsing, a message,
/// a draw or rematch offer, the first-move countdown, or the result.
class OnlineStatusLine extends ConsumerStatefulWidget {
  const OnlineStatusLine({
    super.key,
    required this.view,
    required this.onBackToGame,
    required this.onDismissNotice,
    required this.onAcceptDraw,
    required this.onDeclineDraw,
    required this.onAcceptRematch,
    required this.onShowResult,
  });

  final OnlineGameView view;
  final VoidCallback onBackToGame;
  final VoidCallback onDismissNotice;
  final VoidCallback onAcceptDraw;
  final VoidCallback onDeclineDraw;
  final VoidCallback onAcceptRematch;
  final VoidCallback onShowResult;

  static const double height = 40;

  @override
  ConsumerState<OnlineStatusLine> createState() => _OnlineStatusLineState();
}

class _OnlineStatusLineState extends ConsumerState<OnlineStatusLine> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(OnlineStatusLine old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  /// Repaints every second while the first-move countdown shows.
  void _syncTicker() {
    final counting = widget.view.game.isActive && widget.view.game.ply < 2;
    if (counting && _tick == null) {
      _tick = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!counting) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final w = widget;
    final firstMove = firstMoveTimeLeft(
      v.game,
      ref.watch(serverClockProvider).now(),
    );
    final (String text, List<(String, VoidCallback)> actions) = switch (v) {
      OnlineGameView(isBrowsing: true) => (
        'Viewing an earlier position',
        [('Return to game', w.onBackToGame)],
      ),
      OnlineGameView(:final notice?) => (
        notice,
        [('Dismiss', w.onDismissNotice)],
      ),
      OnlineGameView(opponentOffersDraw: true) => (
        'Draw offered',
        [('Decline', w.onDeclineDraw), ('Accept draw', w.onAcceptDraw)],
      ),
      OnlineGameView(iOfferDraw: true) => ('You offered a draw', const []),
      _ when firstMove != null => (
        v.position.turn == v.mySide
            ? 'Make your first move: ${firstMove.inSeconds}s'
            : "Opponent's first move: ${firstMove.inSeconds}s",
        const [],
      ),
      OnlineGameView(opponentOffersRematch: true) when v.game.isOver => (
        'Rematch offered',
        [('Accept rematch', w.onAcceptRematch)],
      ),
      _ when v.game.isOver => (
        v.result?.reason ?? abortReason(v.game),
        [('Show result', w.onShowResult)],
      ),
      _ => ('', const []),
    };
    return SizedBox(
      height: OnlineStatusLine.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppType.secondary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final (label, onTap) in actions)
              TextButton(onPressed: onTap, child: Text(label)),
          ],
        ),
      ),
    );
  }
}
