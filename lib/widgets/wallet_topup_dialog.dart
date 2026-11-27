import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../providers/api_providers.dart';
import '../services/api_client.dart';
import '../services/google_play_billing_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';
import 'auth_modal_sheet.dart';
import 'vietqr_payment_panel.dart';
import 'wallet_history.dart';

/// Mệnh giá nạp Ví VietQR (dùng chung cho hộp thoại Ví và tab Cửa hàng). Không có thưởng thêm — Backend không hỗ trợ.
const List<({int amount, String tag})> kTopupPackages = [
  (amount: 10000, tag: 'Cơ bản'),
  (amount: 20000, tag: '7 chương'),
  (amount: 50000, tag: 'Phổ biến'),
  (amount: 100000, tag: 'Tiết kiệm'),
  (amount: 200000, tag: 'VIP Độc giả'),
];

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

class _WalletTopupDialogState extends ConsumerState<WalletTopupDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Tab 1: Mệnh giá nạp VNĐ
  int _selectedAmountVnd = 50000;
  bool _isLoadingQr = false;
  TopupResponse? _topupData;
  StreamSubscription<BillingEvent>? _billingSub;

  static bool get _useGooglePlayBilling => GooglePlayBillingService.isSupportedPlatform;

  List<({int amount, String tag})> get _vndPackages => kTopupPackages;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
    // Mở Ví từ bất kỳ đâu (Cài đặt, sheet mở khóa chương...) → lấy số dư & lịch sử mới nhất,
    // giữ dữ liệu đang hiện trong lúc tải để không nháy.
    Future.microtask(() {
      if (mounted && ref.read(authStateProvider).isAuthenticated) {
        ref.read(walletNotifierProvider.notifier).refresh(silent: true);
      }
    });
    if (_useGooglePlayBilling) {
      // Thông báo kết quả do PanelForgeApp hiển thị; hộp thoại chỉ tắt trạng thái đang mua.
      _billingSub = ref.read(googlePlayBillingProvider).events.listen((event) {
        if (!mounted) return;
        if (_isLoadingQr) setState(() => _isLoadingQr = false);
      });
    }
  }

  @override
  void dispose() {
    _billingSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _startTopup() async {
    if (_useGooglePlayBilling) {
      setState(() => _isLoadingQr = true);
      try {
        final started = await ref.read(googlePlayBillingProvider).buyTopupAmount(_selectedAmountVnd);
        if (!started && mounted) {
          setState(() => _isLoadingQr = false);
          showPaymentErrorSnackBar(
            context,
            'Gói nạp chưa sẵn sàng trên Google Play Store. Vui lòng kiểm tra tài khoản CH Play và thử lại.',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingQr = false);
          showPaymentErrorSnackBar(context, 'Không thể khởi tạo thanh toán Google Play: $e');
        }
      }
      return;
    }
    await _generateVietQR();
  }

  Future<void> _generateVietQR() async {
    setState(() {
      _isLoadingQr = true;
      _topupData = null;
    });

    try {
      final order = await ref
          .read(monetizationServiceProvider)
          .createVietQrOrder(purpose: PaymentPurpose.topup, amountVnd: _selectedAmountVnd, seriesId: widget.seriesId);
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
                          style: GoogleFonts.newsreader(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
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
                                  const Icon(Icons.account_balance_wallet_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    currentVnd == null ? 'Đang tải...' : formatVnd(currentVnd),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.darkTextSecondary,
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(icon: Icon(Icons.qr_code_rounded, size: 16), text: 'Nạp Tiền Vào Ví'),
                  Tab(icon: Icon(Icons.history_rounded, size: 16), text: 'Lịch Sử Giao Dịch'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Bar Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildTopupTab(), _buildTransactionHistoryTab()],
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
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
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
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.darkCard,
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

          // Nút nạp tiền (Google Play Billing trên Android CH Play; fallback VietQR trên Desktop/Dev)
          ElevatedButton(
            onPressed: _isLoadingQr ? null : _startTopup,
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
                    _useGooglePlayBilling ? 'Thanh Toán Qua Google Play' : 'Tạo Mã VietQR Thanh Toán',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            _useGooglePlayBilling
                ? 'Thanh toán an toàn qua Google Play Billing. Số dư được cộng ngay khi xác thực.'
                : 'Số dư được cộng ngay khi Studio xác nhận đã nhận tiền.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.darkTextSecondary),
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
                child: const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Chưa có giao dịch nào',
                style: GoogleFonts.newsreader(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Lịch sử nạp tiền và thanh toán chapter sẽ hiển thị tại đây.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return WalletHistoryList(transactions: transactions);
  }
}
