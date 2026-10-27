import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/review_model.dart';
import '../theme/app_theme.dart';

class AnnotationBottomSheet extends StatefulWidget {
  final ReviewPanel panel;
  final ValueChanged<AnnotationItem> onSubmitAnnotation;

  const AnnotationBottomSheet({
    super.key,
    required this.panel,
    required this.onSubmitAnnotation,
  });

  static Future<AnnotationItem?> show({
    required BuildContext context,
    required ReviewPanel panel,
    required ValueChanged<AnnotationItem> onSubmitAnnotation,
  }) {
    return showModalBottomSheet<AnnotationItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) => AnnotationBottomSheet(
        panel: panel,
        onSubmitAnnotation: onSubmitAnnotation,
      ),
    );
  }

  @override
  State<AnnotationBottomSheet> createState() => _AnnotationBottomSheetState();
}

class _AnnotationBottomSheetState extends State<AnnotationBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarAnimController;
  late TextEditingController _noteController;

  AnnotationCategory _selectedCategory = AnnotationCategory.lightingColor;
  Offset _radarPoint = const Offset(0.48, 0.42); // Normalized (0..1, 0..1)
  
  // Audio recording simulation state
  bool _isRecordingAudio = false;
  int _audioDurationSeconds = 0;
  Timer? _audioTimer;
  bool _hasAudioRecorded = false;

  // Sketch attachment state
  bool _hasAttachedSketch = false;

  final int _maxCharLimit = 500;

  @override
  void initState() {
    super.initState();
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _noteController = TextEditingController();
    _noteController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _radarAnimController.dispose();
    _noteController.dispose();
    _audioTimer?.cancel();
    super.dispose();
  }

  void _toggleAudioRecording() {
    if (_isRecordingAudio) {
      _audioTimer?.cancel();
      setState(() {
        _isRecordingAudio = false;
        _hasAudioRecorded = true;
      });
    } else {
      setState(() {
        _isRecordingAudio = true;
        _audioDurationSeconds = 0;
        _hasAudioRecorded = false;
      });
      _audioTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _audioDurationSeconds++;
          if (_audioDurationSeconds >= 60) {
            _toggleAudioRecording();
          }
        });
      });
    }
  }

  void _submit() {
    if (_noteController.text.trim().isEmpty && !_hasAudioRecorded && !_hasAttachedSketch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung góp ý hoặc ghi âm!')),
      );
      return;
    }

    final newAnnotation = AnnotationItem(
      id: 'ann-${DateTime.now().millisecondsSinceEpoch}',
      panelId: widget.panel.id,
      category: _selectedCategory,
      note: _noteController.text.trim().isEmpty
          ? 'Góp ý bằng ${_hasAudioRecorded ? "ghi âm giọng nói" : "phác thảo"}'
          : _noteController.text.trim(),
      createdAt: DateTime.now(),
      author: 'Bạn (Senior Reviewer)',
      hasAudio: _hasAudioRecorded,
      audioDurationSec: _hasAudioRecorded ? _audioDurationSeconds : null,
      hasSketch: _hasAttachedSketch,
      normalizedPoint: _radarPoint,
    );

    widget.onSubmitAnnotation(newAnnotation);
    Navigator.of(context).pop(newAnnotation);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final totalHeight = mediaQuery.size.height * 0.92;
    final topViewportHeight = totalHeight * 0.35; // 35% viewport zoom

    return Container(
      height: totalHeight,
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 35% VIEWPORT ZOOM PHÍA TRÊN VỚI GHIM ĐỊNH VỊ RADAR NHẤP NHÁY
          SizedBox(
            height: topViewportHeight,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // High contrast zoomed canvas of the selected panel
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1E2638),
                          const Color(0xFF0D111A),
                          Color(0xFF1A1C29 + (widget.panel.panelNumber * 0x080608)),
                        ],
                      ),
                    ),
                    child: CustomPaint(
                      painter: _DetailedZoomArtPainter(),
                    ),
                  ),

                  // Interactive Tap to reposition Radar Pin
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        final local = details.localPosition;
                        setState(() {
                          _radarPoint = Offset(
                            (local.dx / mediaQuery.size.width).clamp(0.1, 0.9),
                            (local.dy / topViewportHeight).clamp(0.1, 0.9),
                          );
                        });
                      }
                    },
                  ),

                  // Pulsing Radar Pinpoint at _radarPoint
                  Positioned(
                    left: _radarPoint.dx * mediaQuery.size.width - 24,
                    top: _radarPoint.dy * topViewportHeight - 24,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _radarAnimController,
                        builder: (context, child) {
                          final value = _radarAnimController.value;
                          return SizedBox(
                            width: 48,
                            height: 48,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer expanding radar ring
                                Container(
                                  width: 20 + (28 * value),
                                  height: 20 + (28 * value),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _selectedCategory.color.withValues(
                                        alpha: (1.0 - value).clamp(0.0, 1.0),
                                      ),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                // Inner glowing core
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _selectedCategory.color,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _selectedCategory.color.withValues(alpha: 0.8),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.gps_fixed_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Panel Info Banner on Top Left
                  Positioned(
                    top: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.crop_free_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'PANEL ${widget.panel.panelNumber} (ZOOM 135%)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Helper hint: Tap to move radar
                  Positioned(
                    bottom: 8,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Chạm để di chuyển tiêu điểm radar',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 65% MODAL PHÍA DƯỚI: PHÂN LOẠI, Ô NHẬP, GHI ÂM, ĐÍNH KÈM
          Expanded(
            child: Container(
              color: AppColors.darkBg,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Góp ý khung tranh #${widget.panel.panelNumber}',
                          style: GoogleFonts.newsreader(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // PHÂN LOẠI GÓP Ý CHIPS: Ánh sáng/Màu, Lỗi nét, Thoại/Dịch, Bố cục
                    Text(
                      'PHÂN LOẠI GÓP Ý',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkTextSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AnnotationCategory.values.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedCategory = cat);
                          },
                          avatar: Icon(
                            cat.icon,
                            size: 14,
                            color: isSelected ? Colors.white : cat.color,
                          ),
                          label: Text(cat.label),
                          labelStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.darkTextPrimary,
                          ),
                          selectedColor: cat.color,
                          backgroundColor: AppColors.darkCard,
                          side: BorderSide(
                            color: isSelected ? cat.color : AppColors.darkBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Ô NHẬP GHI CHÚ KÈM ĐẾM KÝ TỰ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NỘI DUNG CHỈ DẪN',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkTextSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '${_noteController.text.length} / $_maxCharLimit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _noteController.text.length > _maxCharLimit
                                ? AppColors.rose
                                : AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    TextField(
                      controller: _noteController,
                      maxLength: _maxCharLimit,
                      maxLines: 3,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập chi tiết điều chỉnh nét inking, độ sáng, hoặc câu thoại...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.darkTextSecondary.withValues(alpha: 0.7),
                        ),
                        fillColor: AppColors.darkCard,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.darkBorder),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // GHI ÂM CHỈ DẪN & ĐÍNH KÈM PHÁC THẢO
                    Row(
                      children: [
                        // Ghi âm nút
                        Expanded(
                          child: InkWell(
                            onTap: _toggleAudioRecording,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _isRecordingAudio
                                    ? AppColors.rose.withValues(alpha: 0.2)
                                    : _hasAudioRecorded
                                        ? AppColors.mintSubtle
                                        : AppColors.darkCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isRecordingAudio
                                      ? AppColors.rose
                                      : _hasAudioRecorded
                                          ? AppColors.mint
                                          : AppColors.darkBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isRecordingAudio
                                        ? Icons.stop_circle_outlined
                                        : _hasAudioRecorded
                                            ? Icons.check_circle_outline
                                            : Icons.mic_rounded,
                                    size: 16,
                                    color: _isRecordingAudio
                                        ? AppColors.rose
                                        : _hasAudioRecorded
                                            ? AppColors.mint
                                            : AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _isRecordingAudio
                                          ? 'Dừng (${_audioDurationSeconds}s)'
                                          : _hasAudioRecorded
                                              ? 'Đã ghi âm (${_audioDurationSeconds}s)'
                                              : 'Ghi âm chỉ dẫn',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _isRecordingAudio
                                            ? AppColors.rose
                                            : _hasAudioRecorded
                                                ? AppColors.mint
                                                : Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Đính kèm phác thảo nút
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _hasAttachedSketch = !_hasAttachedSketch;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              decoration: BoxDecoration(
                                color: _hasAttachedSketch
                                    ? AppColors.blue.withValues(alpha: 0.2)
                                    : AppColors.darkCard,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _hasAttachedSketch ? AppColors.blue : AppColors.darkBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasAttachedSketch
                                        ? Icons.check_box_outlined
                                        : Icons.draw_outlined,
                                    size: 16,
                                    color: _hasAttachedSketch ? AppColors.blue : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _hasAttachedSketch ? 'Đã đính kèm nét vẽ' : 'Đính kèm phác thảo',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _hasAttachedSketch ? AppColors.blue : Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // NÚT GỬI PHẢN HỒI
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('GỬI GÓP Ý KHUNG TRANH'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailedZoomArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1.5;

    // Cross hatching simulation for manga/comic zoom
    for (double x = 0; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x + 40, size.height), p);
    }

    final circlePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.45), 60, circlePaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.45), 110, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
