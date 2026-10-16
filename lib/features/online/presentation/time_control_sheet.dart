import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_type.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/section_card.dart';
import '../../play_ai/domain/time_control.dart';

/// Online time controls (the server accepts 1–60 minutes + 0–60 s).
const List<TimeControl> onlineTimeControls = [
  TimeControl.minutes(1, 0),
  TimeControl.minutes(3, 2),
  TimeControl.minutes(5, 0),
  TimeControl.minutes(10, 0),
  TimeControl.minutes(15, 10),
  TimeControl.minutes(30, 0),
];

String _speed(TimeControl tc) {
  final total = tc.minutes * 60 + 40 * tc.incrementSeconds;
  if (total < 180) return 'Bullet';
  if (total < 480) return 'Blitz';
  if (total < 1500) return 'Rapid';
  return 'Classical';
}

/// Asks for an online time control under [title].
Future<TimeControl?> showTimeControlSheet(
  BuildContext context, {
  required String title,
}) {
  return showAppSheet<TimeControl>(
    context,
    title: title,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tc in onlineTimeControls) ...[
          SectionCard(
            onTap: () => Navigator.pop(context, tc),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(child: Text(tc.label, style: AppType.subtitle)),
                Text(_speed(tc), style: AppType.secondary),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    ),
  );
}
