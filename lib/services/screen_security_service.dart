import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Sự kiện bảo mật màn hình từ lớp Native (chủ yếu iOS: quay màn hình / chụp màn hình).
class ScreenSecurityEvent {
  final String type; // 'capturedChanged' | 'screenshotTaken'
  final bool isCaptured;

  const ScreenSecurityEvent({required this.type, this.isCaptured = false});

  factory ScreenSecurityEvent.fromDynamic(dynamic raw) {
    if (raw is Map) {
      return ScreenSecurityEvent(
        type: raw['type']?.toString() ?? '',
        isCaptured: raw['isCaptured'] == true,
      );
    }
    return const ScreenSecurityEvent(type: '');
  }
}

/// Dịch vụ bảo mật màn hình:
/// - Chặn chụp/quay màn hình cấp hệ điều hành (Android `FLAG_SECURE`, iOS capture/screenshot events)
/// - Giữ sáng màn hình (`WakelockPlus`)
/// - Khóa xoay màn hình khi đọc
/// - Phát hiện phím in ấn/chụp màn hình trên Desktop
class ScreenSecurityService {
  static const MethodChannel _channel = MethodChannel('com.panelforge/screen_security');
  static const EventChannel _eventChannel = EventChannel('com.panelforge/screen_security_events');

  static bool _isAwake = false;
  static bool _isNativeProtected = false;
  static Stream<ScreenSecurityEvent>? _eventsStream;

  /// Trạng thái giữ sáng màn hình hiện tại
  static bool get isAwake => _isAwake;

  /// Trạng thái bảo vệ chống chụp/quay màn hình cấp Native hiện tại
  static bool get isNativeProtected => _isNativeProtected;

  /// Bật bảo vệ chống chụp/quay màn hình cấp OS (Android FLAG_SECURE).
  static Future<void> enableNativeProtection() async {
    _isNativeProtected = true;
    try {
      await _channel.invokeMethod<bool>('setSecureFlag', {'enable': true});
    } on MissingPluginException {
      // Môi trường Desktop / Widget test không đăng ký native channel
    } catch (_) {}
  }

  /// Tắt bảo vệ chống chụp/quay màn hình cấp OS khi rời màn hình đọc truyện.
  static Future<void> disableNativeProtection() async {
    _isNativeProtected = false;
    try {
      await _channel.invokeMethod<bool>('setSecureFlag', {'enable': false});
    } on MissingPluginException {
      // Môi trường Desktop / Widget test không đăng ký native channel
    } catch (_) {}
  }

  /// Kiểm tra xem màn hình có đang bị quay / phản chiếu không (iOS).
  static Future<bool> isScreenCaptured() async {
    try {
      return await _channel.invokeMethod<bool>('isScreenCaptured') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Luồng sự kiện quay/chụp màn hình từ Native (iOS).
  static Stream<ScreenSecurityEvent> get securityEvents {
    _eventsStream ??= _eventChannel
        .receiveBroadcastStream()
        .map(ScreenSecurityEvent.fromDynamic)
        .handleError((_) {});
    return _eventsStream!;
  }

  /// Bật / Tắt giữ sáng màn hình khi đọc truyện
  static Future<void> keepScreenAwake(bool enable) async {
    _isAwake = enable;
    try {
      await WakelockPlus.toggle(enable: enable);
    } catch (_) {
      // Bỏ qua lỗi nền tảng chưa đăng ký channel trong môi trường test/desktop
    }
  }

  /// Khóa cố định hướng xoay màn hình hiện tại (Chống xoay nhầm khi nằm đọc)
  static Future<void> lockOrientation(Orientation orientation) async {
    try {
      if (orientation == Orientation.portrait) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } catch (_) {}
  }

  /// Mở khóa xoay màn hình, trả về tất cả các hướng hỗ trợ
  static Future<void> unlockOrientation() async {
    try {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } catch (_) {}
  }

  /// Kiểm tra xem sự kiện phím có phải là lệnh In ấn (Ctrl+P / Cmd+P), Lưu trang (Ctrl+S / Cmd+S), hoặc Chụp màn hình (PrintScreen) hay không
  static bool isPrintOrSaveOrCaptureKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final isControlOrMeta = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Ctrl+P / Cmd+P (Print)
    if (isControlOrMeta && key == LogicalKeyboardKey.keyP) {
      return true;
    }

    // Ctrl+S / Cmd+S (Save/Export)
    if (isControlOrMeta && key == LogicalKeyboardKey.keyS) {
      return true;
    }

    // PrintScreen
    if (key == LogicalKeyboardKey.printScreen) {
      return true;
    }

    return false;
  }
}
