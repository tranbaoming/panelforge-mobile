import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../providers/catalog_providers.dart';
import '../../services/catalog_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';

/// Tab Tìm kiếm: ô tìm ở trên cùng, hàng bộ lọc (Sắp xếp / Thể loại / Trạng thái), lịch sử tìm kiếm,
/// bên dưới là danh sách truyện. Có từ khóa → lọc realtime theo tên truyện, tác giả / Studio hoặc thể loại.
///
/// Backend chỉ tìm theo tên (`search` của /api/catalog/series), nên màn này tải toàn bộ catalog
/// một lần rồi lọc tại máy để tìm được cả theo Studio / thể loại.
class SearchPage extends StatefulWidget {
  /// Nguồn dữ liệu (thay được trong test). Mặc định: tải mọi trang catalog công khai.
  final Future<List<SeriesItem>> Function()? loadCatalog;

  const SearchPage({super.key, this.loadCatalog});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<SeriesItem>? _catalog;
  bool _isLoading = false;
  bool _hasError = false;
  String _query = '';
  SearchSort _sort = SearchSort.alphabetical;
  String? _genre;
  SeriesStatusFilter _status = SeriesStatusFilter.all;
  List<String> _recent = PreferencesService.getRecentSearches();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final items = await (widget.loadCatalog ?? () => loadWholeCatalog(CatalogService()))();
      if (!mounted) return;
      setState(() {
        _catalog = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[Search Load Error] $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  CatalogSections get _sections => CatalogSections(_catalog ?? const <SeriesItem>[]);

  bool get _filtersActive => _genre != null || _status != SeriesStatusFilter.all;

  /// Lọc theo từ khóa (tên / Studio / thể loại), thể loại và trạng thái, rồi sắp xếp theo lựa chọn.
  List<SeriesItem> get _results {
    final q = _query.trim().toLowerCase();
    final sections = _sections;
    final base = switch (_sort) {
      SearchSort.alphabetical => sections.alphabetical,
      SearchSort.mostViewed => sections.byViews,
      SearchSort.recentlyUpdated => sections.recentlyUpdated,
      SearchSort.newest => sections.newest,
    };
    return base.where((s) {
      if (_genre != null && !s.genres.contains(_genre)) return false;
      if (_status == SeriesStatusFilter.ongoing && s.isCompleted) return false;
      if (_status == SeriesStatusFilter.completed && !s.isCompleted) return false;
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q) ||
          s.author.toLowerCase().contains(q) ||
          s.genres.any((g) => g.toLowerCase().contains(q));
    }).toList();
  }

  List<String> get _allGenres {
    final set = <String>{for (final s in _catalog ?? const <SeriesItem>[]) ...s.genres};
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> _remember(String query) async {
    await PreferencesService.addRecentSearch(query);
    if (mounted) setState(() => _recent = PreferencesService.getRecentSearches());
  }

  void _useRecent(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    setState(() => _query = query);
    _remember(query);
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  void _submit() {
    setState(() => _query = _controller.text);
    _remember(_controller.text);
    _focusNode.unfocus();
    if (_hasError) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForgeColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: _buildSearchField()),
            if (_catalog != null) _buildFilterBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final hasText = _query.isNotEmpty;
    return SizedBox(
      height: 54,
      child: TextField(
        key: const ValueKey('search-field'),
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        cursorColor: ForgeColors.accent,
        style: GoogleFonts.plusJakartaSans(fontSize: 16, color: ForgeColors.text),
        onChanged: (v) => setState(() => _query = v),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'Tìm theo tên truyện, tác giả...',
          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 16, color: ForgeColors.muted),
          filled: true,
          fillColor: ForgeColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefixIcon: IconButton(
            tooltip: 'Tìm kiếm',
            icon: const Icon(Icons.search_rounded, color: ForgeColors.muted, size: 24),
            onPressed: _submit,
          ),
          enabledBorder: _border(Colors.transparent),
          focusedBorder: _border(ForgeColors.accent),
          suffixIcon: hasText
              ? IconButton(
                  tooltip: 'Xóa',
                  icon: Icon(Icons.close_rounded, color: ForgeColors.textSoft, size: 20),
                  onPressed: _clear,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final genres = _allGenres;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _MenuChip<SearchSort>(
            key: const ValueKey('filter-sort'),
            icon: Icons.sort_rounded,
            label: _sort.label,
            active: _sort != SearchSort.alphabetical,
            values: SearchSort.values,
            selected: _sort,
            itemLabel: (v) => v.label,
            onSelected: (v) => setState(() => _sort = v),
          ),
          const SizedBox(width: 8),
          _MenuChip<String>(
            key: const ValueKey('filter-genre'),
            icon: Icons.category_outlined,
            label: _genre ?? 'Thể loại',
            active: _genre != null,
            values: ['', ...genres],
            selected: _genre ?? '',
            itemLabel: (v) => v.isEmpty ? 'Tất cả thể loại' : v,
            onSelected: (v) => setState(() => _genre = v.isEmpty ? null : v),
          ),
          const SizedBox(width: 8),
          _MenuChip<SeriesStatusFilter>(
            key: const ValueKey('filter-status'),
            icon: Icons.flag_outlined,
            label: _status == SeriesStatusFilter.all ? 'Trạng thái' : _status.label,
            active: _status != SeriesStatusFilter.all,
            values: SeriesStatusFilter.values,
            selected: _status,
            itemLabel: (v) => v.label,
            onSelected: (v) => setState(() => _status = v),
          ),
          if (_filtersActive || _sort != SearchSort.alphabetical) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: () => setState(() {
                _sort = SearchSort.alphabetical;
                _genre = null;
                _status = SeriesStatusFilter.all;
              }),
              child: Text('Bỏ lọc', style: GoogleFonts.plusJakartaSans(color: ForgeColors.accent)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tìm gần đây',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: ForgeColors.textSoft),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await PreferencesService.clearRecentSearches();
                  if (mounted) setState(() => _recent = const []);
                },
                child: Text('Xoá lịch sử', style: GoogleFonts.plusJakartaSans(color: ForgeColors.muted)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final q in _recent)
                InputChip(
                  key: ValueKey('recent-$q'),
                  label: Text(q),
                  labelStyle: GoogleFonts.plusJakartaSans(color: ForgeColors.text),
                  backgroundColor: ForgeColors.surface,
                  side: BorderSide(color: ForgeColors.divider),
                  onPressed: () => _useRecent(q),
                  deleteButtonTooltipMessage: 'Xoá "$q"',
                  onDeleted: () async {
                    await PreferencesService.removeRecentSearch(q);
                    if (mounted) setState(() => _recent = PreferencesService.getRecentSearches());
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color, width: 1.2),
  );

  Widget _buildBody() {
    if (_isLoading && _catalog == null) {
      return const Center(child: CircularProgressIndicator(color: ForgeColors.accent));
    }
    if (_hasError && _catalog == null) {
      return Center(
        child: ForgeEmptyState(
          icon: Icons.cloud_off_rounded,
          message: 'Không thể kết nối đến máy chủ',
          actionLabel: 'Thử lại',
          onAction: _load,
        ),
      );
    }

    final results = _results;
    final searching = _query.trim().isNotEmpty;
    final sections = _sections;
    final narrowed = searching || _filtersActive;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (!searching && _recent.isNotEmpty) SliverToBoxAdapter(child: _buildRecentSearches()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              narrowed
                  ? 'Kết quả (${results.length})'
                  : _sort == SearchSort.alphabetical
                  ? 'Truyện (A–Z)'
                  : 'Truyện • ${_sort.label}',
              style: GoogleFonts.plusJakartaSans(fontSize: 21, fontWeight: FontWeight.w800, color: ForgeColors.text),
            ),
          ),
        ),
        if (results.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                narrowed ? 'Không tìm thấy bộ truyện nào phù hợp' : 'Chưa có bộ truyện nào được phát hành.',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: ForgeColors.muted),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList.separated(
              itemCount: results.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: ForgeColors.divider),
              itemBuilder: (_, i) => _SeriesRow(
                series: results[i],
                isNew: sections.isNew(results[i]),
                isUpdated: sections.isUpdated(results[i]),
                onTap: () {
                  if (searching) _remember(_query);
                  context.push('/series/${results[i].id}');
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Một dòng A–Z: ảnh bìa bên trái; bên phải huy hiệu, tên truyện, Studio, lượt đọc và ngày cập nhật.
class _SeriesRow extends StatelessWidget {
  final SeriesItem series;
  final bool isNew;
  final bool isUpdated;
  final VoidCallback onTap;

  const _SeriesRow({required this.series, required this.isNew, required this.isUpdated, required this.onTap});

  static const _thumbH = 112.0;
  static const _thumbW = _thumbH * 3 / 4;

  @override
  Widget build(BuildContext context) {
    final updated = series.latestPublishedAt;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bìa dọc 3:4 hiển thị trọn vẹn (không cắt).
            SizedBox(
              width: _thumbW,
              height: _thumbH,
              child: SeriesCover(series: series, radius: 6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: _thumbH,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StudioStrip(studio: series.author),
                    const SizedBox(height: 5),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (isNew)
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: _Gap(SeriesBadge.newSeries()),
                            ),
                          if (isUpdated)
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: _Gap(SeriesBadge.updated()),
                            ),
                          TextSpan(text: series.title),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: ForgeColors.text,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.visibility_rounded, size: 16, color: ForgeColors.muted),
                        const SizedBox(width: 4),
                        Text(formatViews(series.views), style: ForgeText.tabular(fontSize: 13.5)),
                        const SizedBox(width: 10),
                        Text(
                          '${series.totalChapters} chương',
                          style: ForgeText.tabular(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: ForgeColors.muted,
                          ),
                        ),
                        const Spacer(),
                        if (updated != null)
                          Text(
                            '${updated.day.toString().padLeft(2, '0')}/${updated.month.toString().padLeft(2, '0')}/${updated.year}',
                            style: ForgeText.tabular(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ForgeColors.textSoft,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  final Widget child;
  const _Gap(this.child);

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 5), child: child);
}

enum SearchSort {
  alphabetical('A–Z'),
  mostViewed('Xem nhiều'),
  recentlyUpdated('Mới cập nhật'),
  newest('Truyện mới');

  final String label;
  const SearchSort(this.label);
}

enum SeriesStatusFilter {
  all('Tất cả'),
  ongoing('Đang ra'),
  completed('Hoàn thành');

  final String label;
  const SeriesStatusFilter(this.label);
}

/// Chip mở menu chọn một giá trị (Sắp xếp / Thể loại / Trạng thái); viền cam khi đang lọc.
class _MenuChip<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final List<T> values;
  final T selected;
  final String Function(T) itemLabel;
  final ValueChanged<T> onSelected;

  const _MenuChip({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.values,
    required this.selected,
    required this.itemLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? ForgeColors.accent : ForgeColors.textSoft;
    return PopupMenuButton<T>(
      tooltip: label,
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final v in values)
          CheckedPopupMenuItem<T>(value: v, checked: v == selected, child: Text(itemLabel(v))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? ForgeColors.accentSoft : ForgeColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? ForgeColors.accent : ForgeColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}
