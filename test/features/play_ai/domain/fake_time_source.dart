import 'package:langkah/features/play_ai/domain/time_source.dart';

/// Manually advanced monotonic time for tests.
class FakeTimeSource implements TimeSource {
  Duration current = Duration.zero;

  void advance(Duration by) => current += by;

  @override
  Duration now() => current;
}
