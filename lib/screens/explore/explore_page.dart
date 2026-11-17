import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../navigation/read_guard.dart';
import '../../providers/api_providers.dart';
import '../../providers/catalog_providers.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';
import '../../widgets/wallet_chip.dart';
import 'series_grid_page.dart';

/// Trang chủ: banner truyện nổi bật full-bleed, popup giới thiệu truyện mới, các hàng bìa lớn cuộn ngang,
/// thể loại dạng ảnh tròn, khối "Đề xuất" nổi bật và hàng "Truyện mới".
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<List<SeriesItem>>>(catalogSeriesProvider, (_, next) {
      next.whenOrNull(
        data: (items) {
          ref.read(walletNotifierProvider.notifier).refresh(silent: true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowNewSeriesPromo(items));
        },
        error: (e, _) {
          debugPrint('[Catalog Load Error] $e');
          ref.read(isServerConnectedProvider.notifier).setConnected(false);
        },
      );
    }, fireImmediately: true);
  }

  Future<void> _refresh() async {
    ref.invalidate(catalogSeriesProvider);
    try {
      await ref.read(catalogSeriesProvider.future);
    } catch (_) {
      // Trạng thái lỗi đã hiển thị qua provider.
    }
  }

  /// Popup "Truyện mới" — mỗi bộ mới (tạo trong 30 ngày) chỉ hiện một lần.
  Future<void> _maybeShowNewSeriesPromo(List<SeriesItem> items) async {
    if (!mounted) return;
    final promo = CatalogSections(items).newSeriesPromo;
    if (promo == null || PreferencesService.getPromoSeenSeriesId() == promo.id) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    await PreferencesService.setPromoSeenSeriesId(promo.id);
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (_) => _NewSeriesPromoDialog(series: promo),
    );
    if (open == true && mounted) _openSeries(promo);
  }

  void _openSeries(SeriesItem s) => context.push('/series/${s.id}');

  void _openGrid(String title, List<SeriesItem> list, CatalogSections sections) => SeriesGridPage.open(
    context,
    title: title,
    series: list,
    hotIds: sections.topBy((s) => s.viewsLast7Days).take(3).map((s) => s.id).toSet(),
  );

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogSeriesProvider);
    final items = catalog.asData?.value;

    return Scaffold(
      backgroundColor: ForgeColors.bg,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: ForgeColors.accent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            if (items == null || items.isEmpty) ...[
              SliverToBoxAdapter(child: SafeArea(bottom: false, child: _TopBar())),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: catalog.isLoading && items == null
                      ? const CircularProgressIndicator(color: ForgeColors.accent)
                      : catalog.hasError && items == null
                      ? ForgeEmptyState(
                          icon: Icons.cloud_off_rounded,
                          message: 'Không thể kết nối đến máy chủ',
                          actionLabel: 'Thử lại',
                          onAction: _refresh,
                        )
                      : const ForgeEmptyState(
                          icon: Icons.menu_book_outlined,
                          message: 'Chưa có bộ truyện nào được phát hành.',
                        ),
                ),
              ),
            ] else
              ..._buildSections(CatalogSections(items)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(CatalogSections sections) {
    final hero = sections.featured;
    final spotlight = sections.spotlight;
    final genres = sections.genres;
    return [
      if (hero != null)
        SliverToBoxAdapter(
          child: _HeroBanner(series: hero, sections: sections, onOpen: _openSeries),
        ),
      SliverToBoxAdapter(child: _ContinueReading(all: sections.all)),
      SliverToBoxAdapter(
        child: _row(
          'Phổ biến',
          sections.byViews,
          sections,
          onMore: () => _openGrid('Phổ biến', sections.byViews, sections),
        ),
      ),
      SliverToBoxAdapter(
        child: _row(
          'Mới cập nhật',
          sections.recentlyUpdated,
          sections,
          onMore: () => _openGrid('Mới cập nhật', sections.recentlyUpdated, sections),
        ),
      ),
      if (genres.isNotEmpty)
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ForgeBlockTitle(title: 'Thể loại', onMore: () => context.push('/genres')),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: genres.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GenreAvatar(
                    genre: genres[i].genre,
                    cover: genres[i].series.first,
                    onTap: () => _openGrid(genreLabel(genres[i].genre), genres[i].series, sections),
                  ),
                ),
              ),
            ],
          ),
        ),
      if (spotlight != null)
        SliverToBoxAdapter(
          child: _SpotlightBlock(series: spotlight, onOpen: _openSeries),
        ),
      SliverToBoxAdapter(
        child: _row(
          'Truyện mới',
          sections.newest,
          sections,
          onMore: () => _openGrid('Truyện mới', sections.newest, sections),
        ),
      ),
      SliverToBoxAdapter(child: _ForYouTeaser(onTap: () => context.go('/for-you'))),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  Widget _row(String title, List<SeriesItem> list, CatalogSections sections, {VoidCallback? onMore}) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ForgeBlockTitle(title: title, onMore: onMore),
        SizedBox(
          height: 268,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length.clamp(0, 12),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => CoverTitleCard(
              series: list[i],
              isNew: sections.isNew(list[i]),
              isUpdated: sections.isUpdated(list[i]),
              pillLabel: '${list[i].totalChapters} chương',
              onTap: () => _openSeries(list[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Thanh trên cùng (logo + Ví) khi chưa có banner (đang tải / lỗi / trống).
class _TopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authStateProvider).isAuthenticated;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [const ForgeBrandLogo(), const Spacer(), if (authed) const WalletChip(isServerConnected: true)],
      ),
    );
  }
}

