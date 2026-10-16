import 'package:flutter_test/flutter_test.dart';
import 'package:skak/app/deep_links.dart';

void main() {
  test('skak://join/CODE opens the join screen with the code', () {
    expect(
      routeForLink(Uri.parse('skak://join/RVMP92')),
      '/online/join?code=RVMP92',
    );
    expect(
      routeForLink(Uri.parse('skak://join/rvmp92/')),
      '/online/join?code=rvmp92',
    );
  });

  test('other links are not routes', () {
    expect(routeForLink(Uri.parse('skak://join')), isNull);
    expect(
      routeForLink(Uri.parse('skak://login-callback#access_token=x')),
      isNull,
    );
    expect(routeForLink(Uri.parse('https://example.com/join/ABC')), isNull);
  });
}
