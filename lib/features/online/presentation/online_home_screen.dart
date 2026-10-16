import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import 'profile_card.dart';

/// Play online: invite a friend, join with a code, or quick match.
class OnlineHomeScreen extends StatelessWidget {
  const OnlineHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play online')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            ProfileCard(),
            SizedBox(height: AppSpacing.xl),
            Text('Play a person', style: AppType.heading),
          ],
        ),
      ),
    );
  }
}
