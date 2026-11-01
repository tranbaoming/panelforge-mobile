import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comic_model.dart';
import '../providers/api_providers.dart';
import '../theme/app_theme.dart';
import 'wallet_topup_dialog.dart';

class UnlockChapterBottomSheet extends ConsumerStatefulWidget {
  final ChapterItem chapter;
  final VoidCallback onUnlocked;

  const UnlockChapterBottomSheet({
    super.key,
    required this.chapter,
    required this.onUnlocked,
  });

  static Future<void> show(
    BuildContext context, {
    required ChapterItem chapter,
    required VoidCallback onUnlocked,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UnlockChapterBottomSheet(
        chapter: chapter,
        onUnlocked: onUnlocked,
      ),
    );
  }

  @override
  ConsumerState<UnlockChapterBottomSheet> createState() => _UnlockChapterBottomSheetState();
}

class _UnlockChapterBottomSheetState extends ConsumerState<UnlockChapterBottomSheet> {
  bool _isUnlocking = false;
  String? _errorMessage;

  Future<void> _handleUnlock(int price) async {
    setState(() {
      _isUnlocking = true;
      _errorMessage = null;
    });

    try {
      final response = await ref.read(walletNotifierProvider.notifier).unlockChapter(
            widget.chapter.id,
            price,
          );

      if (mounted) {
        setState(() => _isUnlocking = false);
        Navigator.of(context).pop();
        widget.onUnlocked();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.darkSurface,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    response.message ?? 'Đã mở khóa chương thành công!',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUnlocking = false;
          _errorMessage = e.toString().replaceAll('ApiException: ', '');
        });
      }
    }
  }

  void _openTopupDialog() {
    Navigator.of(context).pop();
    WalletTopupDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletNotifierProvider);
    final wallet = walletState.asData?.value;
    final currentCoins = wallet?.balanceCoins ?? 0;
    final isVip = wallet?.isVip ?? false;
    final price = widget.chapter.priceCoins > 0 ? widget.chapter.priceCoins : 50;
    final hasEnoughCoins = currentCoins >= price || isVip;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.darkBorder, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
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

          // Lock badge & Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mở Khóa Chương Truyện',
                      style: GoogleFonts.newsreader(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chương ${widget.chapter.number}: ${widget.chapter.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Price & Balance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Giá mở khóa:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          isVip ? 'Miễn phí (VIP)' : '$price Coins',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isVip ? AppColors.mint : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(color: AppColors.darkBorder, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Số dư ví của bạn:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 16,
                          color: hasEnoughCoins ? AppColors.mint : AppColors.amber,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$currentCoins Coins',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: hasEnoughCoins ? Colors.white : AppColors.amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Error Message if any
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.rose.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Action Button
          if (hasEnoughCoins)
            ElevatedButton(
              onPressed: _isUnlocking ? null : () => _handleUnlock(price),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isUnlocking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      isVip ? 'Mở Khóa Ngay (Đặc Quyền VIP)' : 'Mở Khóa Ngay (-$price Coins)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            )
          else
            ElevatedButton.icon(
              onPressed: _openTopupDialog,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(
                'Nạp Thêm ForgeCoins',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

          const SizedBox(height: 14),

          // VIP Pass Banner
          GestureDetector(
            onTap: _openTopupDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.darkCard,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nâng Cấp VIP Pass',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Đọc toàn bộ chương và tải CBZ Offline không giới hạn',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
