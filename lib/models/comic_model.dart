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

/// Định dạng số chương thập phân (D9a: 1.0 → "1", 1.5 → "1.5").
String formatChapterNumber(num n) {
  final d = n.toDouble();
  if (d == d.truncateToDouble()) return d.toInt().toString();
  return d.toString().replaceAll(RegExp(r'\.?0+$'), '');
}

class ChapterItem {
  final String id;
  final double chapterNumber;
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
  final String? coverUrl;
  final List<ChapterLanguageOption> languages;
  final List<ComicPageData> pages;

  const ChapterItem({
    required this.id,
    num? number,
    double? chapterNumber,
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
    this.coverUrl,
    this.languages = const [],
    required this.pages,
  }) : chapterNumber = chapterNumber ?? (number is double ? number : (number is int ? number * 1.0 : 1.0));

  /// Tương thích ngược: số nguyên của chương.
  int get number => chapterNumber.toInt();

  /// Nhãn số chương chuẩn hỗ trợ số thập phân (D9a: "1", "1.5").
  String get numberLabel => formatChapterNumber(chapterNumber);

  /// Chương trả phí do Publisher khóa (Backend `isLocked`).
  bool get isLocked => !isFree;

  /// Tìm tùy chọn ngôn ngữ tương ứng cho chương này.
  ChapterLanguageOption? optionFor(String languageCode) {
    final norm = languageCode.trim().toLowerCase();
    for (final opt in languages) {
      if (opt.language.toLowerCase() == norm) return opt;
    }
    return null;
  }

  /// Giá mở khóa theo ấn bản ngôn ngữ [languageCode] (BR-33).
  int priceVndFor([String? languageCode]) {
    if (languageCode != null) {
      final opt = optionFor(languageCode);
      if (opt != null) return opt.priceVnd;
    }
    return priceVnd;
  }

  /// Chương ở ngôn ngữ [languageCode] có phải trả phí không.
  bool isLockedFor([String? languageCode]) {
    if (languageCode != null) {
      final opt = optionFor(languageCode);
      if (opt != null) return opt.priceVnd > 0 || !opt.isUnlocked;
    }
    return isLocked;
  }

  /// Server báo người dùng đã mở khóa ấn bản ngôn ngữ [languageCode] chưa.
  bool isServerUnlockedFor([String? languageCode]) {
    if (languageCode != null) {
      final opt = optionFor(languageCode);
      if (opt != null) return opt.isUnlocked;
    }
    return !isLocked || isUnlocked;
  }

  factory ChapterItem.fromPublicDto(PublicChapterSummaryDto dto) {
    return ChapterItem(
      id: dto.id,
      chapterNumber: dto.chapterNumber,
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
      languages: dto.languages,
      pages: const [],
    );
  }

  factory ChapterItem.fromPublicReadDto(PublicChapterReadDto dto) {
    return ChapterItem(
      id: dto.id,
      chapterNumber: dto.chapterNumber,
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
      languages: dto.languages,
      pages: dto.pages.map((p) => ComicPageData.fromPublicPage(p)).toList(),
    );
  }

  ChapterItem copyWith({
    String? id,
    num? number,
    double? chapterNumber,
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
    String? coverUrl,
    List<ChapterLanguageOption>? languages,
    List<ComicPageData>? pages,
  }) {
    return ChapterItem(
      id: id ?? this.id,
      chapterNumber: chapterNumber ?? number?.toDouble() ?? this.chapterNumber,
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
      coverUrl: coverUrl ?? this.coverUrl,
      languages: languages ?? this.languages,
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
  final String? logline;
  final String? teaser;
  final String? ageRating;
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
    this.logline,
    this.teaser,
    this.ageRating,
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

    final hasLogline = dto.logline != null && dto.logline!.trim().isNotEmpty;
    final quote = hasLogline
        ? dto.logline!.trim()
        : (dto.synopsis != null && dto.synopsis!.isNotEmpty
              ? '“${dto.synopsis!.length > 80 ? dto.synopsis!.substring(0, 80) : dto.synopsis}...„'
              : '“Tác phẩm chính thức được phát hành bởi ${dto.studioName}.„');

    return SeriesItem(
      id: dto.id,
      title: dto.title,
      author: dto.studioName,
      artist: dto.studioName,
      format: fmt,
      coverGradientStart: '0xFF1B2A4A',
      coverGradientEnd: '0xFF0E1424',
      synopsisQuote: quote,
      fullSynopsis: dto.synopsis ?? 'Nội dung bộ truyện đang được cập nhật.',
      logline: dto.logline,
      teaser: dto.teaser,
      ageRating: dto.ageRating,
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

    final hasLogline = dto.logline != null && dto.logline!.trim().isNotEmpty;
    final quote = hasLogline
        ? dto.logline!.trim()
        : (dto.synopsis != null && dto.synopsis!.isNotEmpty
              ? '“${dto.synopsis!.length > 80 ? dto.synopsis!.substring(0, 80) : dto.synopsis}...„'
              : '“Tác phẩm độc quyền bởi ${dto.studioName}.„');

    return SeriesItem(
      id: dto.id,
      title: dto.title,
      author: dto.studioName,
      artist: dto.studioName,
      format: fmt,
      coverGradientStart: '0xFF1B2A4A',
      coverGradientEnd: '0xFF0E1424',
      synopsisQuote: quote,
      fullSynopsis: dto.synopsis ?? 'Nội dung bộ truyện đang được cập nhật.',
      logline: dto.logline,
      teaser: dto.teaser,
      ageRating: dto.ageRating,
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
    String? logline,
    String? teaser,
    String? ageRating,
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
      logline: logline ?? this.logline,
      teaser: teaser ?? this.teaser,
      ageRating: ageRating ?? this.ageRating,
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
