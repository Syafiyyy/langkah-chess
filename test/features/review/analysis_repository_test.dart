import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/core/storage/app_database.dart';
import 'package:langkah/features/review/data/analysis_repository.dart';
import 'package:langkah/features/review/domain/position_eval.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _key = AnalysisKey(settings: 'mt250', engine: 'sf19-light');

void main() {
  setUpAll(sqfliteFfiInit);

  group('cache', () {
    late Database db;
    late AnalysisRepository repo;

    setUp(() async {
      db = await openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
      repo = SqfliteAnalysisRepository(db);
    });
    tearDown(() => db.close());

    test('saves and loads the evals for a game and key', () async {
      await repo.save('g1', _key, const [
        PositionEval(cp: 20, bestMove: 'e2e4'),
        PositionEval(mate: -2, pv: ['d8h4']),
      ]);
      final evals = (await repo.load('g1', _key))!;
      expect(evals.map((e) => e.cp), [20, null]);
      expect(evals.last.mate, -2);
      expect(evals.first.bestMove, 'e2e4');
    });

    test('another game, settings or engine version is a miss', () async {
      await repo.save('g1', _key, const [PositionEval(cp: 1)]);
      expect(await repo.load('g2', _key), isNull);
      expect(
        await repo.load(
          'g1',
          const AnalysisKey(settings: 'mt500', engine: 'sf19-light'),
        ),
        isNull,
      );
      expect(
        await repo.load(
          'g1',
          const AnalysisKey(settings: 'mt250', engine: 'sf20'),
        ),
        isNull,
      );
    });

    test('saving again replaces the cached analysis', () async {
      await repo.save('g1', _key, const [PositionEval(cp: 1)]);
      await repo.save('g1', _key, const [PositionEval(cp: 2)]);
      expect((await repo.load('g1', _key))!.single.cp, 2);
    });
  });

  test('a version 1 database is upgraded and keeps its games', () async {
    final dir = await Directory.systemTemp.createTemp('langkah_db');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v1.db';
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE games (id TEXT PRIMARY KEY)');
          await db.execute(
            'CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.insert('games', {'id': 'old-game'});
        },
      ),
    );
    await v1.close();

    final db = await openAppDatabase(databaseFactoryFfi, path);
    addTearDown(db.close);

    expect(await db.getVersion(), 2);
    expect(await db.query('games'), hasLength(1));
    final repo = SqfliteAnalysisRepository(db);
    await repo.save('old-game', _key, const [PositionEval(cp: 3)]);
    expect((await repo.load('old-game', _key))!.single.cp, 3);
  });
}
