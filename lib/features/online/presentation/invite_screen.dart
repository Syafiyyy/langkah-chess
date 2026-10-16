import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/thinking_dots.dart';
import '../../play_ai/domain/time_control.dart';
import '../application/online_providers.dart';
import '../data/online_api.dart';
import '../domain/online_result.dart';
import '../domain/server_game.dart';

/// Creates (or reopens) an invite and waits for the friend: the code, Share,
/// the `skak://join/CODE` link, and Cancel. Opens the game once it starts.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.timeControl});

  final TimeControl timeControl;

  /// Fallback check in case a Realtime hint is missed.
  static const Duration pollEvery = Duration(seconds: 15);

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  late final OnlineApi _api = ref.read(onlineApiProvider)!;
  late final AppLifecycleListener _lifecycle;
  ServerGame? _game;
  Subscription? _sub;
  Timer? _poll;
  String? _error;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _create();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _sub?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _error = null);
    try {
      final game = await _api.createInvite(widget.timeControl);
      if (!mounted) return;
      _sub?.cancel();
      _sub = _api.watchGame(
        game.id,
        onHint: _refresh,
        onConnected: (up) {
          if (up) _refresh();
        },
      );
      _poll?.cancel();
      _poll = Timer.periodic(InviteScreen.pollEvery, (_) => _refresh());
      _show(game);
    } on OnlineFailure {
      if (mounted) {
        setState(
          () => _error =
              "The invite wasn't created. Check your connection and try again.",
        );
      }
    }
  }

  Future<void> _refresh() async {
    final id = _game?.id;
    if (id == null) return;
    try {
      final game = await _api.fetchGame(id);
      if (mounted) _show(game);
    } on OnlineFailure {
      // Next hint or poll tries again.
    }
  }

  void _show(ServerGame game) {
    if (game.status == GameStatus.active) {
      context.go('/online/game/${game.id}');
      return;
    }
    if (game.isOver) _poll?.cancel();
    setState(() => _game = game);
  }

  Future<void> _cancel() async {
    final game = _game;
    if (game == null) return context.pop();
    setState(() => _cancelling = true);
    try {
      final after = await _api.act(GameAction.abort, game.id);
      if (!mounted) return;
      if (after.status == GameStatus.active) return _show(after);
      context.pop();
    } on OnlineFailure {
      if (mounted) {
        setState(() {
          _cancelling = false;
          _error = "The invite wasn't cancelled. Try again.";
        });
      }
    }
  }

  void _share(String code) {
    SharePlus.instance.share(
      ShareParams(
        text:
            'Play chess with me on Skak (${widget.timeControl.label}). '
            'Join with code $code or open skak://join/$code',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      appBar: AppBar(title: const Text('Invite a friend')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (game == null && _error == null)
              const Center(child: CircularProgressIndicator())
            else if (game != null && game.isOver)
              _Ended(game: game, onNew: _create)
            else if (game != null)
              ..._waiting(game),
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                error,
                style: AppType.secondary.copyWith(color: AppColors.danger),
              ),
              if (game == null) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: _create,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _waiting(ServerGame game) {
    final code = game.inviteCode ?? '';
    return [
      const Text(
        'Share this code with your friend',
        style: AppType.secondary,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.md),
      SectionCard(
        child: Column(
          children: [
            Semantics(
              label: 'Invite code ${code.split('').join(' ')}',
              child: ExcludeSemantics(
                child: Text(
                  code,
                  key: const ValueKey('invite-code'),
                  style: AppType.clock.copyWith(
                    fontSize: AppType.s32,
                    letterSpacing: 6,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SelectableText('skak://join/$code', style: AppType.secondary),
            const SizedBox(height: AppSpacing.xs),
            Text('${widget.timeControl.label} · rated', style: AppType.meta),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      FilledButton.icon(
        onPressed: () => _share(code),
        icon: const Icon(Icons.share_rounded),
        label: const Text('Share invite'),
      ),
      const SizedBox(height: AppSpacing.xl),
      const Center(
        child: ThinkingDots(
          label: 'Waiting for your friend',
          style: AppType.body,
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      OutlinedButton(
        onPressed: _cancelling ? null : _cancel,
        child: Text(_cancelling ? 'Cancelling…' : 'Cancel invite'),
      ),
    ];
  }
}

/// The invite ended without a game (cancelled or expired after 24 h).
class _Ended extends StatelessWidget {
  const _Ended({required this.game, required this.onNew});

  final ServerGame game;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.timer_off_rounded,
          size: 32,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          game.termination == 'expired'
              ? 'This invite expired'
              : 'This invite was cancelled',
          style: AppType.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          abortReason(game),
          style: AppType.secondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: onNew, child: const Text('Create new invite')),
      ],
    );
  }
}
