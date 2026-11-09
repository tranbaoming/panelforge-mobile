import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../models/comic_model.dart';
import '../providers/api_providers.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import 'auth_modal_sheet.dart';
import 'wallet_topup_dialog.dart';

class UnlockChapterBottomSheet extends ConsumerStatefulWidget {
  final ChapterItem chapter;
  final SeriesItem? series;
  final VoidCallback onUnlocked;

  const UnlockChapterBottomSheet({
    super.key,
    required this.chapter,
    this.series,
    required this.onUnlocked,
  });

  static Future<void> show(
    BuildContext context, {
    required ChapterItem chapter,
    SeriesItem? series,
    required VoidCallback onUnlocked,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UnlockChapterBottomSheet(
        chapter: chapter,
        series: series,
        onUnlocked: onUnlocked,
      ),
    );
  }

  @override
  ConsumerState<UnlockChapterBottomSheet> createState() => _UnlockChapterBottomSheetState();
}

class _UnlockChapterBottomSheetState extends ConsumerState<UnlockChapterBottomSheet> {
  bool _isUnlocking = false;
  bool _isPermanentSelected = true;
  String? _errorMessage;

  int _calculatePermanentPriceVnd() {
    if (widget.chapter.isFree) return 0;
    if (widget.chapter.priceVnd > 0) return widget.chapter.priceVnd;
    if (widget.chapter.isWeeklyHot) return 5000;
    if (widget.series != null && widget.series!.baseChapterPriceVnd > 0) {
      return widget.series!.baseChapterPriceVnd;
    }
    if (widget.chapter.priceCoins > 0) {
      return widget.chapter.priceCoins * 100;
    }
    return 1000;
  }

  int _calculateRentalPriceVnd() {
    if (widget.chapter.isFree) return 0;
    if (widget.chapter.rentalPriceVnd > 0) return widget.chapter.rentalPriceVnd;
    final perm = _calculatePermanentPriceVnd();
    if (perm <= 500) return 300;
    if (perm <= 700) return 500;
    if (perm <= 1000) return 500;
    if (perm >= 5000) return 2000;
    return (perm * 0.5).round();
  }

