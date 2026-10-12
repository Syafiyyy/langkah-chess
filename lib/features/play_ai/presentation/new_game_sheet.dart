import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../application/play_ai_providers.dart';
import '../domain/bot_level.dart';
import '../domain/game_setup.dart';
import '../domain/time_control.dart';
import 'custom_time_dialog.dart';

/// One line per level for the picker.
const Map<int, String> levelDescriptions = {
  1: 'Knows the rules. Hangs pieces often.',
  2: 'Grabs free pieces, still blunders.',
  3: 'Avoids most one-move blunders.',
  4: 'Solid moves, the odd mistake.',
  5: 'Stockfish limited to about 1400.',
  6: 'Stockfish limited to about 1800.',
  7: 'Stockfish limited to about 2200.',
  8: 'Stockfish at full strength.',
};

/// Opens the new-game sheet, prefilled with the last choice. Returns the
/// chosen setup, or null if dismissed.
Future<GameSetup?> showNewGameSheet(BuildContext context, WidgetRef ref) async {
  final last = await ref.read(playAiStoreProvider).lastSetup();
  if (!context.mounted) return null;
  return showModalBottomSheet<GameSetup>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => NewGameSheet(initial: last),
  );
}

/// Level, colour, time control and bot speed.
class NewGameSheet extends StatefulWidget {
  const NewGameSheet({super.key, required this.initial});

  final GameSetup initial;

  @override
  State<NewGameSheet> createState() => _NewGameSheetState();
}

class _NewGameSheetState extends State<NewGameSheet> {
  late GameSetup _setup = widget.initial;

  bool get _isCustom => !TimeControl.presets.contains(_setup.timeControl);

  Future<void> _pickCustom() async {
    final custom = await showCustomTimeDialog(context, _setup.timeControl);
    if (custom != null) {
      setState(() => _setup = _setup.copyWith(timeControl: custom));
    }
  }

  Widget _section(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppType.label),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final level = _setup.level;
    final hint = level.ratingHint;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Play vs Bot', style: AppType.title),
            _section(
              'Bot level',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LevelGrid(
                    selected: level,
                    onSelect: (l) =>
                        setState(() => _setup = _setup.copyWith(level: l)),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${level.label}${hint == null ? '' : ' · $hint'}: '
                    '${levelDescriptions[level.number]}',
                    style: AppType.secondary,
                  ),
                ],
              ),
            ),
            _section(
              'Your colour',
              SegmentedButton<ColorChoice>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ColorChoice.white, label: Text('White')),
                  ButtonSegment(
                    value: ColorChoice.random,
                    label: Text('Random'),
                  ),
                  ButtonSegment(value: ColorChoice.black, label: Text('Black')),
                ],
                selected: {_setup.color},
                onSelectionChanged: (s) =>
                    setState(() => _setup = _setup.copyWith(color: s.single)),
              ),
            ),
            _section(
              'Time control',
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final tc in TimeControl.presets)
                    ChoiceChip(
                      label: Text(tc.label),
                      selected: tc == _setup.timeControl,
                      onSelected: (_) => setState(
                        () => _setup = _setup.copyWith(timeControl: tc),
                      ),
                    ),
                  ChoiceChip(
                    label: Text(
                      _isCustom
                          ? 'Custom ${_setup.timeControl.label}'
                          : 'Custom',
                    ),
                    selected: _isCustom,
                    onSelected: (_) => _pickCustom(),
                  ),
                ],
              ),
            ),
            _section(
              'Bot speed',
              SegmentedButton<BotSpeed>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: BotSpeed.natural,
                    label: Text('Natural'),
                    tooltip: 'Pauses to think like a person',
                  ),
                  ButtonSegment(
                    value: BotSpeed.fast,
                    label: Text('Fast'),
                    tooltip: 'Moves as soon as it has decided',
                  ),
                ],
                selected: {_setup.botSpeed},
                onSelectionChanged: (s) => setState(
                  () => _setup = _setup.copyWith(botSpeed: s.single),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: () => Navigator.pop(context, _setup),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Start game'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eight level tiles in two columns: number + name; selected = gold border.
class _LevelGrid extends StatelessWidget {
  const _LevelGrid({required this.selected, required this.onSelect});

  final BotLevel selected;
  final ValueChanged<BotLevel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < BotLevel.all.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(child: _tile(BotLevel.all[i])),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _tile(BotLevel.all[i + 1])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tile(BotLevel level) {
    final isSelected = level.number == selected.number;
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? AppColors.surfaceRaised : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(AppRadius.md),
          side: BorderSide(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelect(level),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.md),
                Text(
                  '${level.number}',
                  style: AppType.move.copyWith(
                    color: isSelected ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    level.name,
                    style: AppType.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
