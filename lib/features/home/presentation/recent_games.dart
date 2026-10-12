import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/section_card.dart';
import '../../history/presentation/result_badge.dart';
import '../../play_ai/domain/bot_level.dart';
import '../../play_ai/presentation/start_game_flow.dart';
import '../application/home_summary.dart';

/// Home's lower half: a slim stats row and the last three games.
class RecentGames extends ConsumerWidget {
  const RecentGames({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider).value;
    // Loading/error: keep the space quiet rather than flash an empty state.
    if (summary == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              const Expanded(child: Text('Recent games', style: AppType.label)),
              if (summary.played > 0)
                TextButton(
                  onPressed: () => context.push('/history'),
                  child: const Text('View all'),
                ),
            ],
          ),
        ),
        if (summary.played == 0)
          const _Empty()
        else ...[
          _Stats(summary),
          const SizedBox(height: AppSpacing.sm),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < summary.recent.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _RecentTile(summary.recent[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _percent(double v) => '${v.round()}%';

/// Games played · wins · best accuracy, as three quiet cells.
class _Stats extends StatelessWidget {
  const _Stats(this.summary);

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final best = summary.bestAccuracy;
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _Stat(value: '${summary.played}', label: 'Games'),
            const VerticalDivider(width: 1, color: AppColors.border),
            _Stat(value: '${summary.wins}', label: 'Wins'),
            const VerticalDivider(width: 1, color: AppColors.border),
            _Stat(
              value: best == null ? '–' : _percent(best),
              label: 'Best accuracy',
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppType.heading),
          Text(label, style: AppType.meta),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile(this.recent);

  final RecentGame recent;

  @override
  Widget build(BuildContext context) {
    final game = recent.game;
    final accuracy = recent.accuracy;
    final date = MaterialLocalizations.of(context)
        .formatShortDate(game.endedAt.toLocal());
    return ListTile(
      key: ValueKey('recent-${game.id}'),
      leading: ResultBadge(game.playerResult),
      title: Text(BotLevel.of(game.botLevel).label, style: AppType.label),
      subtitle: Text(
        [
          if (accuracy != null) '${_percent(accuracy)} accuracy',
          date,
        ].join(' · '),
        style: AppType.secondary,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
      onTap: () => context.push('/history/${game.id}'),
    );
  }
}

/// First use: what will show here, and a way to start.
class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('No games yet', style: AppType.label),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Your last three games show up here, with your accuracy once '
            'you review them.',
            style: AppType.secondary,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () => startGameFlow(context, ref),
            child: const Text('Start a game'),
          ),
        ],
      ),
    );
  }
}
