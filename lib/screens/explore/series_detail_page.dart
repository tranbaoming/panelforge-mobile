import 'dart:ui' show ImageFilter;

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
import '../../widgets/forge_ui.dart';
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
  bool _isFavorite = false;
  bool _isFollowing = false;

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
        _isFavorite = PreferencesService.isFavorite(widget.seriesId);
        _isFollowing = PreferencesService.isFollowing(widget.seriesId);
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
          content: Text(newState ? 'Đã thêm vào danh sách Đọc sau' : 'Đã xóa khỏi danh sách Đọc sau'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 🔔 Theo dõi (danh sách THEO DÕI ở màn Cá nhân) — khác 🔖 Đọc sau (bookmark).
  Future<void> _toggleFollow() async {
    final following = await PreferencesService.toggleFollow(widget.seriesId);
    if (mounted) setState(() => _isFollowing = following);
  }

  Future<void> _toggleFavorite() async {
    final fav = await PreferencesService.toggleFavorite(widget.seriesId);
    if (mounted) setState(() => _isFavorite = fav);
  }

  /// Chương đọc được khi: không bị Producer khóa, Backend báo `isUnlocked` (đã mua / VIP),
  /// người dùng đang có VIP, hoặc vừa mở khóa trong phiên này (`/api/wallet/me` → unlockedChapterIds).
  bool _isChapterUnlocked(ChapterItem chapter) => _isUnlockedFor(ref, chapter);

  bool _isUnlockedFor(WidgetRef ref, ChapterItem chapter) {
    if (!chapter.isLocked) return true;
    if (chapter.isUnlocked) return true;
    final wallet = ref.watch(walletNotifierProvider).asData?.value;
    if (wallet?.hasActiveVip ?? false) return true;
    if (wallet?.unlockedChapterIds.contains(chapter.id) ?? false) return true;
    return ref.watch(unlockedChaptersProvider).contains(chapter.id);
  }

  void _onChapterTap(SeriesItem series, ChapterItem chapter, {VoidCallback? onUnlocked}) {
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
          onUnlocked?.call();
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
            style: GoogleFonts.plusJakartaSans(color: ForgeColors.text, fontSize: 13),
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
                  child: Text('Đã tải gói truyện offline: ${chapter.title}', style: TextStyle(color: ForgeColors.text)),
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
        backgroundColor: ForgeColors.bg,
        appBar: _plainAppBar(),
        body: const Center(child: CircularProgressIndicator(color: ForgeColors.accent)),
      );
    }

    if (_series == null) {
      return Scaffold(
        backgroundColor: ForgeColors.bg,
        appBar: _plainAppBar(),
        body: Center(
          child: ForgeEmptyState(
            icon: _errorMessage != null ? Icons.cloud_off_rounded : Icons.menu_book_outlined,
            message: _errorMessage ?? 'Không tìm thấy tác phẩm này trên hệ thống.',
            actionLabel: 'Tải lại',
            onAction: _fetchDetailFromApi,
          ),
        ),
      );
    }

    final series = _series!;
    final ascending = [...series.chapters]..sort((a, b) => a.number.compareTo(b.number));
    final history = PreferencesService.getReadingHistoryFor(series.id);
    final lastRead = history == null ? null : ascending.where((c) => c.id == history.chapterId).firstOrNull;

    return Scaffold(
      backgroundColor: ForgeColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(series)),
          SliverToBoxAdapter(child: _buildGenres(series)),
          SliverToBoxAdapter(child: _buildChapterTrigger(series, ascending)),
          SliverToBoxAdapter(child: _buildSynopsis(series)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: _buildStickyBar(series, ascending, lastRead),
    );
  }

  PreferredSizeWidget _plainAppBar() => AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      icon: Icon(Icons.arrow_back_rounded, color: ForgeColors.text),
      onPressed: () => context.pop(),
    ),
  );

  Widget _buildHeader(SeriesItem series) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        // Nền: ảnh bìa làm mờ + gradient tối dần xuống dưới.
        Positioned.fill(
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                SeriesCover(series: series, radius: 0),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(color: Colors.black.withValues(alpha: 0.25)),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66141418), ForgeColors.bg],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(8, topPadding + 4, 8, 16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    icon: Icon(Icons.arrow_back_rounded, color: ForgeColors.text),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  const WalletChip(),
                  IconButton(
                    tooltip: 'Danh sách chương',
                    icon: Icon(Icons.menu_rounded, color: ForgeColors.text),
                    onPressed: () => _openChapterSheet(series),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 118,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: SeriesCover(series: series),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            series.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: ForgeColors.text,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _metaLine(
                            Icons.alternate_email_rounded,
                            series.author.isEmpty ? 'PanelForge Studio' : series.author,
                          ),
                          _metaLine(
                            series.isCompleted ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                            series.isCompleted ? 'Hoàn thành' : 'Đang ra',
                          ),
                          _metaLine(Icons.format_list_bulleted_rounded, 'Chương ${series.totalChapters}'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              _action(Icons.visibility_outlined, formatViews(series.views), null),
                              _action(
                                _isFollowing
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_none_rounded,
                                _isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                                _toggleFollow,
                                active: _isFollowing,
                              ),
                              _action(
                                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                'Yêu thích',
                                _toggleFavorite,
                                active: _isFavorite,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaLine(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 15, color: ForgeColors.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.textSoft),
          ),
        ),
      ],
    ),
  );

  Widget _action(IconData icon, String label, VoidCallback? onTap, {bool active = false}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: active ? ForgeColors.accent : ForgeColors.text),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? ForgeColors.accent : ForgeColors.text,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildGenres(SeriesItem series) {
    final genres = series.genres.where((g) => g.trim().isNotEmpty).toSet();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final g in genres)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: ForgeColors.chip, borderRadius: BorderRadius.circular(20)),
              child: Text(
                genreLabel(g),
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: ForgeColors.text),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChapterTrigger(SeriesItem series, List<ChapterItem> ascending) {
    final latest = ascending.isEmpty ? null : ascending.last;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: ForgeColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _openChapterSheet(series),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  'DS Chương',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ForgeColors.text,
                  ),
                ),
                const Spacer(),
                Text(
                  latest == null ? 'Chưa có chương' : 'Chương ${latest.number}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.muted),
                ),
                const Icon(Icons.chevron_right_rounded, color: ForgeColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSynopsis(SeriesItem series) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Giới Thiệu',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: ForgeColors.text),
        ),
        const SizedBox(height: 8),
        Text(
          series.fullSynopsis,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: ForgeColors.textSoft, height: 1.6),
        ),
      ],
    ),
  );

  Widget _buildStickyBar(SeriesItem series, List<ChapterItem> ascending, ChapterItem? lastRead) {
    final target = lastRead ?? (ascending.isEmpty ? null : ascending.first);
    return Container(
      decoration: BoxDecoration(
        color: ForgeColors.bottomBar,
        border: Border(top: BorderSide(color: ForgeColors.divider, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đọc Đến', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: ForgeColors.muted)),
                    const SizedBox(height: 2),
                    Text(
                      lastRead != null ? 'Chương ${lastRead.number}' : 'Chương đầu tiên',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: ForgeColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: target == null ? null : () => _onChapterTap(series, target),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ForgeColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  lastRead != null ? 'Đọc Tiếp' : 'Đọc Ngay',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: _toggleBookmark,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ForgeColors.border),
                  ),
                  child: Icon(
                    series.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: series.isBookmarked ? ForgeColors.accent : ForgeColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom Sheet "DS Chương" ─────────────────────────────────────────────

  void _openChapterSheet(SeriesItem series) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ForgeColors.navBar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.85,
        child: StatefulBuilder(
          builder: (sheetContext, setSheetState) => Consumer(
            builder: (sheetContext, sheetRef, _) {
              // Đọc lại từ state trang để danh sách cập nhật sau khi mở khóa / tải offline.
              final current = _series ?? series;
              final chapters = [...current.chapters]
                ..sort((a, b) => _isNewestFirst ? b.number.compareTo(a.number) : a.number.compareTo(b.number));
              final lastReadId = PreferencesService.getReadingHistoryFor(current.id)?.chapterId;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Đóng',
                          icon: Icon(Icons.close_rounded, color: ForgeColors.text),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                        Expanded(
                          child: Text(
                            'DS Chương',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ForgeColors.text,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _isFollowing ? 'Bỏ theo dõi' : 'Theo dõi',
                          icon: Icon(
                            _isFollowing
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded,
                            color: _isFollowing ? ForgeColors.accent : ForgeColors.text,
                          ),
                          onPressed: () async {
                            await _toggleFollow();
                            setSheetState(() {});
                          },
                        ),
                        IconButton(
                          tooltip: _isNewestFirst ? 'Cũ nhất trước' : 'Mới nhất trước',
                          icon: Icon(Icons.swap_vert_rounded, color: ForgeColors.text),
                          onPressed: () {
                            setState(() => _isNewestFirst = !_isNewestFirst);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: ForgeColors.divider),
                  Expanded(
                    child: chapters.isEmpty
                        ? const Center(
                            child: ForgeEmptyState(icon: Icons.menu_book_outlined, message: 'Chưa có chương nào.'),
                          )
                        : ListView.separated(
                            itemCount: chapters.length,
                            separatorBuilder: (_, _) => Divider(height: 1, color: ForgeColors.divider),
                            itemBuilder: (_, i) => _buildChapterRow(
                              sheetRef,
                              current,
                              chapters[i],
                              isLastRead: chapters[i].id == lastReadId,
                              refreshSheet: () => setSheetState(() {}),
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChapterRow(
    WidgetRef r,
    SeriesItem series,
    ChapterItem chapter, {
    required bool isLastRead,
    required VoidCallback refreshSheet,
  }) {
    final unlocked = _isUnlockedFor(r, chapter);
    final downloaded = r.watch(downloadedChaptersProvider).contains(chapter.id);
    final downloadStatus = r.watch(chapterDownloadStatusProvider(chapter.id));
    final downloadProgress = r.watch(chapterDownloadProgressProvider(chapter.id));
    final isDownloading = downloadStatus == DownloadStatus.downloading || downloadStatus == DownloadStatus.extracting;
    final isVip = r.watch(walletNotifierProvider).asData?.value.isVip ?? PreferencesService.getLocalIsVip();
    final ent =
        r.watch(chapterEntitlementsProvider)[chapter.id] ?? PreferencesService.getChapterEntitlement(chapter.id);
    final isPermanent = isVip || (ent != null ? ent.isPermanent : unlocked);
    final color = isLastRead ? ForgeColors.accent : ForgeColors.text;
    final hasTitle = chapter.title.isNotEmpty && !chapter.title.startsWith('Chương');

    Widget statusBadge;
    if (!chapter.isLocked) {
      statusBadge = const SizedBox.shrink();
    } else if (unlocked) {
      statusBadge = _pill('Đã mở khóa', AppColors.mint);
    } else {
      statusBadge = _pill('🔒 ${formatVnd(chapter.priceVnd)}', AppColors.amber);
    }

    Widget downloadAction;
    if (!unlocked || !isPermanent) {
      downloadAction = const SizedBox(width: 40);
    } else if (isDownloading) {
      downloadAction = SizedBox(
        width: 40,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              value: downloadProgress > 0 ? downloadProgress : null,
              strokeWidth: 2,
              color: ForgeColors.accent,
            ),
          ),
        ),
      );
    } else if (downloaded) {
      downloadAction = const SizedBox(
        width: 40,
        child: Tooltip(
          message: 'Đã lưu offline',
          child: Icon(Icons.check_circle_rounded, size: 20, color: AppColors.mint),
        ),
      );
    } else {
      downloadAction = IconButton(
        tooltip: 'Tải CBZ Offline',
        icon: Icon(Icons.download_for_offline_outlined, size: 20, color: ForgeColors.textSoft),
        onPressed: () => _downloadChapter(series, chapter),
      );
    }

    return InkWell(
      onTap: () => _onChapterTap(series, chapter, onUnlocked: refreshSheet),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          children: [
            if (isLastRead) ...[
              const Icon(Icons.menu_book_rounded, size: 16, color: ForgeColors.accent),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chương ${chapter.number}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                  ),
                  if (hasTitle)
                    Text(
                      chapter.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: ForgeColors.muted),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(chapter.releaseDate, style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: ForgeColors.muted)),
                const SizedBox(height: 4),
                statusBadge,
              ],
            ),
            downloadAction,
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(
      text,
      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
    ),
  );
}
