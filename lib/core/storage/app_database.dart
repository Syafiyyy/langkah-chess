import 'package:sqflite/sqflite.dart';

/// Opens (and creates on first run) the app's single SQLite database.
///
/// Tables:
/// - `games`: finished offline games (see SqfliteHistoryRepository).
/// - `kv`: small key-value settings (last game setup, autosaved game).
Future<Database> openAppDatabase(DatabaseFactory factory, String path) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE games (
            id TEXT PRIMARY KEY,
            ended_at INTEGER NOT NULL,
            player_side TEXT NOT NULL,
            bot_level INTEGER NOT NULL,
            time_control TEXT NOT NULL,
            outcome TEXT NOT NULL,
            player_result TEXT NOT NULL,
            termination TEXT NOT NULL,
            pgn TEXT NOT NULL,
            final_fen TEXT NOT NULL,
            plies INTEGER NOT NULL,
            duration_ms INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX games_ended_at ON games (ended_at DESC)',
        );
        await db.execute(
          'CREATE TABLE kv (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    ),
  );
}
