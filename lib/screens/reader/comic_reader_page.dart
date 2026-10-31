import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/api_dtos.dart';
import '../../models/comic_model.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_scrubber.dart';
import '../../widgets/reading_mode_switcher.dart';

class ComicReaderPage extends StatefulWidget {
  final String seriesId;
  final String? chapterId;

  const ComicReaderPage({
    super.key,
    required this.seriesId,
    this.chapterId,
  });

  @override
  State<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends State<ComicReaderPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ReadingModeSwitcherState> _readerSwitcherKey = GlobalKey<ReadingModeSwitcherState>();

  SeriesItem? _series;
  ChapterItem? _currentChapter;
  bool _isLoading = true;
  String? _errorMessage;

  ReadingMode _readingMode = ReadingMode.ltr;
  ReaderThemeMode _themeMode = ReaderThemeMode.night;
  bool _showHud = true;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final seriesDetail = await CatalogService().getSeriesDetail(widget.seriesId);
      final series = SeriesItem.fromPublicDetailDto(seriesDetail);

      final chId = widget.chapterId ?? (series.chapters.isNotEmpty ? series.chapters.first.id : null);
      if (chId == null) {
        if (mounted) {
          setState(() {
            _series = series;
            _isLoading = false;
            _errorMessage = 'Tác phẩm chưa có chương nào được phát hành.';
          });
        }
        return;
      }

      final readDto = await CatalogService().readChapter(chId);
      final currentChapter = ChapterItem.fromPublicReadDto(readDto);

      var readingMode = ReadingMode.ltr;
      if (readDto.readingDirection == ApiReadingDirection.rightToLeft || series.format == ComicFormat.manga) {
        readingMode = ReadingMode.rtl;
      } else if (readDto.readingDirection == ApiReadingDirection.vertical || series.format == ComicFormat.webtoon) {
        readingMode = ReadingMode.webtoon;
      }

      if (mounted) {
        setState(() {
          _series = series;
          _currentChapter = currentChapter;
          _readingMode = readingMode;
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      debugPrint('[ComicReader API Error] $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể tải nội dung chương truyện. Vui lòng kiểm tra lại kết nối mạng.';
        });
      }
    }
  }

  void _toggleHud() {
    setState(() {
      _showHud = !_showHud;
    });
  }

  Future<void> _onSelectChapter(ChapterItem chapter) async {
    Navigator.of(context).pop(); // Close drawer
    setState(() {
      _isLoading = true;
    });
    try {
      final readDto = await CatalogService().readChapter(chapter.id);
      if (mounted) {
        setState(() {
          _currentChapter = ChapterItem.fromPublicReadDto(readDto);
          _currentPage = 1;
          _isLoading = false;
        });
        _readerSwitcherKey.currentState?.jumpToPage(1);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể mở chương truyện. Vui lòng kiểm tra lại kết nối mạng.')),
        );
      }
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Đang tải nội dung bản vẽ trang truyện...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_series == null || _currentChapter == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_rounded, color: Colors.grey, size: 54),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Không thể mở chương truyện này.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
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
    final currentChapter = _currentChapter!;

    final isDarkTheme = _themeMode == ReaderThemeMode.night;
    final topBarBg = Color(_themeMode.surfaceColor).withValues(alpha: 0.96);
    final hudTextColor = Color(_themeMode.textColor);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(_themeMode.bgColor),
      endDrawer: _buildTableOfContentsDrawer(series, currentChapter),
      body: Stack(
        children: [
          // FULL-BLEED IMMERSIVE READING AREA WITH 3 MODES (LTR, RTL, WEBTOON)
          Positioned.fill(
            child: ReadingModeSwitcher(
              key: _readerSwitcherKey,
              chapter: currentChapter,
              mode: _readingMode,
              themeMode: _themeMode,
              initialPage: _currentPage,
              onPageChanged: (newPage) {
                setState(() => _currentPage = newPage);
              },
              onTapScreen: _toggleHud,
            ),
          ),

          // TOP HUD: Back button, Chapter info, Reading mode switcher, TOC Drawer trigger
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            top: _showHud ? 0 : -110,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 6,
                bottom: 12,
                left: 14,
                right: 14,
              ),
              decoration: BoxDecoration(
                color: topBarBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border(
                  bottom: BorderSide(
                    color: isDarkTheme ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: hudTextColor,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          series.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.newsreader(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: hudTextColor,
                          ),
                        ),
                        Text(
                          currentChapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: hudTextColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reading Mode Popup
                  PopupMenuButton<ReadingMode>(
                    initialValue: _readingMode,
                    tooltip: 'Chế độ đọc',
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            _readingMode == ReadingMode.ltr
                                ? 'LTR'
                                : _readingMode == ReadingMode.rtl
                                    ? 'RTL'
                                    : 'CUỘN',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onSelected: (mode) {
                      setState(() => _readingMode = mode);
                    },
                    itemBuilder: (context) => ReadingMode.values.map((mode) {
                      return PopupMenuItem<ReadingMode>(
                        value: mode,
                        child: Row(
                          children: [
                            Icon(
                              mode == _readingMode ? Icons.check_circle_rounded : Icons.circle_outlined,
                              size: 16,
                              color: mode == _readingMode ? AppColors.primary : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              mode.title,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  // Table of Contents Drawer Button
                  IconButton(
                    icon: const Icon(Icons.menu_book_rounded),
                    color: hudTextColor,
                    tooltip: 'Mục lục chương',
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM HUD: Theme Switcher & Interactive Scrubber
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            bottom: _showHud ? 0 : -180,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 14,
              ),
              decoration: BoxDecoration(
                color: topBarBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: isDarkTheme ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Theme switchers: Đêm / Giấy Cổ / Sáng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ReaderThemeMode.values.map((theme) {
                      final isSelected = _themeMode == theme;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InkWell(
                          onTap: () => setState(() => _themeMode = theme),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Color(theme.bgColor),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.darkBorder,
                                width: isSelected ? 2.0 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  theme.label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                    color: Color(theme.textColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 10),

                  // INTERACTIVE SCRUBBER WITH TANGERINE CITRUS THEME
                  InteractiveScrubber(
                    currentPage: _currentPage,
                    totalPages: currentChapter.pages.length,
                    isDark: isDarkTheme,
                    onPageSelected: (page) {
                      _readerSwitcherKey.currentState?.jumpToPage(page);
                    },
                    onPrevPage: () {
                      if (_currentPage > 1) {
                        _readerSwitcherKey.currentState?.jumpToPage(_currentPage - 1);
                      }
                    },
                    onNextPage: () {
                      if (_currentPage < currentChapter.pages.length) {
                        _readerSwitcherKey.currentState?.jumpToPage(_currentPage + 1);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableOfContentsDrawer(SeriesItem series, ChapterItem currentChapter) {
    return Drawer(
      backgroundColor: AppColors.darkSurface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MỤC LỤC BỘ TRUYỆN',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    series.title,
                    style: GoogleFonts.newsreader(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.darkBorder, height: 1),

            // Chapters List
            Expanded(
              child: ListView.builder(
                itemCount: series.chapters.length,
                itemBuilder: (context, index) {
                  final ch = series.chapters[index];
                  final isCurrent = ch.id == currentChapter.id;

                  return Container(
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isCurrent ? AppColors.primary : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        ch.title,
                        style: GoogleFonts.newsreader(
                          fontSize: 15,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent ? AppColors.primary : Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        '${ch.pageCount} trang • ${ch.releaseDate}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 16)
                          : null,
                      onTap: () => _onSelectChapter(ch),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
