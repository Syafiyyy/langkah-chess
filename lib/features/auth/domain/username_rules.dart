/// Usernames follow the server's `set_profile` rule: `[a-z0-9_]{3,20}`, not
/// starting with `u_` (reserved for the temporary name every signup gets).
String normaliseUsername(String input) => input.trim().toLowerCase();

final RegExp _allowed = RegExp(r'^[a-z0-9_]*$');

/// Why [username] (already normalised) is not allowed, or null.
String? usernameError(String username) {
  if (username.isEmpty) return 'Enter a username';
  if (!_allowed.hasMatch(username)) {
    return 'Use only letters, numbers and underscores';
  }
  if (username.length < 3) return 'Use at least 3 characters';
  if (username.length > 20) return 'Use at most 20 characters';
  if (username.startsWith('u_')) return 'Names starting with "u_" are reserved';
  return null;
}
