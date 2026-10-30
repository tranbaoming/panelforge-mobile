import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/review_model.dart';
import '../theme/app_theme.dart';

class PanelSelectionDetector extends StatelessWidget {
  final ReviewPanel panel;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onAnnotatePressed;

  const PanelSelectionDetector({
    super.key,
    required this.panel,
    required this.isSelected,
    required this.onTap,
    this.onAnnotatePressed,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppColors.primary; // #F97316

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : AppColors.darkBorder,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.15),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header bar with Panel Number and Annotation counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.15)
                      : AppColors.darkCard.withValues(alpha: 0.6),
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? primaryColor.withValues(alpha: 0.4)
                          : AppColors.darkBorder,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : AppColors.darkCard,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PANEL #${panel.panelNumber}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : AppColors.darkTextSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        panel.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                    if (panel.annotations.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.mintSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.mint.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.comment_rounded, size: 12, color: AppColors.mint),
                            const SizedBox(width: 4),
                            Text(
                              '${panel.annotations.length}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Visual Panel Canvas Simulation
              AspectRatio(
                aspectRatio: panel.aspectRatio,
                child: Stack(
                  children: [
                    // Simulated inking & comic sketch background
                    _buildPanelCanvas(context),

                    // Speech bubble simulation
                    Positioned(
                      top: 14,
                      left: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          panel.dialogue,
                          style: GoogleFonts.newsreader(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Inking notes callout at bottom
                    Positioned(
                      bottom: 12,
                      left: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.darkBorder.withValues(alpha: 0.8),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.brush_outlined,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                panel.inkingNotes,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  color: AppColors.darkTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Annotation Pins on the panel
                    ...panel.annotations.map((ann) {
                      return Positioned(
                        left: ann.normalizedPoint.dx * 280, // approximate width scale
                        top: ann.normalizedPoint.dy * 160,
                        child: _buildAnnotationPin(ann),
                      );
                    }),

                    // Quick Tap Feedback if selected
                    if (isSelected)
                      Positioned(
                        bottom: 48,
                        right: 14,
                        child: ElevatedButton.icon(
                          onPressed: onAnnotatePressed,
                          icon: const Icon(Icons.add_comment_rounded, size: 14),
                          label: const Text('Thêm góp ý'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnotationPin(AnnotationItem item) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: item.category.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: item.category.color.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(item.category.icon, size: 12, color: Colors.white),
    );
  }

  Widget _buildPanelCanvas(BuildContext context) {
    if (panel.imageUrl != null && panel.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: panel.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: const Color(0xFF131722),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => _buildSimulatedCanvas(),
      );
    }
    return _buildSimulatedCanvas();
  }

  Widget _buildSimulatedCanvas() {
    // Rich artistic custom sketch simulation
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF131722),
            const Color(0xFF0B0D14),
            Color(0xFF1E2638 + (panel.panelNumber * 0x050403)).withValues(alpha: 0.4),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _ComicLineArtPainter(panelNumber: panel.panelNumber),
        size: Size.infinite,
      ),
    );
  }
}

class _ComicLineArtPainter extends CustomPainter {
  final int panelNumber;
  _ComicLineArtPainter({required this.panelNumber});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final accentPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw dynamic perspective speed lines & perspective grid
    final centerX = size.width * (0.3 + (panelNumber % 3) * 0.2);
    final centerY = size.height * 0.55;

    for (int i = 0; i < 14; i++) {
      final start = Offset(centerX, centerY);
      final end = Offset(
        centerX + size.width * 1.5 * (i % 2 == 0 ? 1 : -1),
        centerY + size.height * (i % 3 - 1),
      );
      canvas.drawLine(start, end, i % 3 == 0 ? accentPaint : linePaint);
    }

    // Draw subtle mechanical or character silhouette framing
    final framePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX, centerY), size.height * 0.35, framePaint);
  }

  @override
  bool shouldRepaint(covariant _ComicLineArtPainter oldDelegate) =>
      oldDelegate.panelNumber != panelNumber;
}
