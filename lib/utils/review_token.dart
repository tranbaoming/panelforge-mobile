/// Bóc tách token xem thử từ chuỗi người dùng dán / quét QR.
/// Chấp nhận: token thuần (`REV-...`), `http(s)://host/review/invite/{token}`, `.../preview/{token}`,
/// kèm query/fragment hoặc dấu `/` cuối.
String extractReviewToken(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return value;
  value = value.split('#').first.split('?').first;
  if (!value.contains('/')) return value;
  final segments = value.split('/').where((s) => s.isNotEmpty).toList();
  return segments.isEmpty ? '' : Uri.decodeComponent(segments.last);
}
