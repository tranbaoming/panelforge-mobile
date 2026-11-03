import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/api_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'wallet_topup_dialog.dart';

/// Bảng BottomSheet Hồ sơ Độc giả (Reader Profile) theo chuẩn Dark Obsidian
class ReaderProfileSheet extends ConsumerStatefulWidget {
  const ReaderProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReaderProfileSheet(),
    );
  }

  @override
  ConsumerState<ReaderProfileSheet> createState() => _ReaderProfileSheetState();
}

class _ReaderProfileSheetState extends ConsumerState<ReaderProfileSheet> {
  bool _isLoading = false;

  // ─── 1. Xử lý Đăng xuất 3 bước chuẩn Backend ─────────────────────────────
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        title: Text(
          'Xác nhận đăng xuất',
          style: GoogleFonts.newsreader(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản trên thiết bị này không?',
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
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      // (1) Gọi API /api/auth/logout revoke token trên DB
      // (2) Xóa sạch CookieJar, SharedPreferences
      // (3) Đặt lại trạng thái về unauthenticated
      final msg = await authService.logout();

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.of(context).pop(); // đóng profile sheet

      // Refesh lại ví và trạng thái
      ref.invalidate(walletNotifierProvider);

      if (context.mounted) {
        context.go('/login');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.darkBorder),
          ),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi đăng xuất: $e')),
      );
    }
  }

  // ─── 2. Quên thiết bị tin cậy 2FA ────────────────────────────────────────
  Future<void> _handleForgetDevice() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final msg = await authService.forgetDevice();

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.mint),
          ),
          behavior: SnackBarBehavior.floating,
          content: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa thiết bị: $e')),
      );
    }
  }

  // ─── 3. Đổi mật khẩu an toàn ─────────────────────────────────────────────
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final otpController = TextEditingController();

    bool isSendingOtp = false;
    bool isChanging = false;
    String? dialogError;
    String? dialogNotice;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.darkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.darkBorder),
            ),
            title: Row(
              children: [
                const Icon(Icons.password_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Đổi Mật Khẩu An Toàn',
                  style: GoogleFonts.newsreader(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Vì lý do bảo mật, bạn cần nhập mật khẩu hiện tại và mã OTP xác nhận gửi về email:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.rose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: AppColors.rose, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (dialogNotice != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.mint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.mint.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        dialogNotice!,
                        style: const TextStyle(color: AppColors.mint, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Mật khẩu hiện tại',
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.darkCard,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.darkCard,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Mã OTP Email',
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.darkCard,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        onPressed: isSendingOtp
                            ? null
                            : () async {
                                setDialogState(() {
                                  isSendingOtp = true;
                                  dialogError = null;
                                  dialogNotice = null;
                                });
                                try {
                                  final auth = ref.read(authServiceProvider);
                                  final msg = await auth.sendChangePasswordOtp();
                                  setDialogState(() {
                                    isSendingOtp = false;
                                    dialogNotice = msg;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    isSendingOtp = false;
                                    dialogError = e.toString().replaceAll('ApiException: ', '');
                                  });
                                }
                              },
                        child: isSendingOtp
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Text('Nhận OTP', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isChanging
                    ? null
                    : () async {
                        final curPass = currentPasswordController.text;
                        final newPass = newPasswordController.text;
                        final otp = otpController.text.trim();

                        if (curPass.isEmpty || newPass.isEmpty || otp.isEmpty) {
                          setDialogState(() => dialogError = 'Vui lòng điền đầy đủ các thông tin.');
                          return;
                        }

                        setDialogState(() {
                          isChanging = true;
                          dialogError = null;
                        });

                        try {
                          final auth = ref.read(authServiceProvider);
                          final msg = await auth.changePassword(
                            currentPassword: curPass,
                            newPassword: newPass,
                            emailOtp: otp,
                          );

                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.darkSurface,
                                content: Text(msg, style: const TextStyle(color: AppColors.mint)),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isChanging = false;
                            dialogError = e.toString().replaceAll('ApiException: ', '');
                          });
                        }
                      },
                child: isChanging
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Xác nhận đổi'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final walletAsync = ref.watch(walletNotifierProvider);

    final coins = walletAsync.asData?.value.balanceCoins ?? 0;
    final isVip = walletAsync.asData?.value.isVip ?? false;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.darkBorder, width: 1.5),
          left: BorderSide(color: AppColors.darkBorder, width: 1),
          right: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header Profile
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkBorder, width: 2),
                ),
                child: Center(
                  child: Text(
                    user != null && user.fullName.isNotEmpty
                        ? user.fullName.substring(0, 1).toUpperCase()
                        : 'R',
                    style: GoogleFonts.newsreader(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user?.fullName ?? 'Độc Giả',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: authState.isRestricted
                                ? AppColors.amber.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: authState.isRestricted
                                  ? AppColors.amber.withValues(alpha: 0.5)
                                  : AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            authState.isRestricted ? 'READER (WEB PRO)' : 'READER',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: authState.isRestricted ? AppColors.amber : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? 'Chưa xác định email',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Thẻ cảnh báo quyền Web nếu là restrictedReader
          if (authState.isRestricted && authState.restrictionNotice != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authState.restrictionNotice!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Thẻ Thông tin Ví & Thiết bị
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                // Số dư ví
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Ví ForgeCoins:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '$coins Coins',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (isVip) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.mint,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'VIP',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            WalletTopupDialog.show(context);
                          },
                          child: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: AppColors.darkBorder, height: 20),
                // Thiết bị hiện tại
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.devices_rounded, color: AppColors.darkTextSecondary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Thiết bị:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      ApiClient.deviceDisplayName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Menu Actions
          _buildActionButton(
            icon: Icons.password_rounded,
            label: 'Đổi mật khẩu an toàn',
            onTap: _showChangePasswordDialog,
          ),
          const SizedBox(height: 8),

          _buildActionButton(
            icon: Icons.phonelink_erase_rounded,
            label: 'Quên thiết bị tin cậy 2FA',
            onTap: _isLoading ? null : _handleForgetDevice,
          ),
          const SizedBox(height: 16),

          // Nút Đăng xuất
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose.withValues(alpha: 0.15),
              foregroundColor: AppColors.rose,
              side: const BorderSide(color: AppColors.rose),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.rose),
                  )
                : const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Đăng Xuất Khỏi Thiết Bị', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.darkTextSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
