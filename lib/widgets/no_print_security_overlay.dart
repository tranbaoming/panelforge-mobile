import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/screen_security_service.dart';
import '../theme/app_theme.dart';

/// Lớp bọc bảo mật No-Print DRM: Bắt và chặn toàn bộ các tổ hợp phím In ấn (Ctrl+P / Cmd+P),
/// Lưu trang / Xuất PDF (Ctrl+S / Cmd+S), và phím chụp màn hình (PrintScreen).
class NoPrintSecurityOverlay extends StatefulWidget {
  final Widget child;
  final String? token;
  final VoidCallback? onSecurityTriggered;

  const NoPrintSecurityOverlay({
    super.key,
    required this.child,
    this.token,
    this.onSecurityTriggered,
  });

  /// Hiển thị hộp thoại cảnh báo vi phạm bản quyền khi phát hiện lệnh in ấn
  static Future<void> showNoPrintAlert(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.rose, width: 2),
        ),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.rose.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.block_rounded, color: AppColors.rose, size: 36),
        ),
        title: Text(
          'CẢNH BÁO BẢO MẬT BẢN THẢO',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.rose,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: Text(
          '⛔ NGHIÊM CẤM IN ẤN: Bản thảo đang trong quá trình kiểm duyệt nội bộ. '
          'Hệ thống đã vô hiệu hóa chức năng In ấn, Xuất PDF và Sao chép theo quy định bản quyền của Studio.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Tôi Đã Hiểu & Đồng Ý',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  State<NoPrintSecurityOverlay> createState() => _NoPrintSecurityOverlayState();
}

class _NoPrintSecurityOverlayState extends State<NoPrintSecurityOverlay> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (ScreenSecurityService.isPrintOrSaveOrCaptureKey(event)) {
      if (mounted) {
        widget.onSecurityTriggered?.call();
        NoPrintSecurityOverlay.showNoPrintAlert(context);
      }
      return true; // Chặn đứng sự kiện phím
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (ScreenSecurityService.isPrintOrSaveOrCaptureKey(event)) {
          widget.onSecurityTriggered?.call();
          NoPrintSecurityOverlay.showNoPrintAlert(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.child,
    );
  }
}

