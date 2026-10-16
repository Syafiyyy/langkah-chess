import 'package:flutter_test/flutter_test.dart';
import 'package:skak/features/auth/domain/username_rules.dart';

void main() {
  test('normalises to trimmed lower case', () {
    expect(normaliseUsername('  Adaam_7 '), 'adaam_7');
  });

  test('accepts 3 to 20 of a-z, 0-9, _', () {
    expect(usernameError('abc'), isNull);
    expect(usernameError('a' * 20), isNull);
    expect(usernameError('chess_fan_99'), isNull);
  });

  test('explains what is wrong', () {
    expect(usernameError(''), 'Enter a username');
    expect(usernameError('ab'), 'Use at least 3 characters');
    expect(usernameError('a' * 21), 'Use at most 20 characters');
    expect(
      usernameError('no-dash'),
      'Use only letters, numbers and underscores',
    );
    expect(
      usernameError('ümlaut'),
      'Use only letters, numbers and underscores',
    );
  });

  test('u_ is reserved for temporary names', () {
    expect(usernameError('u_abc'), 'Names starting with "u_" are reserved');
  });
}
