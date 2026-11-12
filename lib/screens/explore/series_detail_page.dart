import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/api_dtos.dart';
import '../../models/comic_model.dart';
import '../../providers/api_providers.dart';
import '../../theme/app_theme.dart';
import '../../services/catalog_service.dart';
import '../../services/preferences_service.dart';
import '../../widgets/unlock_chapter_bottom_sheet.dart';
import '../../widgets/wallet_chip.dart';

class SeriesDetailPage extends ConsumerStatefulWidget {
  final String seriesId;

  const SeriesDetailPage({super.key, required this.seriesId});

  @override
  ConsumerState<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends ConsumerState<SeriesDetailPage> {
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
        ref.read(isServerConnectedProvider.notifier).state = true;
      }
    } catch (e) {
      debugPrint('[SeriesDetail API Error] $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể tải thông tin tác phẩm. Vui lòng kiểm tra lại kết nối mạng.';
        });
        ref.read(isServerConnectedProvider.notifier).state = false;
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
          content: Text(newState ? 'Đã thêm vào tủ sách cá nhân' : 'Đã xóa khỏi tủ sách'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Chương đọc được khi: không bị Producer khóa, Backend báo `isUnlocked` (đã mua / VIP),
  /// người dùng đang có VIP, hoặc vừa mở khóa trong phiên này (`/api/wallet/me` → unlockedChapterIds).
  bool _isChapterUnlocked(ChapterItem chapter) {
    if (!chapter.isLocked) return true;
    if (chapter.isUnlocked) return true;
    final wallet = ref.watch(walletNotifierProvider).asData?.value;
    if (wallet?.hasActiveVip ?? false) return true;
    if (wallet?.unlockedChapterIds.contains(chapter.id) ?? false) return true;
    return ref.watch(unlockedChaptersProvider).contains(chapter.id);
  }

  void _onChapterTap(SeriesItem series, ChapterItem chapter) {
    final unlocked = _isChapterUnlocked(chapter);
    if (unlocked) {
      context.push('/reader/${series.id}?chapterId=${chapter.id}');
    } else {
      UnlockChapterBottomSheet.show(
        context,
        chapter: chapter,
        series: series,
        onUnlocked: () {
          if (mounted) setState(() {});
        },
      );
    }
  }

  Future<void> _downloadChapter(SeriesItem series, ChapterItem chapter) async {
    // Chương trả phí chưa mở khóa (không VIP, chưa mua) → không cho tải CBZ, mời mở khóa trước.
    if (!_isChapterUnlocked(chapter)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Vui lòng mở khóa chương trước khi tải offline.'),
        ),
      );
      UnlockChapterBottomSheet.show(
        context,
        chapter: chapter,
        series: series,
        onUnlocked: () {
          if (mounted) setState(() {});
        },
      );
      return;
    }
    final isVip = ref.read(walletNotifierProvider).asData?.value.isVip ?? PreferencesService.getLocalIsVip();
    final ent = PreferencesService.getChapterEntitlement(chapter.id);
    if (!isVip && ent != null && !ent.isPermanent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.primary),
          ),
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Gói thuê xem theo lượt không hỗ trợ tải offline. Vui lòng mua vĩnh viễn để tải file .CBZ.',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
          ),
        ),
      );
      return;
    }

    final cbzService = ref.read(cbzPackageServiceProvider);
    try {
      ref.read(downloadStatusProvider.notifier).setStatus(chapter.id, DownloadStatus.downloading);
      await cbzService.downloadAndExtractCbzPackage(
        chapterId: chapter.id,
        customDownloadUrl: chapter.cbzPackageUrl,
        onProgress: (p, received, total) {
          ref.read(downloadProgressProvider.notifier).setProgress(chapter.id, p);
        },
        onStatusChanged: (status) {
          ref.read(downloadStatusProvider.notifier).setStatus(chapter.id, status);
        },
      );
      ref.read(downloadedChaptersProvider.notifier).add(chapter.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.darkSurface,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã tải gói truyện offline: ${chapter.title}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      ref.read(downloadStatusProvider.notifier).setStatus(chapter.id, DownloadStatus.failed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi tải gói offline: $e')));
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.darkTextSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _fetchDetailFromApi,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tải lại'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
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
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (!ref.watch(authStateProvider).isGuest) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: WalletChip(isServerConnected: true)),
                const SizedBox(width: 8),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: InkWell(
                    onTap: () => context.push('/login'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.8), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.login_rounded, color: AppColors.primary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Đăng nhập',
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
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: Icon(
                  series.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: series.isBookmarked ? AppColors.primary : Colors.white70,
                ),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
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
                    colors: [Color(int.parse(series.coverGradientStart)).withValues(alpha: 0.35), AppColors.darkBg],
                  ),
                ),
                child: Center(
                  child: Padding(padding: const EdgeInsets.only(top: 50), child: _buildPrintBookCover(series)),
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
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
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
                        if (series.synopsisQuote.isNotEmpty) const SizedBox(height: 10),
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
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
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

                  // Thanh thông tin chương trả phí (giá do Studio cấu hình trên Backend)
                  if (series.chapters.any((c) => c.isLocked))
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sell_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${series.chapters.where((c) => c.isLocked).length} chương trả phí do Studio định giá • Mở khóa vĩnh viễn bằng Ví hoặc chuyển khoản VietQR',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Danh Sách Chương & Bộ Sắp Xếp (Mới nhất / Cũ nhất)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Danh Sách Chương (${chaptersList.length})',
                        style: GoogleFonts.newsreader(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
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
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.darkTextSecondary),
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
                delegate: SliverChildBuilderDelegate((context, index) {
                  final ch = chaptersList[index];
                  return _buildChapterListItem(context, series, ch);
                }, childCount: chaptersList.length),
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
          colors: [Color(int.parse(series.coverGradientStart)), Color(int.parse(series.coverGradientEnd))],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(4, 12)),
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
                borderRadius: BorderRadius.only(topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
              ),
            ),
          ),
          // Embossed metallic border
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1),
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
                    style: GoogleFonts.newsreader(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(series.author, style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterListItem(BuildContext context, SeriesItem series, ChapterItem chapter) {
    final unlocked = _isChapterUnlocked(chapter);
    final downloaded = ref.watch(downloadedChaptersProvider).contains(chapter.id);
    final downloadStatus = ref.watch(chapterDownloadStatusProvider(chapter.id));
    final downloadProgress = ref.watch(chapterDownloadProgressProvider(chapter.id));
    final isDownloading = downloadStatus == DownloadStatus.downloading || downloadStatus == DownloadStatus.extracting;

    final isVip = ref.watch(walletNotifierProvider).asData?.value.isVip ?? PreferencesService.getLocalIsVip();
    final entitlements = ref.watch(chapterEntitlementsProvider);
    final ent = entitlements[chapter.id] ?? PreferencesService.getChapterEntitlement(chapter.id);
    final bool isPermanent = isVip || (ent != null ? ent.isPermanent : unlocked);
    final int? remainingViews = ent?.remainingViews;

    final isWeeklyHot = chapter.isWeeklyHot;
    // Giá mở khóa thật do Producer cấu hình (PublicChapterDto.priceVnd).
    final displayPriceVnd = chapter.priceVnd;

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
          style: GoogleFonts.newsreader(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        subtitle: Row(
          children: [
            Text(
              '${chapter.releaseDate} • ${chapter.pageCount} trang',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.darkTextSecondary),
            ),
            const SizedBox(width: 8),
            if (chapter.isFree)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.mint.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'MIỄN PHÍ',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mint,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else if (unlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPermanent
                      ? AppColors.mint.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isPermanent
                        ? AppColors.mint.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isPermanent ? 'VĨNH VIỄN' : (remainingViews != null ? 'CÒN $remainingViews/3 LƯỢT XEM' : 'ĐÃ MUA'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isPermanent ? AppColors.mint : AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else if (isWeeklyHot)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '🔥 MỚI TRONG TUẦN',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unlocked) ...[
              if (isPermanent) ...[
                if (isDownloading)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: downloadProgress > 0 ? downloadProgress : null,
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (downloaded)
                  const Tooltip(
                    message: 'Đã lưu offline',
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.check_circle_rounded, size: 20, color: AppColors.mint),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Tải CBZ Offline',
                    icon: const Icon(Icons.download_for_offline_outlined, size: 20, color: Colors.white70),
                    onPressed: () => _downloadChapter(series, chapter),
                  ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
            ] else ...[
              // Nút khóa hiển thị mức giá VNĐ theo phân loại chương
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isWeeklyHot ? AppColors.primary : AppColors.darkCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isWeeklyHot ? AppColors.primary : AppColors.darkBorder),
                  boxShadow: isWeeklyHot
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isWeeklyHot ? Icons.whatshot_rounded : Icons.lock_rounded,
                      size: 11,
                      color: isWeeklyHot ? Colors.white : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isWeeklyHot ? '🔥 ${formatVnd(displayPriceVnd)}' : '🔒 ${formatVnd(displayPriceVnd)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isWeeklyHot ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        onTap: () => _onChapterTap(series, chapter),
      ),
    );
  }
}
