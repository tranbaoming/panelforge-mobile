import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../providers/api_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'vietqr_payment_panel.dart';

/// Mua gói VIP (đọc mọi chương trả phí khi còn hạn): trừ Ví (`POST /api/wallet/vip`)
/// hoặc chuyển khoản VietQR trực tiếp (đơn `VipSubscription`, chờ Studio duyệt).
/// Giá khớp `VipPricing` ở Backend; server luôn tự tính lại giá.
class VipPurchaseSheet extends ConsumerStatefulWidget {
  const VipPurchaseSheet({super.key});

  static const monthlyVnd = 19900;
  static const yearlyVnd = 199900;

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ForgeColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const VipPurchaseSheet(),
  );

  @override
  ConsumerState<VipPurchaseSheet> createState() => _VipPurchaseSheetState();
}

class _VipPurchaseSheetState extends ConsumerState<VipPurchaseSheet> {
  String _plan = 'monthly';
  bool _busy = false;
  String? _error;
  TopupResponse? _order;

  int get _price => _plan == 'yearly' ? VipPurchaseSheet.yearlyVnd : VipPurchaseSheet.monthlyVnd;

  Future<void> _payWithWallet() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(walletNotifierProvider.notifier).subscribeVip(_plan);
      if (!mounted) return;
      Navigator.of(context).pop();
      showPaymentSuccessSnackBar(context, 'Đã kích hoạt VIP. Bạn có thể đọc mọi chương trả phí.');
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : 'Không thể mua VIP. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payWithVietQr() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await ref
          .read(monetizationServiceProvider)
          .createVietQrOrder(purpose: PaymentPurpose.vipSubscription, vipPlan: _plan);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : 'Không tạo được mã VietQR. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletNotifierProvider).asData?.value;
    final balance = wallet?.balanceVnd ?? 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: ForgeColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gói VIP PanelForge',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
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
            if (_order != null)
              VietQrPaymentPanel(
                key: ValueKey(_order!.orderId),
                order: _order!,
                title: 'Quét VietQR để mua VIP • ${formatVnd(_order!.amountVnd)}',
                onApproved: (_) async {
                  await ref.read(walletNotifierProvider.notifier).refresh();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  showPaymentSuccessSnackBar(context, 'Studio đã xác nhận. VIP của bạn đã được kích hoạt!');
                },
                onCancel: () => setState(() => _order = null),
              )
            else ...[
              Text(
                'Đọc mọi chương trả phí khi gói còn hạn.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.muted),
              ),
              const SizedBox(height: 12),
              _planTile('monthly', 'Gói Tháng', '30 ngày', VipPurchaseSheet.monthlyVnd),
              const SizedBox(height: 8),
              _planTile('yearly', 'Gói Năm', '365 ngày • tiết kiệm ~16%', VipPurchaseSheet.yearlyVnd),
              const SizedBox(height: 12),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: GoogleFonts.plusJakartaSans(color: ForgeColors.danger, fontSize: 12.5)),
                ),
              ElevatedButton(
                onPressed: _busy || balance < _price ? null : _payWithWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ForgeColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(
                  balance < _price
                      ? 'Ví không đủ (${formatVnd(balance)})'
                      : 'Trả bằng Ví • ${formatVnd(_price)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _payWithVietQr,
                icon: const Icon(Icons.qr_code_2_rounded),
                label: Text('Chuyển khoản VietQR • ${formatVnd(_price)}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ForgeColors.text,
                  side: BorderSide(color: ForgeColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _planTile(String plan, String title, String subtitle, int price) {
    final selected = _plan == plan;
    return InkWell(
      onTap: () => setState(() => _plan = plan),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ForgeColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? ForgeColors.accent : ForgeColors.border, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? ForgeColors.accent : ForgeColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ForgeColors.text),
                  ),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.muted)),
                ],
              ),
            ),
            Text(
              formatVnd(price),
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ForgeColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
