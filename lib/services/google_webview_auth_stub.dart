/// Bản Web (không có `dart:ffi`): đăng nhập Google qua WebView Windows không dùng được trên nền tảng này.
/// `AuthService.signInWithGoogle` chỉ gọi hàm này khi chạy Windows Desktop, nên trên Web không bao giờ tới đây.
Future<Map<String, String>?> captureGoogleTokensViaWebview(
  String authUrl,
  Map<String, String>? Function(String url) extractTokens,
) {
  throw UnsupportedError('Đăng nhập Google qua WebView chỉ hỗ trợ trên Windows Desktop.');
}
