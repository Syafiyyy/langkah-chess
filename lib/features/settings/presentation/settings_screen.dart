import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../core/board/board_prefs.dart';
import '../../../core/board/board_theme.dart';
import '../../../core/board/piece_choice.dart';
import '../../../shared/widgets/board_frame.dart';
import '../../../shared/widgets/section_card.dart';
import '../../play_ai/application/play_ai_providers.dart';
import '../../play_ai/domain/game_setup.dart';

/// A position that shows both piece colours and a last-move highlight.
const _previewFen =
    'r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';
final _previewLastMove = Move.parse('g8f6');

/// Board theme, piece set and the default bot speed.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  GameSetup? _setup;

  @override
  void initState() {
    super.initState();
    ref.read(playAiStoreProvider).lastSetup().then((s) {
      if (mounted) setState(() => _setup = s);
    });
  }

  Future<void> _setSpeed(BotSpeed speed) async {
    final setup = (_setup ?? GameSetup.defaults).copyWith(botSpeed: speed);
    setState(() => _setup = setup);
    await ref.read(playAiStoreProvider).saveSetup(setup);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(boardPrefsProvider);
    final notifier = ref.read(boardPrefsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final size = BoardFrame.boardSizeFor(c.maxWidth.clamp(0, 320));
                return Center(
                  child: BoardFrame(
                    theme: prefs.theme,
                    boardSize: size,
                    child: StaticChessboard(
                      size: size,
                      orientation: Side.white,
                      fen: _previewFen,
                      lastMove: _previewLastMove,
                      settings: StaticChessboardSettings(
                        colorScheme: prefs.theme.colorScheme,
                        pieceAssets: prefs.pieces.assets,
                      ),
                    ),
                  ),
                );
              },
            ),
            const _Label('Board theme'),
            Row(
              children: [
                for (final theme in BoardTheme.all) ...[
                  if (theme != BoardTheme.all.first)
                    const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ThemeCard(
                      theme: theme,
                      selected: theme == prefs.theme,
                      onTap: () => notifier.setTheme(theme),
                    ),
                  ),
                ],
              ],
            ),
            const _Label('Pieces'),
            Row(
              children: [
                for (final pieces in PieceChoice.values) ...[
                  if (pieces != PieceChoice.values.first)
                    const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _PieceCard(
                      pieces: pieces,
                      selected: pieces == prefs.pieces,
                      onTap: () => notifier.setPieces(pieces),
                    ),
                  ),
                ],
              ],
            ),
            const _Label('Bot speed for new games'),
            SegmentedButton<BotSpeed>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: BotSpeed.natural, label: Text('Natural')),
                ButtonSegment(value: BotSpeed.fast, label: Text('Fast')),
              ],
              selected: {_setup?.botSpeed ?? BotSpeed.natural},
              onSelectionChanged: (s) => _setSpeed(s.single),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Natural pauses like a person thinking. Fast moves as soon as '
              'the engine has decided.',
              style: AppType.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
    child: Text(text, style: AppType.label),
  );
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final BoardTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget square(Color c) => Expanded(
      child: ColoredBox(color: c, child: const SizedBox.expand()),
    );
    return Semantics(
      selected: selected,
      label: '${theme.name} board',
      child: SectionCard(
        selected: selected,
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(AppRadius.sm),
              child: SizedBox(
                height: 48,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [square(theme.light), square(theme.dark)],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [square(theme.dark), square(theme.light)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    theme.name,
                    style: AppType.meta.copyWith(color: AppColors.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PieceCard extends StatelessWidget {
  const _PieceCard({
    required this.pieces,
    required this.selected,
    required this.onTap,
  });

  final PieceChoice pieces;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      label: '${pieces.label} pieces',
      child: SectionCard(
        selected: selected,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Image(
              image: pieces.assets[PieceKind.whiteKnight]!,
              width: 40,
              height: 40,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              pieces.label,
              style: AppType.meta.copyWith(color: AppColors.text),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
