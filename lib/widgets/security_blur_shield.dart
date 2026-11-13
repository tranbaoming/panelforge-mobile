import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Lớp màn chắn bảo mật che phủ nội dung bản quyền khi ứng dụng mất tiêu điểm,
/// người dùng chuyển đa nhiệm hoặc bấm phím chụp màn hình (PrintScreen / Snipping Tool).
class SecurityBlurShield extends StatelessWidget {
  final VoidCallback onDismiss;
  final String? title;
  final String? message;

  const SecurityBlurShield({
    super.key,
    required this.onDismiss,
    this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        color: AppColors.darkBg.withValues(alpha: 0.94),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Security Shield Icon with Orange Glow
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                title ?? '🔒 NỘI DUNG BẢN QUYỀN ĐANG ĐƯỢC BẢO VỆ',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                message ??
                    'Màn hình tạm thời được che chắn bảo mật khi ứng dụng mất tiêu điểm hoặc khi phát hiện công cụ chụp màn hình theo chính sách bản quyền PanelForge Studio.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.darkTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Dismiss Button
              ElevatedButton.icon(
                onPressed: onDismiss,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Tiếp Tục Đọc / Xem Bản Thảo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

