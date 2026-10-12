/// How a weak bot level chooses among the engine's candidate moves.
///
/// See `HumanMovePicker` for how each knob is used. All chances are 0..1;
/// [temperature] is in win% points (higher = more random among candidates).
class HumanStyle {
  const HumanStyle({
    required this.temperature,
    required this.blunderChance,
    required this.missMateInOneChance,
    required this.searchDepth,
    this.randomMoveChance = 0,
    this.bigBlunders = false,
    this.candidates = 10,
    this.searchTime = const Duration(milliseconds: 300),
  });

  /// Softmax temperature over win% (drop from the best candidate).
  final double temperature;

  /// Chance to pick a clearly worse candidate on purpose (drop >= 10 win%).
  final double blunderChance;

  /// Whether such a blunder may lose a lot (drop >= 30 win%).
  final bool bigBlunders;

  /// Chance to play any legal move, ignoring the engine (newcomer only).
  final double randomMoveChance;

  /// Chance to overlook an available mate in one.
  final double missMateInOneChance;

  /// MultiPV lines to ask the engine for.
  final int candidates;

  /// Depth and time cap of the candidate search.
  final int searchDepth;
  final Duration searchTime;
}
