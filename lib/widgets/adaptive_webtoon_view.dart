import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comic_model.dart';
import '../models/comic_package_models.dart';
import '../theme/app_theme.dart';
import 'text_region_overlay.dart';

class AdaptiveWebtoonView extends StatefulWidget {
  final ChapterItem chapter;
  final ReaderThemeMode themeMode;
  final double tileSpacing;
  final LoadedComicPackage? package;
  final String? selectedLanguage;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTapScreen;
  final ValueChanged<TextRegion>? onRegionTap;

  const AdaptiveWebtoonView({
    super.key,
    required this.chapter,
    required this.themeMode,
    this.tileSpacing = 0.0,
    this.package,
    this.selectedLanguage,
    this.initialPage = 1,
    required this.onPageChanged,
    required this.onTapScreen,
    this.onRegionTap,
  });

  @override
  State<AdaptiveWebtoonView> createState() => AdaptiveWebtoonViewState();
}

class AdaptiveWebtoonViewState extends State<AdaptiveWebtoonView> {
  late final ScrollController _scrollController;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPage > 1) {
        jumpToPage(widget.initialPage);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || widget.chapter.pages.isEmpty) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    if (maxScroll > 0 && widget.chapter.pages.length > 1) {
      final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
      final page = (progress * (widget.chapter.pages.length - 1)).round() + 1;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
        widget.onPageChanged(page);
      }
    }
  }

  void jumpToPage(int page) {
    if (widget.chapter.pages.isEmpty || !_scrollController.hasClients) return;
    final clampedPage = page.clamp(1, widget.chapter.pages.length);
    setState(() => _currentPage = clampedPage);
    widget.onPageChanged(clampedPage);

    if (widget.chapter.pages.length > 1) {
      final fraction = (clampedPage - 1) / (widget.chapter.pages.length - 1);
      final targetOffset = fraction * _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildImageContent(String pathOrUrl) {
    final isNetwork = pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://');
    if (isNetwork) {
      return CachedNetworkImage(
        imageUrl: pathOrUrl,
        fit: BoxFit.contain,
        memCacheWidth: 1080,
        placeholder: (context, url) => Container(
          height: 450,
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
      height: 300,
      color: Colors.black12,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_rounded, size: 40, color: Colors.white54),
            const SizedBox(height: 8),
            Text(
              'Không thể tải ảnh webtoon tile',
              style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = widget.chapter.pages;
    final surfaceColor = Color(widget.themeMode.surfaceColor);
    final textColor = Color(widget.themeMode.textColor);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTapScreen,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 1000.0, // Pre-cache up to 1000px ahead to prevent lag
        slivers: [
          SliverPadding(
            padding: EdgeInsets.symmetric(
              vertical: widget.tileSpacing > 0 ? widget.tileSpacing : 12.0,
            ),
            sliver: SliverList.builder(
              itemCount: pages.length,
              addAutomaticKeepAlives: false, // Memory optimization for long webtoons
              addRepaintBoundaries: true,
              itemBuilder: (context, index) {
                final page = pages[index];
                final isLast = index == pages.length - 1;

                return Container(
                  margin: EdgeInsets.only(
                    bottom: isLast ? 40.0 : widget.tileSpacing,
                  ),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (page.imageUrl != null && page.imageUrl!.isNotEmpty)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: [
                                    _buildImageContent(page.imageUrl!),
                                    if (widget.package != null && widget.selectedLanguage != null)
                                      Positioned.fill(
                                        child: TextRegionOverlay(
                                          pageIndex: index,
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
                            )
                          else
                            // Fallback simulation card
                            Container(
                              height: 380,
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: textColor.withValues(alpha: 0.1)),
                              ),
                              child: Center(
                                child: Text(
                                  'Webtoon Tile ${index + 1}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: textColor.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

