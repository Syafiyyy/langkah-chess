import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/move_review.dart';
import '../domain/position_eval.dart';

/// Colour for a move judgement.
Color labelColor(MoveLabel label) => switch (label) {
  MoveLabel.best => AppColors.best,
  MoveLabel.inaccuracy => AppColors.inaccuracy,
  MoveLabel.mistake => AppColors.mistake,
  MoveLabel.blunder => AppColors.danger,
};

/// Move-list mark: only errors get a symbol (a "!" on every engine move
/// would be noise).
({String symbol, Color color})? labelMark(MoveLabel? label) =>
    label == null || !label.isError
    ? null
    : (symbol: label.symbol, color: labelColor(label));

/// Score text from White's view: "+1.3", "-0.4", "#3", "#-2", or the result.
String evalText(PositionEval eval) {
  final result = eval.result;
  if (result != null) {
    return switch (result.winner?.name) {
      'white' => '1-0',
      'black' => '0-1',
      _ => '½-½',
    };
  }
  final mate = eval.mate;
  if (mate != null) return '#$mate';
  final pawns = (eval.cp ?? 0) / 100;
  return '${pawns >= 0 ? '+' : ''}${pawns.toStringAsFixed(1)}';
}
