import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Cấu hình Endpoint kết nối tới PanelForge Backend API (.NET 8)
class ApiConfig {
  static const int defaultPort = 5044;

  /// Máy chủ production, truyền lúc build: `--dart-define=API_BASE_URL=https://api.example.com`.
  /// Bỏ trống (chạy dev) → tự chọn localhost / 10.0.2.2 như bên dưới.
  static const String _buildBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// true khi bản build không có `API_BASE_URL` → đang trỏ vào máy chủ dev (localhost / emulator).
  static bool get usesDevServer =>
      (_customBaseUrl == null || _customBaseUrl!.isEmpty) && _normalize(_buildBaseUrl).isEmpty;

  static String _normalize(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

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
    final fromBuild = _normalize(_buildBaseUrl);
    if (fromBuild.isNotEmpty) return fromBuild;
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

