import '../services/api_config.dart';

/// Hướng đọc chuẩn theo backend ReadingDirection
enum ApiReadingDirection {
  rightToLeft,
  leftToRight,
  vertical;

  static ApiReadingDirection fromDynamic(dynamic val) {
    if (val is int) {
      if (val == 0) return ApiReadingDirection.rightToLeft;
      if (val == 1) return ApiReadingDirection.leftToRight;
      if (val == 2) return ApiReadingDirection.vertical;
    } else if (val is String) {
      final lower = val.toLowerCase();
      if (lower.contains('right') || lower == '0') return ApiReadingDirection.rightToLeft;
      if (lower.contains('left') || lower == '1') return ApiReadingDirection.leftToRight;
      if (lower.contains('vertical') || lower.contains('webtoon') || lower == '2') {
        return ApiReadingDirection.vertical;
      }
    }
    return ApiReadingDirection.rightToLeft;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATALOG MODELS (Reader)
// ─────────────────────────────────────────────────────────────────────────────

class PublicSeriesDto {
  final String id;
  final String title;
  final String? synopsis;
  final String genre;
  final String format;
  final ApiReadingDirection readingDirection;
  final String studioName;
  final int publishedChapterCount;
  final DateTime? latestPublishedAt;

  PublicSeriesDto({
    required this.id,
    required this.title,
    this.synopsis,
    required this.genre,
    required this.format,
    required this.readingDirection,
    required this.studioName,
    required this.publishedChapterCount,
    this.latestPublishedAt,
  });

  factory PublicSeriesDto.fromJson(Map<String, dynamic> json) {
    return PublicSeriesDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      synopsis: json['synopsis']?.toString(),
      genre: json['genre']?.toString() ?? 'Khác',
      format: json['format']?.toString() ?? 'Manga',
      readingDirection: ApiReadingDirection.fromDynamic(json['readingDirection']),
      studioName: json['studioName']?.toString() ?? 'PanelForge Studio',
      publishedChapterCount: (json['publishedChapterCount'] as num?)?.toInt() ?? 0,
      latestPublishedAt: json['latestPublishedAt'] != null
          ? DateTime.tryParse(json['latestPublishedAt'].toString())
          : null,
    );
  }
}

class PublicChapterSummaryDto {
  final String id;
  final double chapterNumber;
  final String? title;
  final DateTime? publishedAt;

  PublicChapterSummaryDto({
    required this.id,
    required this.chapterNumber,
    this.title,
    this.publishedAt,
  });

  factory PublicChapterSummaryDto.fromJson(Map<String, dynamic> json) {
    return PublicChapterSummaryDto(
      id: json['id']?.toString() ?? '',
      chapterNumber: (json['chapterNumber'] as num?)?.toDouble() ?? 1.0,
      title: json['title']?.toString(),
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : null,
    );
  }

  String get displayTitle {
    final numStr = chapterNumber.toString().replaceAll(RegExp(r'\.0$'), '');
    if (title != null && title!.isNotEmpty) {
      return 'Chương $numStr: $title';
    }
    return 'Chương $numStr';
  }
}

class PublicSeriesDetailDto {
  final String id;
  final String title;
  final String? synopsis;
  final String genre;
  final String format;
  final ApiReadingDirection readingDirection;
  final String studioName;
  final List<PublicChapterSummaryDto> chapters;

  PublicSeriesDetailDto({
    required this.id,
    required this.title,
    this.synopsis,
    required this.genre,
    required this.format,
    required this.readingDirection,
    required this.studioName,
    required this.chapters,
  });

