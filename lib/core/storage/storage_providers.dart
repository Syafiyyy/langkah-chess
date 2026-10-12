import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'kv_store.dart';

/// The app database. Opened in `main()` and provided by an override.
final appDatabaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('Override appDatabaseProvider in main()'),
);

/// Small settings and saved state (key-value table).
final kvStoreProvider = Provider<KvStore>(
  (ref) => KvStore(ref.watch(appDatabaseProvider)),
);
