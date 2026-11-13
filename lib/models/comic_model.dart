import 'api_dtos.dart';

enum ComicFormat {
  comic('Comic'),
  manga('Manga'),
  webtoon('Webtoon');

  final String label;
  const ComicFormat(this.label);
}

enum ReadingMode {
  ltr('LTR (Trái sang phải)'),
  rtl('RTL (Manga - Phải sang trái)'),
  webtoon('Webtoon (Cuộn dọc)');

  final String title;
  const ReadingMode(this.title);
}

enum ReaderThemeMode {
  night('Đêm', 0xFF07080D, 0xFF10121A, 0xFFF9FAFB),
  vintage('Giấy Cổ', 0xFFF4EEDD, 0xFFEBE3CE, 0xFF2A2318),
  light('Sáng', 0xFFFCF9F2, 0xFFFFFFFF, 0xFF1E2024);

  final String label;
  final int bgColor;
  final int surfaceColor;
  final int textColor;

  const ReaderThemeMode(this.label, this.bgColor, this.surfaceColor, this.textColor);
}

class ComicPanelData {
  final String id;
  final int panelNumber;
  final String description;
  final String dialogue;
  final String colorHex;
  final String soundEffect;
  final double aspectRatio;

  const ComicPanelData({
    required this.id,
    required this.panelNumber,
    required this.description,
    required this.dialogue,
    required this.colorHex,
    required this.soundEffect,
    this.aspectRatio = 1.33,
  });
}

class ComicPageData {
  final int pageNumber;
  final String title;
  final String? imageUrl;
  final List<ComicPanelData> panels;

  /// Id trang trên server (null với trang offline / dữ liệu mẫu).
  final String? pageId;

  /// Trang nằm sau paywall của chương trả phí (không phải trang xem trước).
  final bool isLocked;

  /// Người đọc đã có quyền xem trang (xem trước / đã mua chương / VIP). Khi false [imageUrl] luôn null.
  final bool isUnlocked;

  /// Trang xem trước của chương trả phí.
  final bool isPreview;

  const ComicPageData({
    required this.pageNumber,
    required this.title,
    this.imageUrl,
    this.panels = const [],
    this.pageId,
    this.isLocked = false,
    this.isUnlocked = true,
    this.isPreview = false,
  });

  /// Trang đang bị khóa với người đọc hiện tại → hiển thị làm mờ + nút mở khóa chương.
  bool get isPaywalled => isLocked && !isUnlocked;

  factory ComicPageData.fromPublicPage(PublicPageDto dto) {
    return ComicPageData(
      pageNumber: dto.pageNumber,
      title: 'Trang ${dto.pageNumber}',
      imageUrl: dto.isPaywalled ? null : dto.fullImageUrl,
      panels: const [],
      pageId: dto.id,
      isLocked: dto.isLocked,
      isUnlocked: dto.isUnlocked,
      isPreview: dto.isPreview,
    );
  }
}

class ChapterItem {
  final String id;
  final int number;
  final String title;
  final String releaseDate;
  final int pageCount;
  final bool isFree;
  final bool isUnlocked;
  final int priceCoins;
  final int priceVnd;
  final int rentalPriceVnd;
  final ChapterAccessPolicy accessPolicy;
  final int? maxAllowedViews;
  final bool isWeeklyHot;
  final String? cbzPackageUrl;
  final String? manifestUrl;
  final List<ComicPageData> pages;

  const ChapterItem({
    required this.id,
    required this.number,
    required this.title,
    required this.releaseDate,
    required this.pageCount,
    this.isFree = true,
    this.isUnlocked = true,
    this.priceCoins = 0,
    this.priceVnd = 0,
    this.rentalPriceVnd = 0,
    this.accessPolicy = ChapterAccessPolicy.free,
    this.maxAllowedViews,
    this.isWeeklyHot = false,
    this.cbzPackageUrl,
    this.manifestUrl,
    required this.pages,
  });

  /// Chương trả phí do Producer khóa (Backend `isLocked`).
  bool get isLocked => !isFree;

  factory ChapterItem.fromPublicDto(PublicChapterSummaryDto dto) {
    return ChapterItem(
      id: dto.id,
      number: dto.chapterNumber.toInt(),
      title: dto.displayTitle,
      releaseDate: dto.publishedAt != null
          ? '${dto.publishedAt!.day.toString().padLeft(2, '0')}/${dto.publishedAt!.month.toString().padLeft(2, '0')}/${dto.publishedAt!.year}'
          : 'Vừa phát hành',
      pageCount: 0,
      isFree: dto.isFree,
      isUnlocked: dto.isUnlocked,
      priceCoins: dto.priceCoins,
      priceVnd: dto.priceVnd,
      rentalPriceVnd: dto.rentalPriceVnd,
      accessPolicy: dto.accessPolicy,
      maxAllowedViews: dto.maxAllowedViews,
      isWeeklyHot: dto.isWeeklyHot,
      cbzPackageUrl: dto.cbzPackageUrl,
      manifestUrl: dto.manifestUrl,
      pages: const [],
    );
  }

