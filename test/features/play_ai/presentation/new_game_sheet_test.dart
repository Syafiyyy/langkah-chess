import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/app/theme/app_theme.dart';
import 'package:langkah/features/play_ai/domain/game_setup.dart';
import 'package:langkah/features/play_ai/presentation/new_game_sheet.dart';

void main() {
  testWidgets('shows level names and returns the chosen bot speed', (
    tester,
  ) async {
    GameSetup? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<GameSetup>(
                context: context,
                isScrollControlled: true,
                builder: (_) => NewGameSheet(initial: GameSetup.defaults),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Level 2 · Beginner'), findsOneWidget);
    await tester.tap(find.text('Newcomer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Level 1 · Newcomer'), findsOneWidget);
    expect(find.textContaining('Hangs pieces often'), findsOneWidget);

    await tester.ensureVisible(find.text('Fast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fast'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start game'));
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();

    expect(result!.botSpeed, BotSpeed.fast);
    expect(result!.level.number, 1);
  });
}
