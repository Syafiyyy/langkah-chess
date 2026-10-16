import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/blur_field.dart';
import '../application/online_providers.dart';
import '../data/online_api.dart';

/// Invite codes: 6 characters without 0/O/1/I (`random_invite_code`).
const int inviteCodeLength = 6;

/// Upper-cases and keeps only letters and digits, up to 6.
class InviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
    final cut = text.length > inviteCodeLength
        ? text.substring(0, inviteCodeLength)
        : text;
    return TextEditingValue(
      text: cut,
      selection: TextSelection.collapsed(offset: cut.length),
    );
  }
}

String? _codeError(String code) =>
    code.length == inviteCodeLength ? null : 'Codes have 6 characters';

/// Join a friend's invite by code. [initialCode] (from a `skak://join/…`
/// link) is joined right away.
class JoinCodeScreen extends ConsumerStatefulWidget {
  const JoinCodeScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinCodeScreen> createState() => _JoinCodeScreenState();
}

class _JoinCodeScreenState extends ConsumerState<JoinCodeScreen> {
  final _code = BlurField(_codeError);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code.attach(() => setState(() {}));
    final initial = widget.initialCode;
    if (initial != null) {
      _code.controller.text = InviteCodeFormatter()
          .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: initial))
          .text;
      WidgetsBinding.instance.addPostFrameCallback((_) => _join());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_busy) return;
    if (!_code.validateNow()) return setState(() {});
    setState(() => _busy = true);
    try {
      final game = await ref.read(onlineApiProvider)!.joinInvite(_code.text);
      if (mounted) context.go('/online/game/${game.id}');
    } on OnlineRejected catch (e) {
      _code.showError(switch (e.code) {
        'NOT_FOUND' => 'No game has that code. Check it and try again.',
        'OWN_GAME' => 'This is your own invite. Share it with a friend.',
        'NOT_AVAILABLE' => 'This game has already started or ended.',
        _ => "Couldn't join. Try again.",
      });
    } on OnlineUnavailable {
      _code.showError('No connection. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join with a code')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const Text('Enter the invite code', style: AppType.title),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Your friend sees it on their invite screen.',
              style: AppType.secondary,
            ),
            const SizedBox(height: AppSpacing.xl),
            _code.build(
              label: 'Invite code',
              helper: '6 letters and numbers',
              inputFormatters: [InviteCodeFormatter()],
              capitalization: TextCapitalization.characters,
              style: AppType.clock.copyWith(
                letterSpacing: 4,
                color: AppColors.text,
              ),
              onSubmitted: (_) => _join(),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _join,
              child: Text(_busy ? 'Joining…' : 'Join game'),
            ),
          ],
        ),
      ),
    );
  }
}
