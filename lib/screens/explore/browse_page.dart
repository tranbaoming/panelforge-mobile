import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';
import 'series_grid_page.dart';

/// Tab Khám phá: chỉ là lưới thể loại 2 cột (định dạng Comic/Manga/Webtoon trước, sau đó các thể loại có trong
/// catalog). Chạm một ô → mở lưới bộ truyện thuộc thể loại đó (`SeriesGridPage`). Tìm kiếm nằm ở `search_page.dart`.
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

/// Một ô thể loại: định dạng (Manga…) hoặc thể loại (Action…).
class _Category {
  final String label;
  final bool Function(SeriesItem) matches;
  const _Category(this.label, this.matches);
}

class _BrowsePageState extends State<BrowsePage> {
  List<SeriesItem> _series = [];
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  /// Tải toàn bộ catalog (server giới hạn 50 bộ/trang) để mỗi thể loại liệt kê đủ bộ truyện.
  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final service = CatalogService();
      final all = <SeriesItem>[];
      var page = 1;
      while (true) {
        final res = await service.getSeries(pageIndex: page, pageSize: 50);
        all.addAll(res.items.map(SeriesItem.fromPublicDto));
        if (page >= res.totalPages || res.items.isEmpty || page >= 20) break;
        page++;
      }
      if (!mounted) return;
      setState(() {
        _series = all;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[Browse Load Error] $e');
      if (!mounted) return;
      setState(() {
        _series = [];
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  List<_Category> get _categories {
    final genres = {for (final s in _series) s.genres.first.trim()}.where((g) => g.isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final formatLabels = {for (final f in ComicFormat.values) f.label.toLowerCase()};
    return [
      for (final f in ComicFormat.values) _Category(f.label, (s) => s.format == f),
      for (final g in genres)
        if (!formatLabels.contains(g.toLowerCase())) _Category(g, (s) => s.genres.first.trim() == g),
    ];
  }

  void _open(_Category c) {
    final list = _series.where(c.matches).toList()
      ..sort((a, b) {
        final ta = a.latestPublishedAt, tb = b.latestPublishedAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });
    SeriesGridPage.open(
      context,
      title: genreLabel(c.label),
      series: list,
      emptyMessage: _hasError ? 'Không thể kết nối đến máy chủ' : 'Chưa có bộ truyện nào thuộc thể loại này.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categories;
    return Scaffold(
      backgroundColor: ForgeColors.bg,
      appBar: const ForgeTopBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetch,
          color: ForgeColors.accent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 52,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _GenreTile(label: genreLabel(categories[i].label), onTap: () => _open(categories[i])),
                    childCount: categories.length,
                  ),
                ),
              ),
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: ForgeColors.accent)),
                  ),
                )
              else if (_hasError)
                SliverToBoxAdapter(
                  child: ForgeEmptyState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Không thể kết nối đến máy chủ',
                    actionLabel: 'Thử lại',
                    onAction: _fetch,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GenreTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForgeColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ForgeColors.divider),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: ForgeColors.text),
          ),
        ),
      ),
    );
  }
}
