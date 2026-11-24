import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_providers.dart';
import 'api_client.dart';
import 'app_info.dart';

/// Cấu hình vận hành từ `GET /api/app/mobile-config`.
@immutable
class MobileAppConfig {
  final String minVersion;
  final String latestVersion;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final String storeUrlAndroid;
  final String storeUrlIos;

  const MobileAppConfig({
    required this.minVersion,
    required this.latestVersion,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.storeUrlAndroid,
    required this.storeUrlIos,
  });

  factory MobileAppConfig.fromJson(Map<String, dynamic> json) {
    return MobileAppConfig(
      minVersion: json['minVersion']?.toString() ?? AppInfo.version,
      latestVersion: json['latestVersion']?.toString() ?? AppInfo.version,
      maintenanceMode: json['maintenanceMode'] == true,
      maintenanceMessage:
          json['maintenanceMessage']?.toString() ?? 'Hệ thống đang bảo trì nâng cấp. Vui lòng quay lại sau ít phút.',
      storeUrlAndroid: json['storeUrlAndroid']?.toString() ?? '',
      storeUrlIos: json['storeUrlIos']?.toString() ?? '',
    );
  }

  /// Trả về `true` nếu [currentVersion] thấp hơn [minVersion] theo chuẩn Semantic Versioning (`major.minor.patch`).
  bool requiresForceUpdate([String currentVersion = AppInfo.version]) {
    return compareSemver(currentVersion, minVersion) < 0;
  }

  /// So sánh 2 chuỗi version `a` và `b` (bỏ qua phần `+build`).
  /// Trả về `< 0` nếu `a < b`, `0` nếu bằng nhau, `> 0` nếu `a > b`.
  static int compareSemver(String a, String b) {
    List<int> parse(String v) {
      final clean = v.split('+').first.split('-').first.trim();
      final parts = clean.split('.');
      return [
        for (var i = 0; i < 3; i++) i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0,
      ];
    }

    final pa = parse(a);
    final pb = parse(b);
    for (var i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return 0;
  }
}

class AppConfigService {
  final ApiClient _client;
  AppConfigService({ApiClient? client}) : _client = client ?? ApiClient();

  /// Lấy cấu hình vận hành mobile. Trả về `null` nếu ngoại tuyến / lỗi mạng để không chặn chế độ đọc offline.
  Future<MobileAppConfig?> fetchMobileConfig() async {
    try {
      final response = await _client.get('/api/app/mobile-config');
      if (response.data is Map<String, dynamic>) {
        return MobileAppConfig.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final appConfigServiceProvider = Provider<AppConfigService>((ref) {
  return AppConfigService(client: ref.watch(apiClientProvider));
});

/// Provider tải cấu hình vận hành một lần khi khởi động app (có thể invalidate để thử lại).
final mobileAppConfigProvider = FutureProvider<MobileAppConfig?>((ref) async {
  return ref.watch(appConfigServiceProvider).fetchMobileConfig();
});
