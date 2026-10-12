import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale. Uses the platform font until a typeface is chosen in F3.
abstract final class AppType {
  static const TextStyle display = TextStyle(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const TextStyle title = TextStyle(
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: AppColors.text,
  );
  static const TextStyle label = TextStyle(
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.35,
    color: AppColors.textMuted,
  );
}
