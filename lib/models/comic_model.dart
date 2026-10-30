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

  const ComicPageData({
    required this.pageNumber,
    required this.title,
    this.imageUrl,
    this.panels = const [],
  });

  factory ComicPageData.fromPublicPage(PublicPageDto dto) {
    return ComicPageData(
      pageNumber: dto.pageNumber,
      title: 'Trang ${dto.pageNumber}',
      imageUrl: dto.fullImageUrl,
      panels: const [],
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
    this.cbzPackageUrl,
    this.manifestUrl,
    required this.pages,
  });

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
  final double rating;
  final int views;
  final int readProgressChapter;
  final int totalChapters;
  final List<String> genres;
  final List<ChapterItem> chapters;
  final bool isBookmarked;
  final String editorialNote;

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
    required this.rating,
    required this.views,
    required this.readProgressChapter,
    required this.totalChapters,
    required this.genres,
    required this.chapters,
    this.isBookmarked = false,
    required this.editorialNote,
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
      rating: 4.9,
      views: dto.publishedChapterCount * 1250,
      readProgressChapter: 0,
      totalChapters: dto.publishedChapterCount,
      genres: [dto.genre, dto.format],
      chapters: const [],
      isBookmarked: false,
      editorialNote: 'Phát hành chính thức bởi Studio ${dto.studioName}.',
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
      rating: 4.9,
      views: dto.chapters.length * 1500,
      readProgressChapter: 0,
      totalChapters: dto.chapters.length,
      genres: [dto.genre, dto.format],
      chapters: dto.chapters.map((c) => ChapterItem.fromPublicDto(c)).toList(),
      isBookmarked: false,
      editorialNote: 'Phát hành chính thức bởi Studio ${dto.studioName}.',
    );
  }

  SeriesItem copyWith({
    bool? isBookmarked,
    int? readProgressChapter,
    List<ChapterItem>? chapters,
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
      rating: rating,
      views: views,
      readProgressChapter: readProgressChapter ?? this.readProgressChapter,
      totalChapters: totalChapters,
      genres: genres,
      chapters: chapters ?? this.chapters,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      editorialNote: editorialNote,
    );
  }
}
