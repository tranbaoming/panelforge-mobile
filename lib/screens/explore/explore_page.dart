import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../navigation/read_guard.dart';
import '../../providers/api_providers.dart';
import '../../services/catalog_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';
import '../../widgets/wallet_chip.dart';
import 'series_grid_page.dart';

/// Trang chủ: Tiếp tục đọc, nút danh mục nhanh, các hàng truyện cuộn ngang.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  List<SeriesItem> _allSeries = [];
  bool _isLoading = false;
  bool _hasError = false;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final res = await CatalogService().getSeries(pageSize: 50);
      if (!mounted) return;
      setState(() {
        _allSeries = res.items.map((e) => SeriesItem.fromPublicDto(e)).toList();
        _isLoading = false;
      });
      ref.read(isServerConnectedProvider.notifier).state = true;
      ref.read(walletNotifierProvider.notifier).refresh();
    } catch (e) {
      debugPrint('[Catalog Load Error] $e');
      if (!mounted) return;
      setState(() {
        _allSeries = [];
        _isLoading = false;
        _hasError = true;
      });
      ref.read(isServerConnectedProvider.notifier).state = false;
    }
  }

  // ─── Phân loại dữ liệu cho các khối ──────────────────────────────────────
  // Số liệu thật từ Backend: lượt đọc tổng và trong 1 / 7 / 30 ngày (chapter_views).

  List<SeriesItem> get _byViews => [..._allSeries]..sort((a, b) => b.views.compareTo(a.views));

  List<SeriesItem> get _recentlyUpdated =>
      [..._allSeries]
        ..sort((a, b) => (b.latestPublishedAt ?? DateTime(1970)).compareTo(a.latestPublishedAt ?? DateTime(1970)));

  /// Mới đăng: theo ngày tạo bộ truyện (mới nhất trước).
  List<SeriesItem> get _newlyPosted =>
      [..._allSeries]..sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));

  /// Xếp hạng theo lượt đọc trong kỳ; bỏ bộ chưa có lượt đọc nào trong kỳ.
  List<SeriesItem> _topBy(int Function(SeriesItem) views) =>
      _allSeries.where((s) => views(s) > 0).toList()..sort((a, b) => views(b).compareTo(views(a)));

  /// HOT = 3 bộ được đọc nhiều nhất trong 7 ngày qua.
  Set<String> get _hotIds => _topBy((s) => s.viewsLast7Days).take(3).map((s) => s.id).toSet();

  void _openSeries(SeriesItem s) => context.push('/series/${s.id}');

  void _openGrid(String title, List<SeriesItem> list, {String? emptyMessage}) =>
      SeriesGridPage.open(context, title: title, series: list, hotIds: _hotIds, emptyMessage: emptyMessage);

  void _onQuickFilter(String key) {
    switch (key) {
      case 'favorite':
        final ids = PreferencesService.getFavorites();
        _openGrid(
          'Yêu Thích Nhất',
          _allSeries.where((s) => ids.contains(s.id)).toList(),
          emptyMessage: 'Bạn chưa yêu thích bộ truyện nào. Bấm 🤍 Yêu thích ở trang chi tiết truyện.',
        );
      case 'completed':
        _openGrid(
          'Truyện Hoàn Thành',
          _allSeries.where((s) => s.isCompleted).toList(),
          emptyMessage: 'Chưa có bộ truyện nào hoàn thành.',
        );
      case 'day':
        _openGrid('Top Ngày', _topBy((s) => s.viewsLast1Day), emptyMessage: 'Chưa có lượt đọc nào trong 24 giờ qua.');
      case 'week':
        _openGrid('Top Tuần', _topBy((s) => s.viewsLast7Days), emptyMessage: 'Chưa có lượt đọc nào trong 7 ngày qua.');
      case 'month':
        _openGrid(
          'Top Tháng',
          _topBy((s) => s.viewsLast30Days),
          emptyMessage: 'Chưa có lượt đọc nào trong 30 ngày qua.',
        );
      case 'random':
        if (_allSeries.isEmpty) return;
        _openSeries(_allSeries[_random.nextInt(_allSeries.length)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForgeColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchCatalog,
          color: ForgeColors.accent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Top AppBar cố định nền đen.
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: ForgeColors.navBar,
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 58,
                titleSpacing: 0,
                title: _buildTopBar(),
              ),
              if (_isLoading && _allSeries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator(color: ForgeColors.accent)),
                )
              else if (_hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ForgeEmptyState(
                      icon: Icons.cloud_off_rounded,
                      message: 'Không thể kết nối đến máy chủ',
                      actionLabel: 'Thử lại',
                      onAction: _fetchCatalog,
                    ),
                  ),
                )
              else if (_allSeries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ForgeEmptyState(
                      icon: Icons.menu_book_outlined,
                      message: 'Chưa có bộ truyện nào được phát hành.',
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _buildContinueReading()),
                SliverToBoxAdapter(child: _buildQuickFilters()),
                SliverToBoxAdapter(child: _buildRow('TRUYỆN MỚI CẬP NHẬT', _recentlyUpdated)),
                SliverToBoxAdapter(child: _buildRow('ĐỘC QUYỀN PANELFORGE', _byViews)),
                SliverToBoxAdapter(child: _buildRow('TRUYỆN MỚI ĐĂNG', _newlyPosted)),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final authState = ref.watch(authStateProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const ForgeBrandLogo(),
          const Spacer(),
          if (authState.isAuthenticated) const WalletChip(isServerConnected: true),
        ],
      ),
    );
  }

  Widget _buildContinueReading() {
    final history = PreferencesService.getReadingHistory();
    ReadingHistoryEntry? entry;
    SeriesItem? series;
    for (final h in history) {
      final match = _allSeries.where((s) => s.id == h.seriesId);
      if (match.isNotEmpty) {
        entry = h;
        series = match.first;
        break;
      }
    }
    series ??= _allSeries.first;

    final target = series;
    final subtitle = entry != null
        ? '📖 Chương ${entry.chapterNumber}   🕒 ${timeAgo(entry.readAt)}'
        : '📖 ${target.totalChapters} chương   ✨ Gợi ý cho bạn';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ForgeSectionHeader(
          title: 'TIẾP TỤC ĐỌC',
          onMore: history.isEmpty ? null : () => _openGrid('Lịch Sử Đọc', _historySeries(history)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ForgeColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ForgeColors.border, width: 0.8),
            ),
            child: Row(
              children: [
                SizedBox(width: 72, height: 96, child: SeriesCover(series: target, radius: 8)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: ForgeColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.muted)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => entry != null
                              ? openReaderGuarded(context, ref, target.id, entry.chapterId, series: target)
                              : _openSeries(target),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ForgeColors.text,
                            side: BorderSide(color: ForgeColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(
                            entry != null ? 'Đọc Tiếp' : 'Xem Truyện',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<SeriesItem> _historySeries(List<ReadingHistoryEntry> history) => [
    for (final h in history) ..._allSeries.where((s) => s.id == h.seriesId),
  ];

  Widget _buildQuickFilters() {
    const filters = [
      ('favorite', 'YÊU THÍCH NHẤT'),
      ('completed', 'TRUYỆN HOÀN THÀNH'),
      ('day', 'TOP NGÀY'),
      ('week', 'TOP TUẦN'),
      ('month', 'TOP THÁNG'),
      ('random', 'TRUYỆN NGẪU NHIÊN'),
    ];
    return SizedBox(
      height: 64,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (key, label) = filters[i];
          return InkWell(
            onTap: () => _onQuickFilter(key),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ForgeColors.tile,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ForgeColors.border, width: 0.6),
              ),
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ForgeColors.text,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow(String title, List<SeriesItem> list) {
    final hot = _hotIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ForgeSectionHeader(title: title, onMore: () => _openGrid(_titleCase(title), list)),
        SizedBox(
          height: 228,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: list.length.clamp(0, 12),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => ComicCard(
              series: list[i],
              width: 120,
              isHot: hot.contains(list[i].id),
              onTap: () => _openSeries(list[i]),
            ),
          ),
        ),
      ],
    );
  }

  static String _titleCase(String upper) => upper
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ')
      .replaceAll('Panelforge', 'PanelForge');
}