  factory ChapterItem.fromPublicReadDto(PublicChapterReadDto dto) {
    return ChapterItem(
      id: dto.id,
      number: dto.chapterNumber.toInt(),
      title: dto.displayTitle,
      releaseDate: dto.publishedAt != null
          ? '${dto.publishedAt!.day.toString().padLeft(2, '0')}/${dto.publishedAt!.month.toString().padLeft(2, '0')}/${dto.publishedAt!.year}'
          : 'Đang mở đọc',
      pageCount: dto.pages.length,
      isFree: dto.isFree,
      isUnlocked: dto.isUnlocked,
      priceCoins: dto.priceCoins,
      priceVnd: dto.priceVnd,
      rentalPriceVnd: dto.rentalPriceVnd,
      accessPolicy: dto.accessPolicy,
      maxAllowedViews: dto.maxAllowedViews,
      isWeeklyHot: dto.isWeeklyHot,
      cbzPackageUrl: dto.cbzPackageUrl,
      manifestUrl: dto.manifestUrl,
      pages: dto.pages.map((p) => ComicPageData.fromPublicPage(p)).toList(),
    );
  }

  ChapterItem copyWith({
    String? id,
    int? number,
    String? title,
    String? releaseDate,
    int? pageCount,
    bool? isFree,
    bool? isUnlocked,
    int? priceCoins,
    int? priceVnd,
    int? rentalPriceVnd,
    ChapterAccessPolicy? accessPolicy,
    int? maxAllowedViews,
    bool? isWeeklyHot,
    String? cbzPackageUrl,
    String? manifestUrl,
    List<ComicPageData>? pages,
  }) {
    return ChapterItem(
      id: id ?? this.id,
      number: number ?? this.number,
      title: title ?? this.title,
      releaseDate: releaseDate ?? this.releaseDate,
      pageCount: pageCount ?? this.pageCount,
      isFree: isFree ?? this.isFree,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      priceCoins: priceCoins ?? this.priceCoins,
      priceVnd: priceVnd ?? this.priceVnd,
      rentalPriceVnd: rentalPriceVnd ?? this.rentalPriceVnd,
      accessPolicy: accessPolicy ?? this.accessPolicy,
      maxAllowedViews: maxAllowedViews ?? this.maxAllowedViews,
      isWeeklyHot: isWeeklyHot ?? this.isWeeklyHot,
      cbzPackageUrl: cbzPackageUrl ?? this.cbzPackageUrl,
      manifestUrl: manifestUrl ?? this.manifestUrl,
      pages: pages ?? this.pages,
    );
  }
}

class SeriesItem {
  final String id;
  final String title;
  final String author;
  final String artist;
  final ComicFormat format;
  final String coverGradientStart;
  final String coverGradientEnd;
  final String synopsisQuote;
  final String fullSynopsis;
  /// Lượt đọc thật từ Backend (tổng / 1 ngày / 7 ngày / 30 ngày).
  final int views;
  final int viewsLast1Day;
  final int viewsLast7Days;
  final int viewsLast30Days;
  final int readProgressChapter;
  final int totalChapters;
  final List<String> genres;
  final List<ChapterItem> chapters;
  final bool isBookmarked;
  final String editorialNote;
  final int baseChapterPriceVnd;
  final int hotChapterPriceVnd;

  /// Thời điểm chương mới nhất được phát hành (catalog list); null nếu chưa rõ.
  final DateTime? latestPublishedAt;

  /// URL đầy đủ của ảnh bìa bộ truyện; null = chưa có bìa (UI dùng khối màu).
  final String? coverUrl;
  final bool isCompleted;
  final DateTime? createdAt;

  const SeriesItem({
    required this.id,
    required this.title,
    required this.author,
    required this.artist,
    required this.format,
    required this.coverGradientStart,
    required this.coverGradientEnd,
    required this.synopsisQuote,
    required this.fullSynopsis,
    required this.views,
    this.viewsLast1Day = 0,
    this.viewsLast7Days = 0,
    this.viewsLast30Days = 0,
    required this.readProgressChapter,
    required this.totalChapters,
    required this.genres,
    required this.chapters,
    this.isBookmarked = false,
    required this.editorialNote,
    this.baseChapterPriceVnd = 3000,
    this.hotChapterPriceVnd = 5000,
    this.latestPublishedAt,
    this.coverUrl,
    this.isCompleted = false,
    this.createdAt,
  });

