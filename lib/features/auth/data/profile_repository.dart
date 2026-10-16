import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

/// The signed-in player's profile. Reads the `profiles` table; writes only
/// through the `set_profile` RPC.
abstract interface class ProfileRepository {
  Future<Profile> me();

  /// True when nobody has [username] (already normalised).
  Future<bool> isAvailable(String username);

  /// Sets the username once. Throws [AuthFailure] (e.g. taken).
  Future<Profile> setUsername(String username);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile> me() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthFailure('Sign in first.');
    final row = await _client.from('profiles').select().eq('id', uid).single();
    return Profile.fromRow(row);
  }

  @override
  Future<bool> isAvailable(String username) async {
    final rows = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .limit(1);
    return rows.isEmpty;
  }

  @override
  Future<Profile> setUsername(String username) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'set_profile',
        params: {'p_username': username, 'p_avatar': null},
      );
      return Profile.fromRow(row);
    } on PostgrestException catch (e) {
      throw AuthFailure(switch (e.message) {
        'USERNAME_TAKEN' => 'That name is taken. Try another.',
        'USERNAME_LOCKED' => 'Your username is already set.',
        'BAD_USERNAME' => 'Use 3 to 20 letters, numbers or underscores.',
        _ => "Your username wasn't saved. Try again.",
      });
    } on Exception catch (e) {
      debugPrint('set_profile failed: $e');
      throw const AuthFailure(
        'No connection. Check your internet and try again.',
      );
    }
  }
}
