import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/forge_ui.dart';

/// Tab Tìm kiếm: không có Top AppBar, chỉ một ô tìm kiếm.
/// Ô trống → bên dưới để trống; có từ khóa → lọc realtime theo tên truyện hoặc tác giả / Studio.
///
/// Backend chỉ tìm theo tên (`search` của /api/catalog/series), nên màn này tải toàn bộ catalog
/// một lần rồi lọc tại máy để tìm được cả theo Studio.
class SearchPage extends StatefulWidget {
  /// Nguồn dữ liệu (thay được trong test). Mặc định: tải mọi trang catalog công khai.
  final Future<List<SeriesItem>> Function()? loadCatalog;

  const SearchPage({super.key, this.loadCatalog});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _maxPages = 20; // 20 × 50 = 1000 bộ truyện

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<SeriesItem>? _catalog;
  bool _isLoading = false;
  bool _hasError = false;
  String _query = '';

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

  static Future<List<SeriesItem>> _loadAllPages() async {
    final service = CatalogService();
    final all = <SeriesItem>[];
    for (var page = 1; page <= _maxPages; page++) {
      final res = await service.getSeries(pageIndex: page, pageSize: 50);
      all.addAll(res.items.map(SeriesItem.fromPublicDto));
      if (page >= res.totalPages || res.items.isEmpty) break;
    }
    return all;
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final items = await (widget.loadCatalog ?? _loadAllPages)();
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

  List<SeriesItem> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return (_catalog ?? const <SeriesItem>[])
        .where((s) => s.title.toLowerCase().contains(q) || s.author.toLowerCase().contains(q))
        .toList();
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  void _submit() {
    setState(() => _query = _controller.text);
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
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: _buildSearchField()),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final hasText = _query.isNotEmpty;
    return SizedBox(
      height: 52,
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
          hintText: 'Nhập tên truyện hoặc tác giả',
          hintStyle: GoogleFonts.plusJakartaSans(fontSize: 16, color: ForgeColors.muted),
          filled: true,
          fillColor: ForgeColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: _border(ForgeColors.searchBorder),
          focusedBorder: _border(ForgeColors.accent),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                IconButton(
                  tooltip: 'Xóa',
                  icon: Icon(Icons.close_rounded, color: ForgeColors.textSoft, size: 20),
                  onPressed: _clear,
                ),
              IconButton(
                tooltip: 'Tìm kiếm',
                icon: Icon(Icons.search, color: ForgeColors.textSoft),
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color, width: 1),
  );

  Widget _buildBody() {
    // Ô trống → để trống hoàn toàn.
    if (_query.trim().isEmpty) return const SizedBox.expand();

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
    if (results.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy bộ truyện nào phù hợp',
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: ForgeColors.muted),
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) =>
          _SearchResultCard(series: results[i], onTap: () => context.push('/series/${results[i].id}')),
    );
  }
}

/// Thẻ kết quả: ảnh bìa dọc, tên truyện, tác giả / Studio, chương mới nhất.
class _SearchResultCard extends StatelessWidget {
  final SeriesItem series;
  final VoidCallback onTap;

  const _SearchResultCard({required this.series, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForgeColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(width: 66, height: 88, child: SeriesCover(series: series, radius: 8)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      series.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ForgeColors.text,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      series.author.isEmpty ? 'PanelForge Studio' : series.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.textSoft),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chương ${series.totalChapters}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ForgeColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: ForgeColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
