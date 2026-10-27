import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/comic_model.dart';
import '../../theme/app_theme.dart';

class SeriesDetailPage extends StatefulWidget {
  final String seriesId;

  const SeriesDetailPage({super.key, required this.seriesId});

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  late SeriesItem _series;
  bool _isNewestFirst = false;

  @override
  void initState() {
    super.initState();
    final all = MockDataRepository.getMockSeries();
    _series = all.firstWhere(
      (s) => s.id == widget.seriesId,
      orElse: () => all.first,
    );
  }

  void _toggleBookmark() {
    setState(() {
      _series = _series.copyWith(isBookmarked: !_series.isBookmarked);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _series.isBookmarked ? 'Đã thêm vào tủ sách cá nhân' : 'Đã xóa khỏi tủ sách',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chaptersList = List<ChapterItem>.from(_series.chapters);
    if (_isNewestFirst) {
      chaptersList.sort((a, b) => b.number.compareTo(a.number));
    } else {
      chaptersList.sort((a, b) => a.number.compareTo(b.number));
    }

    final readPercent = ((_series.readProgressChapter / _series.totalChapters) * 100).round();

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Collapsible Custom AppBar with Book Cover Visual
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: AppColors.lightBg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white70,
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _series.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _series.isBookmarked ? AppColors.primary : AppColors.lightTextPrimary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white70,
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
                      Color(int.parse(_series.coverGradientStart)).withValues(alpha: 0.25),
                      AppColors.lightBg,
                    ],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: _buildPrintBookCover(_series),
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
                          _series.title,
                          style: GoogleFonts.newsreader(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.lightTextPrimary,
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
                          _series.format.label.toUpperCase(),
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
                    'Tác giả: ${_series.author} • Họa sĩ: ${_series.artist}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Genre Badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _series.genres.map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.lightBorder),
                        ),
                        child: Text(
                          g,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightTextPrimary,
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
                      color: AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.lightBorder),
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
                              'Chương ${_series.readProgressChapter} / ${_series.totalChapters} • $readPercent%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (_series.readProgressChapter / _series.totalChapters).clamp(0.0, 1.0),
                            backgroundColor: AppColors.lightBorder,
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
                      color: AppColors.lightVintagePaper,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _series.synopsisQuote,
                          style: GoogleFonts.newsreader(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightTextPrimary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _series.fullSynopsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.lightTextSecondary,
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
                            // Read first chapter or resume
                            final firstCh = _series.chapters.first;
                            context.push('/reader/${_series.id}?chapterId=${firstCh.id}');
                          },
                          icon: const Icon(Icons.play_circle_filled_rounded, size: 20),
                          label: Text(
                            _series.readProgressChapter > 0
                                ? 'ĐỌC TIẾP CHƯƠNG ${_series.readProgressChapter}'
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
                          _series.isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                          color: _series.isBookmarked ? AppColors.primary : AppColors.lightTextPrimary,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.lightSurface,
                          side: const BorderSide(color: AppColors.lightBorder),
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
                        'Danh Sách Chương (${_series.chapters.length})',
                        style: GoogleFonts.newsreader(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lightTextPrimary,
                        ),
                      ),
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
                            color: AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.lightBorder),
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
                                  color: AppColors.lightTextPrimary,
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

          // Chapter List Items
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ch = chaptersList[index];
                  return _buildChapterListItem(context, ch);
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

  Widget _buildChapterListItem(BuildContext context, ChapterItem chapter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          chapter.title,
          style: GoogleFonts.newsreader(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.lightTextPrimary,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              '${chapter.releaseDate} • ${chapter.pageCount} trang',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.lightTextSecondary,
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
          context.push('/reader/${_series.id}?chapterId=${chapter.id}');
        },
      ),
    );
  }
}
