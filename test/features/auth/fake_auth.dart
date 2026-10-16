import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:skak/features/auth/application/auth_providers.dart';
import 'package:skak/features/auth/data/auth_repository.dart';
import 'package:skak/features/auth/data/profile_repository.dart';
import 'package:skak/features/auth/domain/profile.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({String? userId, this.googleAvailable = false})
    : _uid = userId;

  String? _uid;
  final _changes = StreamController<String?>.broadcast();
  final calls = <String>[];

  /// Thrown by the next sign-in / sign-up / delete, then cleared.
  Exception? nextError;
  SignUpResult signUpResult = SignUpResult.signedIn;

  @override
  final bool googleAvailable;

  void setUser(String? uid) {
    _uid = uid;
    _changes.add(uid);
  }

  void _maybeThrow() {
    final e = nextError;
    nextError = null;
    if (e != null) throw e;
  }

  @override
  String? get currentUserId => _uid;

  @override
  Stream<String?> userIdChanges() async* {
    yield _uid;
    yield* _changes.stream;
  }

  @override
  Future<void> signInWithPassword(String email, String password) async {
    calls.add('signIn $email');
    _maybeThrow();
    setUser('user-1');
  }

  @override
  Future<SignUpResult> signUp(String email, String password) async {
    calls.add('signUp $email');
    _maybeThrow();
    if (signUpResult == SignUpResult.signedIn) setUser('user-1');
    return signUpResult;
  }

  @override
  Future<void> signInWithGoogle() async {
    calls.add('google');
    _maybeThrow();
    setUser('user-1');
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    setUser(null);
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('delete');
    _maybeThrow();
    setUser(null);
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({
    this.username = 'u_0123456789ab',
    this.usernameSet = false,
  });

  String username;
  bool usernameSet;
  final taken = <String>{'magnus'};
  final calls = <String>[];

  /// The server rejects the next save with this message.
  String? nextSaveError;

  Profile get _profile => Profile(
    id: 'user-1',
    username: username,
    usernameSet: usernameSet,
    rating: 1212,
    gamesPlayed: 3,
  );

  @override
  Future<Profile> me() async => _profile;

  @override
  Future<bool> isAvailable(String name) async {
    calls.add('available $name');
    return !taken.contains(name);
  }

  @override
  Future<Profile> setUsername(String name) async {
    calls.add('set $name');
    final error = nextSaveError;
    nextSaveError = null;
    if (error != null) throw AuthFailure(error);
    username = name;
    usernameSet = true;
    return _profile;
  }
}

List<Override> authOverrides(
  FakeAuthRepository auth,
  FakeProfileRepository profiles,
) => [
  authRepositoryProvider.overrideWithValue(auth),
  profileRepositoryProvider.overrideWithValue(profiles),
];
