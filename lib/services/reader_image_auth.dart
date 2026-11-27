import 'dart:math' as math;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/widgets.dart';
import 'api_client.dart';

/// Helper tập trung cho việc tải ảnh trang truyện có xác thực & tính kích thước decode theo DPR (AUD-FL-06).
///
/// DEC-04: Hiện tại đính kèm header `Cookie` từ `ApiClient.cookieJar` (đã lưu trong secure storage).
/// Khi backend chốt chuyển sang signed URL, chỉ cần thay đổi tại helper này.
class ReaderImageAuth {
  static const int minMemCacheWidth = 360;
  static const int maxMemCacheWidth = 2048;

  /// Tạo HTTP headers (gồm `Cookie` phiên và `User-Agent`) cho yêu cầu tải ảnh trang truyện.
  static Future<Map<String, String>> headersForUrl(
    String url, {
    CookieJar? cookieJar,
  }) async {
    final headers = <String, String>{
      'User-Agent': ApiClient.getUserAgent(),
    };
    final uri = Uri.tryParse(url);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return headers;
    }
    try {
      final jar = cookieJar ?? ApiClient.cookieJar;
      final cookies = await jar.loadForRequest(uri);
      if (cookies.isNotEmpty) {
        headers['Cookie'] = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      }
    } catch (_) {}
    return headers;
  }

  /// Tính `memCacheWidth` theo chiều rộng hiển thị và `devicePixelRatio` của thiết bị
  /// để tránh giải mã ảnh quá lớn gây OOM trên màn hình độ phân giải cao.
  static int computeMemCacheWidth({
    required double logicalWidth,
    required double devicePixelRatio,
    double maxLogicalWidth = 680.0,
  }) {
    final effectiveLogical = math.min(logicalWidth, maxLogicalWidth);
    final physicalPx = (effectiveLogical * devicePixelRatio).round();
    return physicalPx.clamp(minMemCacheWidth, maxMemCacheWidth);
  }

  /// Phiên bản tiện lợi lấy trực tiếp `MediaQuery` từ [BuildContext].
  static int memCacheWidthForContext(
    BuildContext context, {
    double maxLogicalWidth = 680.0,
  }) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return computeMemCacheWidth(
      logicalWidth: size.width,
      devicePixelRatio: dpr,
      maxLogicalWidth: maxLogicalWidth,
    );
  }
}
