import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/api_dtos.dart';
import '../../providers/api_providers.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/vietqr_payment_panel.dart';
import '../../widgets/vip_purchase_sheet.dart';
import '../../widgets/wallet_topup_dialog.dart';

/// Tab Cửa hàng: thẻ "Tài sản của bạn" (số dư Ví thật + VIP) và hai thẻ
/// NẠP VÍ (mệnh giá VietQR → Studio duyệt) / GÓI VIP (trừ Ví hoặc VietQR).
/// Không có "xu" hay thưởng thêm — chỉ những gì Backend `/api/wallet/*` hỗ trợ.
class ShopPage extends ConsumerStatefulWidget {
  /// 0 = Nạp Ví, 1 = Gói VIP.
  final int initialTab;
  const ShopPage({super.key, this.initialTab = 0});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (ref.read(authStateProvider).isAuthenticated) {
        ref.read(walletNotifierProvider.notifier).refresh(silent: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ShopPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mở lại tab từ banner VIP (`/shop?tab=vip`) khi trang đã có sẵn trong nhánh.
    if (oldWidget.initialTab != widget.initialTab) _tabs.animateTo(widget.initialTab.clamp(0, 1));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Chưa đăng nhập → mở màn Đăng nhập; trả true khi đã đăng nhập.
  Future<bool> _ensureLoggedIn() async {
    if (ref.read(authStateProvider).isAuthenticated) return true;
    await context.push<bool>('/login');
    if (!mounted) return false;
    final ok = ref.read(authStateProvider).isAuthenticated;
    if (ok) ref.read(walletNotifierProvider.notifier).refresh();
    return ok;
  }

  Future<void> _buyTopup(int amount) async {
    if (!await _ensureLoggedIn() || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ForgeColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TopupOrderSheet(amountVnd: amount),
    );
  }

  Future<void> _buyVip(String plan) async {
    if (!await _ensureLoggedIn() || !mounted) return;
    await VipPurchaseSheet.show(context, initialPlan: plan);
  }

  Future<void> _openHistory() async {
    if (!await _ensureLoggedIn() || !mounted) return;
    await WalletTopupDialog.show(context, initialTab: 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForgeColors.bg,
      body: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: _BalanceCard(onLogin: _ensureLoggedIn)),
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabs,
                indicatorColor: ForgeColors.accent,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelColor: ForgeColors.text,
                unselectedLabelColor: ForgeColors.muted,
                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
                tabs: [
                  const Tab(text: 'NẠP VÍ'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('GÓI VIP'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: ForgeColors.gold, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.workspace_premium_rounded, size: 13, color: Color(0xFF13161F)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabs,
            children: [
              _TopupTab(onBuy: _buyTopup, onHistory: _openHistory),
              _VipTab(onBuy: _buyVip, onHistory: _openHistory),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Tài sản của bạn": số dư Ví (VNĐ) + trạng thái VIP từ `GET /api/wallet/me`.
class _BalanceCard extends ConsumerWidget {
  final Future<bool> Function() onLogin;
  const _BalanceCard({required this.onLogin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authStateProvider).isAuthenticated;
    final walletState = authed ? ref.watch(walletNotifierProvider) : null;
    final wallet = walletState?.asData?.value;
    final isVip = wallet?.hasActiveVip ?? false;
    final expires = wallet?.vipExpiresAt;

    final walletError = wallet == null ? walletState?.error : null;
    final sessionExpired = walletError is ApiException && walletError.statusCode == 401;

    Widget notice(String text, String button, VoidCallback onPressed) => Row(
      children: [
        Expanded(
          child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: ForgeColors.textSoft)),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(foregroundColor: ForgeColors.accent),
          child: Text(button, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );

    Widget content;
    if (!authed) {
      content = notice('Đăng nhập để xem số dư Ví và gói VIP.', 'Đăng nhập', onLogin);
    } else if (sessionExpired) {
      content = notice('Phiên đăng nhập đã hết hạn. Đăng nhập lại để xem Ví.', 'Đăng nhập', () async {
        await context.push<bool>('/login');
        ref.read(walletNotifierProvider.notifier).refresh();
      });
    } else if (walletError != null) {
      content = notice(
        'Không tải được số dư Ví.',
        'Thử lại',
        () => ref.read(walletNotifierProvider.notifier).refresh(),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Text(
                'Tài sản của bạn:',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: ForgeColors.muted),
              ),
              const Spacer(),
              _Chip(
                icon: Icons.workspace_premium_rounded,
                color: isVip ? ForgeColors.gold : ForgeColors.chip,
                text: isVip ? 'VIP' : 'Chưa VIP',
              ),
              const SizedBox(width: 12),
              const _Chip(icon: Icons.account_balance_wallet_rounded, color: ForgeColors.gold, text: ''),
              const SizedBox(width: 4),
              walletState?.isLoading == true && wallet == null
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ForgeColors.accent),
                    )
                  : Text(
                      wallet == null ? '—' : formatVnd(wallet.balanceVnd),
                      style: ForgeText.tabular(fontSize: 22, color: ForgeColors.gold),
                    ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isVip
                ? (expires == null ? 'VIP đang hoạt động.' : 'VIP còn hạn đến ${_date(expires)}.')
                : 'Nạp Ví bằng VietQR — Studio xác nhận là tiền vào Ví.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.textSoft),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ForgeColors.border),
      ),
      child: content,
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Chip({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color,
          child: Icon(icon, size: 14, color: color == ForgeColors.gold ? const Color(0xFF13161F) : ForgeColors.muted),
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: ForgeColors.text),
          ),
        ],
      ],
    );
  }
}

/// Thẻ NẠP VÍ: mỗi dòng là một mệnh giá + nút giá → tạo đơn VietQR.
class _TopupTab extends StatelessWidget {
  final void Function(int amount) onBuy;
  final VoidCallback onHistory;
  const _TopupTab({required this.onBuy, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Số dư Ví dùng để mở khóa chương trả phí hoặc mua VIP. '
            'Mỗi lần nạp tạo một mã VietQR; tiền vào Ví khi Studio xác nhận đã nhận.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: ForgeColors.textSoft, height: 1.4),
          ),
        ),
        for (final pkg in kTopupPackages) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 15,
                  backgroundColor: ForgeColors.gold,
                  child: Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF13161F)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('+${formatVnd(pkg.amount)}', style: ForgeText.tabular(fontSize: 19)),
                      Text(pkg.tag, style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.muted)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => onBuy(pkg.amount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ForgeColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      textStyle: ForgeText.tabular(fontSize: 16),
                    ),
                    child: Text(formatVnd(pkg.amount)),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: ForgeColors.divider),
        ],
        const SizedBox(height: 8),
        _ShopLinks(onHistory: onHistory),
      ],
    );
  }
}

