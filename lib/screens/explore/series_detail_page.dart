import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../navigation/back_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/api_dtos.dart';
import '../../models/comic_model.dart';
import '../../navigation/read_guard.dart';
import '../../providers/api_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/catalog_providers.dart';
import '../../services/app_info.dart';
import '../../theme/app_theme.dart';
import '../../services/catalog_service.dart';
import '../../services/preferences_service.dart';
import '../../widgets/forge_ui.dart';
import '../../widgets/series_rating_bar.dart';
import '../../widgets/unlock_chapter_bottom_sheet.dart';

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
  bool _isNewestFirst = true;
  bool _synopsisExpanded = false;
  bool _isFavorite = false;
  bool _isFollowing = false;
  String _selectedLanguage = PreferencesService.getContentLanguage();

  /// Đánh giá sao của bộ truyện (điểm trung bình, số lượt, đánh giá của tôi).
  ({double average, int count, int? mine}) _rating = (average: 0, count: 0, mine: null);

  @override
  void initState() {
    super.initState();
    _fetchDetailFromApi();
    // Mở trang chi tiết = đã thấy chương mới của bộ đang theo dõi.
    if (PreferencesService.isFollowing(widget.seriesId)) {
      Future.microtask(() => ref.read(followUpdatesProvider.notifier).markSeen(widget.seriesId));
    }
  }

  Future<void> _fetchDetailFromApi() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final detail = await CatalogService().getSeriesDetail(widget.seriesId, lang: _selectedLanguage);
      if (mounted) {
        final bookmarked = PreferencesService.isBookmarked(widget.seriesId);
        _isFavorite = PreferencesService.isFavorite(widget.seriesId);
        _isFollowing = PreferencesService.isFollowing(widget.seriesId);
        setState(() {
          _series = SeriesItem.fromPublicDetailDto(detail).copyWith(isBookmarked: bookmarked);
          _rating = (average: detail.ratingAverage, count: detail.ratingCount, mine: detail.myRating);
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

  Future<void> _selectLanguage(String lang) async {
    if (lang == _selectedLanguage) return;
    await PreferencesService.setContentLanguage(lang);
    if (!mounted) return;
    setState(() => _selectedLanguage = lang);
    await _fetchDetailFromApi();
  }

  /// Danh sách các ngôn ngữ đã phát hành trong toàn bộ các chương của Series này.
  List<String> _availableSeriesLanguages(SeriesItem series) {
    final langs = <String>{};
    for (final ch in series.chapters) {
      for (final opt in ch.languages) {
        langs.add(opt.language);
      }
    }
    if (langs.isEmpty) return const ['vi'];
    return [
      if (langs.contains('vi')) 'vi',
      if (langs.contains('en')) 'en',
      ...langs.where((l) => l != 'vi' && l != 'en'),
    ];
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
    ref.read(followUpdatesProvider.notifier).recompute();
    if (mounted) setState(() => _isFollowing = following);
  }

  Future<void> _toggleFavorite() async {
    final fav = await PreferencesService.toggleFavorite(widget.seriesId);
    if (mounted) setState(() => _isFavorite = fav);
  }

  /// Chương đọc được ở ngôn ngữ [_selectedLanguage] khi: không khóa ở ngôn ngữ đó, Backend báo `isUnlocked`,
  /// hoặc đã mở khóa đúng ấn bản ngôn ngữ này.
  bool _isChapterUnlocked(ChapterItem chapter) {
    final lang = _effectiveChapterLanguage(chapter);
    if (!chapter.isLockedFor(lang) || chapter.isServerUnlockedFor(lang)) return true;
    return ref.read(unlockedChaptersProvider.notifier).isUnlocked(chapter.id, language: lang);
  }

  bool _isUnlockedFor(WidgetRef ref, ChapterItem chapter) {
    final lang = _effectiveChapterLanguage(chapter);
    if (!chapter.isLockedFor(lang)) return true;
    if (chapter.isServerUnlockedFor(lang)) return true;
    final unlockedSet = ref.watch(unlockedChaptersProvider);
    final editionKey = ChapterEntitlement.editionKey(chapter.id, lang);
    if (unlockedSet.contains(editionKey)) return true;
    if (unlockedSet.any((id) => id.startsWith('${chapter.id}:'))) return false;
    return unlockedSet.contains(chapter.id);
  }

  String _effectiveChapterLanguage(ChapterItem chapter) {
    if (chapter.optionFor(_selectedLanguage) != null) return _selectedLanguage;
    if (chapter.languages.isNotEmpty) return chapter.languages.first.language;
    return _selectedLanguage;
  }

  /// Mở một chương (thanh đáy "Đọc Ngay / Đọc Tiếp" hoặc chọn trong DS Chương).
  /// Lazy Authentication: chưa đăng nhập → mở màn Đăng nhập; đăng nhập xong tiếp tục đúng chương này.
  Future<void> _onChapterTap(SeriesItem series, ChapterItem chapter, {VoidCallback? onUnlocked}) async {
    final wasLoggedIn = canReadChapters(ref.read(authStateProvider));
    if (!await ensureLoggedInForReading(context, ref, series: series)) return;
    if (!mounted) return;
    if (!wasLoggedIn) {
      // Vừa đăng nhập: tải lại quyền đọc (đã mua) trước khi quyết định có cần mở khóa không.
      await Future.wait([_fetchDetailFromApi(), ref.read(walletNotifierProvider.notifier).refresh()]);
      if (!mounted) return;
      series = _series ?? series;
      chapter = series.chapters.where((c) => c.id == chapter.id).firstOrNull ?? chapter;
    }
    final lang = _effectiveChapterLanguage(chapter);
    // Chương trả phí chưa mua: hỏi dùng Ví để mở khóa cả chương hay đọc thử trang xem trước.
    // (Đọc thử vẫn mở Reader: trang xem trước rõ, trang khác làm mờ kèm nút mở khóa cả chương.)
    if (!_isChapterUnlocked(chapter)) {
      final choice = await ChapterPurchaseOptionsSheet.show(context, chapter: chapter, series: series, language: lang);
      if (!mounted || choice == null) return;
      if (choice == ChapterPurchaseChoice.useWallet) {
        await UnlockChapterBottomSheet.show(
          context,
          chapter: chapter,
          series: series,
          language: lang,
          onUnlocked: () {
            if (mounted) setState(() {});
            onUnlocked?.call();
          },
        );
        return;
      }
    }
    if (!mounted) return;
    context.push(readerPath(series.id, chapter.id));
  }

  Future<void> _downloadChapter(SeriesItem series, ChapterItem chapter) async {
    // Tải offline cũng là đọc → cần tài khoản thật (Lazy Authentication).
    if (!await ensureLoggedInForReading(context, ref, series: series)) return;
    if (!mounted) return;
    // Chương trả phí chưa mở khóa → không cho tải CBZ, mời mở khóa trước.
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
    final ent = PreferencesService.getChapterEntitlement(chapter.id);
    if (ent != null && !ent.isPermanent) {
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
      await PreferencesService.saveOfflineChapterInfo(
        OfflineChapterInfo(
          chapterId: chapter.id,
          seriesId: series.id,
          seriesTitle: series.title,
          chapterNumber: chapter.chapterNumber,
          chapterTitle: chapter.title,
          downloadedAt: DateTime.now(),
        ),
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

  Future<void> _share(SeriesItem series) async {
    final link = AppInfo.seriesDeepLink(series.id);
    final text = AppInfo.shareUrl.isEmpty
        ? 'Đọc "${series.title}" trên PanelForge: $link'
        : 'Đọc "${series.title}" trên PanelForge: $link\nTải ứng dụng: ${AppInfo.shareUrl}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Đã sao chép lời giới thiệu để chia sẻ.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _series == null) {
      return Scaffold(
        backgroundColor: ForgeColors.bg,
        appBar: _appBar(null),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: ForgeColors.accent))
            : Center(
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
    final ordered = _isNewestFirst ? ascending.reversed.toList() : ascending;
    final history = PreferencesService.getReadingHistoryFor(series.id);
    final lastRead = history == null ? null : ascending.where((c) => c.id == history.chapterId).firstOrNull;
    final related = ref.watch(catalogSeriesProvider).asData?.value;
    final sameGenre = related == null ? const <SeriesItem>[] : CatalogSections(related).sameGenre(series);

    return Scaffold(
      backgroundColor: ForgeColors.bg,
      appBar: _appBar(series),
      body: RefreshIndicator(
        color: ForgeColors.accent,
        onRefresh: _fetchDetailFromApi,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(series)),
            SliverToBoxAdapter(
              child: SeriesRatingBar(
                key: ValueKey('rating-${series.id}-${_rating.count}'),
                series: series,
                average: _rating.average,
                count: _rating.count,
                myRating: _rating.mine,
              ),
            ),
            SliverToBoxAdapter(child: _buildSynopsis(series)),
            if (sameGenre.isNotEmpty) SliverToBoxAdapter(child: _buildSameGenre(sameGenre)),
            SliverToBoxAdapter(child: _buildChapterHeader(ascending)),
            if (ordered.isEmpty)
              const SliverToBoxAdapter(
                child: ForgeEmptyState(icon: Icons.menu_book_outlined, message: 'Chưa có chương nào.'),
              )
            else
              SliverList.separated(
                itemCount: ordered.length,
                separatorBuilder: (_, _) => Divider(height: 1, indent: 150, color: ForgeColors.divider),
                itemBuilder: (_, i) => _buildChapterRow(series, ordered[i], isLastRead: ordered[i].id == lastRead?.id),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
      bottomNavigationBar: _buildStickyBar(series, ascending, lastRead),
    );
  }

  PreferredSizeWidget _appBar(SeriesItem? series) => AppBar(
    backgroundColor: ForgeColors.bg,
    surfaceTintColor: Colors.transparent,
    titleSpacing: 0,
    leading: IconButton(
      tooltip: 'Quay lại',
      icon: Icon(Icons.arrow_back_rounded, color: ForgeColors.text),
      onPressed: () => context.popOrGo('/'),
    ),
    title: Text(
      series?.title ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: ForgeColors.text),
    ),
    actions: [
      if (series != null) ...[
        IconButton(
          tooltip: 'Chia sẻ',
          icon: Icon(Icons.ios_share_rounded, color: ForgeColors.text),
          onPressed: () => _share(series),
        ),
        IconButton(
          tooltip: _isFavorite ? 'Bỏ yêu thích' : 'Yêu thích',
          icon: Icon(
            _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: _isFavorite ? ForgeColors.accent : ForgeColors.text,
            size: 28,
          ),
          onPressed: _toggleFavorite,
        ),
      ],
      const SizedBox(width: 4),
    ],
  );

  Widget _buildHeader(SeriesItem series) {
    final genres = series.genres.where((g) => g.trim().isNotEmpty).toSet();
    final studio = series.author.isEmpty ? 'PanelForge Studio' : series.author;
    final status = series.isCompleted ? 'Hoàn thành' : 'Đang ra';
    final ageRating = series.ageRating?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 112, height: 150, child: SeriesCover(series: series, radius: 8)),
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
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: ForgeColors.text,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$studio • $status',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.textSoft),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (ageRating != null && ageRating.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: ForgeColors.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ForgeColors.accent.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          ageRating,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ForgeColors.accent,
                          ),
                        ),
                      ),
                    for (final g in genres)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: ForgeColors.chip, borderRadius: BorderRadius.circular(14)),
                        child: Text(
                          g,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ForgeColors.text,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _action(Icons.visibility_outlined, formatViews(series.views), null),
                    _action(
                      _isFollowing ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      _isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                      _toggleFollow,
                      active: _isFollowing,
                    ),
                    _action(
                      series.isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      'Đọc sau',
                      _toggleBookmark,
                      active: series.isBookmarked,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap, {bool active = false}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: active ? ForgeColors.accent : ForgeColors.text),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: active ? ForgeColors.accent : ForgeColors.text,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSynopsis(SeriesItem series) {
    final logline = series.logline?.trim();
    final teaser = series.teaser?.trim();
    final bodyText = (teaser != null && teaser.isNotEmpty) ? teaser : series.fullSynopsis;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: InkWell(
        onTap: () => setState(() => _synopsisExpanded = !_synopsisExpanded),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (logline != null && logline.isNotEmpty && logline != bodyText) ...[
              Text(
                logline,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: ForgeColors.text,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              bodyText,
              maxLines: _synopsisExpanded ? null : 3,
              overflow: _synopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: ForgeColors.textSoft, height: 1.55),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _synopsisExpanded ? 'Thu gọn' : 'Xem thêm',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: ForgeColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSameGenre(List<SeriesItem> list) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const ForgeBlockTitle(title: 'Cùng thể loại'),
      SizedBox(
        height: 198,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: list.length.clamp(0, 10),
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) => CoverTitleCard(
            series: list[i],
            width: 112,
            onTap: () => context.pushReplacement('/series/${list[i].id}'),
          ),
        ),
      ),
    ],
  );

  Widget _buildChapterHeader(List<ChapterItem> ascending) {
    final latest = ascending.isEmpty ? null : ascending.last;
    final availableLangs = _series == null ? const <String>['vi'] : _availableSeriesLanguages(_series!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Danh sách chương',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: ForgeColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      latest == null
                          ? 'Chưa có chương nào'
                          : '${ascending.length} chương • Mới nhất: Chương ${latest.numberLabel} (${latest.releaseDate})',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: ForgeColors.textSoft),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _isNewestFirst ? 'Cũ nhất trước' : 'Mới nhất trước',
                icon: Icon(Icons.swap_vert_rounded, color: ForgeColors.text, size: 30),
                onPressed: () => setState(() => _isNewestFirst = !_isNewestFirst),
              ),
            ],
          ),
          if (availableLangs.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.language_rounded, size: 16, color: ForgeColors.textSoft),
                const SizedBox(width: 6),
                Text(
                  'Ấn bản:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ForgeColors.textSoft,
                  ),
                ),
                const SizedBox(width: 8),
                for (final lang in availableLangs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      key: ValueKey('series-lang-$lang'),
                      onTap: () => _selectLanguage(lang),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedLanguage == lang ? ForgeColors.accent : ForgeColors.chip,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedLanguage == lang ? ForgeColors.accent : ForgeColors.border,
                          ),
                        ),
                        child: Text(
                          '${contentLanguageLabel(lang)} (${lang.toUpperCase()})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _selectedLanguage == lang ? Colors.white : ForgeColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterRow(SeriesItem series, ChapterItem chapter, {required bool isLastRead}) {
    final lang = _effectiveChapterLanguage(chapter);
    final unlocked = _isUnlockedFor(ref, chapter);
    final locked = chapter.isLockedFor(lang);
    final price = chapter.priceVndFor(lang);
    final downloaded = ref.watch(downloadedChaptersProvider).contains(chapter.id);
    final downloadStatus = ref.watch(chapterDownloadStatusProvider(chapter.id));
    final downloadProgress = ref.watch(chapterDownloadProgressProvider(chapter.id));
    final isDownloading = downloadStatus == DownloadStatus.downloading || downloadStatus == DownloadStatus.extracting;
    final ent =
        ref.watch(chapterEntitlementsProvider)[ChapterEntitlement.editionKey(chapter.id, lang)] ??
        ref.watch(chapterEntitlementsProvider)[chapter.id] ??
        PreferencesService.getChapterEntitlement(chapter.id, language: lang);
    final isPermanent = ent != null ? ent.isPermanent : unlocked;
    final subtitle = chapterSubtitle(chapter.title);
    final hasTitle = subtitle.isNotEmpty;
    final history = isLastRead ? PreferencesService.getReadingHistoryFor(series.id) : null;

    // Nhãn bên phải: miễn phí / đã mở khóa / giá (đang khóa).
    Widget status;
    if (!locked) {
      status = _pill('Miễn phí', AppColors.mint);
    } else if (unlocked) {
      status = _pill(
        'Đã mở',
        AppColors.mint,
        icon: Icons.lock_open_rounded,
      );
    } else {
      status = _pill(formatVnd(price), ForgeColors.accent, icon: Icons.lock_rounded);
    }

    Widget? download;
    if (unlocked && isPermanent) {
      if (isDownloading) {
        download = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: downloadProgress > 0 ? downloadProgress : null,
            strokeWidth: 2,
            color: ForgeColors.accent,
          ),
        );
      } else if (downloaded) {
        download = const Tooltip(
          message: 'Đã lưu offline',
          child: Icon(Icons.offline_pin_rounded, size: 22, color: AppColors.mint),
        );
      } else {
        download = InkWell(
          onTap: () => _downloadChapter(series, chapter),
          child: Tooltip(
            message: 'Tải CBZ Offline',
            child: Icon(Icons.download_for_offline_outlined, size: 22, color: ForgeColors.textSoft),
          ),
        );
      }
    }

    return InkWell(
      onTap: () => _onChapterTap(series, chapter, onUnlocked: () => setState(() {})),
      child: Container(
        decoration: isLastRead
            ? BoxDecoration(
                color: ForgeColors.accent.withValues(alpha: 0.08),
                border: const Border(left: BorderSide(color: ForgeColors.accent, width: 3)),
              )
            : null,
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChapterThumbnail(series: series, number: chapter.numberLabel),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'Chương ${chapter.numberLabel}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: isLastRead ? ForgeColors.accent : ForgeColors.text,
                            ),
                          ),
                        ),
                        status,
                      ],
                    ),
                    if (hasTitle)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: ForgeColors.textSoft),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        if (isLastRead) ...[
                          const Icon(Icons.menu_book_rounded, size: 15, color: ForgeColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            history != null && history.lastPageNumber > 1
                                ? 'Đang đọc (Tr.${history.lastPageNumber}) • '
                                : 'Đang đọc • ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ForgeColors.accent,
                            ),
                          ),
                        ],
                        Text(
                          chapter.releaseDate,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: ForgeColors.muted),
                        ),
                        if (chapter.languages.length > 1) ...[
                          const SizedBox(width: 6),
                          for (final opt in chapter.languages)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: opt.language == lang
                                      ? ForgeColors.accent.withValues(alpha: 0.16)
                                      : ForgeColors.chip,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  opt.language.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: opt.language == lang ? ForgeColors.accent : ForgeColors.muted,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        const Spacer(),
                        ?download,
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    ),
  );

  /// Nút đọc dính đáy, full-width: "Bắt đầu đọc" hoặc "Đọc tiếp • Chương N".
  Widget _buildStickyBar(SeriesItem series, List<ChapterItem> ascending, ChapterItem? lastRead) {
    final target = lastRead ?? (ascending.isEmpty ? null : ascending.first);
    final history = lastRead == null ? null : PreferencesService.getReadingHistoryFor(series.id);
    final pageSuffix = (history != null && history.lastPageNumber > 1) ? ' (Trang ${history.lastPageNumber})' : '';
    return Container(
      color: ForgeColors.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: target == null ? null : () => _onChapterTap(series, target),
              style: ElevatedButton.styleFrom(
                backgroundColor: ForgeColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ForgeColors.chip,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                textStyle: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              child: Text(
                lastRead != null ? 'Đọc tiếp • Chương ${lastRead.numberLabel}$pageSuffix' : 'Bắt đầu đọc',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
