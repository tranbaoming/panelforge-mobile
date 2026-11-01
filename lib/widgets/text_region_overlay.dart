import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comic_package_models.dart';
import '../theme/app_theme.dart';

class TextRegionOverlay extends StatelessWidget {
  final int pageIndex;
  final double containerWidth;
  final double containerHeight;
  final LoadedComicPackage? package;
  final String? selectedLanguage;
  final ValueChanged<TextRegion>? onRegionTap;

  const TextRegionOverlay({
    super.key,
    required this.pageIndex,
    required this.containerWidth,
    required this.containerHeight,
    this.package,
    this.selectedLanguage,
    this.onRegionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (package == null || selectedLanguage == null) {
      return const SizedBox.shrink();
    }

    final regions = package!.getTextRegionsForPage(pageIndex);
    if (regions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: regions.map((region) {
        final translation = package!.getTranslation(selectedLanguage!, region.id);
        final displayText = translation?.text ?? '';
        if (displayText.isEmpty) return const SizedBox.shrink();

        final bounds = region.bounds;
        final left = (bounds.x * containerWidth).clamp(0.0, containerWidth - 20);
        final top = (bounds.y * containerHeight).clamp(0.0, containerHeight - 20);
        final width = (bounds.w * containerWidth).clamp(24.0, containerWidth - left);
        final height = (bounds.h * containerHeight).clamp(20.0, containerHeight - top);

        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: GestureDetector(
            onTap: () => onRegionTap?.call(region),
            behavior: HitTestBehavior.opaque,
            child: _buildBubbleContent(region, displayText),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBubbleContent(TextRegion region, String text) {
    final type = region.type.toLowerCase();

    // 1. Thuyết minh (Narration): Hộp chữ nhật góc vát màu hổ phách / vàng nhạt
    if (type == 'narration') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB).withValues(alpha: 0.95), // Warm parchment
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.amber, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.newsreader(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              color: Colors.black87,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // 2. Suy nghĩ (Thought): Viền bo tròn lớn, màu xám xanh mây
    if (type == 'thought') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF94A3B8), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // 3. Hiệu ứng âm thanh (SFX): Viền cam, chữ đậm cách điệu
    if (type == 'sfx') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 4),
              ],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // 4. Bóng thoại thông thường (Speech bubble)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 5,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
            height: 1.25,
          ),
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

