import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class InteractiveScrubber extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageSelected;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;
  final bool isDark;

  const InteractiveScrubber({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
    this.onPrevPage,
    this.onNextPage,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppColors.primary;
    final surfaceColor = isDark ? const Color(0xFF13151F) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row: Prev Button, Page Number Indicator Badge, Next Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: currentPage > 1 ? primaryColor : textColor.withValues(alpha: 0.3),
                iconSize: 26,
                tooltip: 'Trang trước',
                onPressed: currentPage > 1 ? onPrevPage : null,
              ),

              // Page XX / YY Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Trang ',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      '$currentPage',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      ' / $totalPages',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: currentPage < totalPages ? primaryColor : textColor.withValues(alpha: 0.3),
                iconSize: 26,
                tooltip: 'Trang sau',
                onPressed: currentPage < totalPages ? onNextPage : null,
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Custom Slider with Tangerine Citrus Theme
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              thumbColor: primaryColor,
              overlayColor: primaryColor.withValues(alpha: 0.25),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 9,
                elevation: 4,
                pressedElevation: 8,
              ),
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              value: currentPage.toDouble().clamp(1.0, totalPages.toDouble()),
              min: 1.0,
              max: totalPages.toDouble(),
              divisions: totalPages > 1 ? (totalPages - 1) : 1,
              onChanged: (val) {
                onPageSelected(val.round());
              },
            ),
          ),
        ],
      ),
    );
  }
}
