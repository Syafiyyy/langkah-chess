import 'package:chessground/chessground.dart';

/// The piece sets offered in Settings (bundled with chessground).
enum PieceChoice {
  cburnett(PieceSet.cburnett, 'Classic'),
  merida(PieceSet.merida, 'Merida'),
  california(PieceSet.california, 'California'),
  staunty(PieceSet.staunty, 'Staunty');

  const PieceChoice(this.pieceSet, this.label);

  final PieceSet pieceSet;
  final String label;

  static const PieceChoice defaultChoice = cburnett;

  PieceAssets get assets => pieceSet.assets;

  static PieceChoice byName(String? name) =>
      values.asNameMap()[name] ?? defaultChoice;
}
