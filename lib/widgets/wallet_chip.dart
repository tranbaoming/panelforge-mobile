import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/api_providers.dart';
import '../theme/app_theme.dart';
import 'wallet_topup_dialog.dart';

/// Chip hiển thị số dư ForgeCoins và huy hiệu VIP trên AppBar
/// Tự động ẩn hoàn toàn (SizedBox.shrink) khi chưa kết nối được với máy chủ (Backend)
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

    // Chỉ khi nhận được dữ liệu thực tế thành công từ Backend (AsyncData) mới hiển thị
    return walletAsync.when(
      data: (wallet) {
        final coins = wallet.balanceCoins;
        final isVip = wallet.isVip;

        return InkWell(
          onTap: () => WalletTopupDialog.show(context),
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
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '$coins',
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
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
