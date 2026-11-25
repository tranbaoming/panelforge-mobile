import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/content/legal_content.dart';

Iterable<String> _allText(LegalDocument d) sync* {
  yield d.title;
  if (d.intro != null) yield d.intro!;
  for (final s in d.sections) {
    yield s.heading;
    yield* s.body;
  }
}

void main() {
  test('bản Android (Google Play) không hướng người dùng sang VietQR / chuyển khoản', () {
    final docs = legalDocumentsFor(googlePlayBilling: true);
    expect(docs.keys, containsAll(['terms', 'privacy', 'copyright', 'faq']));
    for (final doc in docs.values) {
      for (final text in _allText(doc)) {
        expect(text.toLowerCase(), isNot(contains('vietqr')), reason: '${doc.id}: $text');
        expect(text.toLowerCase(), isNot(contains('chuyển khoản')), reason: '${doc.id}: $text');
      }
    }
    expect(_allText(docs['terms']!).any((t) => t.contains('Google Play')), isTrue);
  });

  test('nền tảng khác giữ nguyên văn bản VietQR', () {
    expect(identical(legalDocumentsFor(googlePlayBilling: false), legalDocuments), isTrue);
  });
}
