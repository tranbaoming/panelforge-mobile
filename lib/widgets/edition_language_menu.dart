import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../theme/app_theme.dart';

/// Chọn bản phát hành theo ngôn ngữ (vi gốc / en / ja) của chương đang đọc.
///
/// Khác với bộ chọn lớp chữ dịch của gói CBZ: mỗi bản ngôn ngữ là ảnh trang riêng do Publisher phát hành,
/// mua theo từng ngôn ngữ — bản chưa mua hiện ổ khóa + giá.
class EditionLanguageMenu extends StatelessWidget {
  final String current;
  final List<ChapterLanguageOption> options;
  final ValueChanged<String> onSelected;

  const EditionLanguageMenu({super.key, required this.current, required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const ValueKey('edition-language-menu'),
      initialValue: current,
      tooltip: 'Bản ngôn ngữ',
      onSelected: onSelected,
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.mint.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 14, color: AppColors.mint),
            const SizedBox(width: 4),
            Text(
              current.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.mint),
            ),
          ],
        ),
      ),
      itemBuilder: (context) => options.map((o) {
        final selected = o.language == current;
        return PopupMenuItem<String>(
          value: o.language,
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 16,
                color: selected ? AppColors.primary : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  contentLanguageLabel(o.language),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (!o.isUnlocked) ...[
                const Icon(Icons.lock_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(formatVnd(o.priceVnd), style: GoogleFonts.plusJakartaSans(fontSize: 11.5)),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
