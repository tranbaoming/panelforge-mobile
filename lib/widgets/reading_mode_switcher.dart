import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comic_model.dart';
import '../models/comic_package_models.dart';
import '../theme/app_theme.dart';
import 'adaptive_webtoon_view.dart';
import 'guided_panel_viewer.dart';
import 'text_region_overlay.dart';

class ReadingModeSwitcher extends StatefulWidget {
  final ChapterItem chapter;
  final ReadingMode mode;
  final ReaderThemeMode themeMode;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTapScreen;
  final LoadedComicPackage? package;
  final String? selectedLanguage;
  final bool isGuidedPanelMode;
  final double webtoonTileSpacing;
  final ValueChanged<TextRegion>? onRegionTap;

  const ReadingModeSwitcher({
    super.key,
    required this.chapter,
    required this.mode,
    required this.themeMode,
    this.initialPage = 1,
    required this.onPageChanged,
    required this.onTapScreen,
    this.package,
    this.selectedLanguage,
    this.isGuidedPanelMode = false,
    this.webtoonTileSpacing = 0.0,
    this.onRegionTap,
  });

  @override
  State<ReadingModeSwitcher> createState() => ReadingModeSwitcherState();
}

class ReadingModeSwitcherState extends State<ReadingModeSwitcher> {
  late PageController _pageController;
  final GlobalKey<AdaptiveWebtoonViewState> _webtoonKey = GlobalKey<AdaptiveWebtoonViewState>();
  int _currentPage = 1;
  int _currentPanelIndex = 0; // -1: Overview, 0..N-1: specific panel

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    final initialIndex = (_currentPage - 1).clamp(
      0,
      widget.chapter.pages.isEmpty ? 0 : widget.chapter.pages.length - 1,
    );

