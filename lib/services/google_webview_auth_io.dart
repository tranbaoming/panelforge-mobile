import 'dart:async';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/material.dart' show Brightness;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Mở [authUrl] (Google OAuth) trong cửa sổ WebView2 trên Windows Desktop và chờ token trả về.
///
/// [extractTokens] đọc token từ URL / hash fragment; trả `null` khi chưa có token.
/// Trả `null` khi người dùng đóng cửa sổ trước khi đăng nhập xong.
///
/// Tách riêng file này vì `desktop_webview_window` dùng `dart:ffi` — không biên dịch được trên Web
/// (Web dùng `google_webview_auth_stub.dart` qua import có điều kiện).
Future<Map<String, String>?> captureGoogleTokensViaWebview(
  String authUrl,
  Map<String, String>? Function(String url) extractTokens,
) async {
  final isAvailable = await WebviewWindow.isWebviewAvailable();
  if (!isAvailable) {
    throw Exception('WebView2 Runtime chưa được cài đặt trên hệ thống Windows.');
  }

  final supportDir = await getApplicationSupportDirectory();
  final completer = Completer<Map<String, String>?>();
  bool isHandled = false;
  Map<String, String>? capturedTokens;
  Timer? pollTimer;
  Webview? webview;

  void handleUrl(String url) async {
    if (isHandled) return;
    final tokens = extractTokens(url);
    if (tokens != null) {
      isHandled = true;
      capturedTokens = tokens;
      pollTimer?.cancel();

      // Hoàn tất completer với token TRƯỚC để tránh race condition khi đóng WebView
      if (!completer.isCompleted) {
        completer.complete(tokens);
      }

      // Sau đó mới đóng cửa sổ WebView
      try {
        await webview?.close();
      } catch (_) {}
    }
  }

  try {
    webview = await WebviewWindow.create(
      configuration: CreateConfiguration(
        windowWidth: 520,
        windowHeight: 720,
        title: 'Đăng nhập với Google • PanelForge',
        brightness: Brightness.dark,
        windows: WindowsWebviewOptions(
          userDataFolder: p.join(supportDir.path, 'WebView2'),
        ),
      ),
    );

    // Bắt URL khi WebView chuyển hướng
    await webview.setOnUrlRequestCallback((url) {
      handleUrl(url);
      return true;
    });

    // Lắng nghe URL và Hash fragment định kỳ (200ms) bằng JavaScript evaluate
    pollTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (isHandled || completer.isCompleted) {
        timer.cancel();
        return;
      }
      try {
        // 1. Kiểm tra hash fragment trước vì Google OAuth trả token sau dấu #
        final hash = await webview?.evaluateJavaScript('window.location.hash');
        if (hash is String && hash.isNotEmpty) {
          handleUrl(hash);
          if (isHandled) return;
        }

        // 2. Kiểm tra full URL
        final currentUrl = await webview?.evaluateJavaScript('window.location.href');
        if (currentUrl is String && currentUrl.isNotEmpty) {
          handleUrl(currentUrl);
        }
      } catch (_) {
        // Bỏ qua khi trang đang load hoặc cửa sổ đang đóng
      }
    });

    // Bắt sự kiện người dùng chủ động đóng cửa sổ WebView bằng dấu X
    webview.onClose.then((_) {
      pollTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(capturedTokens);
      }
    });

    await webview.launch(authUrl);
    return await completer.future;
  } finally {
    pollTimer?.cancel();
    if (webview != null) {
      try {
        await webview.close();
      } catch (_) {}
    }
  }
}
