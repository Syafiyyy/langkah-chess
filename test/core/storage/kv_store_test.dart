import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/core/storage/app_database.dart';
import 'package:langkah/core/storage/kv_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late KvStore kv;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await openAppDatabase(databaseFactoryFfi, inMemoryDatabasePath);
    kv = KvStore(db);
  });

  tearDown(() => db.close());

  test('get returns null for a missing key', () async {
    expect(await kv.get('x'), isNull);
  });

  test('set overwrites, remove deletes', () async {
    await kv.set('x', 'one');
    await kv.set('x', 'two');
    expect(await kv.get('x'), 'two');
    await kv.remove('x');
    expect(await kv.get('x'), isNull);
  });
}
