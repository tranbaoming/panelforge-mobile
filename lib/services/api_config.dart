import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Cấu hình Endpoint kết nối tới PanelForge Backend API (.NET 8)
class ApiConfig {
  static const int defaultPort = 5044;

  static String? _customBaseUrl;

  static void setCustomBaseUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      _customBaseUrl = null;
    } else {
      var trimmed = url.trim();
      if (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      _customBaseUrl = trimmed;
    }
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (kIsWeb) {
      return 'http://localhost:$defaultPort';
    }
    try {
      if (Platform.isAndroid) {
        // 10.0.2.2 ánh xạ tới localhost của máy tính khi chạy Android Emulator
        return 'http://10.0.2.2:$defaultPort';
      }
    } catch (_) {
      // Fallback cho môi trường không hỗ trợ dart:io
    }
    return 'http://localhost:$defaultPort';
  }

  static String get apiBaseUrl => '$baseUrl/api';

  /// Chuẩn hóa đường dẫn ảnh hoặc endpoint từ tương đối thành tuyệt đối
  static String resolveUrl(String? relativeOrAbsoluteUrl) {
    if (relativeOrAbsoluteUrl == null || relativeOrAbsoluteUrl.isEmpty) {
      return '';
    }
    if (relativeOrAbsoluteUrl.startsWith('http://') ||
        relativeOrAbsoluteUrl.startsWith('https://')) {
      return relativeOrAbsoluteUrl;
    }
    final cleanPath = relativeOrAbsoluteUrl.startsWith('/')
        ? relativeOrAbsoluteUrl
        : '/$relativeOrAbsoluteUrl';
    return '$baseUrl$cleanPath';
  }
}

