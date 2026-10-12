import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/core/engine/engine_provider.dart';
import 'package:langkah/core/engine/engine_service.dart';
import 'package:langkah/features/play_ai/presentation/board_smoke_screen.dart';

import '../../core/engine/fake_uci_engine.dart';

void main() {
  testWidgets('board screen builds with a board and engine button', (
    tester,
  ) async {
    final service = EngineService(() async => FakeUciEngine());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [engineServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: BoardSmokeScreen()),
      ),
    );

    expect(find.byType(Chessboard), findsOneWidget);
    expect(find.text('Engine move'), findsOneWidget);
    expect(find.text('New game'), findsOneWidget);
  });
}
