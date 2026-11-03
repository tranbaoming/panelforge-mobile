import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/api_providers.dart';
import '../theme/app_theme.dart';

/// Hộp thoại xác nhận đăng xuất và thực hiện thoát ra màn hình LoginPage
Future<void> showLogoutConfirmDialog(BuildContext context, WidgetRef ref) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
      title: Row(
        children: [
          const Icon(Icons.logout_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'Xác nhận đăng xuất',
            style: GoogleFonts.newsreader(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: Text(
        'Bạn có chắc chắn muốn đăng xuất khỏi PanelForge và quay lại màn hình Đăng nhập?',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: AppColors.darkTextSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
  );

  if (shouldLogout == true) {
    final auth = ref.read(authServiceProvider);
    await auth.logout();
    ref.read(authStateProvider.notifier).setUnauthenticated();
    if (context.mounted) {
      context.go('/login');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.darkBorder),
          ),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Bạn đã đăng xuất khỏi PanelForge',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
          ),
        ),
      );
    }
  }
}

