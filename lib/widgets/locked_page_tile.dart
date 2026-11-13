import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comic_model.dart';
import '../theme/app_theme.dart';

/// Trang của chương trả phí nằm ngoài phần xem trước (Publisher chọn trang xem trước trên web).
///
/// Server không trả ảnh thật cho trang này (ImageUrl = null, endpoint ảnh 403) nên ô chỉ vẽ một nền
/// giả làm mờ + ổ khóa và một nút "Mở khóa chương" — mua chương mở toàn bộ trang (Ví / VietQR / VIP).
/// Giữ tỷ lệ trang truyện để bố cục đọc không nhảy.
class LockedPageTile extends StatelessWidget {
  final ComicPageData page;
  final VoidCallback? onUnlock;
  final double aspectRatio;

  const LockedPageTile({super.key, required this.page, this.onUnlock, this.aspectRatio = 1 / 1.45});

  @override
  Widget build(BuildContext context) {
    // Chế độ lật trang đặt ô trong Column (chiều cao không giới hạn): giữ tỷ lệ trang nhưng không cao quá
    // ~65% màn hình để không tràn khung đọc.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.65;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : maxHeight * aspectRatio;
        var height = width / aspectRatio;
        if (constraints.hasBoundedHeight && constraints.maxHeight < height) height = constraints.maxHeight;
        if (height > maxHeight) height = maxHeight;
        return SizedBox(width: width, height: height, child: _content());
      },
    );
  }

  Widget _content() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Nền giả lập nội dung đã bị làm mờ (không phải ảnh thật của trang).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A2A22), Color(0xFF1C1C22), Color(0xFF2B2140)],
              ),
            ),
          ),
          const _PanelSilhouettes(),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Trang ${page.pageNumber} • Hết phần xem trước',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mở khóa chương để đọc toàn bộ • VIP đọc miễn phí',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    key: ValueKey('unlock-chapter-from-page-${page.pageNumber}'),
                    onPressed: onUnlock,
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: Text(
                      'Mở khóa chương',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vài khối khung tranh mờ để ô khóa trông giống một trang truyện bị che.
class _PanelSilhouettes extends StatelessWidget {
  const _PanelSilhouettes();

  @override
  Widget build(BuildContext context) {
    Widget block(int flex) => Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          block(3),
          Expanded(flex: 4, child: Row(children: [block(1), block(1)])),
          block(3),
        ],
      ),
    );
  }
}
