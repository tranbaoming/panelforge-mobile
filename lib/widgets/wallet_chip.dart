import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../providers/api_providers.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import 'auth_modal_sheet.dart';
import 'wallet_topup_dialog.dart';

/// Chip hiển thị số dư Ví tiền (VNĐ) trên Header
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

    return InkWell(
      onTap: () {
        final authState = ref.read(authStateProvider);
        if (!authState.isAuthenticated) {
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
          color: ForgeColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ForgeColors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: ForgeColors.gold, size: 15),
            const SizedBox(width: 5),
            Text(formatVnd(balanceVnd), style: ForgeText.tabular(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
