import 'package:multistockfish/multistockfish.dart';

/// Minimal UCI process interface, so EngineService can be tested with a fake.
abstract interface class UciEngine {
  /// Engine output, one line per event. Listened to exactly once.
  Stream<String> get stdout;

  /// Sends one UCI command.
  void send(String command);

  /// Quits the engine and frees its slot.
  Future<void> dispose();
}

/// Stockfish 19 from multistockfish, light flavor (embedded ~1 MB NNUE).
class StockfishUciEngine implements UciEngine {
  StockfishUciEngine._(this._stockfish);

  /// Starts the engine. Completes once it is ready for commands.
  /// Throws [StateError] if a light-flavor engine is already live.
  static Future<UciEngine> start() async {
    // Stockfish.create() defaults to StockfishFlavor.light (ADR-0002).
    final stockfish = await Stockfish.create();
    return StockfishUciEngine._(stockfish);
  }

  final Stockfish _stockfish;

  @override
  Stream<String> get stdout => _stockfish.stdout;

  @override
  void send(String command) => _stockfish.stdin = command;

  @override
  Future<void> dispose() => _stockfish.dispose();
}
