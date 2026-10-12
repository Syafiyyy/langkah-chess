import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skak/core/engine/engine_provider.dart';
import 'package:skak/core/engine/engine_service.dart';
import 'package:skak/core/storage/app_database.dart';
import 'package:skak/features/history/domain/finished_game.dart';
import 'package:skak/features/play_ai/application/play_ai_providers.dart';
import 'package:skak/features/play_ai/domain/bot_level.dart';
import 'package:skak/features/play_ai/domain/game_controller.dart';
import 'package:skak/features/play_ai/domain/game_state.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';
import 'package:skak/features/review/application/review_notifier.dart';
import 'package:skak/features/review/domain/position_eval.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/engine/fake_uci_engine.dart';
import '../play_ai/application/bot_engine_fake.dart';
import '../play_ai/domain/fake_time_source.dart';

/// A finished game: 1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6?? 4. Qxf7# (player white).
FinishedGame _scholarsMate() {
  final c = GameController(
    state: GameState.start(
      id: 'scholar',
      level: BotLevel.of(1),
      timeControl: TimeControl.unlimited,
      playerSide: Side.black, // the player lost with black
      startedAt: DateTime.utc(2026, 10, 12, 9),
    ),
    time: FakeTimeSource(),
    wallClock: () => DateTime.utc(2026, 10, 12, 9, 3),
  );
  for (final uci in ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7']) {
    c.play(Move.parse(uci)!);
  }
  return FinishedGame.fromState(c.state);
}

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
  });
  tearDown(() => db.close());

  Future<ProviderContainer> container(FakeUciEngine engine) async {
    final c = ProviderContainer.test(
      overrides: [
        engineServiceProvider.overrideWithValue(
          EngineService(() async => engine),
        ),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    await c.read(historyRepositoryProvider).save(_scholarsMate());
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('analyses every position progressively and caches it', () async {
    final engine = botEngine();
    final c = await container(engine);
    final seen = <int>[];
    c.listen(
      reviewProvider('scholar'),
      (_, next) => seen.add(next.evals.length),
      fireImmediately: true,
    );
    await settle();

    final state = c.read(reviewProvider('scholar'));
    expect(state.analysing, isFalse);
    expect(state.evals, hasLength(8)); // 7 moves + start
    expect(state.reviews, hasLength(7));
    expect(seen.toSet().length, greaterThan(3)); // filled step by step
    final cached = await c
        .read(analysisRepositoryProvider)
        .load('scholar', reviewAnalysisKey);
    expect(cached, hasLength(8));
  });

  test('the checkmate position is scored without the engine', () async {
    final engine = botEngine();
    final c = await container(engine);
    c.listen(reviewProvider('scholar'), (_, _) {});
    await settle();

    expect(engine.commands.where((x) => x.startsWith('go')), hasLength(7));
    final last = c.read(reviewProvider('scholar')).evals.last;
    expect(last.result, Outcome.whiteWins);
  });

  test('analysis runs at full strength with MultiPV 1', () async {
    final engine = botEngine();
    final c = await container(engine);
    c.listen(reviewProvider('scholar'), (_, _) {});
    await settle();

    final firstGo = engine.commands.indexWhere((x) => x.startsWith('go'));
    final strength = engine.commands.indexOf(
      'setoption name UCI_LimitStrength value false',
    );
    expect(strength, isNonNegative);
    expect(strength, lessThan(firstGo));
    expect(
      engine.commands[firstGo],
      'go movetime ${reviewMoveTime.inMilliseconds}',
    );
  });

  test('a cached analysis opens instantly without the engine', () async {
    final engine = botEngine();
    final c = await container(engine);
    await c.read(analysisRepositoryProvider).save(
      'scholar',
      reviewAnalysisKey,
      [for (var i = 0; i < 8; i++) PositionEval(cp: i * 10)],
    );
    c.listen(reviewProvider('scholar'), (_, _) {});
    await settle();

    final state = c.read(reviewProvider('scholar'));
    expect(state.evals.map((e) => e.cp).take(3), [0, 10, 20]);
    expect(state.analysing, isFalse);
    expect(engine.commands.where((x) => x.startsWith('go')), isEmpty);
  });

  test('leaving the screen stops the engine', () async {
    final engine = botEngine(holdUntilStop: true);
    final c = await container(engine);
    final sub = c.listen(reviewProvider('scholar'), (_, _) {});
    await settle();
    expect(c.read(reviewProvider('scholar')).analysing, isTrue);

    sub.close();
    await settle();

    expect(engine.commands, contains('stop'));
    expect(engine.commands.where((x) => x.startsWith('go')), hasLength(1));
    expect(
      await c
          .read(analysisRepositoryProvider)
          .load('scholar', reviewAnalysisKey),
      isNull,
    );
  });

  test('an unknown game is reported as not found', () async {
    final c = await container(botEngine());
    c.listen(reviewProvider('nope'), (_, _) {});
    await settle();
    expect(c.read(reviewProvider('nope')).notFound, isTrue);
  });

  test('navigation: plies, and jumping between the player\'s errors', () async {
    final c = await container(botEngine());
    await c.read(analysisRepositoryProvider).save(
      'scholar',
      reviewAnalysisKey,
      [
        const PositionEval(cp: 20),
        const PositionEval(cp: 30),
        const PositionEval(cp: 30),
        const PositionEval(cp: 40), // after Qh5
        const PositionEval(cp: 40), // after Nc6: fine
        const PositionEval(cp: 50), // after Bc4
        const PositionEval(mate: 1), // after Nf6??: black blunders
        PositionEval.gameOver(Outcome.whiteWins),
      ],
    );
    c.listen(reviewProvider('scholar'), (_, _) {});
    await settle();
    final notifier = c.read(reviewProvider('scholar').notifier);

    expect(c.read(reviewProvider('scholar')).ply, 0);
    notifier.nextError();
    expect(c.read(reviewProvider('scholar')).ply, 6); // 3... Nf6??
    notifier.goTo(99);
    expect(c.read(reviewProvider('scholar')).ply, 7);
    notifier.previousError();
    expect(c.read(reviewProvider('scholar')).ply, 6);
    notifier
      ..goTo(0)
      ..previousError();
    expect(c.read(reviewProvider('scholar')).ply, 0);
  });
}
