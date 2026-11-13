import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/api_dtos.dart';
import '../../navigation/read_guard.dart';
import '../../providers/api_providers.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';

/// Tab Thông báo / Hoạt động: giao dịch Ví gần đây, lịch sử đọc và lối vào Trung tâm Review bản thảo.
class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final transactions = !auth.isAuthenticated
        ? const <WalletTransactionDto>[]
        : PreferencesService.getWalletTransactions();
    final history = PreferencesService.getReadingHistory();

    return Scaffold(
      backgroundColor: ForgeColors.bg,
      appBar: const ForgeTopBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Thông báo',
              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: ForgeColors.text),
            ),
          ),
          _card(
            child: ListTile(
              onTap: () => context.push('/review'),
              leading: const CircleAvatar(
                backgroundColor: ForgeColors.accent,
                child: Icon(Icons.verified_user_rounded, color: Colors.white),
              ),
              title: Text(
                'Trung tâm Review bản thảo',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ForgeColors.text),
              ),
              subtitle: Text(
                'Nhập mã REV-... hoặc quét QR để xem & góp ý bản thảo',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.muted),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: ForgeColors.muted),
            ),
          ),
          const ForgeSectionHeader(title: 'GIAO DỊCH VÍ'),
          if (transactions.isEmpty)
            _empty(!auth.isAuthenticated ? 'Đăng nhập để xem giao dịch Ví.' : 'Chưa có giao dịch nào.')
          else
            _card(
              child: Column(
                children: [
                  for (final (i, tx) in transactions.take(20).indexed) ...[
                    if (i > 0) Divider(height: 1, color: ForgeColors.divider),
                    ListTile(
                      dense: true,
                      leading: Icon(
                        tx.amountVnd >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
                        color: tx.amountVnd >= 0 ? ForgeColors.green : ForgeColors.accent,
                      ),
                      title: Text(tx.title, style: GoogleFonts.plusJakartaSans(color: ForgeColors.text)),
                      subtitle: Text(
                        timeAgo(tx.createdAt),
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: ForgeColors.muted),
                      ),
                      trailing: Text(
                        formatVnd(tx.amountVnd, showSign: true),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: tx.amountVnd >= 0 ? ForgeColors.green : ForgeColors.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const ForgeSectionHeader(title: 'ĐỌC GẦN ĐÂY'),
          if (history.isEmpty)
            _empty('Bạn chưa đọc chương nào.')
          else
            _card(
              child: Column(
                children: [
                  for (final (i, h) in history.take(20).indexed) ...[
                    if (i > 0) Divider(height: 1, color: ForgeColors.divider),
                    ListTile(
                      dense: true,
                      onTap: () => openReaderGuarded(context, ref, h.seriesId, h.chapterId),
                      leading: const Icon(Icons.menu_book_rounded, color: ForgeColors.accent),
                      title: Text(
                        h.seriesTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(color: ForgeColors.text),
                      ),
                      subtitle: Text(
                        'Chương ${h.chapterNumber} • ${timeAgo(h.readAt)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: ForgeColors.muted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(color: ForgeColors.card, borderRadius: BorderRadius.circular(14)),
    clipBehavior: Clip.antiAlias,
    child: Material(type: MaterialType.transparency, child: child),
  );

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Text(text, style: GoogleFonts.plusJakartaSans(color: ForgeColors.muted, fontSize: 13)),
  );
}
