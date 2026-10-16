import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/thinking_dots.dart';
import '../../play_ai/domain/time_control.dart';
import '../../play_ai/presentation/clock_text.dart';
import '../application/online_providers.dart';
import '../data/online_api.dart';

/// Quick match: queues the player and waits for a pairing. `join_queue` is
/// re-called every 30 s (the queue drops entries not seen for 2 minutes) and
/// on every Realtime hint about the player's games; it returns the game once
/// paired. Leaving the screen leaves the queue.
class SearchingScreen extends ConsumerStatefulWidget {
  const SearchingScreen({super.key, required this.timeControl});

  final TimeControl timeControl;

  static const Duration heartbeat = Duration(seconds: 30);

  @override
  ConsumerState<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends ConsumerState<SearchingScreen> {
  late final OnlineApi _api = ref.read(onlineApiProvider)!;
  late final AppLifecycleListener _lifecycle;
  late final Subscription _sub;
  late final Timer _heartbeat;
  late final Timer _ticker;
  int _seconds = 0;
  bool _offline = false;
  bool _paired = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _ask);
    _sub = _api.watchMyGames(onHint: _ask);
    _heartbeat = Timer.periodic(SearchingScreen.heartbeat, (_) => _ask());
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _seconds++),
    );
    _ask();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _sub.cancel();
    _heartbeat.cancel();
    _ticker.cancel();
    if (!_paired) unawaited(_api.leaveQueue().catchError((_) {}));
    super.dispose();
  }

  Future<void> _ask() async {
    if (_asking || _paired) return;
    _asking = true;
    try {
      final game = await _api.joinQueue(widget.timeControl);
      if (!mounted) return;
      setState(() => _offline = false);
      if (game != null) {
        _paired = true;
        context.go('/online/game/${game.id}');
      }
    } on OnlineFailure {
      if (mounted) setState(() => _offline = true);
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick match')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                widget.timeControl.label,
                style: AppType.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              const Center(
                child: ThinkingDots(
                  label: 'Looking for an opponent',
                  style: AppType.body,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatClock(Duration(seconds: _seconds)).split('.').first,
                key: const ValueKey('elapsed'),
                style: AppType.clock.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
              if (_offline) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Reconnecting…',
                  style: AppType.secondary.copyWith(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Stop searching'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
