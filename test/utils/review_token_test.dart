import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/utils/review_token.dart';

void main() {
  test('plain token is kept', () => expect(extractReviewToken('  REV-abc123 '), 'REV-abc123'));
  test('review invite URL', () => expect(extractReviewToken('https://x.io/review/invite/REV-abc?x=1'), 'REV-abc'));
  test('legacy preview URL', () => expect(extractReviewToken('http://localhost:5173/preview/tok_9/'), 'tok_9'));
}
