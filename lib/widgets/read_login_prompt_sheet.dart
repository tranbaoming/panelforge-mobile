import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comic_model.dart';
import '../theme/app_theme.dart';
import 'forge_ui.dart';

/// Sheet mời đăng nhập khi người đọc chưa có tài khoản bấm đọc một chương.
///
/// Nửa dưới màn hình (nền đen), trang chi tiết truyện phía trên bị làm mờ:
/// ảnh bìa truyện + huy hiệu, lời mời, nút **Tiếp Theo** (→ màn nhập Email) và **Để sau**.
/// Trả `true` khi bấm Tiếp Theo; `false` khi bấm Để sau / vuốt đóng.
class ReadLoginPromptSheet extends StatelessWidget {
  final SeriesItem? series;
  const ReadLoginPromptSheet({super.key, this.series});

  static const _accent = Color(0xFFF28A1E);

  static Future<bool> show(BuildContext context, {SeriesItem? series}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.black,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      shape: const RoundedRectangleBorder(),
      builder: (_) => ReadLoginPromptSheet(series: series),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height * 0.6),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CoverWithBadge(series: series),
              const SizedBox(height: 40),
              Text(
                'Đăng nhập để theo dõi truyện bạn yêu thích và lưu lại lịch sử đọc nhé!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 56),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('read-login-next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Tiếp Theo',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const ValueKey('read-login-later'),
                style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(160, 48)),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Để sau', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ảnh bìa truyện với huy hiệu tròn đè ở cạnh dưới (không có truyện → chỉ hiện huy hiệu).
class _CoverWithBadge extends StatelessWidget {
  final SeriesItem? series;
  const _CoverWithBadge({this.series});

  static const _coverW = 130.0;
  static const _coverH = 175.0;
  static const _badge = 62.0;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: _badge,
      height: _badge,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 5),
      ),
      child: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 28),
    );
    final s = series;
    if (s == null) return badge;
    return SizedBox(
      width: _coverW,
      height: _coverH + _badge / 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          SizedBox(width: _coverW, height: _coverH, child: SeriesCover(series: s, radius: 8)),
          Positioned(bottom: 0, child: badge),
        ],
      ),
    );
  }
}
