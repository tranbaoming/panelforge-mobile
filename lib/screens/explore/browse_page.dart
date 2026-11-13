import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';

/// Tab Khám phá / Danh mục (lọc theo định dạng & thể loại) và tab Tìm kiếm (`searchMode`).
class BrowsePage extends StatefulWidget {
  final bool searchMode;
  const BrowsePage({super.key, this.searchMode = false});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final _searchController = TextEditingController();
  List<SeriesItem> _series = [];
  bool _isLoading = false;
  bool _hasError = false;
  ComicFormat? _format;
  String? _genre;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final res = await CatalogService().getSeries(search: _query.isEmpty ? null : _query, pageSize: 50);
      if (!mounted) return;
      setState(() {
        _series = res.items.map((e) => SeriesItem.fromPublicDto(e)).toList();
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

  List<String> get _genres => {for (final s in _series) s.genres.first}.where((g) => g.isNotEmpty).toList()..sort();

  List<SeriesItem> get _filtered => _series.where((s) {
    final q = _query.toLowerCase();
    final matchesQuery =
        q.isEmpty ||
        s.title.toLowerCase().contains(q) ||
        s.author.toLowerCase().contains(q) ||
        s.genres.any((g) => g.toLowerCase().contains(q));
    return matchesQuery && (_format == null || s.format == _format) && (_genre == null || s.genres.contains(_genre));
  }).toList();

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return Scaffold(
      backgroundColor: ForgeColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                widget.searchMode ? 'Tìm Kiếm' : 'Khám Phá',
                style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: ForgeColors.text),
              ),
            ),
            if (widget.searchMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  style: TextStyle(color: ForgeColors.text),
                  onChanged: (v) => setState(() => _query = v.trim()),
                  onSubmitted: (_) => _fetch(),
                  decoration: InputDecoration(
                    hintText: 'Tên truyện, studio, thể loại...',
                    hintStyle: const TextStyle(color: ForgeColors.muted),
                    prefixIcon: const Icon(Icons.search_rounded, color: ForgeColors.muted),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, color: ForgeColors.muted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                              _fetch();
                            },
                          ),
                    filled: true,
                    fillColor: ForgeColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              )
            else ...[
              _chipRow([
                _chip('Tất Cả', _format == null, () => setState(() => _format = null)),
                for (final f in ComicFormat.values)
                  _chip(f.label, _format == f, () => setState(() => _format = _format == f ? null : f)),
              ]),
              if (_genres.isNotEmpty)
                _chipRow([
                  for (final g in _genres)
                    _chip(genreLabel(g), _genre == g, () => setState(() => _genre = _genre == g ? null : g)),
                ]),
            ],
            Expanded(child: _buildBody(results)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<SeriesItem> results) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: ForgeColors.accent));
    if (_hasError) {
      return Center(
        child: ForgeEmptyState(
          icon: Icons.cloud_off_rounded,
          message: 'Không thể kết nối đến máy chủ',
          actionLabel: 'Thử lại',
          onAction: _fetch,
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: ForgeEmptyState(
          icon: Icons.search_off_rounded,
          message: widget.searchMode && _query.isEmpty
              ? 'Nhập tên truyện để tìm kiếm.'
              : 'Không tìm thấy bộ truyện phù hợp.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      color: ForgeColors.accent,
      child: ComicGrid(series: results, onOpen: (s) => context.push('/series/${s.id}')),
    );
  }

  Widget _chipRow(List<Widget> chips) => SizedBox(
    height: 44,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, i) => chips[i],
    ),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? ForgeColors.accent : ForgeColors.chip,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : ForgeColors.text,
        ),
      ),
    ),
  );
}
