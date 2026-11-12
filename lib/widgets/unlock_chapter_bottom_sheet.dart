import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../models/comic_model.dart';
import '../providers/api_providers.dart';
import '../services/api_client.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import 'auth_modal_sheet.dart';
import 'vietqr_payment_panel.dart';
import 'wallet_topup_dialog.dart';

enum _UnlockMethod { wallet, vietQr }

/// Mở khóa chương trả phí do Producer cấu hình (`isLocked` + `priceVnd`).
///
/// - **Trừ Ví**: `POST /api/wallet/unlock-chapter` (miễn phí nếu có VIP).
/// - **VietQR trực tiếp**: `POST /api/wallet/topup` với purpose `ChapterUnlock` → đơn Pending xuất hiện ngay
///   trên màn hình Thanh toán của Producer; khi Producer xác nhận, chương được mở khóa tự động.
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

  /// Guest sẽ nhận SnackBar yêu cầu đăng nhập thay vì mở màn hình thanh toán.
  static Future<void> show(
    BuildContext context, {
    required ChapterItem chapter,
    SeriesItem? series,
    required VoidCallback onUnlocked,
  }) {
    final container = ProviderScope.containerOf(context, listen: false);
    if (!container.read(authStateProvider).isAuthenticated) {
      showLoginRequiredSnackBar(context, 'Vui lòng đăng nhập tài khoản Độc giả để mua chương này.');
      AuthModalSheet.show(context);
      return Future.value();
    }
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
  _UnlockMethod _method = _UnlockMethod.wallet;
  bool _isProcessing = false;
  String? _errorMessage;
  TopupResponse? _vietQrOrder;

  int get _priceVnd => widget.chapter.priceVnd;

  @override
  void initState() {
    super.initState();
    // Lấy số dư mới nhất (có thể vừa nạp ở thiết bị khác / vừa được Producer duyệt).
    Future.microtask(() => ref.read(walletNotifierProvider.notifier).refresh(silent: true));
  }

  bool _handleAuthError(Object e) {
    if (e is ApiException && e.statusCode == 401) {
      Navigator.of(context).pop();
      showLoginRequiredSnackBar(context, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để thanh toán.');
      AuthModalSheet.show(context);
      return true;
    }
    return false;
  }

  String _errorText(Object e) =>
      e is ApiException ? e.message : 'Không thể kết nối máy chủ thanh toán. Vui lòng thử lại.';

  Future<void> _unlockWithWallet() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final response = await ref
          .read(walletNotifierProvider.notifier)
          .unlockChapter(widget.chapter.id, seriesId: widget.series?.id);
      if (!mounted) return;
      _finishUnlocked(response.message ?? 'Mở khóa chương thành công!');
    } catch (e) {
      if (!mounted || _handleAuthError(e)) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = _errorText(e);
      });
    }
  }

  Future<void> _createVietQrOrder() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final order = await ref.read(monetizationServiceProvider).createVietQrOrder(
            purpose: PaymentPurpose.chapterUnlock,
            chapterId: widget.chapter.id,
            seriesId: widget.series?.id,
          );
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _vietQrOrder = order;
      });
    } catch (e) {
      if (!mounted || _handleAuthError(e)) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = _errorText(e);
      });
    }
  }

  /// Producer đã xác nhận đơn VietQR → Backend đã tạo quyền đọc; đồng bộ lại Ví & danh sách chương.
  Future<void> _onVietQrApproved(TransactionStatusDto status) async {
    ref.read(unlockedChaptersProvider.notifier).add(widget.chapter.id);
    await ref.read(walletNotifierProvider.notifier).refresh(silent: true);
    if (!mounted) return;
    _finishUnlocked('Studio đã xác nhận thanh toán ${formatVnd(status.amountVnd)}. Chương đã được mở khóa!');
  }

  void _finishUnlocked(String message) {
    final router = GoRouter.maybeOf(context);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    widget.onUnlocked();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.mint),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
    if (widget.series != null && router != null) {
      router.push('/reader/${widget.series!.id}?chapterId=${widget.chapter.id}');
    }
  }

  void _openTopupDialog() {
    final seriesId = widget.series?.id;
    final parentContext = Navigator.of(context).context;
    Navigator.of(context).pop();
    WalletTopupDialog.show(parentContext, seriesId: seriesId);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletNotifierProvider).asData?.value;
    final currentBalanceVnd = wallet?.balanceVnd ?? PreferencesService.getLocalBalanceVnd();
    final isVip = wallet?.hasActiveVip ?? PreferencesService.getLocalIsVip();
    final hasEnoughMoney = isVip || currentBalanceVnd >= _priceVnd;
    final missingVnd = (_priceVnd - currentBalanceVnd).clamp(0, 1 << 31);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.darkBorder, width: 1.5)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.darkBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            _buildHeader(),
            const SizedBox(height: 16),
            if (_vietQrOrder != null)
              VietQrPaymentPanel(
                key: ValueKey(_vietQrOrder!.orderId),
                order: _vietQrOrder!,
                title: 'Quét VietQR để mở khóa chương • ${formatVnd(_vietQrOrder!.amountVnd)}',
                onApproved: _onVietQrApproved,
                onCancel: () => setState(() => _vietQrOrder = null),
              )
            else ...[
              if (!isVip) ...[
                _buildMethodSelector(),
                const SizedBox(height: 14),
              ],
              if (isVip || _method == _UnlockMethod.wallet)
                _buildWalletSummary(currentBalanceVnd, isVip, hasEnoughMoney)
              else
                _buildVietQrHint(),
              const SizedBox(height: 16),
              if (_errorMessage != null) _buildError(_errorMessage!),
              if (!isVip && _method == _UnlockMethod.wallet && !hasEnoughMoney)
                _buildInsufficientBanner(missingVnd),
              _buildPrimaryAction(isVip, hasEnoughMoney),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                widget.chapter.title,
                style: GoogleFonts.newsreader(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Chương trả phí • Mở khóa vĩnh viễn ${formatVnd(_priceVnd)}',
                style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.darkTextSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSelector() {
    Widget option(_UnlockMethod method, IconData icon, String title, String subtitle) {
      final selected = _method == method;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isProcessing ? null : () => setState(() => _method = method),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.darkBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: selected ? AppColors.primary : Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.primary : Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      size: 16,
                      color: selected ? AppColors.primary : AppColors.darkTextSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppColors.darkTextSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(_UnlockMethod.wallet, Icons.account_balance_wallet_rounded, 'Trừ số dư Ví', 'Mở khóa tức thì'),
        const SizedBox(width: 10),
        option(_UnlockMethod.vietQr, Icons.qr_code_2_rounded, 'Chuyển khoản VietQR', 'Studio xác nhận'),
      ],
    );
  }

  Widget _buildWalletSummary(int balance, bool isVip, bool hasEnoughMoney) {
    Widget row(String label, String value, {Color color = Colors.white, bool bold = false}) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: bold ? Colors.white70 : AppColors.darkTextSecondary)),
            Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          row('Số dư Ví hiện tại:', formatVnd(balance)),
          const SizedBox(height: 10),
          row('Giá mở khóa:', isVip ? '0đ (VIP)' : '-${formatVnd(_priceVnd)}',
              color: isVip ? AppColors.mint : AppColors.primary),
          const Divider(color: AppColors.darkBorder, height: 22),
          row('Số dư sau thanh toán:', formatVnd(isVip ? balance : balance - _priceVnd),
              color: hasEnoughMoney ? AppColors.mint : AppColors.rose, bold: true),
        ],
      ),
    );
  }

  Widget _buildVietQrHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(
        'Hệ thống tạo mã VietQR ${formatVnd(_priceVnd)} chuyển thẳng vào tài khoản của Studio. '
        'Chương được mở khóa ngay khi Studio xác nhận đã nhận tiền.',
        style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: Colors.white70, height: 1.4),
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
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
              child: Text(message, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsufficientBanner(int missingVnd) {
    return Padding(
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
                'Số dư Ví không đủ (thiếu ${formatVnd(missingVnd)}). Nạp thêm hoặc chọn chuyển khoản VietQR.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.rose),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryAction(bool isVip, bool hasEnoughMoney) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final labelStyle = GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700);
    const spinner = SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );

    if (!isVip && _method == _UnlockMethod.vietQr) {
      return ElevatedButton.icon(
        onPressed: _isProcessing ? null : _createVietQrOrder,
        icon: _isProcessing ? spinner : const Icon(Icons.qr_code_rounded, size: 18),
        label: Text('Tạo mã VietQR ${formatVnd(_priceVnd)}', style: labelStyle),
        style: style,
      );
    }
    if (!hasEnoughMoney) {
      return ElevatedButton.icon(
        onPressed: _openTopupDialog,
        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
        label: Text('Nạp thêm tiền vào Ví', style: labelStyle),
        style: style,
      );
    }
    return ElevatedButton(
      onPressed: _isProcessing ? null : _unlockWithWallet,
      style: style,
      child: _isProcessing
          ? spinner
          : Text(
              isVip ? 'Mở khóa ngay (Đặc quyền VIP)' : 'Thanh toán ${formatVnd(_priceVnd)} & Đọc ngay',
              style: labelStyle,
            ),
    );
  }
}