/// Banner full-bleed của bộ truyện nổi bật: ảnh bìa tràn viền, logo + Ví phía trên, tên + nút phía dưới.
class _HeroBanner extends ConsumerWidget {
  final SeriesItem series;
  final CatalogSections sections;
  final void Function(SeriesItem) onOpen;
  const _HeroBanner({required this.series, required this.sections, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authStateProvider).isAuthenticated;
    final topPad = MediaQuery.of(context).padding.top;
    final height = (MediaQuery.of(context).size.width * 1.05).clamp(380.0, 560.0);
    final genre = series.genres.isEmpty ? '' : series.genres.first;
    return SizedBox(
      height: height + topPad,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => onOpen(series),
            child: SeriesCover(series: series, radius: 0),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.22, 0.55, 1],
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.transparent,
                    ForgeColors.bg,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: topPad + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [const ForgeBrandLogo(), const Spacer(), if (authed) const WalletChip(isServerConnected: true)],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ForgeColors.isDark ? const Color(0x33FFFFFF) : ForgeColors.chip,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ForgeColors.isDark ? const Color(0x33FFFFFF) : ForgeColors.border),
                      ),
                      child: Text(
                        'NỔI BẬT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: ForgeColors.text,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (sections.isNew(series)) const SeriesBadge.newSeries(),
                    if (sections.isUpdated(series)) const SeriesBadge.updated(),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  series.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: ForgeColors.text,
                    shadows: [Shadow(color: ForgeColors.bg.withValues(alpha: 0.8), blurRadius: 12)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [series.author, genre, '${series.totalChapters} chương'].where((t) => t.isNotEmpty).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.textSoft),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => onOpen(series),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text('Đọc'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ForgeColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Tiếp tục đọc" gọn: chỉ hiện khi lịch sử đọc có bộ còn trong catalog.
class _ContinueReading extends ConsumerWidget {
  final List<SeriesItem> all;
  const _ContinueReading({required this.all});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ReadingHistoryEntry? entry;
    SeriesItem? series;
    for (final h in PreferencesService.getReadingHistory()) {
      final match = all.where((s) => s.id == h.seriesId);
      if (match.isNotEmpty) {
        entry = h;
        series = match.first;
        break;
      }
    }
    if (entry == null || series == null) return const SizedBox.shrink();
    final e = entry;
    final s = series;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: ForgeColors.surface,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ForgeColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openReaderGuarded(context, ref, s.id, e.chapterId, series: s),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SizedBox(width: 48, height: 64, child: SeriesCover(series: s, radius: 6)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiếp tục đọc',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: ForgeColors.muted,
                        ),
                      ),
                      Text(
                        s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: ForgeColors.text,
                        ),
                      ),
                      Text(
                        'Chương ${e.chapterNumber} • ${timeAgo(e.readAt)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: ForgeColors.chip, shape: BoxShape.circle),
                  child: Icon(Icons.play_arrow_rounded, color: ForgeColors.text, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Khối "Đề xuất": thẻ nền #1E2330 viền cam mảnh — ảnh lớn + tên + đoạn giới thiệu ngắn.
class _SpotlightBlock extends StatelessWidget {
  final SeriesItem series;
  final void Function(SeriesItem) onOpen;
  const _SpotlightBlock({required this.series, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      decoration: BoxDecoration(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ForgeColors.accent.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.only(bottom: 18),
      child: InkWell(
        onTap: () => onOpen(series),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ForgeBlockTitle(title: 'Đề xuất'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SeriesCover(series: series, radius: 0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    series.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ForgeColors.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    series.fullSynopsis,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14.5, color: ForgeColors.textSoft, height: 1.5),
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

/// Banner cuối trang dẫn sang tab "Dành cho bạn".
class _ForYouTeaser extends StatelessWidget {
  final VoidCallback onTap;
  const _ForYouTeaser({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Material(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHƯA BIẾT ĐỌC GÌ?',
                        style: GoogleFonts.bebasNeue(fontSize: 26, color: ForgeColors.text, letterSpacing: 1),
                      ),
                      Text(
                        'Xem gợi ý dành riêng cho bạn',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: ForgeColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.auto_stories_rounded, size: 44, color: ForgeColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Popup giới thiệu truyện mới: ảnh bìa, "TRUYỆN MỚI 📣", tên truyện, một nút "Đọc".
class _NewSeriesPromoDialog extends StatelessWidget {
  final SeriesItem series;
  const _NewSeriesPromoDialog({required this.series});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ForgeColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: SeriesCover(series: series, radius: 12),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton.filledTonal(
                      tooltip: 'Đóng',
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'TRUYỆN MỚI 📣',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ForgeColors.accent,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '“${series.title}”',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w800, color: ForgeColors.text),
              ),
              const SizedBox(height: 8),
              Text(
                series.fullSynopsis,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: ForgeColors.textSoft, height: 1.45),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ForgeColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Đọc'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
