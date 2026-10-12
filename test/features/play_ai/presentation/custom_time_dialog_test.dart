import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/app/theme/app_theme.dart';
import 'package:langkah/features/play_ai/domain/time_control.dart';
import 'package:langkah/features/play_ai/presentation/custom_time_dialog.dart';

Future<TimeControl? Function()> _open(WidgetTester tester) async {
  TimeControl? result;
  var closed = false;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showCustomTimeDialog(
              context,
              const TimeControl.minutes(10, 0),
            );
            closed = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => closed ? result : null;
}

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  testWidgets('no error while typing; error after leaving the field', (
    tester,
  ) async {
    await _open(tester);

    await tester.enterText(_field('Minutes per side'), '0');
    await tester.pump();
    expect(find.text('Enter 1 to 180 minutes'), findsNothing);

    await tester.tap(_field('Increment (seconds)')); // leave the field
    await tester.pump();
    expect(find.text('Enter 1 to 180 minutes'), findsOneWidget);

    await tester.enterText(_field('Minutes per side'), '05');
    await tester.pump();
    expect(find.text('Enter 1 to 180 minutes'), findsNothing);
  });

  testWidgets('the confirm button is always enabled and shows errors', (
    tester,
  ) async {
    final result = await _open(tester);
    await tester.enterText(_field('Increment (seconds)'), '99');
    final button = find.widgetWithText(TextButton, 'Use this time');
    expect(tester.widget<TextButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Enter 0 to 60 seconds'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget); // still open

    await tester.enterText(_field('Increment (seconds)'), '5');
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(result(), const TimeControl.minutes(10, 5));
  });
}