  factory PublicSeriesDetailDto.fromJson(Map<String, dynamic> json) {
    final rawChapters = json['chapters'] as List<dynamic>? ?? [];
    return PublicSeriesDetailDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      synopsis: json['synopsis']?.toString(),
      genre: json['genre']?.toString() ?? 'Khác',
      format: json['format']?.toString() ?? 'Manga',
      readingDirection: ApiReadingDirection.fromDynamic(json['readingDirection']),
      studioName: json['studioName']?.toString() ?? 'PanelForge Studio',
      chapters: rawChapters
          .map((e) => PublicChapterSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PublicPageDto {
  final String id;
  final int pageNumber;
  final String? relativeImageUrl;

  PublicPageDto({
    required this.id,
    required this.pageNumber,
    this.relativeImageUrl,
  });

  factory PublicPageDto.fromJson(Map<String, dynamic> json) {
    return PublicPageDto(
      id: json['id']?.toString() ?? '',
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      relativeImageUrl: json['imageUrl']?.toString(),
    );
  }

  String? get fullImageUrl =>
      relativeImageUrl != null ? ApiConfig.resolveUrl(relativeImageUrl) : null;
}

class PublicChapterReadDto {
  final String id;
  final String seriesId;
  final String seriesTitle;
  final ApiReadingDirection readingDirection;
  final double chapterNumber;
  final String? title;
  final DateTime? publishedAt;
  final List<PublicPageDto> pages;

  PublicChapterReadDto({
    required this.id,
    required this.seriesId,
    required this.seriesTitle,
    required this.readingDirection,
    required this.chapterNumber,
    this.title,
    this.publishedAt,
    required this.pages,
  });

  factory PublicChapterReadDto.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>? ?? [];
    return PublicChapterReadDto(
      id: json['id']?.toString() ?? '',
      seriesId: json['seriesId']?.toString() ?? '',
      seriesTitle: json['seriesTitle']?.toString() ?? '',
      readingDirection: ApiReadingDirection.fromDynamic(json['readingDirection']),
      chapterNumber: (json['chapterNumber'] as num?)?.toDouble() ?? 1.0,
      title: json['title']?.toString(),
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : null,
      pages: rawPages
          .map((e) => PublicPageDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get displayTitle {
    final numStr = chapterNumber.toString().replaceAll(RegExp(r'\.0$'), '');
    if (title != null && title!.isNotEmpty) {
      return 'Chương $numStr: $title';
    }
    return 'Chương $numStr';
  }
}

class PagedCatalogResult {
  final List<PublicSeriesDto> items;
  final int totalCount;
  final int pageIndex;
  final int pageSize;
  final int totalPages;

  PagedCatalogResult({
    required this.items,
    required this.totalCount,
    required this.pageIndex,
    required this.pageSize,
    required this.totalPages,
  });

  factory PagedCatalogResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PagedCatalogResult(
      items: rawItems
          .map((e) => PublicSeriesDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREVIEW / REVIEW MODELS (Reviewer)
// ─────────────────────────────────────────────────────────────────────────────

class PreviewPanelDto {
  final String panelId;
  final int panelNumber;
  final String boundingBox;

  PreviewPanelDto({
    required this.panelId,
    required this.panelNumber,
    required this.boundingBox,
  });

  factory PreviewPanelDto.fromJson(Map<String, dynamic> json) {
    return PreviewPanelDto(
      panelId: json['panelId']?.toString() ?? '',
      panelNumber: (json['panelNumber'] as num?)?.toInt() ?? 1,
      boundingBox: json['boundingBox']?.toString() ?? '',
    );
  }
}

class PreviewPageDto {
  final String pageId;
  final int pageNumber;
  final String assetReferenceId;
  final int versionNumber;
  final String relativeImageUrl;
  final List<PreviewPanelDto> panels;

  PreviewPageDto({
    required this.pageId,
    required this.pageNumber,
    required this.assetReferenceId,
    required this.versionNumber,
    required this.relativeImageUrl,
    required this.panels,
  });

  factory PreviewPageDto.fromJson(Map<String, dynamic> json) {
    final rawPanels = json['panels'] as List<dynamic>? ?? [];
    return PreviewPageDto(
      pageId: json['pageId']?.toString() ?? '',
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      assetReferenceId: json['assetReferenceId']?.toString() ?? '',
      versionNumber: (json['versionNumber'] as num?)?.toInt() ?? 1,
      relativeImageUrl: json['imageUrl']?.toString() ?? '',
      panels: rawPanels
          .map((e) => PreviewPanelDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get fullImageUrl => ApiConfig.resolveUrl(relativeImageUrl);
}

class PreviewChapterDto {
  final String chapterId;
  final String seriesTitle;
  final double chapterNumber;
  final String? chapterTitle;
  final ApiReadingDirection readingDirection;
  final String recipientEmail;
  final String watermarkText;
  final DateTime expiresAt;
  final int chapterVersion;
  final List<PreviewPageDto> pages;

  PreviewChapterDto({
    required this.chapterId,
    required this.seriesTitle,
    required this.chapterNumber,
    this.chapterTitle,
    required this.readingDirection,
    required this.recipientEmail,
    required this.watermarkText,
    required this.expiresAt,
    required this.chapterVersion,
    required this.pages,
  });

  factory PreviewChapterDto.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>? ?? [];
    return PreviewChapterDto(
      chapterId: json['chapterId']?.toString() ?? '',
      seriesTitle: json['seriesTitle']?.toString() ?? 'Bản Thảo Độc Quyền',
      chapterNumber: (json['chapterNumber'] as num?)?.toDouble() ?? 1.0,
      chapterTitle: json['chapterTitle']?.toString(),
      readingDirection: ApiReadingDirection.fromDynamic(json['readingDirection']),
      recipientEmail: json['recipientEmail']?.toString() ?? '',
      watermarkText: json['watermarkText']?.toString() ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'].toString())
          : DateTime.now().add(const Duration(hours: 4)),
      chapterVersion: (json['chapterVersion'] as num?)?.toInt() ?? 1,
      pages: rawPages
          .map((e) => PreviewPageDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime {
    if (isExpired) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }
}

class PreviewFeedbackDto {
  final String id;
  final String previewLinkId;
  final String chapterId;
  final String? pageId;
  final String? panelId;
  final String recipientEmail;
  final String message;
  final String status;
  final DateTime createdAt;

  PreviewFeedbackDto({
    required this.id,
    required this.previewLinkId,
    required this.chapterId,
    this.pageId,
    this.panelId,
    required this.recipientEmail,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory PreviewFeedbackDto.fromJson(Map<String, dynamic> json) {
    return PreviewFeedbackDto(
      id: json['id']?.toString() ?? '',
      previewLinkId: json['previewLinkId']?.toString() ?? '',
      chapterId: json['chapterId']?.toString() ?? '',
      pageId: json['pageId']?.toString(),
      panelId: json['panelId']?.toString(),
      recipientEmail: json['recipientEmail']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }
}

