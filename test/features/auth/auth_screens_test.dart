import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skak/app/theme/app_theme.dart';
import 'package:skak/features/auth/application/auth_providers.dart';
import 'package:skak/features/auth/domain/profile.dart';
import 'package:skak/features/auth/presentation/online_gate.dart';
import 'package:skak/features/auth/presentation/profile_screen.dart';

import 'fake_auth.dart';

const _child = Text('ONLINE HOME');

Future<void> _pump(
  WidgetTester tester,
  List<Override> overrides, {
  Widget page = const OnlineGate(child: _child),
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => page)],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  group('gate', () {
    testWidgets('explains when online play is not configured', (tester) async {
      await _pump(tester, [authRepositoryProvider.overrideWithValue(null)]);
      expect(find.textContaining("isn't set up"), findsOneWidget);
    });

    testWidgets('signed out → sign in; no username → choose one; then the '
        'online screen', (tester) async {
      final auth = FakeAuthRepository();
      final profiles = FakeProfileRepository();
      await _pump(tester, authOverrides(auth, profiles));
      expect(find.text('Sign in to play online'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextField).at(1), 'secret1');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['signIn a@b.co']);
      expect(find.text('What should opponents call you?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Adaam_7');
      await tester.tap(find.text('Save username'));
      await tester.pumpAndSettle();
      expect(profiles.calls.last, 'set adaam_7');
      expect(find.text('ONLINE HOME'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('sign in', () {
    testWidgets('checks the email when the field is left, not while typing', (
      tester,
    ) async {
      await _pump(
        tester,
        authOverrides(FakeAuthRepository(), FakeProfileRepository()),
      );
      await tester.enterText(find.byType(TextField).at(0), 'not-an-email');
      await tester.pump();
      expect(find.text('Check the email address'), findsNothing);
      await _blur(tester);
      expect(find.text('Check the email address'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.pump();
      expect(find.text('Check the email address'), findsNothing);
    });

    testWidgets('shows the server message on a failed sign in', (tester) async {
      final auth = FakeAuthRepository()
        ..nextError = const AuthFailure("That email and password don't match.");
      await _pump(tester, authOverrides(auth, FakeProfileRepository()));
      await tester.enterText(find.byType(TextField).at(0), 'a@b.co');
      await tester.enterText(find.byType(TextField).at(1), 'wrong');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text("That email and password don't match."), findsOneWidget);
    });

    testWidgets('sign up that needs email confirmation says so', (
      tester,
    ) async {
      final auth = FakeAuthRepository()
        ..signUpResult = SignUpResult.confirmEmail;
      await _pump(tester, authOverrides(auth, FakeProfileRepository()));
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'new@b.co');
      await tester.enterText(find.byType(TextField).at(1), '12345');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Use at least 6 characters'), findsOneWidget);
      expect(auth.calls, isEmpty);

      await tester.enterText(find.byType(TextField).at(1), '123456');
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['signUp new@b.co']);
      expect(find.textContaining('confirmation link'), findsOneWidget);
    });

    testWidgets('Google button only when configured', (tester) async {
      await _pump(
        tester,
        authOverrides(FakeAuthRepository(), FakeProfileRepository()),
      );
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('Google sign-in', (tester) async {
      final auth = FakeAuthRepository(googleAvailable: true);
      await _pump(
        tester,
        authOverrides(auth, FakeProfileRepository(usernameSet: true)),
      );
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['google']);
      expect(find.text('ONLINE HOME'), findsOneWidget);
    });
  });

  group('username', () {
    Future<FakeProfileRepository> pumpUsername(WidgetTester tester) async {
      final profiles = FakeProfileRepository();
      await _pump(
        tester,
        authOverrides(FakeAuthRepository(userId: 'user-1'), profiles),
      );
      return profiles;
    }

    testWidgets('rules are checked on blur', (tester) async {
      await pumpUsername(tester);
      await tester.enterText(find.byType(TextField), 'u_me');
      await _blur(tester);
      expect(
        find.text('Names starting with "u_" are reserved'),
        findsOneWidget,
      );
    });

    testWidgets('a taken name is reported on blur', (tester) async {
      final profiles = await pumpUsername(tester);
      await tester.enterText(find.byType(TextField), 'Magnus');
      await _blur(tester);
      expect(profiles.calls, ['available magnus']);
      expect(find.text('That name is taken. Try another.'), findsOneWidget);
    });

    testWidgets('a free name says so', (tester) async {
      await pumpUsername(tester);
      await tester.enterText(find.byType(TextField), 'adaam');
      await _blur(tester);
      expect(find.text('adaam is available'), findsOneWidget);
    });

    testWidgets('the server can still reject on save', (tester) async {
      final profiles = await pumpUsername(tester)
        ..nextSaveError = 'That name is taken. Try another.';
      await tester.enterText(find.byType(TextField), 'adaam');
      await tester.tap(find.text('Save username'));
      await tester.pumpAndSettle();
      expect(find.text('That name is taken. Try another.'), findsOneWidget);
      expect(profiles.usernameSet, isFalse);
    });
  });

  group('profile', () {
    testWidgets('sign out goes home (the gate swaps the page out first)', (
      tester,
    ) async {
      final auth = FakeAuthRepository(userId: 'user-1');
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('HOME')),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const OnlineGate(child: ProfileScreen()),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: authOverrides(
            auth,
            FakeProfileRepository(username: 'adaam', usernameSet: true),
          ),
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(auth.calls, ['signOut']);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('shows rating and games; delete needs the typed name', (
      tester,
    ) async {
      final auth = FakeAuthRepository(userId: 'user-1');
      final profiles = FakeProfileRepository(
        username: 'adaam',
        usernameSet: true,
      );
      await _pump(
        tester,
        authOverrides(auth, profiles),
        page: const OnlineGate(child: ProfileScreen()),
      );
      expect(find.text('1212'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(TextButton, 'Delete account').last;
      expect(tester.widget<TextButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'adaam');
      await tester.pump();
      expect(tester.widget<TextButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(auth.calls, ['delete']);
    });

    testWidgets('a failed delete keeps the account and says why', (
      tester,
    ) async {
      final auth = FakeAuthRepository(userId: 'user-1')
        ..nextError = const AuthFailure("Your account wasn't deleted.");
      await _pump(
        tester,
        authOverrides(
          auth,
          FakeProfileRepository(username: 'adaam', usernameSet: true),
        ),
        page: const OnlineGate(child: ProfileScreen()),
      );
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'adaam');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Delete account').last);
      await tester.pumpAndSettle();
      expect(find.text("Your account wasn't deleted."), findsOneWidget);
    });
  });
}
