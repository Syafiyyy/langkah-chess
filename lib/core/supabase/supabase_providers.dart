import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'server_clock.dart';
import 'supabase_config.dart';

/// The Supabase client, or null when online play is unavailable (not
/// configured, or initialisation failed). Overridden in `main()`.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

/// Server time estimate shared by every online feature. Overridden in
/// `main()` with the instance the HTTP client feeds.
final serverClockProvider = Provider<ServerClock>((ref) => ServerClock());

/// Starts Supabase if configured. Never throws: offline play must work with
/// no config and no network.
Future<SupabaseClient?> initSupabase(ServerClock clock) async {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    final supabase = await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      httpClient: DateHeaderClient(clock),
      authOptions: FlutterAuthClientOptions(
        // Only email-confirmation links are auth callbacks; skak://join/…
        // links are invites.
        detectSessionInUriPredicate: (uri) =>
            uri.toString().startsWith(SupabaseConfig.authCallback),
      ),
    );
    return supabase.client;
  } on Object catch (e) {
    debugPrint('Supabase init failed, online play off: $e');
    return null;
  }
}
