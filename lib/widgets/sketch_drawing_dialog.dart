import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SketchDrawingDialog extends StatefulWidget {
  final String panelTitle;

  const SketchDrawingDialog({super.key, required this.panelTitle});

  static Future<bool?> show(BuildContext context, {required String panelTitle}) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => SketchDrawingDialog(panelTitle: panelTitle),
    );
  }

  @override
  State<SketchDrawingDialog> createState() => _SketchDrawingDialogState();
}

class _SketchDrawingDialogState extends State<SketchDrawingDialog> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  Color _selectedColor = AppColors.rose;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.draw_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Phác Thảo Chỉ Dẫn • ${widget.panelTitle}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Color Palette & Controls
            Row(
              children: [
                _buildColorDot(AppColors.rose),
                const SizedBox(width: 8),
                _buildColorDot(AppColors.amber),
                const SizedBox(width: 8),
                _buildColorDot(AppColors.mint),
                const SizedBox(width: 8),
                _buildColorDot(AppColors.blue),
                const SizedBox(width: 8),
                _buildColorDot(Colors.white),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.undo_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Hoàn tác nét vẽ',
                  onPressed: _strokes.isNotEmpty
                      ? () {
                          setState(() {
                            _strokes.removeLast();
                          });
                        }
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.rose, size: 20),
                  tooltip: 'Xóa toàn bộ nét',
                  onPressed: _strokes.isNotEmpty
                      ? () {
                          setState(() {
                            _strokes.clear();
                          });
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Interactive Drawing Canvas
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141824),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _currentStroke = [details.localPosition];
                        _strokes.add(_currentStroke);
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _currentStroke.add(details.localPosition);
                      });
                    },
                    child: CustomPaint(
                      painter: _SketchPainter(strokes: _strokes, strokeColor: _selectedColor),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Bottom Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(_strokes.isNotEmpty);
                  },
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Lưu Nét Vẽ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
              : null,
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color strokeColor;

  _SketchPainter({required this.strokes, required this.strokeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length > 1) {
        final path = Path();
        path.moveTo(stroke.first.dx, stroke.first.dy);
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        canvas.drawPath(path, paint);
      } else if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 2.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}

