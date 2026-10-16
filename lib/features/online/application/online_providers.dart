import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../data/online_api.dart';
import '../data/supabase_online_api.dart';
import '../domain/server_game.dart';

/// The online API for the signed-in player; null when signed out or when
/// online play is unavailable. Screens using it sit behind `OnlineGate`.
final onlineApiProvider = Provider<OnlineApi?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final uid = ref.watch(userIdProvider).value;
  if (client == null || uid == null) return null;
  return SupabaseOnlineApi(client, ref.watch(serverClockProvider));
});

/// The player's running online game (for "Resume"), refetched on watch.
final activeOnlineGameProvider = FutureProvider.autoDispose<ServerGame?>((
  ref,
) async {
  final api = ref.watch(onlineApiProvider);
  if (api == null) return null;
  try {
    return await api.activeGame();
  } on OnlineFailure {
    return null;
  }
});
