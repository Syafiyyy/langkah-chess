import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/play_ai/domain/time_control.dart';

void main() {
  test('presets match the spec', () {
    expect(TimeControl.presets.map((t) => t.label), [
      'Unlimited',
      '3+2',
      '5+0',
      '10+0',
      '15+10',
      '30+0',
    ]);
  });

  test('unlimited is not timed', () {
    expect(TimeControl.unlimited.isTimed, isFalse);
    expect(const TimeControl.minutes(5, 3).isTimed, isTrue);
  });

  test('custom control keeps minutes and increment', () {
    const custom = TimeControl.minutes(7, 5);
    expect(custom.initial, const Duration(minutes: 7));
    expect(custom.increment, const Duration(seconds: 5));
    expect(custom.label, '7+5');
  });

  test('equality is by value', () {
    expect(const TimeControl.minutes(3, 2), TimeControl.presets[1]);
  });

  test('round-trips through a compact string', () {
    for (final t in [...TimeControl.presets, const TimeControl.minutes(7, 5)]) {
      expect(TimeControl.parse(t.encode()), t);
    }
  });
}
