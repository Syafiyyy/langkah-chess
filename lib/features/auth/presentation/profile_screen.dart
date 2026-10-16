import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/section_card.dart';
import '../application/auth_providers.dart';
import '../domain/profile.dart';
import 'delete_account_dialog.dart';

/// Username, rating, games played; sign out and delete account.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider)!.signOut();
    if (mounted) context.go('/');
  }

  Future<void> _delete(Profile profile) async {
    if (!await showDeleteAccountDialog(context, profile.username)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider)!.deleteAccount();
      if (mounted) context.go('/');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: switch (profile) {
          AsyncData(value: final p?) => _body(p),
          AsyncError() => _Retry(
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
          AsyncData() => const Center(
            child: Text('Signed out.', style: AppType.body),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _body(Profile p) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(p.username, style: AppType.title),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          child: Row(
            children: [
              Expanded(
                child: _Stat(value: '${p.rating}', label: 'Rating'),
              ),
              Expanded(
                child: _Stat(value: '${p.gamesPlayed}', label: 'Rated games'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton(
          onPressed: _busy ? null : _signOut,
          child: const Text('Sign out'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: _busy ? null : () => _delete(p),
          child: Text(_busy ? 'Deleting…' : 'Delete account'),
        ),
        if (_error case final error?)
          Text(
            error,
            style: AppType.secondary.copyWith(color: AppColors.danger),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppType.stat),
        Text(label, style: AppType.meta),
      ],
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Your profile didn't load.", style: AppType.body),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
