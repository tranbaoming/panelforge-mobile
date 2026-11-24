import 'dart:async';

import 'package:flutter/material.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../navigation/back_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/api_dtos.dart';
import '../../models/comic_model.dart';
import '../../models/comic_package_models.dart';
import '../../providers/api_providers.dart';
import '../../services/catalog_service.dart';
import '../../services/preferences_service.dart';
import '../../services/screen_security_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/edition_language_menu.dart';
import '../../widgets/interactive_scrubber.dart';
import '../../widgets/reading_mode_switcher.dart';
import '../../widgets/security_blur_shield.dart';
import '../../widgets/text_region_detail_sheet.dart';
import '../../widgets/unlock_chapter_bottom_sheet.dart';
import '../../widgets/vertical_page_slider.dart';
import '../../widgets/wallet_topup_dialog.dart';
import '../../widgets/watermark_overlay.dart';

class ComicReaderPage extends ConsumerStatefulWidget {
  final String seriesId;
  final String? chapterId;

  const ComicReaderPage({super.key, required this.seriesId, this.chapterId});

  @override
  ConsumerState<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends ConsumerState<ComicReaderPage> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ReadingModeSwitcherState> _readerSwitcherKey = GlobalKey<ReadingModeSwitcherState>();

  SeriesItem? _series;
  ChapterItem? _currentChapter;
  LoadedComicPackage? _loadedPackage;
  String? _selectedLanguage;

  /// Bản ngôn ngữ độc giả muốn đọc (lưu trong Preferences) và bản thực sự đang đọc của chương hiện tại
  /// (rơi về bản gốc vi nếu chương chưa phát hành bản đó). Mua theo từng ngôn ngữ.
  String _preferredLanguage = PreferencesService.getContentLanguage();
  String _activeLanguage = 'vi';
  List<ChapterLanguageOption> _chapterLanguages = const [];
  bool _isOfflinePackage = false;
  bool _isLoading = true;
  String? _errorMessage;

  /// Backend trả 403/402 cho chương khóa (dữ liệu client cũ hơn server) → hiển thị Paywall thay vì màn lỗi.
  bool _lockedByServer = false;

  ReadingMode _readingMode = ReadingMode.ltr;
  ReaderThemeMode _themeMode = ReaderThemeMode.night;
  bool _isGuidedPanelMode = false;
  double _webtoonTileSpacing = 0.0;
  bool _showHud = true;
  int _currentPage = 1;

  bool _isScreenLocked = false;
  bool _isPrivacyShieldActive = false;
  StreamSubscription<ScreenSecurityEvent>? _securityEventsSub;

  /// Cài đặt riêng của bộ truyện này (chế độ đọc, nền, độ sáng) — lưu ngay khi độc giả đổi.
  late ReaderSeriesSettings _seriesSettings = PreferencesService.getReaderSeriesSettings(widget.seriesId);
  bool _autoNext = PreferencesService.getAutoNextChapter();

