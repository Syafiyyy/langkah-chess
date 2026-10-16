import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/blur_field.dart';
import '../application/auth_providers.dart';
import '../domain/profile.dart';

/// Email + password (sign in or create an account) and Google.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = BlurField(_emailError);
  late final _password = BlurField(_passwordError);
  bool _creating = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  static String? _emailError(String v) {
    final t = v.trim();
    if (t.isEmpty) return 'Enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
      return 'Check the email address';
    }
    return null;
  }

  String? _passwordError(String v) {
    if (v.isEmpty) return 'Enter your password';
    if (_creating && v.length < 6) return 'Use at least 6 characters';
    return null;
  }

  @override
  void initState() {
    super.initState();
    for (final f in [_email, _password]) {
      f.attach(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on AuthCancelled {
      // Closed the picker: nothing to say.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final ok = [_email, _password].every((f) => f.validateNow());
    setState(() {});
    if (!ok) return;
    final auth = ref.read(authRepositoryProvider)!;
    final email = _email.text.trim();
    final password = _password.text;
    await _run(() async {
      if (!_creating) return auth.signInWithPassword(email, password);
      final result = await auth.signUp(email, password);
      if (result == SignUpResult.confirmEmail && mounted) {
        setState(
          () => _notice =
              'Check $email for a confirmation link, then sign in here.',
        );
        _creating = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authRepositoryProvider)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Play online')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              _creating ? 'Create your account' : 'Sign in to play online',
              style: AppType.title,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Games against the bot work without an account.',
              style: AppType.secondary,
            ),
            const SizedBox(height: AppSpacing.xl),
            _email.build(
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: AppSpacing.md),
            _password.build(
              label: 'Password',
              obscure: true,
              autofillHints: [
                _creating ? AutofillHints.newPassword : AutofillHints.password,
              ],
              onSubmitted: (_) => _submit(),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                error,
                style: AppType.secondary.copyWith(color: AppColors.danger),
              ),
            ],
            if (_notice case final notice?) ...[
              const SizedBox(height: AppSpacing.md),
              Text(notice, style: AppType.body),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _submit,
              child: Text(
                _busy
                    ? 'Please wait…'
                    : _creating
                    ? 'Create account'
                    : 'Sign in',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _creating = !_creating;
                      _error = null;
                      _password.clearError();
                    }),
              child: Text(
                _creating
                    ? 'I have an account: sign in'
                    : 'New here? Create an account',
              ),
            ),
            if (auth.googleAvailable) ...[
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(auth.signInWithGoogle),
                icon: const Icon(Icons.account_circle_rounded),
                label: const Text('Continue with Google'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
