import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_info.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../play_ai/application/play_ai_notifier.dart';
import '../../play_ai/application/play_ai_providers.dart';
import '../../play_ai/presentation/new_game_sheet.dart';

/// Start screen: play the bot, open history, or resume a saved game.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final unfinished = await ref.read(savedGameProvider.future);
    if (unfinished) {
      if (!context.mounted || !await _confirmAbandon(context)) return;
      await ref.read(playAiProvider.notifier).abandon();
    }
    if (!context.mounted) return;
    final setup = await showNewGameSheet(context, ref);
    if (setup == null || !context.mounted) return;
    await ref.read(playAiProvider.notifier).start(setup);
    if (context.mounted) await context.push('/play');
  }

  Future<bool> _confirmAbandon(BuildContext context) async {
    final abandon = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon current game?'),
        content: const Text(
          'Your unfinished game will be deleted. It is not saved to history '
          'and does not count as a loss.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep game'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abandon game'),
          ),
        ],
      ),
    );
    return abandon ?? false;
  }

  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    final resumed = await ref.read(playAiProvider.notifier).resumeSaved();
    if (resumed && context.mounted) await context.push('/play');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSaved = ref.watch(savedGameProvider).value ?? false;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              const Text(kAppName, style: AppType.display),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Chess against Stockfish, on your phone.',
                style: AppType.caption,
              ),
              const Spacer(),
              if (hasSaved) ...[
                _ResumeBanner(onResume: () => _resume(context, ref)),
                const SizedBox(height: AppSpacing.lg),
              ],
              FilledButton(
                onPressed: () => _play(context, ref),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Play vs Bot'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => context.push('/history'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('History'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.onResume});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.all(AppRadius.md),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text('You have an unfinished game.', style: AppType.body),
          ),
          TextButton(onPressed: onResume, child: const Text('Resume game')),
        ],
      ),
    );
  }
}
