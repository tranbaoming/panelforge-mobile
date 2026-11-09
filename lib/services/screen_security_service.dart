import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Dịch vụ bảo mật màn hình: Giữ sáng màn hình, Khóa xoay màn hình, và phát hiện phím in ấn/chụp màn hình
class ScreenSecurityService {
  static bool _isAwake = false;

  /// Trạng thái giữ sáng màn hình hiện tại
  static bool get isAwake => _isAwake;

  /// Bật / Tắt giữ sáng màn hình khi đọc truyện hoặc review bản thảo
  static Future<void> keepScreenAwake(bool enable) async {
    _isAwake = enable;
    try {
      // Gửi yêu cầu qua platform channel nếu thiết bị hỗ trợ
      await SystemChannels.platform.invokeMethod<void>(
        enable ? 'SystemNavigator.keepAwake' : 'SystemNavigator.allowSleep',
      );
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

