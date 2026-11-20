import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/api_dtos.dart';
import '../theme/app_theme.dart';

String _two(int v) => v.toString().padLeft(2, '0');

String formatTxTime(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.day)}/${_two(l.month)}/${l.year} ${_two(l.hour)}:${_two(l.minute)}';
}

/// Lịch sử giao dịch Ví (dữ liệu `GET /api/wallet/me`): lọc theo tháng, tổng nạp / chi của tháng,
/// chạm một giao dịch để xem biên lai.
class WalletHistoryList extends StatefulWidget {
  final List<WalletTransactionDto> transactions;
  const WalletHistoryList({super.key, required this.transactions});

  @override
  State<WalletHistoryList> createState() => _WalletHistoryListState();
}

class _WalletHistoryListState extends State<WalletHistoryList> {
  /// null = tất cả; ngược lại (năm, tháng).
  (int, int)? _month;

  List<(int, int)> get _months {
    final set = <(int, int)>{
      for (final t in widget.transactions) (t.createdAt.toLocal().year, t.createdAt.toLocal().month),
    };
    return set.toList()..sort((a, b) => a.$1 != b.$1 ? b.$1.compareTo(a.$1) : b.$2.compareTo(a.$2));
  }

  @override
  Widget build(BuildContext context) {
    final list = [
      for (final t in widget.transactions)
        if (_month == null || (t.createdAt.toLocal().year, t.createdAt.toLocal().month) == _month) t,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final income = list.where((t) => t.amountVnd > 0).fold<int>(0, (a, t) => a + t.amountVnd);
    final spent = list.where((t) => t.amountVnd < 0).fold<int>(0, (a, t) => a - t.amountVnd);

    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            children: [_monthChip('Tất cả', null), for (final m in _months) _monthChip('Tháng ${m.$2}/${m.$1}', m)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Row(
            children: [
              Expanded(child: _total('Nạp vào', income, AppColors.mint)),
              const SizedBox(width: 10),
              Expanded(child: _total('Đã chi', spent, AppColors.primary)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(color: AppColors.darkBorder, height: 1),
            itemBuilder: (context, index) => _TxRow(tx: list[index]),
          ),
        ),
      ],
    );
  }

  Widget _monthChip(String label, (int, int)? value) {
    final selected = _month == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.darkCard,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.darkBorder),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.darkTextSecondary,
        ),
        onSelected: (_) => setState(() => _month = value),
      ),
    );
  }

  Widget _total(String label, int amount, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(10)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.darkTextSecondary)),
        Text(
          formatVnd(amount),
          style: ForgeText.tabular(fontSize: 14, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    ),
  );
}

class _TxRow extends StatelessWidget {
  final WalletTransactionDto tx;
  const _TxRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isPositive = tx.amountVnd > 0;
    return InkWell(
      key: ValueKey('tx-${tx.id}'),
      onTap: () => showTransactionReceipt(context, tx),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isPositive ? AppColors.mint : AppColors.primary).withValues(alpha: 0.15),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatTxTime(tx.createdAt)} • Sau GD: ${formatVnd(tx.balanceAfter)}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.darkTextSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatVnd(tx.amountVnd, showSign: true),
              style: ForgeText.tabular(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: isPositive ? AppColors.mint : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Biên lai một giao dịch Ví: mã, loại, thời gian, số tiền, số dư sau giao dịch; sao chép mã để đối soát.
Future<void> showTransactionReceipt(BuildContext context, WalletTransactionDto tx) {
  final isPositive = tx.amountVnd > 0;
  final kind = isPositive ? 'Nạp vào Ví' : 'Thanh toán từ Ví';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.darkSurface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      Widget line(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.darkTextSecondary)),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: ForgeText.tabular(fontSize: 13.5, fontWeight: FontWeight.w700, color: color ?? Colors.white),
              ),
            ),
          ],
        ),
      );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Biên lai giao dịch',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                formatVnd(tx.amountVnd, showSign: true),
                key: const ValueKey('receipt-amount'),
                style: ForgeText.tabular(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isPositive ? AppColors.mint : AppColors.primary,
                ),
              ),
              const Divider(color: AppColors.darkBorder, height: 24),
              line('Nội dung', tx.title),
              line('Loại', kind),
              line('Thời gian', formatTxTime(tx.createdAt)),
              line('Số dư sau GD', formatVnd(tx.balanceAfter)),
              line('Mã giao dịch', tx.id.isEmpty ? '—' : tx.id),
              const SizedBox(height: 12),
              if (tx.id.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: tx.id));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(const SnackBar(content: Text('Đã sao chép mã giao dịch.')));
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Sao chép mã giao dịch'),
                ),
            ],
          ),
        ),
      );
    },
  );
}
