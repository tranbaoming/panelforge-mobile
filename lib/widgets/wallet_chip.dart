import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../providers/api_providers.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import 'auth_modal_sheet.dart';
import 'wallet_topup_dialog.dart';

/// Chip hiển thị số dư Ví tiền (VNĐ) và huy hiệu VIP trên Header
/// Luôn hiển thị số dư trực tuyến từ server hoặc số dư dự phòng cục bộ cho Độc giả
class WalletChip extends ConsumerWidget {
  final bool? isServerConnected;

  const WalletChip({super.key, this.isServerConnected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Nếu màn hình chỉ định rõ trạng thái kết nối server đang offline/thất bại, ẩn chip
    if (isServerConnected == false) {
      return const SizedBox.shrink();
    }

    final walletAsync = ref.watch(walletNotifierProvider);

    // Lấy số dư VNĐ: ưu tiên từ server (walletAsync), fallback về cache cục bộ
    final cachedVnd = PreferencesService.getLocalBalanceVnd();
    final balanceVnd = walletAsync.asData?.value.balanceVnd ?? cachedVnd;
    final isVip = walletAsync.asData?.value.isVip ?? PreferencesService.getLocalIsVip();

    return InkWell(
      onTap: () {
        final authState = ref.read(authStateProvider);
        if (authState.isGuest) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.darkSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.primary),
              ),
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Vui lòng đăng nhập tài khoản Độc giả để nạp và quản lý Ví tiền.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: Colors.white),
              ),
            ),
          );
          AuthModalSheet.show(context);
        } else {
          WalletTopupDialog.show(context);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isVip ? AppColors.mint.withValues(alpha: 0.6) : AppColors.darkBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              formatVnd(balanceVnd),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (isVip) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'VIP',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
