import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class QRScannerDialog extends StatefulWidget {
  final ValueChanged<String> onCodeScanned;

  const QRScannerDialog({
    super.key,
    required this.onCodeScanned,
  });

  static Future<String?> show({
    required BuildContext context,
    required ValueChanged<String> onCodeScanned,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => QRScannerDialog(onCodeScanned: onCodeScanned),
    );
  }

  @override
  State<QRScannerDialog> createState() => _QRScannerDialogState();
}

class _QRScannerDialogState extends State<QRScannerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late TextEditingController _manualController;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _manualController = TextEditingController();
  }

  @override
  void dispose() {
    _laserController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _triggerScanResult(String token) {
    widget.onCodeScanned(token);
    Navigator.of(context).pop(token);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Quét Mã QR Bản Thảo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Camera Viewfinder Box with Animated Laser
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera Simulation Texture
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.8,
                          colors: [
                            _isTorchOn
                                ? Colors.white.withValues(alpha: 0.15)
                                : const Color(0xFF141824),
                            Colors.black,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Framing corners
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: CustomPaint(
                      painter: _ViewfinderCornersPainter(),
                    ),
                  ),

                  // Animated Laser Scanning Line
                  AnimatedBuilder(
                    animation: _laserController,
                    builder: (context, child) {
                      return Positioned(
                        top: 40 + (_laserController.value * 150),
                        left: 40,
                        right: 40,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primary,
                                AppColors.primaryLight,
                                AppColors.primary,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Center QR Code target hint
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),

                  // Torch toggle button
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: () => setState(() => _isTorchOn = !_isTorchOn),
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isTorchOn ? AppColors.primary : Colors.white60,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Quick Testing Tokens for easy testing
            Text(
              'HOẶC CHỌN MẪU TEST NHANH',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.darkTextSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _triggerScanResult('REV-8891-OBSIDIAN-AETHEL'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppColors.mint),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Bản Còn Hạn (Active)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mint,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _triggerScanResult('REV-EXPIRED-TEST-TOKEN'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppColors.rose),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Bản Hết Hạn (Lock)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.rose,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewfinderCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 24.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLen, 0), p);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLen), p);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLen, 0), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLen), p);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLen, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLen), p);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLen, size.height), p);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLen), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
