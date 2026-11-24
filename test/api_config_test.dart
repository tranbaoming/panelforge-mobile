import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/services/api_config.dart';

void main() {
  tearDown(() => ApiConfig.setCustomBaseUrl(null));

  test('build không có API_BASE_URL dùng máy chủ dev (localhost)', () {
    expect(ApiConfig.usesDevServer, isTrue);
    expect(ApiConfig.baseUrl, 'http://localhost:${ApiConfig.defaultPort}');
  });

  test('địa chỉ cấu hình được ưu tiên và bỏ dấu / cuối', () {
    ApiConfig.setCustomBaseUrl('https://api.example.com/');
    expect(ApiConfig.usesDevServer, isFalse);
    expect(ApiConfig.apiBaseUrl, 'https://api.example.com/api');
    expect(ApiConfig.resolveUrl('/covers/1.png'), 'https://api.example.com/covers/1.png');
  });
}
