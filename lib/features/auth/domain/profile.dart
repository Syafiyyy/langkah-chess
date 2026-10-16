/// A player's public profile (`profiles` row).
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.usernameSet,
    required this.rating,
    required this.gamesPlayed,
  });

  factory Profile.fromRow(Map<String, dynamic> row) => Profile(
    id: row['id'] as String,
    username: row['username'] as String,
    usernameSet: row['username_set'] as bool,
    rating: row['rating'] as int,
    gamesPlayed: row['games_played'] as int,
  );

  final String id;
  final String username;

  /// False until the player picks a name (they have a temporary `u_…` one).
  final bool usernameSet;
  final int rating;
  final int gamesPlayed;
}

/// A sign-in or profile failure with a message fit to show the player.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => 'AuthFailure($message)';
}

/// The player closed the Google account picker.
class AuthCancelled implements Exception {
  const AuthCancelled();
}

/// Result of creating an account.
enum SignUpResult { signedIn, confirmEmail }
