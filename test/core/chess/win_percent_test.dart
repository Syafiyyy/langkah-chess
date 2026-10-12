import 'package:flutter_test/flutter_test.dart';
import 'package:langkah/core/chess/win_percent.dart';

void main() {
  test('0 cp is 50%', () => expect(winPercent(cp: 0), closeTo(50, 0.001)));

  test('follows the Lichess curve', () {
    // 50 + 50 * (2 / (1 + exp(-0.00368208 * 300)) - 1) = 75.1
    expect(winPercent(cp: 300), closeTo(75.1, 0.1));
    expect(winPercent(cp: -300), closeTo(24.9, 0.1));
  });

  test('mate scores are 100 or 0', () {
    expect(winPercent(mate: 3), 100);
    expect(winPercent(mate: -1), 0);
  });
}
