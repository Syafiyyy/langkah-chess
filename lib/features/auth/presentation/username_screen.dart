import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/blur_field.dart';
import '../application/auth_providers.dart';
import '../domain/profile.dart';
import '../domain/username_rules.dart';

/// First login: pick the name opponents will see. Checked when the field is
/// left (rules, then availability); the server has the last word on save.
class UsernameScreen extends ConsumerStatefulWidget {
  const UsernameScreen({super.key});

  @override
  ConsumerState<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends ConsumerState<UsernameScreen> {
  final _name = BlurField((v) => usernameError(normaliseUsername(v)));
  bool _busy = false;

  /// The name last confirmed free, shown as a hint.
  String? _available;

  @override
  void initState() {
    super.initState();
    _name.attach(() => setState(() {}));
    _name.focus.addListener(() {
      if (!_name.focus.hasFocus) _checkAvailable();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _value => normaliseUsername(_name.text);

  Future<void> _checkAvailable() async {
    final name = _value;
    if (usernameError(name) != null) return;
    try {
      final free = await ref.read(profileRepositoryProvider)!.isAvailable(name);
      if (!mounted || name != _value) return;
      if (free) {
        setState(() => _available = name);
      } else {
        _name.showError('That name is taken. Try another.');
      }
    } on Exception {
      // Offline: the save will tell.
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_name.validateNow()) return setState(() {});
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider)!.setUsername(_value);
      ref.invalidate(myProfileProvider);
    } on AuthFailure catch (e) {
      _name.showError(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _available != null && _available == _value;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a username')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text('What should opponents call you?', style: AppType.title),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'You can set it once. 3 to 20 letters, numbers or underscores.',
              style: AppType.secondary,
            ),
            const SizedBox(height: AppSpacing.xl),
            _name.build(
              label: 'Username',
              helper: available ? '$_value is available' : null,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              autofillHints: const [AutofillHints.username],
              onSubmitted: (_) => _save(),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _save,
              child: Text(_busy ? 'Saving…' : 'Save username'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => ref.read(authRepositoryProvider)!.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