/// Thẻ GÓI VIP: giá thật theo `VipPurchaseSheet` (khớp `VipPricing` ở Backend), quyền lợi và nút đăng ký.
class _VipTab extends ConsumerWidget {
  final void Function(String plan) onBuy;
  final VoidCallback onHistory;
  const _VipTab({required this.onBuy, required this.onHistory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authStateProvider).isAuthenticated;
    final isVip = authed && (ref.watch(walletNotifierProvider).asData?.value.hasActiveVip ?? false);

    Widget benefit(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: ForgeColors.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: ForgeColors.text,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            color: ForgeColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ForgeColors.gold.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVip ? 'Bạn đang là VIP' : 'Đăng ký VIP PanelForge',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: ForgeColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Đọc mọi chương trả phí khi gói còn hạn',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: ForgeColors.textSoft),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.workspace_premium_rounded, color: ForgeColors.gold, size: 48),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final plan in const [
          ('monthly', VipPurchaseSheet.monthlyVnd, 'tháng', '30 ngày'),
          ('yearly', VipPurchaseSheet.yearlyVnd, 'năm', '365 ngày • tiết kiệm ~16%'),
        ]) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: ForgeColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: plan.$1 == 'monthly' ? Border.all(color: ForgeColors.accent, width: 1.4) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${formatVnd(plan.$2)}/${plan.$3}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontFeatures: ForgeText.tabularFeatures),
                      ),
                      TextSpan(
                        text: '  (${plan.$4})',
                        style: TextStyle(fontSize: 15, color: ForgeColors.muted),
                      ),
                    ],
                  ),
                  style: GoogleFonts.plusJakartaSans(fontSize: 24, color: ForgeColors.text),
                ),
                const SizedBox(height: 14),
                benefit('Đọc trọn mọi chương trả phí của tất cả bộ truyện khi gói còn hạn'),
                benefit('Mở khóa chương bằng VIP không trừ số dư Ví'),
                benefit('Trả bằng số dư Ví hoặc chuyển khoản VietQR'),
                const SizedBox(height: 6),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => onBuy(plan.$1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.$1 == 'monthly' ? ForgeColors.accent : ForgeColors.chip,
                      foregroundColor: plan.$1 == 'monthly' ? Colors.white : ForgeColors.text,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    child: Text(isVip ? 'Gia hạn gói ${plan.$3}' : 'Đăng ký gói ${plan.$3}'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        _ShopLinks(onHistory: onHistory, padded: false),
      ],
    );
  }
}

