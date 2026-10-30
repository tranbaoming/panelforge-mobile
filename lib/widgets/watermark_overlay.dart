import 'dart:math' as math;
import 'package:flutter/material.dart';

class WatermarkOverlay extends StatelessWidget {
  final String text;
  final Widget? child;
  final double angle; // in radians
  final double opacity;
  final double spacingX;
  final double spacingY;
  final TextStyle? textStyle;

  const WatermarkOverlay({
    super.key,
    required this.text,
    this.child,
    this.angle = -0.32, // approx -18 degrees
    this.opacity = 0.12,
    this.spacingX = 220,
    this.spacingY = 90,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final watermarkPainter = CustomPaint(
      painter: _WatermarkCustomPainter(
        text: text,
        angle: angle,
        opacity: opacity,
        spacingX: spacingX,
        spacingY: spacingY,
        style: textStyle ??
            TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: opacity),
              letterSpacing: 1.5,
            ),
      ),
      size: Size.infinite,
    );

    if (child == null) {
      return IgnorePointer(child: watermarkPainter);
    }

    return Stack(
      children: [
        child!,
        Positioned.fill(
          child: IgnorePointer(
            child: watermarkPainter,
          ),
        ),
      ],
    );
  }
}

class _WatermarkCustomPainter extends CustomPainter {
  final String text;
  final double angle;
  final double opacity;
  final double spacingX;
  final double spacingY;
  final TextStyle style;

  _WatermarkCustomPainter({
    required this.text,
    required this.angle,
    required this.opacity,
    required this.spacingX,
    required this.spacingY,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final textWidth = textPainter.width;

    // Expand bounding box for rotation coverage
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final cols = (diagonal / (textWidth + spacingX)).ceil() + 2;
    final rows = (diagonal / spacingY).ceil() + 2;

    canvas.save();
    // Rotate canvas around center
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.translate(-diagonal / 2, -diagonal / 2);

    for (int r = 0; r < rows; r++) {
      final offsetX = (r % 2 == 1) ? (textWidth + spacingX) / 2 : 0.0;
      for (int c = 0; c < cols; c++) {
        final x = c * (textWidth + spacingX) + offsetX;
        final y = r * spacingY;
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkCustomPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.angle != angle ||
        oldDelegate.opacity != opacity ||
        oldDelegate.spacingX != spacingX ||
        oldDelegate.spacingY != spacingY;
  }
}
