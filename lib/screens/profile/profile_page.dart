import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/api_dtos.dart';
import '../../models/comic_model.dart';
import '../../navigation/read_guard.dart';
import '../../providers/api_providers.dart';
import '../../providers/catalog_providers.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';
import '../../widgets/reader_profile_sheet.dart';
import '../../widgets/wallet_topup_dialog.dart';
import '../explore/series_grid_page.dart';

/// Tab Cá nhân: thẻ tài khoản (mời tạo tài khoản / hồ sơ + Ví), lối tắt danh sách,
/// hai thẻ Lịch sử / Yêu thích. Cài đặt nằm ở bánh răng góc phải (`/settings`).
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  void _openSeriesList(String title, Set<String> ids, List<SeriesItem> catalog) => SeriesGridPage.open(
    context,
    title: title,
    series: catalog.where((s) => ids.contains(s.id)).toList(),
    emptyMessage: 'Danh sách trống.',
  );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final catalog = ref.watch(catalogSeriesProvider).asData?.value ?? const <SeriesItem>[];
    final wallet = auth.isAuthenticated ? ref.watch(walletNotifierProvider).asData?.value : null;
    final bookmarks = PreferencesService.getBookmarks();
    final follows = PreferencesService.getFollows();
    final unlocked = {...?wallet?.unlockedChapterIds, ...PreferencesService.getUnlockedChapterIds()};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: ForgeColors.bg,
        appBar: AppBar(
          backgroundColor: ForgeColors.bg,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Text(
            'Cá nhân',
            style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w700, color: ForgeColors.text),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: ForgeColors.divider),
          ),
          actions: [
            IconButton(
              tooltip: 'Thông báo',
              icon: Icon(Icons.notifications_none_rounded, color: ForgeColors.text),
              onPressed: () => context.push('/activity'),
            ),
            IconButton(
              tooltip: 'Cài đặt',
              icon: Icon(Icons.settings_outlined, color: ForgeColors.text, size: 26),
              onPressed: () => context.push('/settings'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: auth.isAuthenticated && auth.user != null
                  ? _AccountCard(user: auth.user!, wallet: wallet)
                  : const _CreateAccountCard(),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    _ListChip(
                      icon: Icons.bookmark_rounded,
                      title: 'ĐỌC SAU',
                      count: '${bookmarks.length} tựa',
                      onTap: () => _openSeriesList('Đọc Sau', bookmarks, catalog),
                    ),
                    _ListChip(
                      icon: Icons.notifications_rounded,
                      title: 'THEO DÕI',
                      count: '${follows.length} tựa',
                      onTap: () => _openSeriesList('Theo Dõi', follows, catalog),
                    ),
                    _ListChip(
                      icon: Icons.lock_open_rounded,
                      title: 'ĐÃ MỞ KHÓA',
                      count: '${unlocked.length} chương',
                      onTap: auth.isAuthenticated ? () => WalletTopupDialog.show(context, initialTab: 1) : null,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: ForgeColors.divider)),
                ),
                child: TabBar(
                  indicatorColor: ForgeColors.accent,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelColor: ForgeColors.text,
                  unselectedLabelColor: ForgeColors.muted,
                  labelStyle: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800),
                  tabs: const [
                    Tab(text: 'Lịch sử'),
                    Tab(text: 'Yêu thích'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _HistoryTab(catalog: catalog),
              _FavoritesTab(catalog: catalog),
            ],
          ),
        ),
      ),
    );
  }
}