/// Liên kết cuối trang: Lịch sử giao dịch / Điều khoản thanh toán.
class _ShopLinks extends StatelessWidget {
  final VoidCallback onHistory;
  final bool padded;
  const _ShopLinks({required this.onHistory, this.padded = true});

  @override
  Widget build(BuildContext context) {
    Widget link(String text, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padded ? 16 : 0, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: ForgeColors.text),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: ForgeColors.muted),
          ],
        ),
      ),
    );
    return Column(
      children: [
        link('Lịch sử giao dịch', onHistory),
        Divider(height: 1, color: ForgeColors.divider),
        link('Điều khoản thanh toán', () => _showTerms(context)),
      ],
    );
  }

  static void _showTerms(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ForgeColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Điều khoản thanh toán',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: ForgeColors.text),
            ),
            const SizedBox(height: 12),
            for (final line in const [
              'Nạp Ví và mua VIP bằng VietQR là chuyển khoản trực tiếp tới Studio; giao dịch hoàn tất khi Studio xác nhận đã nhận tiền.',
              'Số dư Ví dùng để mở khóa vĩnh viễn từng chương trả phí hoặc mua gói VIP.',
              'VIP cho phép đọc mọi chương trả phí khi gói còn hạn.',
              'Giá chương do Studio đặt trên web; máy chủ luôn tính lại giá khi thanh toán.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• $line',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: ForgeColors.textSoft, height: 1.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sheet tạo đơn VietQR nạp [amountVnd] vào Ví và chờ Studio duyệt.
class _TopupOrderSheet extends ConsumerStatefulWidget {
  final int amountVnd;
  const _TopupOrderSheet({required this.amountVnd});

  @override
  ConsumerState<_TopupOrderSheet> createState() => _TopupOrderSheetState();
}

class _TopupOrderSheetState extends ConsumerState<_TopupOrderSheet> {
  TopupResponse? _order;
  String? _error;

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    setState(() {
      _error = null;
      _order = null;
    });
    try {
      final order = await ref
          .read(monetizationServiceProvider)
          .createVietQrOrder(purpose: PaymentPurpose.topup, amountVnd: widget.amountVnd);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException ? e.message : 'Không thể tạo mã VietQR. Vui lòng thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nạp ${formatVnd(widget.amountVnd)} vào Ví',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ForgeColors.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  icon: Icon(Icons.close_rounded, color: ForgeColors.text),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (_error != null) ...[
              Text(_error!, style: GoogleFonts.plusJakartaSans(color: ForgeColors.danger, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _create,
                style: ElevatedButton.styleFrom(backgroundColor: ForgeColors.accent, foregroundColor: Colors.white),
                child: const Text('Thử lại'),
              ),
            ] else if (_order == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: ForgeColors.accent)),
              )
            else
              VietQrPaymentPanel(
                key: ValueKey(_order!.orderId),
                order: _order!,
                title: 'Quét mã VietQR để nạp ${formatVnd(_order!.amountVnd)} vào Ví',
                onApproved: (status) async {
                  await ref.read(walletNotifierProvider.notifier).refresh(silent: true);
                  if (!context.mounted) return;
                  showPaymentSuccessSnackBar(context, 'Nạp thành công +${formatVnd(status.amountVnd)} vào Ví!');
                  Navigator.of(context).pop();
                },
                onCancel: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
