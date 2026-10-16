import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

/// Null when online play is unavailable (no config or init failed).
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAuthRepository(client);
});

final profileRepositoryProvider = Provider<ProfileRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseProfileRepository(client);
});

/// The signed-in user id, or null.
final userIdProvider = StreamProvider<String?>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  if (auth == null) return Stream.value(null);
  return auth.userIdChanges();
});

/// The signed-in player's profile; null when signed out. Invalidate after a
/// change (username, finished game).
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final uid = await ref.watch(userIdProvider.future);
  if (uid == null) return null;
  return ref.watch(profileRepositoryProvider)!.me();
});
