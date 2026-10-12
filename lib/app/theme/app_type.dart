import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale: 12 / 13 / 15 / 17 / 20 / 24 / 32 only.
///
/// - Sora (600/700): headings and the wordmark.
/// - Plus Jakarta Sans (400/500/700): UI text (700 only for the score in
///   summary cards, never for running text).
/// - DM Mono (500): clocks and move lists (tabular figures).
///
/// Line height falls as size rises: headings 1.2, body 1.5, meta 1.4.
abstract final class AppType {
  static const String fontDisplay = 'Sora';
  static const String fontUi = 'PlusJakartaSans';
  static const String fontMono = 'DMMono';

  // Sizes.
  static const double s12 = 12;
  static const double s13 = 13;
  static const double s15 = 15;
  static const double s17 = 17;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  /// Screen titles (Sora 600, 32).
  static const TextStyle headline = TextStyle(
    fontFamily: fontDisplay,
    fontSize: s32,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  /// Section and sheet titles (Sora 600, 24).
  static const TextStyle title = TextStyle(
    fontFamily: fontDisplay,
    fontSize: s24,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  /// App bar titles and card headings (Sora 600, 20).
  static const TextStyle heading = TextStyle(
    fontFamily: fontDisplay,
    fontSize: s20,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  /// Wordmark (Sora 700, 20).
  static const TextStyle wordmark = TextStyle(
    fontFamily: fontDisplay,
    fontSize: s20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  /// Prominent UI text: card titles, player names (17, 500).
  static const TextStyle subtitle = TextStyle(
    fontFamily: fontUi,
    fontSize: s17,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  /// Body text (15, 400).
  static const TextStyle body = TextStyle(
    fontFamily: fontUi,
    fontSize: s15,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );

  /// Buttons and interactive labels (15, 500).
  static const TextStyle label = TextStyle(
    fontFamily: fontUi,
    fontSize: s15,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  /// Secondary text (13, 400, muted).
  static const TextStyle secondary = TextStyle(
    fontFamily: fontUi,
    fontSize: s13,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );

  /// Meta: timestamps, hints, tile captions (12, 500, muted).
  static const TextStyle meta = TextStyle(
    fontFamily: fontUi,
    fontSize: s12,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  /// Big numbers in summary cards (PJS 700, 24).
  static const TextStyle stat = TextStyle(
    fontFamily: fontUi,
    fontSize: s24,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );

  /// Move lists (DM Mono 500, 15).
  static const TextStyle move = TextStyle(
    fontFamily: fontMono,
    fontSize: s15,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
  );

  /// Clocks (DM Mono 500, 24).
  static const TextStyle clock = TextStyle(
    fontFamily: fontMono,
    fontSize: s24,
    height: 1.2,
    fontWeight: FontWeight.w500,
    color: AppColors.text,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
