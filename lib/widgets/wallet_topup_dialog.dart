import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../providers/api_providers.dart';
import '../services/preferences_service.dart';
import '../theme/app_theme.dart';

class WalletTopupDialog extends ConsumerStatefulWidget {
  final int initialTab;

  const WalletTopupDialog({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => WalletTopupDialog(initialTab: initialTab),
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
  bool _isConfirming = false;

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
      final service = ref.read(monetizationServiceProvider);
      final response = await service.requestTopup(
        amountVnd: _selectedAmountVnd,
      );
      if (mounted) {
        setState(() {
          _isLoadingQr = false;
          _topupData = response;
        });
      }
    } catch (e) {
      debugPrint('[WalletTopupDialog QR error] $e');
      if (mounted) {
        setState(() {
          _isLoadingQr = false;
          _topupData = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.darkSurface,
            content: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: AppColors.rose, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Không thể kết nối đến máy chủ thanh toán. Đang dùng mã VietQR dự phòng.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmPayment() async {
    if (_topupData == null) return;
    setState(() => _isConfirming = true);

    await Future.delayed(const Duration(milliseconds: 600));
    await ref.read(walletNotifierProvider.notifier).completeTopup(
          orderId: _topupData!.orderId,
          amountVnd: _topupData!.amountVnd,
        );

    if (mounted) {
      final addedAmount = _topupData!.amountVnd;
      setState(() {
        _isConfirming = false;
        _topupData = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.mint, width: 1),
          ),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 20),
              const SizedBox(width: 10),
              Text(
                'Nạp thành công +${formatVnd(addedAmount)} vào Ví!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label!'),
        duration: const Duration(seconds: 1),
      ),
    );
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
      final qr = _topupData!;
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                children: [
                  Text(
                    'Quét mã VietQR để nạp ${formatVnd(qr.amountVnd)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // QR Image Container
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: qr.qrCodeUrl != null
                        ? CachedNetworkImage(
                            imageUrl: qr.qrCodeUrl!,
                            width: 170,
                            height: 170,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const SizedBox(
                              width: 170,
                              height: 170,
                              child: Center(
                                child: CircularProgressIndicator(color: AppColors.primary),
                              ),
                            ),
                            errorWidget: (context, url, error) => const SizedBox(
                              width: 170,
                              height: 170,
                              child: Center(
                                child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                              ),
                            ),
                          )
                        : const SizedBox(
                            width: 170,
                            height: 170,
                            child: Center(child: Icon(Icons.qr_code_2_rounded, size: 80)),
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Thông tin chuyển khoản
                  _buildInfoRow('Ngân hàng:', qr.bankName ?? 'Vietcombank'),
                  _buildCopyRow('Số tài khoản:', qr.accountNumber ?? '9876543210'),
                  _buildInfoRow('Chủ tài khoản:', qr.accountName ?? 'PANELFORGE COMICS'),
                  _buildInfoRow('Số tiền:', formatVnd(qr.amountVnd), highlight: true),
                  _buildCopyRow('Nội dung CK:', qr.transferContent ?? 'PFWALLET ${qr.orderId}'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Nút Xác nhận chuyển khoản
            ElevatedButton(
              onPressed: _isConfirming ? null : _confirmPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mint,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isConfirming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      'Tôi Đã Chuyển Khoản Thành Công',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(height: 8),

            TextButton(
              onPressed: () => setState(() => _topupData = null),
              child: Text(
                'Chọn mệnh giá khác',
                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
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
            'Hệ thống tự động cộng tiền ngay sau khi xác nhận chuyển khoản thành công.',
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
    final transactions = PreferencesService.getWalletTransactions();

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

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: highlight ? AppColors.primary : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
          ),
          Row(
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _copyToClipboard(value, label),
                child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
