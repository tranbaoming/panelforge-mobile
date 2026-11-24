import 'dart:async';

import 'package:flutter/foundation.dart';
import 'preferences_service.dart';

/// Ghi lại lỗi chưa bắt được vào nhật ký trên máy (Cài đặt → Nhật ký lỗi).
/// Backend chưa có endpoint nhận báo lỗi, nên không gửi đi đâu; độc giả tự sao chép gửi hỗ trợ.
class CrashReporter {
  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack);
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack);
      return false;
    };
  }

  static void record(Object error, StackTrace? stack) {
    final lines = (stack ?? StackTrace.empty).toString().split('\n').take(12).join('\n');
    unawaited(
      PreferencesService.addCrashLog(CrashLogEntry(time: DateTime.now(), error: error.toString(), stack: lines)),
    );
  }
}
