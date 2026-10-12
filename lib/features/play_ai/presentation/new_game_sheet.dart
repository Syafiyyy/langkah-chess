import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../application/play_ai_providers.dart';
import '../domain/bot_level.dart';
import '../domain/game_setup.dart';
import '../domain/time_control.dart';
import 'custom_time_dialog.dart';

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

/// Level, colour and time control.
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

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: AppSpacing.lg),
            Text.rich(
              TextSpan(
                text: _setup.level.label,
                children: [
                  if (_setup.level.ratingHint case final hint?)
                    TextSpan(text: '  $hint', style: AppType.caption),
                ],
              ),
              style: AppType.label,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final level in BotLevel.all)
                  ChoiceChip(
                    label: Text('${level.number}'),
                    selected: level.number == _setup.level.number,
                    onSelected: (_) =>
                        setState(() => _setup = _setup.copyWith(level: level)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Your colour', style: AppType.label),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<ColorChoice>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ColorChoice.white, label: Text('White')),
                ButtonSegment(value: ColorChoice.random, label: Text('Random')),
                ButtonSegment(value: ColorChoice.black, label: Text('Black')),
              ],
              selected: {_setup.color},
              onSelectionChanged: (s) =>
                  setState(() => _setup = _setup.copyWith(color: s.single)),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Time control', style: AppType.label),
            const SizedBox(height: AppSpacing.sm),
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
                    _isCustom ? 'Custom ${_setup.timeControl.label}' : 'Custom',
                  ),
                  selected: _isCustom,
                  onSelected: (_) => _pickCustom(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('Bot speed', style: AppType.label),
            const SizedBox(height: AppSpacing.sm),
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
              onSelectionChanged: (s) =>
                  setState(() => _setup = _setup.copyWith(botSpeed: s.single)),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: () => Navigator.pop(context, _setup),
              child: const Text('Start game'),
            ),
          ],
        ),
      ),
    );
  }
}