/// Khách: mời tạo tài khoản.
class _CreateAccountCard extends StatelessWidget {
  const _CreateAccountCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ForgeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tạo tài khoản',
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: ForgeColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Tài khoản giúp bạn đọc trọn chương, nạp Ví, mua VIP và giữ các chương đã mua khi đổi máy hay cài lại ứng dụng.',
            style: GoogleFonts.plusJakartaSans(fontSize: 14.5, color: ForgeColors.textSoft, height: 1.45),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () => context.push('/login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ForgeColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: const Text('Đăng nhập / Đăng ký'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Đã đăng nhập: hồ sơ + số dư Ví / VIP và lối tắt tới Cửa hàng.
class _AccountCard extends StatelessWidget {
  final AuthUser user;
  final UserWalletDto? wallet;
  const _AccountCard({required this.user, required this.wallet});

  @override
  Widget build(BuildContext context) {
    final name = user.fullName.isNotEmpty ? user.fullName : user.email.split('@').first;
    final hasAvatar = user.avatarUrl?.isNotEmpty ?? false;
    final isVip = wallet?.hasActiveVip ?? false;
    final expires = wallet?.vipExpiresAt;
    String two(int v) => v.toString().padLeft(2, '0');
    final vipText = !isVip
        ? 'Chưa có VIP'
        : expires == null
        ? 'VIP đang hoạt động'
        : 'VIP đến ${two(expires.day)}/${two(expires.month)}/${expires.year}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ForgeColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: ForgeColors.chip,
                backgroundImage: hasAvatar ? NetworkImage(user.avatarUrl!) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        name.isEmpty ? 'R' : name.characters.first.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: ForgeColors.text,
                          fontSize: 20,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ForgeColors.text,
                      ),
                    ),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Chỉnh sửa hồ sơ',
                icon: Icon(Icons.edit_outlined, color: ForgeColors.textSoft),
                onPressed: () => ReaderProfileSheet.show(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: ForgeColors.gold, size: 20),
                const SizedBox(width: 6),
                Text(
                  wallet == null ? '—' : formatVnd(wallet!.balanceVnd),
                  style: ForgeText.tabular(fontSize: 18, color: ForgeColors.gold),
                ),
                const SizedBox(width: 12),
                Icon(Icons.workspace_premium_rounded, size: 18, color: isVip ? ForgeColors.gold : ForgeColors.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    vipText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.textSoft),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/shop'),
                  style: TextButton.styleFrom(foregroundColor: ForgeColors.accent),
                  child: const Text('Nạp Ví', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListChip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String count;
  final VoidCallback? onTap;
  const _ListChip({required this.icon, required this.title, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: ForgeColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: ForgeColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: ForgeColors.muted),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ForgeColors.text,
                      ),
                    ),
                    Text(
                      count,
                      style: ForgeText.tabular(fontSize: 11.5, fontWeight: FontWeight.w500, color: ForgeColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dữ liệu tối thiểu khi bộ truyện chưa có trong catalog đã tải (ngoại tuyến).
SeriesItem _fallbackSeries(String id, String title) => SeriesItem(
  id: id,
  title: title,
  author: '',
  artist: '',
  format: ComicFormat.manga,
  coverGradientStart: '',
  coverGradientEnd: '',
  synopsisQuote: '',
  fullSynopsis: '',
  views: 0,
  readProgressChapter: 0,
  totalChapters: 0,
  genres: const [],
  chapters: const [],
  editorialNote: '',
);

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Lịch sử đọc (lưu trên máy): chạm để đọc tiếp đúng chương.
class _HistoryTab extends ConsumerWidget {
  final List<SeriesItem> catalog;
  const _HistoryTab({required this.catalog});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = PreferencesService.getReadingHistory();
    if (history.isEmpty) {
      return const _EmptyTab(icon: Icons.history_rounded, message: 'Bạn chưa đọc truyện nào.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final h = history[i];
        final series =
            catalog.where((s) => s.id == h.seriesId).firstOrNull ?? _fallbackSeries(h.seriesId, h.seriesTitle);
        return _SeriesListRow(
          series: series,
          line: h.lastPageNumber > 1
              ? 'Chương ${h.chapterNumberLabel} (Trang ${h.lastPageNumber}) • ${timeAgo(h.readAt)}'
              : 'Chương ${h.chapterNumberLabel} • ${timeAgo(h.readAt)}',
          date: _date(h.readAt),
          onTap: () => openReaderGuarded(context, ref, h.seriesId, h.chapterId, series: series),
        );
      },
    );
  }
}

/// Yêu thích (lưu trên máy, bật bằng ☆ ở trang truyện).
class _FavoritesTab extends StatelessWidget {
  final List<SeriesItem> catalog;
  const _FavoritesTab({required this.catalog});

  @override
  Widget build(BuildContext context) {
    final ids = PreferencesService.getFavorites();
    final list = catalog.where((s) => ids.contains(s.id)).toList();
    if (list.isEmpty) {
      return _EmptyTab(
        icon: Icons.star_border_rounded,
        message: ids.isEmpty
            ? 'Chưa có truyện yêu thích. Chạm ☆ ở trang truyện để thêm.'
            : 'Đang tải danh sách truyện yêu thích...',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final s = list[i];
        return _SeriesListRow(
          series: s,
          line: '${s.totalChapters} chương${s.isCompleted ? ' • Hoàn thành' : ''}',
          date: s.latestPublishedAt == null ? null : _date(s.latestPublishedAt!),
          onTap: () => context.push('/series/${s.id}'),
        );
      },
    );
  }
}

class _SeriesListRow extends StatelessWidget {
  final SeriesItem series;
  final String line;
  final String? date;
  final VoidCallback onTap;
  const _SeriesListRow({required this.series, required this.line, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: ForgeColors.divider)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 132,
              height: 84,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(width: 132, height: 176, child: SeriesCover(series: series, radius: 0)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ForgeColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(line, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.muted)),
                  if (date != null) ...[
                    const SizedBox(height: 6),
                    Text(date!, style: ForgeText.tabular(fontSize: 13.5, color: ForgeColors.textSoft)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyTab({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => ListView(children: [ForgeEmptyState(icon: icon, message: message)]);
}
