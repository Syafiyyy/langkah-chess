import 'dart:async';

import 'package:langkah/core/engine/uci_engine.dart';

/// Scripted UCI engine for tests. Records commands; replies via [onCommand].
class FakeUciEngine implements UciEngine {
  FakeUciEngine({this.onCommand});

  final void Function(FakeUciEngine engine, String command)? onCommand;
  final List<String> commands = [];
  final StreamController<String> _out = StreamController<String>();
  bool disposed = false;

  /// Emits one engine output line.
  void emit(String line) => _out.add(line);

  @override
  Stream<String> get stdout => _out.stream;

  @override
  void send(String command) {
    commands.add(command);
    onCommand?.call(this, command);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _out.close();
  }
}
