/// Monotonic time, injected so tests can control it.
abstract interface class TimeSource {
  /// Time since an arbitrary fixed origin. Never goes backwards.
  Duration now();
}

/// Real monotonic time from a [Stopwatch] (not wall-clock time, so device
/// clock changes can't affect game clocks).
class MonotonicTimeSource implements TimeSource {
  MonotonicTimeSource() : _watch = Stopwatch()..start();

  final Stopwatch _watch;

  @override
  Duration now() => _watch.elapsed;
}
