import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theo dõi trạng thái ngoại tuyến của thiết bị.
/// Trả về `true` khi không có kết nối mạng (Wi-Fi / Mobile / Ethernet), `false` khi có mạng hoặc không hỗ trợ.
final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  try {
    final initial = await connectivity.checkConnectivity();
    yield _isDisconnected(initial);
    await for (final results in connectivity.onConnectivityChanged) {
      yield _isDisconnected(results);
    }
  } on MissingPluginException {
    yield false;
  } catch (_) {
    yield false;
  }
});

bool _isDisconnected(List<ConnectivityResult> results) {
  if (results.isEmpty) return true;
  return results.every((r) => r == ConnectivityResult.none);
}
