import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';

/// The game's app bar title: [title], or "Reconnecting…" while the channel
/// or requests fail. It lives in the app bar so the board never moves when
/// the connection drops, and it never blocks the board.
class ConnectionTitle extends StatelessWidget {
  const ConnectionTitle({
    super.key,
    required this.title,
    required this.reconnecting,
  });

  final String title;
  final bool reconnecting;

  @override
  Widget build(BuildContext context) {
    if (!reconnecting) return Text(title);
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 20, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              'Reconnecting…',
              style: AppType.heading.copyWith(color: AppColors.danger),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
