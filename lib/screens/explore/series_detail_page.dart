import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../theme/app_theme.dart';
import '../../services/catalog_service.dart';
import '../../services/preferences_service.dart';

class SeriesDetailPage extends StatefulWidget {
  final String seriesId;

  const SeriesDetailPage({super.key, required this.seriesId});

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  SeriesItem? _series;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isNewestFirst = false;

  @override
  void initState() {
    super.initState();
    _fetchDetailFromApi();
  }

  Future<void> _fetchDetailFromApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final detail = await CatalogService().getSeriesDetail(widget.seriesId);
      if (mounted) {
        final bookmarked = PreferencesService.isBookmarked(widget.seriesId);
        setState(() {
          _series = SeriesItem.fromPublicDetailDto(detail).copyWith(isBookmarked: bookmarked);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[SeriesDetail API Error] $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể tải thông tin tác phẩm. Vui lòng kiểm tra lại kết nối mạng.';
        });
      }
    }
  }

  void _toggleBookmark() async {
    if (_series == null) return;
    final newState = await PreferencesService.toggleBookmark(_series!.id);
    if (mounted) {
      setState(() {
        _series = _series!.copyWith(isBookmarked: newState);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState ? 'Đã thêm vào tủ sách cá nhân' : 'Đã xóa khỏi tủ sách',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_series == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _errorMessage != null ? Icons.cloud_off_rounded : Icons.menu_book_outlined,
                  size: 48,
                  color: AppColors.darkTextSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Không tìm thấy tác phẩm này trên hệ thống.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _fetchDetailFromApi,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tải lại'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final series = _series!;
    final chaptersList = List<ChapterItem>.from(series.chapters);
    if (_isNewestFirst) {
      chaptersList.sort((a, b) => b.number.compareTo(a.number));
    } else {
      chaptersList.sort((a, b) => a.number.compareTo(b.number));
    }

    final readPercent = series.totalChapters > 0
        ? ((series.readProgressChapter / series.totalChapters) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collapsible Custom AppBar with Book Cover Visual
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: AppColors.darkBg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  series.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: series.isBookmarked ? AppColors.primary : Colors.white70,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                ),
                onPressed: _toggleBookmark,
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(int.parse(series.coverGradientStart)).withValues(alpha: 0.35),
                      AppColors.darkBg,
                    ],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: _buildPrintBookCover(series),
                  ),
                ),
              ),
            ),
          ),

          // Series Information Body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Format Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          series.title,
                          style: GoogleFonts.newsreader(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          series.format.label.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Author & Artist
                  Text(
                    'Tác giả: ${series.author} • Họa sĩ: ${series.artist}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkTextSecondary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Genre Badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: series.genres.map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: Text(
                          g,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Reading Progress Box (Ước tính tiến độ đọc)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timelapse_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'ƯỚC TÍNH TIẾN ĐỘ ĐỌC',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Chương ${series.readProgressChapter} / ${series.totalChapters} • $readPercent%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: series.totalChapters > 0
                                ? (series.readProgressChapter / series.totalChapters).clamp(0.0, 1.0)
                                : 0.0,
                            backgroundColor: AppColors.darkBorder,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Tóm Tắt Trích Dẫn (Synopsis Quote & Full Synopsis)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (series.synopsisQuote.isNotEmpty)
                          Text(
                            series.synopsisQuote,
                            style: GoogleFonts.newsreader(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        if (series.synopsisQuote.isNotEmpty)
                          const SizedBox(height: 10),
                        Text(
                          series.fullSynopsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.darkTextSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Primary CTA Buttons: Đọc chương đầu / Đọc tiếp
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (series.chapters.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tác phẩm chưa có chương truyện nào được phát hành')),
                              );
                              return;
                            }
                            final firstCh = series.chapters.first;
                            context.push('/reader/${series.id}?chapterId=${firstCh.id}');
                          },
                          icon: const Icon(Icons.play_circle_filled_rounded, size: 20),
                          label: Text(
                            series.readProgressChapter > 0
                                ? 'ĐỌC TIẾP CHƯƠNG ${series.readProgressChapter}'
                                : 'ĐỌC CHƯƠNG ĐẦU',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: _toggleBookmark,
                        icon: Icon(
                          series.isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                          color: series.isBookmarked ? AppColors.primary : Colors.white70,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.darkSurface,
                          side: const BorderSide(color: AppColors.darkBorder),
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Danh Sách Chương & Bộ Sắp Xếp (Mới nhất / Cũ nhất)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Danh Sách Chương (${chaptersList.length})',
                        style: GoogleFonts.newsreader(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (chaptersList.isNotEmpty)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _isNewestFirst = !_isNewestFirst;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.darkSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.darkBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isNewestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isNewestFirst ? 'Mới nhất' : 'Cũ nhất',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Chapter List Items or Empty
          if (chaptersList.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 40, color: Colors.white30),
                      const SizedBox(height: 8),
                      Text(
                        'Chưa có chương nào được phát hành',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final ch = chaptersList[index];
                    return _buildChapterListItem(context, series, ch);
                  },
                  childCount: chaptersList.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildPrintBookCover(SeriesItem series) {
    return Container(
      width: 140,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(int.parse(series.coverGradientStart)),
            Color(int.parse(series.coverGradientEnd)),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(4, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Realistic Print Book Spine Simulation
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 10,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
          ),
          // Embossed metallic border
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          // Cover typography
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'BẢN IN GỐC',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.withValues(alpha: 0.8),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    series.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    series.author,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterListItem(BuildContext context, SeriesItem series, ChapterItem chapter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          chapter.title,
          style: GoogleFonts.newsreader(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              '${chapter.releaseDate} • ${chapter.pageCount} trang',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.darkTextSecondary,
              ),
            ),
            if (!chapter.isFree) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 10, color: AppColors.amber),
                    const SizedBox(width: 3),
                    Text(
                      'Khóa',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AppColors.primary,
        ),
        onTap: () {
          context.push('/reader/${series.id}?chapterId=${chapter.id}');
        },
      ),
    );
  }
}
