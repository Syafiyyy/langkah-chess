/// Online config from `--dart-define-from-file=env/dev.json`.
///
/// Only the project URL and the publishable key reach the app; secret keys
/// never do. Without them the app runs offline only.
abstract final class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Web OAuth client id (Google Cloud), used as Google Sign-In's server
  /// client id so the id token is accepted by Supabase. Empty = no Google
  /// button.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// Where Supabase sends users back after confirming their email.
  static const String authCallback = 'skak://login-callback';
}
