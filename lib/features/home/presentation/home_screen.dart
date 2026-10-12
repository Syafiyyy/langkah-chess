import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/wordmark.dart';
import '../../play_ai/application/play_ai_notifier.dart';
import '../../play_ai/application/play_ai_providers.dart';
import '../../play_ai/presentation/start_game_flow.dart';
import 'recent_games.dart';

/// Start screen: play the bot, resume a saved game, recent games, settings.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final resumed = await ref.read(playAiProvider.notifier).resumeSaved();
    if (resumed && context.mounted) await context.push('/play');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSaved = ref.watch(savedGameProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: const Wordmark()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            const Text('Ready for a game?', style: AppType.title),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Play Stockfish offline, then review every move.',
              style: AppType.secondary,
            ),
            const SizedBox(height: AppSpacing.xl),
            if (hasSaved) ...[
              _ResumeCard(onResume: () => _resume(context, ref)),
              const SizedBox(height: AppSpacing.md),
            ],
            _PlayCard(onTap: () => startGameFlow(context, ref)),
            const SizedBox(height: AppSpacing.xl),
            const RecentGames(),
            const SizedBox(height: AppSpacing.xl),
            _LinkRow(
              icon: Icons.tune_rounded,
              title: 'Settings',
              subtitle: 'Board theme, pieces, bot speed',
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The primary action: a card with a gold icon tile.
class _PlayCard extends StatelessWidget {
  const _PlayCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.all(AppRadius.lg),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: AppColors.onAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Play vs Bot', style: AppType.heading),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Eight levels, from Newcomer to full strength.',
                  style: AppType.secondary,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      color: AppColors.surfaceRaised,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_rounded, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text('You have an unfinished game.', style: AppType.body),
          ),
          TextButton(onPressed: onResume, child: const Text('Resume game')),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.label),
                Text(subtitle, style: AppType.secondary),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
