import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../providers/api_providers.dart';
import '../services/api_client.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import 'auth_modal_sheet.dart';
import 'vietqr_payment_panel.dart';

class WalletTopupDialog extends ConsumerStatefulWidget {
  final int initialTab;

  /// Ngữ cảnh bộ truyện đang đọc — giúp đơn nạp hiển thị đúng Studio trên màn hình Thanh toán của Producer.
  final String? seriesId;

  const WalletTopupDialog({super.key, this.initialTab = 0, this.seriesId});

  /// Mở Ví. Guest sẽ được yêu cầu đăng nhập trước khi thanh toán.
  static Future<void> show(BuildContext context, {int initialTab = 0, String? seriesId}) {
    final container = ProviderScope.containerOf(context, listen: false);
    if (!container.read(authStateProvider).isAuthenticated) {
      showLoginRequiredSnackBar(context, 'Vui lòng đăng nhập tài khoản Độc giả để nạp tiền vào Ví.');
      AuthModalSheet.show(context);
      return Future.value();
    }
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => WalletTopupDialog(initialTab: initialTab, seriesId: seriesId),
    );
  }

  @override
  ConsumerState<WalletTopupDialog> createState() => _WalletTopupDialogState();
}

class _WalletTopupDialogState extends ConsumerState<WalletTopupDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Tab 1: Mệnh giá nạp VNĐ
  int _selectedAmountVnd = 50000;
  bool _isLoadingQr = false;
  TopupResponse? _topupData;

  final _vndPackages = const [
    (amount: 10000, tag: 'Cơ bản'),
    (amount: 20000, tag: '7 chương'),
    (amount: 50000, tag: 'Phổ biến'),
    (amount: 100000, tag: 'Tiết kiệm'),
    (amount: 200000, tag: 'VIP Độc giả'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateVietQR() async {
    setState(() {
      _isLoadingQr = true;
      _topupData = null;
    });

    try {
      final order = await ref.read(monetizationServiceProvider).createVietQrOrder(
            purpose: PaymentPurpose.topup,
            amountVnd: _selectedAmountVnd,
            seriesId: widget.seriesId,
          );
      if (mounted) {
        setState(() {
          _isLoadingQr = false;
          _topupData = order;
        });
      }
    } catch (e) {
      debugPrint('[WalletTopupDialog] Tạo đơn VietQR thất bại: $e');
      if (!mounted) return;
      setState(() => _isLoadingQr = false);
      if (e is ApiException && e.statusCode == 401) {
        Navigator.of(context).pop();
        showLoginRequiredSnackBar(context, 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để nạp tiền.');
        AuthModalSheet.show(context);
        return;
      }
      showPaymentErrorSnackBar(
        context,
        e is ApiException ? e.message : 'Không thể tạo mã VietQR. Vui lòng kiểm tra kết nối mạng và thử lại.',
      );
    }
  }

  /// Producer đã duyệt đơn nạp trên Web → làm mới số dư thật từ `/api/wallet/me`.
  Future<void> _onTopupApproved(TransactionStatusDto status) async {
    await ref.read(walletNotifierProvider.notifier).refresh(silent: true);
    if (!mounted) return;
    setState(() => _topupData = null);
    showPaymentSuccessSnackBar(context, 'Nạp thành công +${formatVnd(status.amountVnd)} vào Ví!');
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletNotifierProvider);
    final wallet = walletState.asData?.value;
    final cachedVnd = PreferencesService.getLocalBalanceVnd();
    final currentVnd = wallet?.balanceVnd ?? cachedVnd;
    final isVip = wallet?.isVip ?? PreferencesService.getLocalIsVip();

    return Dialog(
      backgroundColor: AppColors.darkSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 700),
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ví Tiền PanelForge',
                          style: GoogleFonts.newsreader(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    formatVnd(currentVnd),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isVip) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.mint.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.mint.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'VIP ACTIVE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.mint,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.darkTextSecondary,
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.qr_code_rounded, size: 16),
                    text: 'Nạp Tiền Vào Ví',
                  ),
                  Tab(
                    icon: Icon(Icons.history_rounded, size: 16),
                    text: 'Lịch Sử Giao Dịch',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Bar Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTopupTab(),
                  _buildTransactionHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 1: NẠP TIỀN VÀO VÍ ────────────────────────────────────────────────
  Widget _buildTopupTab() {
    if (_topupData != null) {
      final order = _topupData!;
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: VietQrPaymentPanel(
          key: ValueKey(order.orderId),
          order: order,
          title: 'Quét mã VietQR để nạp ${formatVnd(order.amountVnd)} vào Ví',
          onApproved: _onTopupApproved,
          onCancel: () => setState(() => _topupData = null),
        ),
      );
    }


    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Chọn mệnh giá nạp vào Ví:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Danh sách các gói mệnh giá VNĐ
          ..._vndPackages.map((pkg) {
            final isSelected = _selectedAmountVnd == pkg.amount;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedAmountVnd = pkg.amount);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.darkBorder,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? AppColors.primary : AppColors.darkTextSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formatVnd(pkg.amount),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            pkg.tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppColors.primary : AppColors.darkTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 14),

          // Nút tạo mã VietQR
          ElevatedButton(
            onPressed: _isLoadingQr ? null : _generateVietQR,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoadingQr
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Tạo Mã VietQR Thanh Toán',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'Số dư được cộng ngay khi Studio xác nhận đã nhận tiền.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: LỊCH SỬ GIAO DỊCH ──────────────────────────────────────────────
  Widget _buildTransactionHistoryTab() {
    final transactions = ref.watch(walletNotifierProvider).asData?.value.transactions ?? const [];

    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 40,
                  color: AppColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có giao dịch nào',
                style: GoogleFonts.newsreader(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Lịch sử nạp tiền và thanh toán chapter sẽ hiển thị tại đây.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const Divider(color: AppColors.darkBorder, height: 1),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isPositive = tx.amountVnd > 0;
        final dateStr =
            '${tx.createdAt.day.toString().padLeft(2, '0')}/${tx.createdAt.month.toString().padLeft(2, '0')}/${tx.createdAt.year} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPositive
                      ? AppColors.mint.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                  color: isPositive ? AppColors.mint : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr • Sau GD: ${formatVnd(tx.balanceAfter)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatVnd(tx.amountVnd, showSign: true),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isPositive ? AppColors.mint : AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
