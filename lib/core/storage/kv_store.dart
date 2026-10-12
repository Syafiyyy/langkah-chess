import 'package:sqflite/sqflite.dart';

/// Tiny string key-value store on the app database's `kv` table.
class KvStore {
  KvStore(this._db);

  final Database _db;

  Future<String?> get(String key) async {
    final rows = await _db.query(
      'kv',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  Future<void> set(String key, String value) => _db.insert('kv', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> remove(String key) =>
      _db.delete('kv', where: 'key = ?', whereArgs: [key]);
}
