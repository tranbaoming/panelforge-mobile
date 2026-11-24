import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/api_dtos.dart';
import '../../models/notification_model.dart';
import '../../navigation/read_guard.dart';
import '../../providers/api_providers.dart';
import '../../providers/notification_providers.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';

/// Tab Thông báo / Hoạt động: thông báo từ server (`/api/notifications`), giao dịch Ví gần đây,
/// lịch sử đọc và lối vào Trung tâm Review bản thảo.
class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final transactions = !auth.isAuthenticated
        ? const <WalletTransactionDto>[]
        : PreferencesService.getWalletTransactions();
    final history = PreferencesService.getReadingHistory();
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final followUpdates = ref.watch(followUpdatesProvider);

    return Scaffold(
      backgroundColor: ForgeColors.bg,
      appBar: const ForgeTopBar(),
      body: RefreshIndicator(
        color: ForgeColors.accent,
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Thông báo',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ForgeColors.text,
                      ),
                    ),
                  ),
                  if (unread > 0)
                    TextButton(
                      onPressed: () => _markAllRead(context, ref),
                      child: Text(
                        'Đánh dấu đã đọc',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ForgeColors.accent),
                      ),
                    ),
                ],
              ),
            ),
            if (followUpdates.isNotEmpty) ...[
              _card(
                child: Column(
                  children: [
                    for (final (i, s) in followUpdates.indexed) ...[
                      if (i > 0) Divider(height: 1, color: ForgeColors.divider),
                      ListTile(
                        key: ValueKey('follow-update-${s.id}'),
                        onTap: () {
                          ref.read(followUpdatesProvider.notifier).markSeen(s.id);
                          context.push('/series/${s.id}');
                        },
                        leading: SizedBox(width: 36, height: 48, child: SeriesCover(series: s, radius: 4)),
                        title: Text(
                          'Chương mới: ${s.title}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: ForgeColors.text),
                        ),
                        subtitle: Text(
                          'Truyện bạn theo dõi vừa cập nhật • ${timeAgo(s.latestPublishedAt)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.muted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, color: ForgeColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!auth.isAuthenticated)
              _empty('Đăng nhập để nhận thông báo.')
            else
              notifications.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(color: ForgeColors.accent)),
                ),
                error: (_, _) => _empty('Không tải được thông báo. Kéo xuống để thử lại.'),
                data: (page) => page.items.isEmpty
                    ? _empty('Chưa có thông báo nào.')
                    : _card(
                        child: Column(
                          children: [
                            for (final (i, n) in page.items.indexed) ...[
                              if (i > 0) Divider(height: 1, color: ForgeColors.divider),
                              _NotificationTile(notification: n, onTap: () => _markRead(context, ref, n)),
                            ],
                          ],
                        ),
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
                          'Chương ${h.chapterNumberLabel} • ${timeAgo(h.readAt)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: ForgeColors.muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _markRead(BuildContext context, WidgetRef ref, AppNotification n) async {
    if (n.isRead) return;
    try {
      await ref.read(notificationsProvider.notifier).markRead(n.id);
    } catch (_) {
      if (context.mounted) _toast(context, 'Không đánh dấu được thông báo. Thử lại sau.');
    }
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
    } catch (_) {
      if (context.mounted) _toast(context, 'Không đánh dấu được thông báo. Thử lại sau.');
    }
  }

  void _toast(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

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

/// Một thông báo: chấm cam khi chưa đọc, tiêu đề, nội dung, thời gian.
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 10),
              child: Container(
                key: n.isRead ? null : ValueKey('unread-${n.id}'),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: n.isRead ? Colors.transparent : ForgeColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                      color: ForgeColors.text,
                    ),
                  ),
                  if (n.message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.textSoft),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    timeAgo(n.createdAt),
                    style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: ForgeColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