    if (widget.mode == ReadingMode.rtl) {
      _pageController = PageController(
        initialPage: widget.chapter.pages.isEmpty
            ? 0
            : widget.chapter.pages.length - 1 - initialIndex,
      );
    } else {
      _pageController = PageController(initialPage: initialIndex);
    }
  }

  @override
  void didUpdateWidget(covariant ReadingModeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode || oldWidget.chapter != widget.chapter) {
      final targetIndex = (_currentPage - 1).clamp(
        0,
        widget.chapter.pages.isEmpty ? 0 : widget.chapter.pages.length - 1,
      );
      _pageController.dispose();
      if (widget.mode == ReadingMode.rtl) {
        _pageController = PageController(
          initialPage: widget.chapter.pages.isEmpty
              ? 0
              : widget.chapter.pages.length - 1 - targetIndex,
        );
      } else {
        _pageController = PageController(initialPage: targetIndex);
      }
    }

    if (oldWidget.isGuidedPanelMode != widget.isGuidedPanelMode) {
      _currentPanelIndex = widget.isGuidedPanelMode ? 0 : -1;
    }
  }

  void jumpToPage(int page) {
    if (widget.chapter.pages.isEmpty) return;
    final clampedPage = page.clamp(1, widget.chapter.pages.length);
    setState(() {
      _currentPage = clampedPage;
      _currentPanelIndex = 0;
    });
    widget.onPageChanged(clampedPage);

    if (widget.mode == ReadingMode.webtoon) {
      _webtoonKey.currentState?.jumpToPage(clampedPage);
    } else if (widget.mode == ReadingMode.rtl) {
      final rtlIndex = widget.chapter.pages.length - clampedPage;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(rtlIndex);
      }
    } else {
      final index = clampedPage - 1;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(widget.themeMode.bgColor);
    final surfaceColor = Color(widget.themeMode.surfaceColor);
    final textColor = Color(widget.themeMode.textColor);

    if (widget.chapter.pages.isEmpty) {
      return Container(
        color: bgColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_stories_outlined, size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              Text(
                'Chương truyện này chưa có trang nào.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    // 1. CHẾ ĐỘ CUỘN DỌC TỐI ƯU (ADAPTIVE WEBTOON RENDERING)
    if (widget.mode == ReadingMode.webtoon) {
      return Container(
        color: bgColor,
        child: AdaptiveWebtoonView(
          key: _webtoonKey,
          chapter: widget.chapter,
          themeMode: widget.themeMode,
          tileSpacing: widget.webtoonTileSpacing,
          package: widget.package,
          selectedLanguage: widget.selectedLanguage,
          initialPage: widget.initialPage,
          onPageChanged: (page) {
            setState(() => _currentPage = page);
            widget.onPageChanged(page);
          },
          onTapScreen: widget.onTapScreen,
          onRegionTap: widget.onRegionTap,
        ),
      );
    }

    // 2. CHẾ ĐỘ LẬT TRANG (LTR / RTL) CÓ THỂ KÈM PANEL GUIDED READING
    return Container(
      color: bgColor,
      child: _buildHorizontalPageView(surfaceColor, textColor),
    );
  }

  Widget _buildHorizontalPageView(Color surfaceColor, Color textColor) {
    final isRtl = widget.mode == ReadingMode.rtl;
    final pages = widget.chapter.pages;

    return PageView.builder(
      controller: _pageController,
      reverse: isRtl,
      physics: widget.isGuidedPanelMode
          ? const NeverScrollableScrollPhysics() // Khóa lướt tự do để Guided Panel Viewer điều khiển
          : const BouncingScrollPhysics(),
      itemCount: pages.length,
      onPageChanged: (index) {
        final actualPage = isRtl ? (pages.length - index) : (index + 1);
        setState(() {
          _currentPage = actualPage;
          _currentPanelIndex = 0;
        });
        widget.onPageChanged(actualPage);
      },
      itemBuilder: (context, index) {
        final actualIndex = isRtl ? (pages.length - 1 - index) : index;
        final page = pages[actualIndex];
        final panels = widget.package?.getPanelsForPage(actualIndex) ?? [];

        final pageWidget = _buildComicSinglePage(actualIndex, page, surfaceColor, textColor);

        // NẾU BẬT GUIDED PANEL MODE & CÓ DỮ LIỆU KHUNG TRANH (PANELS.JSON)
        if (widget.isGuidedPanelMode && panels.isNotEmpty) {
          return GuidedPanelViewer(
            panels: panels,
            currentPanelIndex: _currentPanelIndex,
            onPanelChanged: (newIdx) {
              setState(() => _currentPanelIndex = newIdx);
            },
            onNextPage: () {
              if (index < pages.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            onPrevPage: () {
              if (index > 0) {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              }
            },
            onTapScreen: widget.onTapScreen,
            child: pageWidget,
          );
        }

        // Chế độ đọc thông thường (bấm vào màn hình để bật tắt HUD)
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTapScreen,
          child: Center(
            child: pageWidget,
          ),
        );
      },
    );
  }

  Widget _buildComicSinglePage(
    int pageIndex,
    ComicPageData page,
    Color surfaceColor,
    Color textColor,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 580),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page Header tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.chapter.title.toUpperCase()} • ${page.title.toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textColor.withValues(alpha: 0.5),
                    letterSpacing: 1.2,
                  ),
                ),
                if (widget.mode == ReadingMode.rtl)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'RTL MANGA',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content: Either real Page Image (network/local) or simulated panels
          Padding(
            padding: const EdgeInsets.all(12),
            child: page.imageUrl != null && page.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            _buildImageContent(page.imageUrl!),
                            // TÍNH NĂNG 3: MULTILINGUAL TEXT LAYERS VỚI TƯƠNG TÁC
                            if (widget.package != null && widget.selectedLanguage != null)
                              Positioned.fill(
                                child: TextRegionOverlay(
                                  pageIndex: pageIndex,
                                  containerWidth: constraints.maxWidth,
                                  containerHeight: constraints.maxWidth * 1.45,
                                  package: widget.package,
                                  selectedLanguage: widget.selectedLanguage,
                                  onRegionTap: widget.onRegionTap,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  )
                : Column(
                    children: page.panels.map((panel) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: textColor.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        child: AspectRatio(
                          aspectRatio: panel.aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(int.parse(panel.colorHex)),
                                      Color(int.parse(panel.colorHex)).withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              CustomPaint(
                                painter: _SpeedLinesPainter(),
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                right: 48,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    panel.dialogue,
                                    style: GoogleFonts.newsreader(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                right: 12,
                                child: Transform.rotate(
                                  angle: -0.12,
                                  child: Text(
                                    panel.soundEffect,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                      shadows: const [
                                        Shadow(color: Colors.black, blurRadius: 4),
                                        Shadow(color: Colors.white, blurRadius: 2),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(String pathOrUrl) {
    final isNetwork = pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://');
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: pathOrUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          height: 400,
          color: Colors.black12,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
        errorWidget: (context, url, error) => _buildImageErrorWidget(),
      );
    }

    final file = File(pathOrUrl);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildImageErrorWidget(),
      );
    }

    if (pathOrUrl.startsWith('file://')) {
      final sanitized = pathOrUrl.replaceFirst('file://', '');
      final altFile = File(sanitized);
      if (altFile.existsSync()) {
        return Image.file(
          altFile,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildImageErrorWidget(),
        );
      }
    }

    return _buildImageErrorWidget();
  }

  Widget _buildImageErrorWidget() {
    return Container(
      height: 280,
      color: Colors.black12,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_rounded, size: 40, color: Colors.white54),
            const SizedBox(height: 8),
            Text(
              'Không thể tải ảnh trang truyện',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 8; i++) {
      final y = size.height * (i / 8);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 20), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
