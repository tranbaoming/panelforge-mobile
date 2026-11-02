import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../providers/api_providers.dart';
import '../../theme/app_theme.dart';
import '../../services/api_config.dart';
import '../../services/catalog_service.dart';
import '../../services/preferences_service.dart';
import '../../widgets/wallet_chip.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  List<SeriesItem> _allSeries = [];
  String _searchQuery = '';
  ComicFormat? _selectedFormat;
  late final TextEditingController _searchController;
  bool _isLoading = false;
  bool _isLiveBackend = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final res = await CatalogService().getSeries(
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );
      if (mounted) {
        setState(() {
          _allSeries = res.items.map((e) => SeriesItem.fromPublicDto(e)).toList();
          _isLiveBackend = true;
          _isLoading = false;
          _hasError = false;
        });
        ref.read(isServerConnectedProvider.notifier).state = true;
        ref.read(walletNotifierProvider.notifier).refresh();
      }
    } catch (e) {
      debugPrint('[Catalog Load Error] $e');
      if (mounted) {
        setState(() {
          _allSeries = [];
          _isLiveBackend = false;
          _isLoading = false;
          _hasError = true;
        });
        ref.read(isServerConnectedProvider.notifier).state = false;
      }
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedFormat = null;
    });
    _fetchCatalog();
  }

  void _showServerConfigDialog() {
    final ipController = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Cấu Hình Máy Chủ',
            style: GoogleFonts.newsreader(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Địa chỉ máy chủ API:',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.darkTextSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.darkCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.darkBorder),
                  ),
                  hintText: 'http://10.0.2.2:5044',
                  hintStyle: const TextStyle(color: Colors.white38),
                  isDense: true,
                ),
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _isLiveBackend ? AppColors.mint : AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isLiveBackend ? 'Đã kết nối máy chủ' : 'Chưa có kết nối máy chủ',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isLiveBackend ? AppColors.mint : AppColors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await PreferencesService.setCustomBaseUrl(ipController.text.trim());
                if (context.mounted) Navigator.of(context).pop();
                _fetchCatalog();
                ref.read(walletNotifierProvider.notifier).refresh();
              },
              child: const Text('Lưu & Thử kết nối'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SeriesItem> get _filteredSeries {
    return _allSeries.where((series) {
      final matchesQuery = _searchQuery.isEmpty ||
          series.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          series.author.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          series.genres.any((g) => g.toLowerCase().contains(_searchQuery.toLowerCase()));

      final matchesFormat = _selectedFormat == null || series.format == _selectedFormat;

      return matchesQuery && matchesFormat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchCatalog,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // App Bar with Brand Title & Profile
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _isLiveBackend ? AppColors.mint : AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _isLiveBackend ? 'PANELFORGE • TRỰC TUYẾN' : 'PANELFORGE',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2.0,
                                      color: _isLiveBackend ? AppColors.mint : AppColors.primary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Khám Phá Truyện Tranh',
                              style: GoogleFonts.newsreader(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          if (_isLiveBackend) ...[
                            const WalletChip(isServerConnected: true),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                : const Icon(Icons.tune_rounded),
                            onPressed: _showServerConfigDialog,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.darkSurface,
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.darkBorder),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.darkBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm bộ truyện, tác giả, thể loại...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppColors.darkTextSecondary,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white70),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ),

            // Format Filter Chips: Tất cả, Comic, Manga, Webtoon
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildFormatChip(null, 'Tất Cả'),
                      const SizedBox(width: 8),
                      ...ComicFormat.values.map((fmt) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFormatChip(fmt, fmt.label),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            if (_isLoading && _allSeries.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Đang tải danh mục tác phẩm...',
                        style: GoogleFonts.plusJakartaSans(color: AppColors.darkTextSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else if (_hasError && _allSeries.isEmpty)
              // Khi gặp lỗi kết nối mạng / không gọi được Backend (Error State)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.darkSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.darkBorder),
                          ),
                          child: const Icon(
                            Icons.cloud_off_rounded,
                            size: 40,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Không thể kết nối đến máy chủ',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.newsreader(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Đã xảy ra sự cố khi tải dữ liệu. Vui lòng kiểm tra lại kết nối mạng hoặc thiết lập máy chủ của bạn.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchCatalog,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Thử lại',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showServerConfigDialog,
                          icon: const Icon(Icons.settings_outlined, size: 16, color: AppColors.darkTextSecondary),
                          label: Text(
                            'Cấu hình máy chủ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.darkTextSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_allSeries.isEmpty)
              // Khi danh sách truyện rỗng (chưa có truyện xuất bản)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.darkSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.darkBorder),
                          ),
                          child: const Icon(
                            Icons.auto_stories_outlined,
                            size: 40,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Chưa có tác phẩm nào được phát hành',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.newsreader(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Các bộ truyện mới đang trong quá trình hoàn thiện và sẽ sớm ra mắt. Hãy kéo xuống hoặc bấm làm mới để cập nhật danh mục mới nhất.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchCatalog,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            'Làm mới',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_filteredSeries.isEmpty)
              // Khi người dùng đang nhập từ khóa tìm kiếm hoặc chọn bộ lọc nhưng không có kết quả
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.darkSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.darkBorder),
                          ),
                          child: const Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Không tìm thấy tác phẩm phù hợp',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.newsreader(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Không có bộ truyện nào khớp với từ khóa hoặc bộ lọc hiện tại của bạn.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear_all_rounded, size: 18),
                          label: const Text(
                            'Xóa bộ lọc',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // Banner Tiêu Điểm Tuần (Weekly Spotlight)
              if (_searchQuery.isEmpty && _selectedFormat == null && _allSeries.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: _buildSpotlightBanner(context, _allSeries.first),
                  ),
                ),

              // Section Header: Truyện Đã Lên Kệ
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Truyện Đã Lên Kệ',
                            style: GoogleFonts.newsreader(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_filteredSeries.length}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Xem tất cả',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Lưới truyện 2 cột (2-Column Grid)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.60,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _filteredSeries[index];
                      return _buildComicGridCard(context, item);
                    },
                    childCount: _filteredSeries.length,
                  ),
                ),
              ),

              // Ghi Chú Biên Tập (Editorial Notes)
              if (_allSeries.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                    child: _buildEditorialNoteCard(_allSeries.first),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFormatChip(ComicFormat? format, String label) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFormat = format;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.darkBorder,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.darkTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSpotlightBanner(BuildContext context, SeriesItem item) {
    return GestureDetector(
      onTap: () => context.push('/series/${item.id}'),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(int.parse(item.coverGradientStart)),
              Color(int.parse(item.coverGradientEnd)),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background line art motif
              Positioned(
                right: -30,
                bottom: -30,
                child: Opacity(
                  opacity: 0.15,
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 240,
                    color: Colors.white,
                  ),
                ),
              ),

              // Content overlay
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge: Tiêu điểm tuần
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'TIÊU ĐIỂM TUẦN',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${item.rating}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Title & Synopsis quote
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.newsreader(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.synopsisQuote,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.newsreader(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),

                    // Author & CTA row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tác giả: ${item.author}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Xem bộ truyện',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.black87),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComicGridCard(BuildContext context, SeriesItem item) {
    return GestureDetector(
      onTap: () => context.push('/series/${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book cover representation with print spine & 3D shadow
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(int.parse(item.coverGradientStart)),
                    Color(int.parse(item.coverGradientEnd)),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(2, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Spine line simulation
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 7,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Format Badge (Comic / Manga / Webtoon)
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.format.label.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // Progress Indicator if reading
                  if (item.readProgressChapter > 0)
                    Positioned(
                      bottom: 8,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Đang đọc ch.${item.readProgressChapter}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Title
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.newsreader(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),

          // Author & Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 13, color: AppColors.amber),
                  Text(
                    '${item.rating}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditorialNoteCard(SeriesItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'GHI CHÚ BIÊN TẬP (EDITORIAL)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '“${item.editorialNote}”',
            style: GoogleFonts.newsreader(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '— Ban Biên Tập Hội Đồng PanelForge',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.darkTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
