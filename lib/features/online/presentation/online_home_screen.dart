import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/section_card.dart';
import '../application/online_providers.dart';
import 'profile_card.dart';
import 'time_control_sheet.dart';

/// `+` must be encoded in a query (it would decode as a space).
String _withTc(String path, String label) =>
    Uri(path: path, queryParameters: {'tc': label}).toString();

/// Play online: invite a friend, join with a code, or quick match.
class OnlineHomeScreen extends ConsumerWidget {
  const OnlineHomeScreen({super.key});

  Future<void> _invite(BuildContext context) async {
    final tc = await showTimeControlSheet(context, title: 'Invite a friend');
    if (tc != null && context.mounted) {
      await context.push(_withTc('/online/invite', tc.label));
    }
  }

  Future<void> _quickMatch(BuildContext context) async {
    final tc = await showTimeControlSheet(context, title: 'Quick match');
    if (tc != null && context.mounted) {
      await context.push(_withTc('/online/search', tc.label));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeOnlineGameProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Play online')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const ProfileCard(),
            if (active != null) ...[
              const SizedBox(height: AppSpacing.md),
              SectionCard(
                color: AppColors.surfaceRaised,
                onTap: () => context.push('/online/game/${active.id}'),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_rounded,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Game in progress (${active.timeControl.label})',
                        style: AppType.body,
                      ),
                    ),
                    const Text('Resume game', style: AppType.label),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const Text('Play a person', style: AppType.heading),
            const SizedBox(height: AppSpacing.md),
            _Option(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Invite a friend',
              subtitle: 'Get a code to share. Rated.',
              onTap: () => _invite(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Option(
              icon: Icons.pin_rounded,
              title: 'Join with a code',
              subtitle: 'Enter the 6-character code from a friend.',
              onTap: () => context.push('/online/join'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Option(
              icon: Icons.bolt_rounded,
              title: 'Quick match',
              subtitle: 'Play the next person looking for the same time.',
              onTap: () => _quickMatch(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.subtitle),
                Text(subtitle, style: AppType.secondary),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
