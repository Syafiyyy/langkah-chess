import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../domain/profile.dart';

/// Sign-in state and account actions. Failures are [AuthFailure] (message
/// for the player) or [AuthCancelled].
abstract interface class AuthRepository {
  String? get currentUserId;

  /// The signed-in user id (null when signed out), current value first.
  Stream<String?> userIdChanges();

  Future<void> signInWithPassword(String email, String password);
  Future<SignUpResult> signUp(String email, String password);
  bool get googleAvailable;
  Future<void> signInWithGoogle();
  Future<void> signOut();

  /// Deletes the account on the server (`delete_account`), then signs out.
  Future<void> deleteAccount();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  static Future<void>? _googleInit;

  GoTrueClient get _auth => _client.auth;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Stream<String?> userIdChanges() async* {
    yield currentUserId;
    yield* _auth.onAuthStateChange.map((s) => s.session?.user.id).distinct();
  }

  @override
  Future<void> signInWithPassword(String email, String password) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  @override
  Future<SignUpResult> signUp(String email, String password) async {
    final res = await _guard(
      () => _auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: SupabaseConfig.authCallback,
      ),
    );
    return res.session == null ? SignUpResult.confirmEmail : SignUpResult.signedIn;
  }

  @override
  bool get googleAvailable => SupabaseConfig.googleWebClientId.isNotEmpty;

  @override
  Future<void> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    _googleInit ??= google.initialize(
      serverClientId: SupabaseConfig.googleWebClientId,
    );
    final String? idToken;
    try {
      await _googleInit;
      final account = await google.authenticate();
      idToken = account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthCancelled();
      }
      debugPrint('Google sign-in failed: $e');
      throw const AuthFailure(
        "Couldn't sign in with Google. Try again or use email.",
      );
    }
    if (idToken == null) {
      throw const AuthFailure("Google didn't return an account. Try again.");
    }
    await _guard(
      () => _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken!,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (googleAvailable && _googleInit != null) {
      unawaited(GoogleSignIn.instance.signOut().catchError((_) {}));
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('delete_account');
    } on FunctionException catch (e) {
      debugPrint('delete_account failed: $e');
      throw const AuthFailure(
        "Your account wasn't deleted. Check your connection and try again.",
      );
    } on Exception {
      throw const AuthFailure(_offline);
    }
    await signOut();
  }

  static const String _offline =
      'No connection. Check your internet and try again.';

  /// Runs [call], turning Supabase errors into messages for the player.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AuthException catch (e) {
      throw AuthFailure(authMessage(e.code, e.message));
    } on AuthFailure {
      rethrow;
    } on Exception catch (e) {
      debugPrint('Auth request failed: $e');
      throw const AuthFailure(_offline);
    }
  }
}

/// Player-facing text for a Supabase Auth error code.
@visibleForTesting
String authMessage(String? code, String fallback) => switch (code) {
  'invalid_credentials' => "That email and password don't match.",
  'email_not_confirmed' =>
    'Confirm your email first: open the link we sent you.',
  'user_already_exists' ||
  'email_exists' => 'That email already has an account. Sign in instead.',
  'weak_password' => 'Choose a longer password (at least 6 characters).',
  'over_email_send_rate_limit' ||
  'over_request_rate_limit' => 'Too many tries. Wait a minute and try again.',
  'validation_failed' => 'Check the email address.',
  _ => fallback,
};
