import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/confirm_dialog.dart';
import '../application/play_ai_notifier.dart';
import '../application/play_ai_providers.dart';
import 'new_game_sheet.dart';

/// "Play vs Bot" from anywhere: asks before abandoning an unfinished game,
/// opens the new-game sheet, starts the game and opens the game screen.
Future<void> startGameFlow(BuildContext context, WidgetRef ref) async {
  final unfinished = await ref.read(savedGameProvider.future);
  if (unfinished) {
    if (!context.mounted) return;
    final abandon = await showConfirmDialog(
      context,
      title: 'Abandon current game?',
      message:
          'Your unfinished game will be deleted. It is not saved to '
          'history and does not count as a loss.',
      confirmLabel: 'Abandon game',
      cancelLabel: 'Keep game',
      destructive: true,
    );
    if (!abandon) return;
    await ref.read(playAiProvider.notifier).abandon();
  }
  if (!context.mounted) return;
  final setup = await showNewGameSheet(context, ref);
  if (setup == null || !context.mounted) return;
  await ref.read(playAiProvider.notifier).start(setup);
  if (context.mounted) await context.push('/play');
}