  factory SeriesItem.fromPublicDto(PublicSeriesDto dto) {
    ComicFormat fmt = ComicFormat.manga;
    final lowerFormat = dto.format.toLowerCase();
    if (lowerFormat.contains('webtoon')) {
      fmt = ComicFormat.webtoon;
    } else if (lowerFormat.contains('comic')) {
      fmt = ComicFormat.comic;
    }

    return SeriesItem(
      id: dto.id,
      title: dto.title,
      author: dto.studioName,
      artist: dto.studioName,
      format: fmt,
      coverGradientStart: '0xFF1B2A4A',
      coverGradientEnd: '0xFF0E1424',
      synopsisQuote: dto.synopsis != null && dto.synopsis!.isNotEmpty
          ? '“${dto.synopsis!.length > 80 ? dto.synopsis!.substring(0, 80) : dto.synopsis}...„'
          : '“Tác phẩm chính thức được phát hành bởi ${dto.studioName}.„',
      fullSynopsis: dto.synopsis ?? 'Nội dung bộ truyện đang được cập nhật.',
      views: dto.viewCount,
      viewsLast1Day: dto.viewsLast1Day,
      viewsLast7Days: dto.viewsLast7Days,
      viewsLast30Days: dto.viewsLast30Days,
      readProgressChapter: 0,
      totalChapters: dto.publishedChapterCount,
      genres: [dto.genre, dto.format],
      chapters: const [],
      isBookmarked: false,
      editorialNote: 'Phát hành chính thức bởi Studio ${dto.studioName}.',
      baseChapterPriceVnd: dto.baseChapterPriceVnd,
      hotChapterPriceVnd: dto.hotChapterPriceVnd,
      latestPublishedAt: dto.latestPublishedAt,
      coverUrl: dto.fullCoverUrl,
      isCompleted: dto.isCompleted,
      createdAt: dto.createdAt,
    );
  }

  factory SeriesItem.fromPublicDetailDto(PublicSeriesDetailDto dto) {
    ComicFormat fmt = ComicFormat.manga;
    final lowerFormat = dto.format.toLowerCase();
    if (lowerFormat.contains('webtoon')) {
      fmt = ComicFormat.webtoon;
    } else if (lowerFormat.contains('comic')) {
      fmt = ComicFormat.comic;
    }

    return SeriesItem(
      id: dto.id,
      title: dto.title,
      author: dto.studioName,
      artist: dto.studioName,
      format: fmt,
      coverGradientStart: '0xFF1B2A4A',
      coverGradientEnd: '0xFF0E1424',
      synopsisQuote: dto.synopsis != null && dto.synopsis!.isNotEmpty
          ? '“${dto.synopsis!.length > 80 ? dto.synopsis!.substring(0, 80) : dto.synopsis}...„'
          : '“Tác phẩm độc quyền bởi ${dto.studioName}.„',
      fullSynopsis: dto.synopsis ?? 'Nội dung bộ truyện đang được cập nhật.',
      views: dto.viewCount,
      readProgressChapter: 0,
      totalChapters: dto.chapters.length,
      genres: [dto.genre, dto.format],
      chapters: dto.chapters.map((c) => ChapterItem.fromPublicDto(c)).toList(),
      isBookmarked: false,
      editorialNote: 'Phát hành chính thức bởi Studio ${dto.studioName}.',
      baseChapterPriceVnd: dto.baseChapterPriceVnd,
      hotChapterPriceVnd: dto.hotChapterPriceVnd,
      coverUrl: dto.fullCoverUrl,
      isCompleted: dto.isCompleted,
      createdAt: dto.createdAt,
    );
  }

  SeriesItem copyWith({
    bool? isBookmarked,
    int? readProgressChapter,
    List<ChapterItem>? chapters,
    int? baseChapterPriceVnd,
    int? hotChapterPriceVnd,
  }) {
    return SeriesItem(
      id: id,
      title: title,
      author: author,
      artist: artist,
      format: format,
      coverGradientStart: coverGradientStart,
      coverGradientEnd: coverGradientEnd,
      synopsisQuote: synopsisQuote,
      fullSynopsis: fullSynopsis,
      views: views,
      viewsLast1Day: viewsLast1Day,
      viewsLast7Days: viewsLast7Days,
      viewsLast30Days: viewsLast30Days,
      readProgressChapter: readProgressChapter ?? this.readProgressChapter,
      totalChapters: totalChapters,
      genres: genres,
      chapters: chapters ?? this.chapters,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      editorialNote: editorialNote,
      baseChapterPriceVnd: baseChapterPriceVnd ?? this.baseChapterPriceVnd,
      hotChapterPriceVnd: hotChapterPriceVnd ?? this.hotChapterPriceVnd,
      latestPublishedAt: latestPublishedAt,
      coverUrl: coverUrl,
      isCompleted: isCompleted,
      createdAt: createdAt,
    );
  }
}