  /// Đếm ngược tự sang chương sau khi đọc tới trang cuối; null = không chờ.
  Timer? _autoNextTimer;
  ChapterItem? _autoNextTarget;
  static const autoNextDelay = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    // Cài đặt "Giữ màn hình sáng khi đọc" ở màn Cá nhân.
    ScreenSecurityService.keepScreenAwake(PreferencesService.getKeepScreenOn());
    // Bảo vệ bản quyền cấp Native (Android FLAG_SECURE / iOS capture shield) cho TẤT CẢ các chương.
    ScreenSecurityService.enableNativeProtection();
    _securityEventsSub = ScreenSecurityService.securityEvents.listen((event) {
      if (!mounted) return;
      if (event.type == 'capturedChanged') {
        setState(() => _isPrivacyShieldActive = event.isCaptured);
      } else if (event.type == 'screenshotTaken') {
        setState(() => _isPrivacyShieldActive = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Bảo mật: Không được phép chụp màn hình nội dung bản quyền PanelForge.'),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    final savedTheme = ReaderThemeMode.values.where((t) => t.name == _seriesSettings.theme).firstOrNull;
    if (savedTheme != null) _themeMode = savedTheme;
    _loadData();
  }

  ReadingMode? get _savedReadingMode =>
      ReadingMode.values.where((m) => m.name == _seriesSettings.readingMode).firstOrNull;

  void _updateSeriesSettings(ReaderSeriesSettings next) {
    _seriesSettings = next;
    PreferencesService.saveReaderSeriesSettings(widget.seriesId, next);
  }

  void _setReadingMode(ReadingMode mode) {
    setState(() => _readingMode = mode);
    _updateSeriesSettings(_seriesSettings.copyWith(readingMode: mode.name));
  }

  void _setTheme(ReaderThemeMode theme) {
    setState(() => _themeMode = theme);
    _updateSeriesSettings(_seriesSettings.copyWith(theme: theme.name));
  }

  void _setBrightness(double value) {
    setState(() => _seriesSettings = _seriesSettings.copyWith(brightness: value));
    PreferencesService.saveReaderSeriesSettings(widget.seriesId, _seriesSettings);
  }

  /// Chương kế tiếp theo số chương (null nếu đang ở chương mới nhất).
  ChapterItem? _nextChapterOf(SeriesItem series, ChapterItem current) {
    final sorted = [...series.chapters]..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    final idx = sorted.indexWhere((c) => c.id == current.id);
    return (idx >= 0 && idx < sorted.length - 1) ? sorted[idx + 1] : null;
  }

  /// Tới trang cuối → đếm ngược rồi sang chương sau. Không tự mở chương còn khóa (tránh bất ngờ trừ tiền / paywall).
  void _maybeScheduleAutoNext(SeriesItem series, ChapterItem current, int page) {
    final atEnd = current.pages.isNotEmpty && page >= current.pages.length;
    if (!atEnd) {
      _cancelAutoNext();
      return;
    }
    if (!_autoNext || _autoNextTimer != null || _isScreenLocked) return;
    final next = _nextChapterOf(series, current);
    if (next == null || !_isChapterUnlocked(next)) return;
    setState(() => _autoNextTarget = next);
    _autoNextTimer = Timer(autoNextDelay, () {
      _autoNextTimer = null;
      if (!mounted || _autoNextTarget == null) return;
      final target = _autoNextTarget!;
      setState(() => _autoNextTarget = null);
      _switchToChapter(target);
    });
  }

  void _cancelAutoNext() {
    _autoNextTimer?.cancel();
    _autoNextTimer = null;
    if (_autoNextTarget != null && mounted) setState(() => _autoNextTarget = null);
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _securityEventsSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    ScreenSecurityService.disableNativeProtection();
    ScreenSecurityService.keepScreenAwake(false);
    ScreenSecurityService.unlockOrientation();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (mounted && !_isPrivacyShieldActive) {
        setState(() => _isPrivacyShieldActive = true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (mounted && _isPrivacyShieldActive) {
        setState(() => _isPrivacyShieldActive = false);
      }
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.printScreen) {
      if (mounted) {
        setState(() => _isPrivacyShieldActive = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Bảo mật: Không được phép chụp màn hình nội dung bản quyền PanelForge.'),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    }
    return false;
  }

  void _enableScreenLock() {
    setState(() {
      _isScreenLocked = true;
      _showHud = false;
    });
    ScreenSecurityService.lockOrientation(MediaQuery.of(context).orientation);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đã khóa màn hình: Chống bấm nhầm & cố định xoay. Nhấn giữ 2s nút khóa góc dưới để mở lại.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _disableScreenLock() {
    setState(() {
      _isScreenLocked = false;
      _showHud = true;
    });
    ScreenSecurityService.unlockOrientation();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.mint, width: 1.2),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: AppColors.mint, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đã mở khóa thao tác màn hình.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cùng quy tắc với SeriesDetailPage: Backend `isLocked`/`isUnlocked` + quyền sở hữu theo ấn bản ngôn ngữ.
  bool _isChapterUnlocked(ChapterItem chapter, [String? lang]) {
    final targetLang = lang ?? _activeLanguage;
    if (!chapter.isLockedFor(targetLang)) return true;
    if (chapter.isServerUnlockedFor(targetLang)) return true;
    final unlockedSet = ref.watch(unlockedChaptersProvider);
    final editionKey = ChapterEntitlement.editionKey(chapter.id, targetLang);
    if (unlockedSet.contains(editionKey)) return true;
    if (unlockedSet.any((id) => id.startsWith('${chapter.id}:'))) return false;
    return unlockedSet.contains(chapter.id);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lockedByServer = false;
    });

    try {
      final seriesDetail = await CatalogService().getSeriesDetail(widget.seriesId, lang: _preferredLanguage);
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

      _applyChapterLanguages(
        seriesDetail.chapters.where((c) => c.id == chId).map((c) => c.languages).firstOrNull ?? const [],
      );

      // Tìm chapter trong danh sách của series nếu có
      ChapterItem targetChapter = series.chapters.firstWhere(
        (c) => c.id == chId,
        orElse: () =>
            ChapterItem(id: chId, number: 1, title: 'Chương Truyện', releaseDate: '', pageCount: 0, pages: const []),
      );

      // Luôn gọi _loadChapterContent để lấy danh sách trang (kể cả chương khóa vẫn có N trang xem trước BR-33).
      await _loadChapterContent(series, targetChapter);
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

  /// Trang ngoài phần xem trước: mở sheet mở khóa ấn bản (Ví / VietQR);
  /// mua xong tải lại chương để server trả ảnh mọi trang.
  void _showUnlockChapterSheet(ComicPageData page) {
    final chapter = _currentChapter;
    if (chapter == null || _isScreenLocked) return;
    UnlockChapterBottomSheet.show(
      context,
      chapter: chapter,
      series: _series,
      language: _activeLanguage,
      onUnlocked: _reloadUnlockedPages,
    );
  }

  /// Ghi nhận các bản ngôn ngữ của chương; bản ưu tiên chưa phát hành thì đọc bản gốc.
  void _applyChapterLanguages(List<ChapterLanguageOption> options) {
    _chapterLanguages = options;
    _activeLanguage = options.any((o) => o.language == _preferredLanguage) ? _preferredLanguage : 'vi';
  }

  /// Độc giả đổi bản ngôn ngữ: lưu lựa chọn (thiết bị + tài khoản nếu đã đăng nhập) và tải lại.
  Future<void> _changeEdition(String language) async {
    if (language == _activeLanguage) return;
    await PreferencesService.setContentLanguage(language);
    if (ref.read(authStateProvider).isAuthenticated) {
      CatalogService().updatePreferredReadingLanguage(language).catchError((Object e) {
        debugPrint('[ReadingLanguage] $e');
      });
    }
    if (!mounted) return;
    setState(() => _preferredLanguage = language);
    await _loadData();
  }

  Future<void> _reloadUnlockedPages() async {
    final chapter = _currentChapter;
    if (chapter == null) return;
    final keepPage = _currentPage;
    try {
      final readDto = await CatalogService().readChapter(chapter.id, lang: _activeLanguage);
      if (!mounted) return;
      setState(() => _currentChapter = ChapterItem.fromPublicReadDto(readDto));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _readerSwitcherKey.currentState?.jumpToPage(keepPage);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Không tải lại được trang vừa mở khóa.')));
    }
  }

  Future<void> _loadChapterContent(SeriesItem series, ChapterItem targetChapter) async {
    _lockedByServer = false;
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

      final loadedPackage = package;
      ChapterItem currentChapter = targetChapter;
      var readingMode = _readingMode;

      if (loadedPackage.manifest.pageFiles.isNotEmpty && isDownloaded) {
        // Nạp các trang trực tiếp từ file offline
        final offlinePages = <ComicPageData>[];
        for (int i = 0; i < loadedPackage.manifest.pageFiles.length; i++) {
          final filePath = loadedPackage.getPageFilePath(i);
          offlinePages.add(
            ComicPageData(pageNumber: i + 1, title: 'Trang ${i + 1}', imageUrl: filePath, panels: const []),
          );
        }
        currentChapter = targetChapter.copyWith(pageCount: offlinePages.length, pages: offlinePages);
      } else {
        // Nạp qua Catalog API — D9b: 404 EDITION_NOT_PUBLISHED tuyệt đối không tự động fallback sang ngôn ngữ khác.
        PublicChapterReadDto readDto;
        try {
          readDto = await CatalogService().readChapter(chId, lang: _activeLanguage);
        } on ApiException catch (e) {
          if (e.statusCode == 404) {
            throw ApiException(
              'Ấn bản ${contentLanguageLabel(_activeLanguage)} chưa được phát hành cho chương này.',
              statusCode: 404,
            );
          }
          rethrow;
        }
        _applyChapterLanguages(readDto.languages);
        currentChapter = ChapterItem.fromPublicReadDto(readDto);

        if (readDto.readingDirection == ApiReadingDirection.rightToLeft || series.format == ComicFormat.manga) {
          readingMode = ReadingMode.rtl;
        } else if (readDto.readingDirection == ApiReadingDirection.vertical || series.format == ComicFormat.webtoon) {
          readingMode = ReadingMode.webtoon;
        }
      }
      // Độc giả đã chọn chế độ đọc riêng cho bộ này → ưu tiên hơn hướng đọc mặc định của server.
      readingMode = _savedReadingMode ?? readingMode;

      String? selectedLang = _selectedLanguage;
      if (loadedPackage.availableLanguages.isNotEmpty) {
        selectedLang ??= loadedPackage.availableLanguages.first;
      }

      if (mounted) {
        final history = PreferencesService.getReadingHistoryFor(series.id);
        final savedPage = (history != null && history.chapterId == currentChapter.id) ? history.lastPageNumber : 1;
        final initialPage = currentChapter.pages.isEmpty ? 1 : savedPage.clamp(1, currentChapter.pages.length);

        setState(() {
          _series = series;
          _currentChapter = currentChapter;
          _loadedPackage = loadedPackage;
          _selectedLanguage = selectedLang;
          _isOfflinePackage = isDownloaded;
          _readingMode = readingMode;
          _webtoonTileSpacing = loadedPackage.manifest.webtoonTileSpacing;
          _isLoading = false;
          _currentPage = initialPage;
        });
        if (initialPage > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _readerSwitcherKey.currentState?.jumpToPage(initialPage);
          });
        }
        PreferencesService.saveReadingProgress(
          ReadingHistoryEntry(
            seriesId: series.id,
            seriesTitle: series.title,
            chapterId: currentChapter.id,
            chapterNumber: currentChapter.chapterNumber,
            lastPageNumber: initialPage,
            totalPages: currentChapter.pages.length,
            language: _activeLanguage,
            readAt: DateTime.now(),
          ),
        );
        // Lượt xem thật trên catalog; lỗi mạng không ảnh hưởng việc đọc.
        CatalogService().recordChapterView(currentChapter.id, lang: _activeLanguage).catchError((Object e) {
          debugPrint('[ChapterView] $e');
        });

        // Tiêu hao lượt xem nếu là tập thuê có giới hạn số lần xem
        if (!currentChapter.isFree && currentChapter.isUnlocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final consumeResult = await ref.read(walletNotifierProvider.notifier).consumeChapterView(currentChapter.id);
            if (consumeResult.message != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.darkSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: consumeResult.remainingViews == 0 ? AppColors.rose : AppColors.primary,
                      width: 1,
                    ),
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                  content: Row(
                    children: [
                      Icon(
                        consumeResult.remainingViews == 0 ? Icons.lock_clock_rounded : Icons.visibility_rounded,
                        color: consumeResult.remainingViews == 0 ? AppColors.rose : AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          consumeResult.message!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[ComicReader Content Load Error] $e');
      if (e is ApiException && (e.statusCode == 403 || e.statusCode == 402)) {
        if (mounted) {
          setState(() {
            _series = series;
            _currentChapter = targetChapter;
            _lockedByServer = true;
            _isLoading = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể tải nội dung bản vẽ trang truyện. Vui lòng thử lại sau.';
        });
      }
    }
  }

  void _toggleHud() {
    if (_isScreenLocked) return;
    setState(() {
      _showHud = !_showHud;
    });
  }

  Future<void> _onSelectChapter(ChapterItem chapter) async {
    Navigator.of(context).pop(); // Close drawer

    // Chương trả phí chưa mua vẫn mở được: đọc trang xem trước, trang khác mời mở khóa cả chương.
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
            onPressed: () => context.popOrGo('/series/${widget.seriesId}'),
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
            onPressed: () => context.popOrGo('/series/${widget.seriesId}'),
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final series = _series!;
    final currentChapter = _currentChapter!;

    // Chương trả phí chưa mua: đọc trang xem trước, trang khác hiện ô khóa (mở khóa cả chương).
    // Chỉ hiện paywall toàn màn hình khi server từ chối hẳn hoặc chương không có trang nào xem được.
    final hasViewablePage = currentChapter.pages.any((p) => !p.isPaywalled);
    if (_lockedByServer || (!_isChapterUnlocked(currentChapter) && !hasViewablePage)) {
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
          // Bấm đè ở mép phải → thanh trượt trang dọc hiện ra để tua; bình thường ẩn, lướt như cũ.
          Positioned.fill(
            child: VerticalPageScrubber(
              currentPage: _currentPage,
              totalPages: currentChapter.pages.isEmpty ? 1 : currentChapter.pages.length,
              enabled: !_isScreenLocked,
              trackMargin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 90,
                bottom: MediaQuery.of(context).padding.bottom + 110,
              ),
              onPageSelected: (page) => _readerSwitcherKey.currentState?.jumpToPage(page),
              child: ReadingModeSwitcher(
                key: _readerSwitcherKey,
                chapter: currentChapter,
                mode: _readingMode,
                themeMode: _themeMode,
                initialPage: _currentPage,
                package: _loadedPackage,
                selectedLanguage: _selectedLanguage,
                isGuidedPanelMode: _isGuidedPanelMode,
                webtoonTileSpacing: _webtoonTileSpacing,
                onRegionTap: (region) {
                  if (_isScreenLocked) return;
                  TextRegionDetailSheet.show(
                    context,
                    region: region,
                    activeLanguage: _selectedLanguage ?? 'vi',
                    package: _loadedPackage,
                  );
                },
                onPageChanged: (newPage) {
                  setState(() => _currentPage = newPage);
                  _maybeScheduleAutoNext(series, currentChapter, newPage);
                  PreferencesService.saveReadingProgress(
                    ReadingHistoryEntry(
                      seriesId: series.id,
                      seriesTitle: series.title,
                      chapterId: currentChapter.id,
                      chapterNumber: currentChapter.chapterNumber,
                      lastPageNumber: newPage,
                      totalPages: currentChapter.pages.length,
                      language: _activeLanguage,
                      readAt: DateTime.now(),
                    ),
                  );
                },
                onTapScreen: _toggleHud,
                onUnlockPage: _isOfflinePackage ? null : _showUnlockChapterSheet,
              ),
            ),
          ),

          // Độ sáng trong app: phủ lớp tối lên trang, không chặn thao tác.
          if (_seriesSettings.brightness < 1.0)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  key: const ValueKey('reader-dim-overlay'),
                  color: Colors.black.withValues(alpha: (1 - _seriesSettings.brightness) * 0.85),
                ),
              ),
            ),

          // TOP HUD: Back button, Chapter info, Language selector, TOC Drawer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Trượt ra ngoài đúng bằng chiều cao thật của khung (cao hơn khi phóng to cỡ chữ).
            child: IgnorePointer(
              ignoring: !_showHud,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                offset: _showHud ? Offset.zero : const Offset(0, -1.05),
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
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 14, offset: const Offset(0, 4)),
                    ],
                    border: Border(
                      bottom: BorderSide(color: isDarkTheme ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        color: hudTextColor,
                        onPressed: () => context.popOrGo('/series/${widget.seriesId}'),
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

                      // Bản phát hành theo ngôn ngữ (ảnh trang riêng, mua theo từng ngôn ngữ)
                      if (_chapterLanguages.length > 1 && !_isOfflinePackage)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: EditionLanguageMenu(
                            current: _activeLanguage,
                            options: _chapterLanguages,
                            onSelected: _changeEdition,
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
                        onSelected: _setReadingMode,
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
                                Text(mode.title, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      // Guided Panel Mode Toggle Button
                      if (_readingMode != ReadingMode.webtoon)
                        IconButton(
                          icon: Icon(
                            _isGuidedPanelMode ? Icons.crop_free_rounded : Icons.crop_square_rounded,
                            size: 20,
                            color: _isGuidedPanelMode ? AppColors.primary : hudTextColor,
                          ),
                          tooltip: _isGuidedPanelMode
                              ? 'Tắt đọc từng khung tranh'
                              : 'Bật đọc từng khung tranh (Guided Panel Mode)',
                          onPressed: () {
                            setState(() {
                              _isGuidedPanelMode = !_isGuidedPanelMode;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _isGuidedPanelMode
                                      ? 'Đã bật chế độ đọc từng khung tranh (Guided Panel Mode)'
                                      : 'Đã chuyển về chế độ đọc trang toàn cảnh',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),

                      // Lock Screen Button (Chống bấm nhầm & Cố định xoay)
                      IconButton(
                        icon: const Icon(Icons.lock_outline_rounded, size: 20),
                        color: hudTextColor,
                        tooltip: 'Khóa màn hình (Chống bấm nhầm & Cố định xoay)',
                        onPressed: _enableScreenLock,
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
            ),
          ),

          // BOTTOM HUD: Theme Switcher & Interactive Scrubber
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            // Trượt ra ngoài đúng bằng chiều cao thật của khung (cao hơn khi phóng to cỡ chữ).
            child: IgnorePointer(
              ignoring: !_showHud,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                offset: _showHud ? Offset.zero : const Offset(0, 1.05),
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
                    border: Border(top: BorderSide(color: isDarkTheme ? AppColors.darkBorder : AppColors.lightBorder)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Theme switchers: Đêm / Giấy Cổ / Sáng & Nút Khóa màn hình
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...ReaderThemeMode.values.map((theme) {
                            final isSelected = _themeMode == theme;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () => _setTheme(theme),
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
                          }),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: _enableScreenLock,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Khóa',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Cài đặt khoảng cách khung tranh Webtoon (Adaptive Webtoon Spacing)
                      if (_readingMode == ReadingMode.webtoon) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Khoảng cách khung:',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: hudTextColor.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...[0.0, 8.0, 16.0, 24.0].map((spacing) {
                              final isSelected = _webtoonTileSpacing == spacing;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  onTap: () => setState(() => _webtoonTileSpacing = spacing),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : AppColors.darkCard,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.darkBorder),
                                    ),
                                    child: Text(
                                      '${spacing.toInt()}px',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                        color: isSelected ? Colors.white : AppColors.darkTextSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ],

                      // Độ sáng (riêng cho bộ này) + tự sang chương sau.
                      Row(
                        children: [
                          Icon(Icons.brightness_low_rounded, size: 18, color: hudTextColor.withValues(alpha: 0.7)),
                          Expanded(
                            child: Slider(
                              key: const ValueKey('reader-brightness'),
                              value: _seriesSettings.brightness,
                              min: 0.2,
                              max: 1.0,
                              activeColor: AppColors.primary,
                              label: 'Độ sáng',
                              semanticFormatterCallback: (v) => 'Độ sáng ${(v * 100).round()}%',
                              onChanged: _setBrightness,
                            ),
                          ),
                          Icon(Icons.brightness_high_rounded, size: 18, color: hudTextColor.withValues(alpha: 0.7)),
                          const SizedBox(width: 10),
                          Text(
                            'Tự sang chương',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: hudTextColor,
                            ),
                          ),
                          Switch(
                            key: const ValueKey('reader-auto-next'),
                            value: _autoNext,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.primary,
                            onChanged: (v) {
                              setState(() => _autoNext = v);
                              PreferencesService.setAutoNextChapter(v);
                              if (!v) _cancelAutoNext();
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

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

                      // THANH CHUYỂN CHƯƠNG NHANH (CHƯƠNG TRƯỚC / CHƯƠNG TIẾP)
                      if (series.chapters.length > 1) ...[
                        const SizedBox(height: 8),
                        _buildQuickChapterNav(series, currentChapter, hudTextColor),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Đếm ngược tự sang chương sau (key để test tìm được).
          if (_autoNextTarget != null)
            Positioned(
              key: const ValueKey('auto-next-banner'),
              left: 16,
              right: 16,
              // Giữa vùng đọc, vẽ sau khung điều khiển nên không bị che (khung cao hơn khi chữ to).
              top: MediaQuery.of(context).size.height * 0.42,
              child: Material(
                color: AppColors.darkSurface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.skip_next_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sang Chương ${_autoNextTarget!.numberLabel} sau ${autoNextDelay.inSeconds} giây',
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(onPressed: _cancelAutoNext, child: const Text('Hủy')),
                    ],
                  ),
                ),
              ),
            ),

          // FLOATING LOCK PILL: Hiển thị khi đang khóa màn hình (Giữ 2s hoặc nhấn đúp để mở)
          if (_isScreenLocked)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              right: 20,
              child: GestureDetector(
                onLongPress: _disableScreenLock,
                onDoubleTap: _disableScreenLock,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '🔒 Đang khóa • Giữ 2s để mở',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Watermark bản quyền nhẹ mang danh tính độc giả trên mọi chương (cả miễn phí lẫn trả phí)
          Positioned.fill(
            child: IgnorePointer(
              child: WatermarkOverlay(
                text: ref.watch(authStateProvider).user?.email ?? 'PanelForge Reader',
                opacity: 0.06,
              ),
            ),
          ),

          // Lớp bảo mật chống chụp màn hình / chuyển tác vụ
          if (_isPrivacyShieldActive)
            Positioned.fill(
              child: SecurityBlurShield(
                title: '🔒 BẢO VỆ BẢN QUYỀN NỘI DUNG',
                message:
                    'Nội dung truyện tranh tạm thời được che mờ khi chuyển tác vụ hoặc kích hoạt công cụ chụp màn hình.',
                onDismiss: () {
                  setState(() => _isPrivacyShieldActive = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _switchToChapter(ChapterItem chapter) async {
    _cancelAutoNext();
    setState(() => _isLoading = true);
    await _loadChapterContent(_series!, chapter);
    _readerSwitcherKey.currentState?.jumpToPage(1);
  }

  Widget _buildQuickChapterNav(SeriesItem series, ChapterItem currentChapter, Color hudTextColor) {
    final sorted = [...series.chapters]..sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
    final idx = sorted.indexWhere((c) => c.id == currentChapter.id);
    final prev = idx > 0 ? sorted[idx - 1] : null;
    final next = (idx >= 0 && idx < sorted.length - 1) ? sorted[idx + 1] : null;
    final isAtLastPage = currentChapter.pages.isNotEmpty && _currentPage >= currentChapter.pages.length;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: prev == null ? null : () => _switchToChapter(prev),
            icon: const Icon(Icons.skip_previous_rounded, size: 16),
            label: Text(
              prev == null ? 'Đầu truyện' : 'Chương ${prev.numberLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: hudTextColor,
              side: BorderSide(color: hudTextColor.withValues(alpha: 0.25)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: next == null ? null : () => _switchToChapter(next),
            icon: Icon(
              next != null && !_isChapterUnlocked(next) ? Icons.lock_rounded : Icons.skip_next_rounded,
              size: 16,
            ),
            label: Text(
              next == null ? 'Chương mới nhất' : 'Chương ${next.numberLabel} ›',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: (next != null && isAtLastPage)
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.2),
              foregroundColor: (next != null && isAtLastPage) ? Colors.white : AppColors.primary,
              disabledBackgroundColor: Colors.transparent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: next == null ? hudTextColor.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Màn hình Paywall khóa chương truyện giao diện Dark Obsidian
  Widget _buildPaywallView(SeriesItem series, ChapterItem currentChapter) {
    final wallet = ref.watch(walletNotifierProvider).asData?.value;
    final cachedVnd = PreferencesService.getLocalBalanceVnd();
    final balanceVnd = wallet?.balanceVnd ?? cachedVnd;

    final priceVnd = currentChapter.priceVnd;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      endDrawer: _buildTableOfContentsDrawer(series, currentChapter),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.popOrGo('/series/${widget.seriesId}'),
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
      body: Stack(
        children: [
          Center(
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
                    child: const Icon(Icons.lock_rounded, size: 44, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Chương Này Đang Bị Khóa',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Chương "${currentChapter.title}" yêu cầu mở khóa để đọc toàn bộ nội dung bản vẽ chất lượng cao và tính năng dịch thuật.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.5, color: AppColors.darkTextSecondary),
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
                                const Icon(Icons.account_balance_wallet_rounded, size: 15, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  formatVnd(priceVnd),
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
                              formatVnd(balanceVnd),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: balanceVnd >= priceVnd ? AppColors.mint : AppColors.rose,
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
                          series: series,
                          language: _activeLanguage,
                          onUnlocked: () {
                            setState(() => _lockedByServer = false);
                            _loadChapterContent(series, currentChapter);
                          },
                        );
                      },
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: Text(
                        'Mở Khóa Ngay (${formatVnd(priceVnd)})',
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

                  // Nút Nạp tiền vào Ví
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        WalletTopupDialog.show(context, initialTab: 0, seriesId: series.id);
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                      label: Text(
                        'Nạp Tiền Vào Ví',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.darkBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.darkTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isPrivacyShieldActive)
            Positioned.fill(
              child: SecurityBlurShield(
                title: '🔒 BẢO VỆ BẢN QUYỀN NỘI DUNG',
                message: 'Nội dung tạm thời được che mờ khi chuyển tác vụ hoặc kích hoạt công cụ chụp màn hình.',
                onDismiss: () {
                  setState(() => _isPrivacyShieldActive = false);
                },
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
                    style: GoogleFonts.newsreader(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
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
                      color: isCurrent ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                      border: Border(
                        left: BorderSide(color: isCurrent ? AppColors.primary : Colors.transparent, width: 4),
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
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.darkTextSecondary),
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
                                    formatVnd(ch.priceVnd),
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
