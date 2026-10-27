import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/review_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/annotation_sheet.dart';
import '../../widgets/panel_selection_detector.dart';
import '../../widgets/watermark_overlay.dart';

class ReviewCanvasPage extends StatefulWidget {
  final String token;

  const ReviewCanvasPage({super.key, required this.token});

  @override
  State<ReviewCanvasPage> createState() => _ReviewCanvasPageState();
}

class _ReviewCanvasPageState extends State<ReviewCanvasPage> {
  late ReviewManuscript _manuscript;
  String? _selectedPanelId;
  int _totalAnnotationCount = 0;

  @override
  void initState() {
    super.initState();
    _manuscript = MockReviewRepository.getActiveReview();
    _recalculateAnnotations();
    if (_manuscript.panels.isNotEmpty) {
      _selectedPanelId = _manuscript.panels.first.id;
    }
  }

  void _recalculateAnnotations() {
    int count = 0;
    for (final p in _manuscript.panels) {
      count += p.annotations.length;
    }
    _totalAnnotationCount = count;
  }

  void _openAnnotationSheet(ReviewPanel panel) {
    AnnotationBottomSheet.show(
      context: context,
      panel: panel,
      onSubmitAnnotation: (newAnnotation) {
        setState(() {
          final updatedPanels = _manuscript.panels.map((p) {
            if (p.id == panel.id) {
              return p.copyWith(
                annotations: [...p.annotations, newAnnotation],
              );
            }
            return p;
          }).toList();

          _manuscript = _manuscript.copyWith(panels: updatedPanels);
          _recalculateAnnotations();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 18),
                const SizedBox(width: 8),
                Text('Đã lưu góp ý cho Khung Tranh #${panel.panelNumber}!'),
              ],
            ),
            backgroundColor: AppColors.darkSurface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final watermarkText = '${_manuscript.recipientEmail} • BẢN REVIEW KHẨN';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg.withValues(alpha: 0.9),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _manuscript.seriesTitle,
              style: GoogleFonts.newsreader(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              _manuscript.chapterTitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.mintSubtle,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.mint.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.comment_rounded, size: 12, color: AppColors.mint),
                const SizedBox(width: 4),
                Text(
                  '$_totalAnnotationCount GÓP Ý',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top DRM Watermark warning ribbon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.primary.withValues(alpha: 0.12),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, size: 13, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watermark đang nhúng: ${_manuscript.recipientEmail}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${_manuscript.panels.length} Khung Tranh',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // MAIN SCROLLABLE CANVAS WITH WATERMARK OVERLAY
            Expanded(
              child: WatermarkOverlay(
                text: watermarkText,
                spacingX: 200,
                spacingY: 90,
                opacity: 0.14,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _manuscript.panels.length,
                  itemBuilder: (context, index) {
                    final panel = _manuscript.panels[index];
                    final isSelected = panel.id == _selectedPanelId;

                    return PanelSelectionDetector(
                      panel: panel,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedPanelId = panel.id;
                        });
                      },
                      onAnnotatePressed: () {
                        _openAnnotationSheet(panel);
                      },
                    );
                  },
                ),
              ),
            ),

            // BOTTOM CONTROL BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.darkSurface,
                border: Border(
                  top: BorderSide(color: AppColors.darkBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Khung đang chọn:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        Text(
                          _selectedPanelId != null
                              ? 'PANEL #${_manuscript.panels.firstWhere((p) => p.id == _selectedPanelId).panelNumber}'
                              : 'Chưa chọn',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final currentPanel = _manuscript.panels.firstWhere(
                        (p) => p.id == _selectedPanelId,
                        orElse: () => _manuscript.panels.first,
                      );
                      _openAnnotationSheet(currentPanel);
                    },
                    icon: const Icon(Icons.add_comment_rounded, size: 16),
                    label: const Text('GÓP Ý PANEL NÀY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