  Future<void> _handleUnlock(int priceVnd, bool isPermanent) async {
    // Nếu đang là Guest, yêu cầu đăng nhập trước khi dùng Ví tiền
    if (ref.read(authStateProvider).isGuest) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primary),
          ),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Vui lòng đăng nhập tài khoản Độc giả để thanh toán mở khóa chương.',
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: Colors.white),
          ),
        ),
      );
      AuthModalSheet.show(context);
      return;
    }

    setState(() {
      _isUnlocking = true;
      _errorMessage = null;
    });

    try {
      final response = await ref.read(walletNotifierProvider.notifier).unlockChapter(
            widget.chapter.id,
            priceVnd,
            seriesId: widget.series?.id,
            chapterTitle: widget.chapter.title,
            isPermanent: isPermanent,
            rentalViews: isPermanent ? null : 3,
          );

      if (mounted) {
        setState(() => _isUnlocking = false);
        Navigator.of(context).pop();
        widget.onUnlocked();

        final msg = response.message ??
            'Đã trừ ${formatVnd(priceVnd)} trong Ví. Mở khóa chương thành công!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.darkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.mint, width: 1),
            ),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 20),
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

        // Tự động điều hướng vào trang đọc nếu có thông tin bộ truyện
        if (widget.series != null) {
          context.push('/reader/${widget.series!.id}?chapterId=${widget.chapter.id}');
        }
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
    final cachedVnd = PreferencesService.getLocalBalanceVnd();
    final currentBalanceVnd = wallet?.balanceVnd ?? cachedVnd;
    final isVip = wallet?.isVip ?? PreferencesService.getLocalIsVip();

    final permanentPrice = _calculatePermanentPriceVnd();
    final rentalPrice = _calculateRentalPriceVnd();
    final selectedPrice = _isPermanentSelected ? permanentPrice : rentalPrice;

    final balanceAfter = currentBalanceVnd - selectedPrice;
    final hasEnoughMoney = isVip || balanceAfter >= 0;
    final missingVnd = (selectedPrice - currentBalanceVnd).clamp(0, 999999999);

    final bool isWeeklyHot = widget.chapter.isWeeklyHot || permanentPrice == 5000;
    final String pricingReason = isWeeklyHot
        ? '🔥 Chương đặc sắc mới phát hành trong tuần'
        : 'Chương tiêu chuẩn';

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

          // Header icon + Series Title + Chapter Title
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
                    if (widget.series != null)
                      Text(
                        widget.series!.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      widget.chapter.title,
                      style: GoogleFonts.newsreader(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pricing reason badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isWeeklyHot
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isWeeklyHot
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.darkBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isWeeklyHot ? Icons.whatshot_rounded : Icons.label_outline_rounded,
                  size: 14,
                  color: isWeeklyHot ? AppColors.primary : AppColors.darkTextSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  pricingReason,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isWeeklyHot ? AppColors.primary : AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2 Tùy chọn Mở Khóa: Xem giới hạn (Tiết kiệm) vs Sở hữu vĩnh viễn
          Row(
            children: [
              // Tùy chọn 1: Xem 3 lượt
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _isPermanentSelected = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isPermanentSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_isPermanentSelected ? AppColors.primary : AppColors.darkBorder,
                        width: !_isPermanentSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Thuê Xem 3 Lần',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: !_isPermanentSelected ? AppColors.primary : Colors.white,
                              ),
                            ),
                            Icon(
                              !_isPermanentSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 16,
                              color: !_isPermanentSelected ? AppColors.primary : AppColors.darkTextSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '3 lượt đọc • Đọc online',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatVnd(rentalPrice),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: !_isPermanentSelected ? AppColors.primary : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Tùy chọn 2: Sở hữu vĩnh viễn
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _isPermanentSelected = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isPermanentSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isPermanentSelected ? AppColors.primary : AppColors.darkBorder,
                        width: _isPermanentSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Mua Vĩnh Viễn',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _isPermanentSelected ? AppColors.primary : Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.mint.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'CBZ',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.mint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              _isPermanentSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              size: 16,
                              color: _isPermanentSelected ? AppColors.primary : AppColors.darkTextSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mãi mãi • Tải offline',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatVnd(permanentPrice),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _isPermanentSelected ? AppColors.primary : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Balance calculation table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                // Row 1: Số dư Ví hiện tại
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Số dư Ví hiện tại:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 14,
                          color: AppColors.darkTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatVnd(currentBalanceVnd),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Row 2: Giá mở khóa chương này
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPermanentSelected ? 'Giá mua vĩnh viễn:' : 'Giá thuê 3 lượt xem:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    Text(
                      isVip ? '0đ (VIP)' : '-${formatVnd(selectedPrice)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isVip ? AppColors.mint : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.darkBorder, height: 22),

                // Row 3: Số dư Ví sau thanh toán
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Số dư Ví sau thanh toán:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      isVip ? formatVnd(currentBalanceVnd) : formatVnd(balanceAfter),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: hasEnoughMoney ? AppColors.mint : AppColors.rose,
                      ),
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

          // If not enough money: Warning banner
          if (!hasEnoughMoney)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.rose, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Số dư trong Ví không đủ (thiếu ${formatVnd(missingVnd)})',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.rose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Action Button
          if (hasEnoughMoney)
            ElevatedButton(
              onPressed: _isUnlocking ? null : () => _handleUnlock(selectedPrice, _isPermanentSelected),
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
                      isVip
                          ? 'Mở Khóa Ngay (Đặc Quyền VIP)'
                          : 'Thanh toán ${formatVnd(selectedPrice)} & Đọc ngay',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            )
          else
            ElevatedButton.icon(
              onPressed: _openTopupDialog,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(
                'Nạp thêm tiền vào Ví ngay',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }
}
