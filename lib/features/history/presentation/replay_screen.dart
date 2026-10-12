import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/move_list.dart';
import '../application/history_providers.dart';
import '../domain/finished_game.dart';
import '../domain/replay_line.dart';

/// Steps through a finished game. Share or copy its PGN.
class ReplayScreen extends ConsumerWidget {
  const ReplayScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(finishedGameProvider(gameId));
    return switch (game) {
      AsyncData(value: final game?) => _Replay(game: game),
      AsyncData() || AsyncError() => Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('This game is no longer saved.', style: AppType.body),
        ),
      ),
      _ => Scaffold(appBar: AppBar()),
    };
  }
}

class _Replay extends StatefulWidget {
  const _Replay({required this.game});

  final FinishedGame game;

  @override
  State<_Replay> createState() => _ReplayState();
}

class _ReplayState extends State<_Replay> {
  late final ReplayLine _line = replayPgn(widget.game.pgn);
  late int _ply = _line.sans.length;
  bool _flipped = false;

  void _go(int ply) => setState(() => _ply = ply.clamp(0, _line.sans.length));

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.game.pgn));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PGN copied')));
    }
  }

  Future<void> _share() =>
      SharePlus.instance.share(ShareParams(text: widget.game.pgn));

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final orientation = _flipped ? game.playerSide.opposite : game.playerSide;
    final last = _line.sans.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Level ${game.botLevel} · ${game.timeControl.label}'),
        actions: [
          TextButton(
            onPressed: () => context.push('/review/${game.id}'),
            child: const Text('Review'),
          ),
          IconButton(
            tooltip: 'Copy PGN',
            onPressed: _copy,
            icon: const Icon(Icons.copy),
          ),
          IconButton(
            tooltip: 'Share PGN',
            onPressed: _share,
            icon: const Icon(Icons.share),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                '${Outcome.toPgnString(game.result.outcome)} · '
                '${game.result.reason}',
                style: AppType.label,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: StaticChessboard(
                    size: constraints.biggest.shortestSide,
                    orientation: orientation,
                    fen: _line.fens[_ply],
                    lastMove: _line.lastMoves[_ply],
                    settings: const StaticChessboardSettings(
                      colorScheme: ChessboardColorScheme.green,
                      enableCoordinates: true,
                    ),
                  ),
                ),
              ),
            ),
            MoveList(sans: _line.sans, selectedPly: _ply, onSelect: _go),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Flip board',
                  onPressed: () => setState(() => _flipped = !_flipped),
                  icon: const Icon(Icons.swap_vert),
                ),
                IconButton(
                  tooltip: 'Start',
                  onPressed: _ply > 0 ? () => _go(0) : null,
                  icon: const Icon(Icons.first_page),
                ),
                IconButton(
                  tooltip: 'Previous move',
                  onPressed: _ply > 0 ? () => _go(_ply - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next move',
                  onPressed: _ply < last ? () => _go(_ply + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: 'End',
                  onPressed: _ply < last ? () => _go(last) : null,
                  icon: const Icon(Icons.last_page),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
