import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/api_dtos.dart';
import '../providers/api_providers.dart';
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

  // Tab 1: Topup
  int _selectedCoins = 500;
  int _selectedAmountVnd = 90000;
  bool _isLoadingQr = false;
  TopupResponse? _topupData;
  bool _isConfirming = false;

  // Tab 2: VIP
  String _selectedVipPlan = 'monthly';
  bool _isSubscribingVip = false;
  String? _vipMessage;

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

  final _coinPackages = const [
    (coins: 100, price: 20000, tag: 'Cơ bản'),
    (coins: 500, price: 90000, tag: 'Phổ biến • -10%'),
    (coins: 1000, price: 160000, tag: 'Ưu đãi • -20%'),
  ];

  Future<void> _generateVietQR() async {
    setState(() {
      _isLoadingQr = true;
      _topupData = null;
    });

    try {
      final service = ref.read(monetizationServiceProvider);
      final response = await service.requestTopup(
        coinsAmount: _selectedCoins,
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
                    'Không thể kết nối đến máy chủ thanh toán. Vui lòng kiểm tra lại kết nối mạng hoặc thử lại sau.',
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

    await Future.delayed(const Duration(milliseconds: 600)); // Simulate gateway check
    await ref.read(walletNotifierProvider.notifier).completeTopup(
          orderId: _topupData!.orderId,
          coinsAmount: _topupData!.coins,
        );

    if (mounted) {
      setState(() {
        _isConfirming = false;
        _topupData = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurface,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 20),
              const SizedBox(width: 10),
              Text(
                'Nạp thành công +$_selectedCoins ForgeCoins vào ví!',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _handleSubscribeVip() async {
    setState(() {
      _isSubscribingVip = true;
      _vipMessage = null;
    });

    try {
      final res = await ref.read(walletNotifierProvider.notifier).subscribeVip(_selectedVipPlan);
      if (mounted) {
        setState(() {
          _isSubscribingVip = false;
          _vipMessage = res.message ?? 'Đăng ký VIP thành công!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubscribingVip = false;
          _vipMessage = e.toString().replaceAll('ApiException: ', '');
        });
      }
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
    final currentCoins = wallet?.balanceCoins ?? 0;
    final isVip = wallet?.isVip ?? false;
    final currencyFormat = NumberFormat('#,###', 'vi_VN');

    return Dialog(
      backgroundColor: AppColors.darkSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 680),
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
                          'Ví ForgeCoins & Gói VIP',
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
                                  const Icon(Icons.monetization_on_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  if (walletState.isLoading)
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    )
                                  else if (walletState.hasError)
                                    Text(
                                      'Chưa kết nối',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.rose,
                                      ),
                                    )
                                  else
                                    Text(
                                      '$currentCoins Coins',
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 14, color: AppColors.mint),
                                    const SizedBox(width: 4),
                                    Text(
                                      'VIP ACTIVE',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.mint,
                                      ),
                                    ),
                                  ],
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
                  Tab(text: 'Nạp ForgeCoins'),
                  Tab(text: 'Gói VIP Pass'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab Bar Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTopupTab(currencyFormat),
                  _buildVipTab(currentCoins, isVip),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 1: NẠP COINS ──────────────────────────────────────────────────────
  Widget _buildTopupTab(NumberFormat currencyFormat) {
    if (_topupData != null) {
      final qr = _topupData!;
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (qr.qrCodeUrl != null)
                    CachedNetworkImage(
                      imageUrl: qr.qrCodeUrl!,
                      height: 180,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox(
                        height: 180,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => const SizedBox(
                        height: 180,
                        child: Center(
                          child: Icon(Icons.qr_code_2_rounded, size: 80, color: Colors.black54),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Quét mã qua ứng dụng ngân hàng bất kỳ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Transfer details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                children: [
                  _buildCopyRow('Ngân hàng:', qr.bankName ?? 'Vietcombank', qr.bankName ?? ''),
                  const Divider(color: AppColors.darkBorder, height: 16),
                  _buildCopyRow('Số tài khoản:', qr.accountNumber ?? '9876543210', qr.accountNumber ?? ''),
                  const Divider(color: AppColors.darkBorder, height: 16),
                  _buildCopyRow('Số tiền:', '${currencyFormat.format(qr.amountVnd)} đ', qr.amountVnd.toString()),
                  const Divider(color: AppColors.darkBorder, height: 16),
                  _buildCopyRow('Nội dung CK:', qr.transferContent ?? 'PF', qr.transferContent ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 14),

            ElevatedButton.icon(
              onPressed: _isConfirming ? null : _confirmPayment,
              icon: _isConfirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                _isConfirming ? 'Đang kiểm tra...' : 'Tôi Đã Chuyển Khoản',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mint,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _topupData = null),
              child: const Text('Chọn gói khác', style: TextStyle(color: Colors.white60, fontSize: 12)),
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
            'Chọn gói ForgeCoins:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkTextSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Packages
          ..._coinPackages.map((pkg) {
            final isSelected = _selectedCoins == pkg.coins;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCoins = pkg.coins;
                    _selectedAmountVnd = pkg.price;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.darkCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.darkBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.monetization_on_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pkg.coins} ForgeCoins',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              pkg.tag,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: isSelected ? AppColors.primary : AppColors.darkTextSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${currencyFormat.format(pkg.price)} đ',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isLoadingQr ? null : _generateVietQR,
            icon: _isLoadingQr
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.qr_code_rounded, size: 18),
            label: Text(
              _isLoadingQr ? 'Đang tạo mã...' : 'Tạo Mã Thanh Toán VietQR',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
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

  Widget _buildCopyRow(String label, String value, String rawCopy) {
    return Row(
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
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _copyToClipboard(rawCopy, label),
              child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
            ),
          ],
        ),
      ],
    );
  }

  // ─── TAB 2: GÓI VIP PASS ───────────────────────────────────────────────────
  Widget _buildVipTab(int currentCoins, bool isVip) {
    final isYearly = _selectedVipPlan == 'yearly';
    final cost = isYearly ? 1999 : 199;
    final hasEnough = currentCoins >= cost;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Privileges list
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đặc Quyền Hội Viên VIP:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                _buildPrivilegeItem('Đọc miễn phí toàn bộ chương truyện trả phí'),
                _buildPrivilegeItem('Tải Single-file CBZ không giới hạn đọc Offline'),
                _buildPrivilegeItem('Dịch thuật AI đa ngôn ngữ không giới hạn lượt'),
                _buildPrivilegeItem('Huy hiệu VIP Obsidian nổi bật trên tài khoản'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Plan selection: Monthly vs Yearly
          Row(
            children: [
              Expanded(
                child: _buildPlanCard(
                  title: 'Gói Tháng',
                  priceCoins: 199,
                  subtitle: '30 ngày',
                  selected: !isYearly,
                  onTap: () => setState(() => _selectedVipPlan = 'monthly'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPlanCard(
                  title: 'Gói Năm',
                  priceCoins: 1999,
                  subtitle: '365 ngày • Tiết kiệm 16%',
                  selected: isYearly,
                  onTap: () => setState(() => _selectedVipPlan = 'yearly'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_vipMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _vipMessage!,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          if (hasEnough)
            ElevatedButton(
              onPressed: _isSubscribingVip ? null : _handleSubscribeVip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubscribingVip
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Kích Hoạt VIP Ngay ($cost Coins)',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: Text(
                'Số dư không đủ • Nạp Coins để nâng cấp',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivilegeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required int priceCoins,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.monetization_on_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '$priceCoins',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.darkTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
