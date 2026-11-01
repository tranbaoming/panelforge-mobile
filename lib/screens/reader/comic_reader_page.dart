import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/api_dtos.dart';
import '../../models/comic_model.dart';
import '../../models/comic_package_models.dart';
import '../../providers/api_providers.dart';
import '../../services/catalog_service.dart';
import '../../services/preferences_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_scrubber.dart';
import '../../widgets/reading_mode_switcher.dart';
import '../../widgets/unlock_chapter_bottom_sheet.dart';
import '../../widgets/wallet_topup_dialog.dart';

class ComicReaderPage extends ConsumerStatefulWidget {
  final String seriesId;
  final String? chapterId;

  const ComicReaderPage({
    super.key,
    required this.seriesId,
    this.chapterId,
  });

  @override
  ConsumerState<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends ConsumerState<ComicReaderPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ReadingModeSwitcherState> _readerSwitcherKey = GlobalKey<ReadingModeSwitcherState>();

  SeriesItem? _series;
  ChapterItem? _currentChapter;
  LoadedComicPackage? _loadedPackage;
  String? _selectedLanguage;
  bool _isOfflinePackage = false;
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

  bool _isChapterUnlocked(ChapterItem chapter) {
    if (chapter.isFree) return true;
    final wallet = ref.watch(walletNotifierProvider).asData?.value;
    if (wallet?.isVip ?? false) return true;
    final unlockedIds = ref.watch(unlockedChaptersProvider);
    if (unlockedIds.contains(chapter.id)) return true;
    if (PreferencesService.isChapterUnlocked(chapter.id)) return true;
    return chapter.isUnlocked;
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

      // Tìm chapter trong danh sách của series nếu có
      ChapterItem targetChapter = series.chapters.firstWhere(
        (c) => c.id == chId,
        orElse: () => ChapterItem(
          id: chId,
          number: 1,
          title: 'Chương Truyện',
          releaseDate: '',
          pageCount: 0,
          pages: const [],
        ),
      );

      // Nếu chương đã được mở khóa, nạp chi tiết các trang
      if (_isChapterUnlocked(targetChapter)) {
        await _loadChapterContent(series, targetChapter);
      } else {
        if (mounted) {
          setState(() {
            _series = series;
            _currentChapter = targetChapter;
            _isLoading = false;
          });
        }
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

  Future<void> _loadChapterContent(SeriesItem series, ChapterItem targetChapter) async {
    try {
      final chId = targetChapter.id;
      final isDownloaded = PreferencesService.isChapterDownloaded(chId);
      final cbzService = ref.read(cbzPackageServiceProvider);

      LoadedComicPackage? package;
      if (isDownloaded) {
        package = await cbzService.loadOfflinePackage(chId);
      }

      package ??= await cbzService.loadPackage(
        chapterId: chId,
        manifestUrl: targetChapter.manifestUrl,
        cbzUrl: targetChapter.cbzPackageUrl,
      );

      ChapterItem currentChapter = targetChapter;
      var readingMode = _readingMode;

      if (package.manifest.pageFiles.isNotEmpty && isDownloaded) {
        // Nạp các trang trực tiếp từ file offline
        final offlinePages = <ComicPageData>[];
        for (int i = 0; i < package.manifest.pageFiles.length; i++) {
          final filePath = package.getPageFilePath(i);
          offlinePages.add(
            ComicPageData(
              pageNumber: i + 1,
              title: 'Trang ${i + 1}',
              imageUrl: filePath,
              panels: const [],
            ),
          );
        }
        currentChapter = targetChapter.copyWith(
          pageCount: offlinePages.length,
          pages: offlinePages,
        );
      } else {
        // Nạp qua Catalog API
        final readDto = await CatalogService().readChapter(chId);
        currentChapter = ChapterItem.fromPublicReadDto(readDto);

        if (readDto.readingDirection == ApiReadingDirection.rightToLeft || series.format == ComicFormat.manga) {
          readingMode = ReadingMode.rtl;
        } else if (readDto.readingDirection == ApiReadingDirection.vertical || series.format == ComicFormat.webtoon) {
          readingMode = ReadingMode.webtoon;
        }
      }

      String? selectedLang = _selectedLanguage;
      if (package.availableLanguages.isNotEmpty) {
        selectedLang ??= package.availableLanguages.first;
      }

      if (mounted) {
        setState(() {
          _series = series;
          _currentChapter = currentChapter;
          _loadedPackage = package;
          _selectedLanguage = selectedLang;
          _isOfflinePackage = isDownloaded;
          _readingMode = readingMode;
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      debugPrint('[ComicReader Content Load Error] $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể tải nội dung bản vẽ trang truyện. Vui lòng thử lại sau.';
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

    if (!_isChapterUnlocked(chapter)) {
      UnlockChapterBottomSheet.show(
        context,
        chapter: chapter,
        onUnlocked: () {
          _loadChapterContent(_series!, chapter);
        },
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await _loadChapterContent(_series!, chapter);
    _readerSwitcherKey.currentState?.jumpToPage(1);
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
                'Đang chuẩn bị trang truyện & gói Comic Package...',
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

    // NẾU CHƯƠNG ĐANG BỊ KHÓA -> HIỂN THỊ PAYWALL GIAO DIỆN DARK OBSIDIAN
    if (!_isChapterUnlocked(currentChapter)) {
      return _buildPaywallView(series, currentChapter);
    }

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
              package: _loadedPackage,
              selectedLanguage: _selectedLanguage,
              onPageChanged: (newPage) {
                setState(() => _currentPage = newPage);
              },
              onTapScreen: _toggleHud,
            ),
          ),

          // TOP HUD: Back button, Chapter info, Language selector, TOC Drawer
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                series.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.newsreader(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: hudTextColor,
                                ),
                              ),
                            ),
                            if (_isOfflinePackage) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.mint.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'OFFLINE',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.mint,
                                  ),
                                ),
                              ),
                            ],
                          ],
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

                  // Language Switcher (Dịch đa ngôn ngữ nếu có trong Comic Package)
                  if (_loadedPackage != null && _loadedPackage!.availableLanguages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: PopupMenuButton<String>(
                        initialValue: _selectedLanguage,
                        tooltip: 'Bản dịch ngôn ngữ',
                        icon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.translate_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                _selectedLanguage?.toUpperCase() ?? 'GỐC',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        onSelected: (lang) {
                          setState(() => _selectedLanguage = lang);
                        },
                        itemBuilder: (context) => _loadedPackage!.availableLanguages.map((lang) {
                          final isSelected = _selectedLanguage == lang;
                          return PopupMenuItem<String>(
                            value: lang,
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                  size: 16,
                                  color: isSelected ? AppColors.primary : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  lang.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
                    totalPages: currentChapter.pages.isEmpty ? 1 : currentChapter.pages.length,
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

  /// Màn hình Paywall khóa chương truyện giao diện Dark Obsidian
  Widget _buildPaywallView(SeriesItem series, ChapterItem currentChapter) {
    final wallet = ref.watch(walletNotifierProvider).asData?.value;
    final balance = wallet?.balanceCoins ?? 0;
    final price = currentChapter.priceCoins;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      endDrawer: _buildTableOfContentsDrawer(series, currentChapter),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          series.title,
          style: GoogleFonts.newsreader(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
            tooltip: 'Mục lục chương',
            onPressed: () {
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon khóa
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Chương Này Đang Bị Khóa',
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Chương "${currentChapter.title}" yêu cầu mở khóa để đọc toàn bộ nội dung bản vẽ chất lượng cao và tính năng dịch thuật.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Thẻ thông tin giá & số dư ví
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Giá mở khóa chương:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.darkTextSecondary),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.monetization_on_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '$price ForgeCoins',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: AppColors.darkBorder, height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Số dư ví của bạn:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.darkTextSecondary),
                        ),
                        Text(
                          '$balance ForgeCoins',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: balance >= price ? AppColors.mint : AppColors.rose,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nút Mở khóa ngay
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    UnlockChapterBottomSheet.show(
                      context,
                      chapter: currentChapter,
                      onUnlocked: () {
                        _loadChapterContent(series, currentChapter);
                      },
                    );
                  },
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(
                    'Mở Khóa Ngay ($price Xu)',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Nút VIP Pass
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    WalletTopupDialog.show(context, initialTab: 1);
                  },
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18, color: AppColors.amber),
                  label: Text(
                    'Nâng cấp VIP Pass (Đọc Không Giới Hạn)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.amber,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.amber, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Nút xem mục lục
              TextButton.icon(
                onPressed: () {
                  _scaffoldKey.currentState?.openEndDrawer();
                },
                icon: const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.darkTextSecondary),
                label: Text(
                  'Chọn chương truyện khác',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                  final isUnlocked = _isChapterUnlocked(ch);
                  final isDownloaded = PreferencesService.isChapterDownloaded(ch.id);

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
                        '${ch.pageCount > 0 ? '${ch.pageCount} trang' : 'Đang cập nhật'} • ${ch.releaseDate}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDownloaded)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 16),
                            ),
                          if (isCurrent)
                            const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 16)
                          else if (ch.isFree)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.mint.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'FREE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.mint,
                                ),
                              ),
                            )
                          else if (isUnlocked)
                            const Icon(Icons.lock_open_rounded, color: AppColors.mint, size: 16)
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_rounded, size: 11, color: AppColors.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${ch.priceCoins}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
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
