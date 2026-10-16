import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../application/auth_providers.dart';
import 'sign_in_screen.dart';
import 'username_screen.dart';

/// Shows [child] only to a signed-in player with a username; otherwise the
/// sign-in or username screen in its place.
class OnlineGate extends ConsumerWidget {
  const OnlineGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authRepositoryProvider) == null) {
      return const _Message(
        text: "Online play isn't set up in this build. Bot games work as usual.",
      );
    }
    final uid = ref.watch(userIdProvider);
    if (uid case AsyncData(value: null)) return const SignInScreen();
    if (uid is! AsyncData) return const _Loading();

    return switch (ref.watch(myProfileProvider)) {
      AsyncData(value: final p?) when !p.usernameSet => const UsernameScreen(),
      AsyncData(value: _?) => child,
      AsyncError() => _Message(
        text: "Your profile didn't load. Check your connection.",
        onRetry: () => ref.invalidate(myProfileProvider),
      ),
      _ => const _Loading(),
    };
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: const Center(child: CircularProgressIndicator()),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return Scaffold(
      appBar: AppBar(title: const Text('Play online')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: AppType.body, textAlign: TextAlign.center),
              if (retry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton(onPressed: retry, child: const Text('Try again')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
