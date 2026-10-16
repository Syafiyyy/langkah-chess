import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'app/app.dart';
import 'core/storage/app_database.dart';
import 'core/supabase/server_clock.dart';
import 'core/supabase/supabase_providers.dart';
import 'features/play_ai/application/play_ai_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase(
    databaseFactory,
    '${await getDatabasesPath()}/skak.db',
  );
  final serverClock = ServerClock();
  final supabase = await initSupabase(serverClock);
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        serverClockProvider.overrideWithValue(serverClock),
        supabaseClientProvider.overrideWithValue(supabase),
      ],
      child: const SkakApp(),
    ),
  );
}
