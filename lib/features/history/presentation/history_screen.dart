import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/section_card.dart';
import '../application/history_providers.dart';
import '../domain/finished_game.dart';

/// Finished games, newest first, with a win/loss/draw filter.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryFilter _filter = HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final games = ref.watch(historyListProvider(_filter));
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SegmentedButton<HistoryFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: HistoryFilter.all, label: Text('All')),
                ButtonSegment(value: HistoryFilter.wins, label: Text('Wins')),
                ButtonSegment(
                  value: HistoryFilter.losses,
                  label: Text('Losses'),
                ),
                ButtonSegment(value: HistoryFilter.draws, label: Text('Draws')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.single),
            ),
          ),
          Expanded(
            child: switch (games) {
              AsyncData(:final value) when value.isEmpty => _Empty(
                filter: _filter,
              ),
              AsyncData(:final value) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                children: [
                  // L1 panel with hairline dividers between games.
                  SectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < value.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: AppColors.border),
                          _GameTile(game: value[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              AsyncError() => const Center(
                child: Text(
                  'History could not be loaded. Restart the app to try again.',
                  style: AppType.secondary,
                ),
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game});

  final FinishedGame game;

  @override
  Widget build(BuildContext context) {
    final (letter, color) = switch (game.playerResult) {
      PlayerResult.win => ('W', AppColors.success),
      PlayerResult.loss => ('L', AppColors.danger),
      PlayerResult.draw => ('D', AppColors.textMuted),
    };
    final date = MaterialLocalizations.of(context)
        .formatShortDate(game.endedAt.toLocal());
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: const BorderRadius.all(AppRadius.md),
          border: Border.all(color: color),
        ),
        child: Text(letter, style: AppType.move.copyWith(color: color)),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
      title: Text(
        'Level ${game.botLevel} · ${game.timeControl.label} · '
        'as ${game.playerSide.name}',
        style: AppType.label,
      ),
      subtitle: Text(
        '${game.result.reason} · ${game.moveCount} moves · $date',
        style: AppType.secondary,
      ),
      onTap: () => context.push('/history/${game.id}'),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter});

  final HistoryFilter filter;

  @override
  Widget build(BuildContext context) {
    final text = filter == HistoryFilter.all
        ? 'No finished games yet. Games you finish against the bot are '
              'saved here.'
        : 'No games match this filter.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          text,
          style: AppType.secondary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
