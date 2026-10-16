import 'package:flutter_test/flutter_test.dart';
import 'package:skak/core/supabase/server_clock.dart';

void main() {
  final local = DateTime.utc(2026, 10, 16, 12);
  late DateTime now;
  late ServerClock clock;

  setUp(() {
    now = local;
    clock = ServerClock(localNow: () => now);
  });

  test('starts with no offset', () {
    expect(clock.offset, Duration.zero);
    expect(clock.now(), local);
  });

  test('a precise sample (server_now) sets the offset exactly', () {
    clock.addPreciseSample(local.add(const Duration(milliseconds: 1234)));
    expect(clock.offset, const Duration(milliseconds: 1234));
    expect(clock.now(), local.add(const Duration(milliseconds: 1234)));
  });

  test('a Date header sample is the middle of its second', () {
    // Header "12:00:05" means the server time was in [12:00:05, 12:00:06).
    clock.addDateHeaderSample(local.add(const Duration(seconds: 5)));
    expect(clock.offset, const Duration(milliseconds: 5500));
  });

  test('Date header samples are ignored within 60 s of a precise one', () {
    clock.addPreciseSample(local.add(const Duration(milliseconds: 300)));
    now = local.add(const Duration(seconds: 59));
    clock.addDateHeaderSample(now.add(const Duration(seconds: 3)));
    expect(clock.offset, const Duration(milliseconds: 300));

    now = local.add(const Duration(seconds: 61));
    clock.addDateHeaderSample(now.add(const Duration(seconds: 3)));
    expect(clock.offset, const Duration(milliseconds: 3500));
  });

  test('parses HTTP dates', () {
    expect(
      parseHttpDate('Fri, 16 Oct 2026 12:00:05 GMT'),
      DateTime.utc(2026, 10, 16, 12, 0, 5),
    );
    expect(parseHttpDate('garbage'), isNull);
  });
}
