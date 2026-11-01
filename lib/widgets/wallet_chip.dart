import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/api_providers.dart';
import '../theme/app_theme.dart';
import 'wallet_topup_dialog.dart';

/// Chip hiển thị số dư ForgeCoins và huy hiệu VIP trên AppBar
class WalletChip extends ConsumerWidget {
  const WalletChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletNotifierProvider);
    final wallet = walletAsync.asData?.value;
    final coins = wallet?.balanceCoins ?? 0;
    final isVip = wallet?.isVip ?? false;

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
  }
}
