import '../services/api_config.dart';
import 'comic_package_models.dart';

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

  String get apiValue {
    switch (this) {
      case ApiReadingDirection.rightToLeft:
        return 'RightToLeft';
      case ApiReadingDirection.leftToRight:
        return 'LeftToRight';
      case ApiReadingDirection.vertical:
        return 'Vertical';
    }
  }
}

/// Chính sách lượt xem cho từng Tập/Chapter
enum ChapterAccessPolicy {
  free,
  rentalLimitedViews,
  permanent;

  static ChapterAccessPolicy fromDynamic(dynamic val) {
    if (val is ChapterAccessPolicy) return val;
    if (val is String) {
      final lower = val.toLowerCase();
      if (lower.contains('rental') || lower.contains('limited')) {
        return ChapterAccessPolicy.rentalLimitedViews;
      }
      if (lower.contains('permanent') || lower.contains('buy')) {
        return ChapterAccessPolicy.permanent;
      }
      if (lower.contains('free')) {
        return ChapterAccessPolicy.free;
      }
    }
    return ChapterAccessPolicy.free;
  }

  String get value {
    switch (this) {
      case ChapterAccessPolicy.free:
        return 'free';
      case ChapterAccessPolicy.rentalLimitedViews:
        return 'rentalLimitedViews';
      case ChapterAccessPolicy.permanent:
        return 'permanent';
    }
  }
}

/// Trạng thái sở hữu của Reader cho từng chapter
class ChapterEntitlement {
  final String chapterId;
  final bool isPermanent;
  final int? remainingViews;
  final DateTime? lastOpenedAt;
  final DateTime? unlockedAt;

  const ChapterEntitlement({
    required this.chapterId,
    this.isPermanent = false,
    this.remainingViews,
    this.lastOpenedAt,
    this.unlockedAt,
  });

  bool get isValid {
    if (isPermanent) return true;
    return (remainingViews ?? 0) > 0;
  }

  factory ChapterEntitlement.fromJson(Map<String, dynamic> json) {
    return ChapterEntitlement(
      chapterId: json['chapterId']?.toString() ?? '',
      isPermanent: json['isPermanent'] as bool? ?? false,
      remainingViews: (json['remainingViews'] as num?)?.toInt(),
      lastOpenedAt: json['lastOpenedAt'] != null
          ? DateTime.tryParse(json['lastOpenedAt'].toString())
          : null,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.tryParse(json['unlockedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'chapterId': chapterId,
        'isPermanent': isPermanent,
        if (remainingViews != null) 'remainingViews': remainingViews,
        if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt!.toIso8601String(),
        if (unlockedAt != null) 'unlockedAt': unlockedAt!.toIso8601String(),
      };

  ChapterEntitlement copyWith({
    String? chapterId,
    bool? isPermanent,
    int? remainingViews,
    DateTime? lastOpenedAt,
    DateTime? unlockedAt,
  }) {
    return ChapterEntitlement(
      chapterId: chapterId ?? this.chapterId,
      isPermanent: isPermanent ?? this.isPermanent,
      remainingViews: remainingViews ?? this.remainingViews,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

/// Kết quả trừ lượt xem khi đọc chapter
class ConsumeViewResult {
  final bool didConsume;
  final bool isPermanent;
  final int? remainingViews;
  final String? message;

  const ConsumeViewResult({
    required this.didConsume,
    this.isPermanent = false,
    this.remainingViews,
    this.message,
  });
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
  final int baseChapterPriceVnd;
  final int hotChapterPriceVnd;

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
    this.baseChapterPriceVnd = 3000,
    this.hotChapterPriceVnd = 5000,
  });

  factory PublicSeriesDto.fromJson(Map<String, dynamic> json) {
    final formatLower = (json['format']?.toString() ?? '').toLowerCase();
    final defaultBase = formatLower.contains('manga') ? 2000 : 3000;

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
      baseChapterPriceVnd:
          (json['baseChapterPriceVnd'] as num?)?.toInt() ?? defaultBase,
      hotChapterPriceVnd:
          (json['hotChapterPriceVnd'] as num?)?.toInt() ?? 5000,
    );
  }
}

class PublicChapterSummaryDto {
  final String id;
  final double chapterNumber;
  final String? title;
  final DateTime? publishedAt;
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

  PublicChapterSummaryDto({
    required this.id,
    required this.chapterNumber,
    this.title,
    this.publishedAt,
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
  });

  factory PublicChapterSummaryDto.fromJson(Map<String, dynamic> json) {
    final rawFree = json['isFree'] as bool? ?? false;
    final numVal = (json['chapterNumber'] as num?)?.toDouble() ?? 1.0;
    final free = rawFree || numVal == 1.0;

    DateTime? pubAt;
    if (json['publishedAt'] != null) {
      pubAt = DateTime.tryParse(json['publishedAt'].toString());
    }

    final bool isHotFromPub = pubAt != null &&
        DateTime.now().difference(pubAt).inDays <= 7 &&
        !free;
    final bool isHot = (json['isWeeklyHot'] as bool?) ?? isHotFromPub;

    int priceVnd;
    int rentalPriceVnd;

    if (free) {
      priceVnd = 0;
      rentalPriceVnd = 0;
    } else if (json['priceVnd'] != null) {
      priceVnd = (json['priceVnd'] as num).toInt();
      rentalPriceVnd = (json['rentalPriceVnd'] as num?)?.toInt() ??
          (priceVnd <= 500
              ? 300
              : priceVnd <= 700
                  ? 500
                  : priceVnd <= 1000
                      ? 500
                      : priceVnd <= 3000
                          ? 1500
                          : 2000);
    } else if (isHot) {
      priceVnd = 5000;
      rentalPriceVnd = 2000;
    } else if (numVal == 2.0) {
      priceVnd = 500;
      rentalPriceVnd = 300;
    } else if (numVal == 3.0) {
      priceVnd = 700;
      rentalPriceVnd = 500;
    } else if (numVal == 4.0) {
      priceVnd = 1000;
      rentalPriceVnd = 500;
    } else if (json['priceCoins'] != null && (json['priceCoins'] as num) > 0) {
      priceVnd = ((json['priceCoins'] as num).toInt() * 60).clamp(500, 5000);
      rentalPriceVnd = (priceVnd * 0.5).round();
    } else {
      priceVnd = 1000;
      rentalPriceVnd = 500;
    }

    final coins = (json['priceCoins'] as num?)?.toInt() ?? (priceVnd ~/ 100);
    final policy = free
        ? ChapterAccessPolicy.free
        : (json['accessPolicy'] != null
            ? ChapterAccessPolicy.fromDynamic(json['accessPolicy'])
            : ChapterAccessPolicy.rentalLimitedViews);
    final maxViews = (json['maxAllowedViews'] as num?)?.toInt() ?? (free ? null : 3);

    return PublicChapterSummaryDto(
      id: json['id']?.toString() ?? '',
      chapterNumber: numVal,
      title: json['title']?.toString(),
      publishedAt: pubAt,
      isFree: free,
      isUnlocked: json['isUnlocked'] as bool? ?? free,
      priceCoins: coins,
      priceVnd: priceVnd,
      rentalPriceVnd: rentalPriceVnd,
      accessPolicy: policy,
      maxAllowedViews: maxViews,
      isWeeklyHot: isHot,
      cbzPackageUrl: json['cbzPackageUrl']?.toString(),
      manifestUrl: json['manifestUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapterNumber': chapterNumber,
        if (title != null) 'title': title,
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        'isFree': isFree,
        'isUnlocked': isUnlocked,
        'priceCoins': priceCoins,
        'priceVnd': priceVnd,
        'rentalPriceVnd': rentalPriceVnd,
        'accessPolicy': accessPolicy.value,
        if (maxAllowedViews != null) 'maxAllowedViews': maxAllowedViews,
        'isWeeklyHot': isWeeklyHot,
        if (cbzPackageUrl != null) 'cbzPackageUrl': cbzPackageUrl,
        if (manifestUrl != null) 'manifestUrl': manifestUrl,
      };

  String? get fullCbzPackageUrl =>
      cbzPackageUrl != null ? ApiConfig.resolveUrl(cbzPackageUrl!) : null;

  String? get fullManifestUrl =>
      manifestUrl != null ? ApiConfig.resolveUrl(manifestUrl!) : null;

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
  final int baseChapterPriceVnd;
  final int hotChapterPriceVnd;

  PublicSeriesDetailDto({
    required this.id,
    required this.title,
    this.synopsis,
    required this.genre,
    required this.format,
    required this.readingDirection,
    required this.studioName,
    required this.chapters,
    this.baseChapterPriceVnd = 3000,
    this.hotChapterPriceVnd = 5000,
  });

  factory PublicSeriesDetailDto.fromJson(Map<String, dynamic> json) {
    final rawChapters = json['chapters'] as List<dynamic>? ?? [];
    final formatLower = (json['format']?.toString() ?? '').toLowerCase();
    final defaultBase = formatLower.contains('manga') ? 2000 : 3000;

    return PublicSeriesDetailDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      synopsis: json['synopsis']?.toString(),
      genre: json['genre']?.toString() ?? 'Khác',
      format: json['format']?.toString() ?? 'Manga',
      readingDirection: ApiReadingDirection.fromDynamic(json['readingDirection']),
      studioName: json['studioName']?.toString() ?? 'PanelForge Studio',
      baseChapterPriceVnd:
          (json['baseChapterPriceVnd'] as num?)?.toInt() ?? defaultBase,
      hotChapterPriceVnd:
          (json['hotChapterPriceVnd'] as num?)?.toInt() ?? 5000,
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

  PublicChapterReadDto({
    required this.id,
    required this.seriesId,
    required this.seriesTitle,
    required this.readingDirection,
    required this.chapterNumber,
    this.title,
    this.publishedAt,
    required this.pages,
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
  });

  factory PublicChapterReadDto.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>? ?? [];
    final rawFree = json['isFree'] as bool? ?? false;
    final numVal = (json['chapterNumber'] as num?)?.toDouble() ?? 1.0;
    final free = rawFree || numVal == 1.0;

    DateTime? pubAt;
    if (json['publishedAt'] != null) {
      pubAt = DateTime.tryParse(json['publishedAt'].toString());
    }

    final bool isHotFromPub = pubAt != null &&
        DateTime.now().difference(pubAt).inDays <= 7 &&
        !free;
    final bool isHot = (json['isWeeklyHot'] as bool?) ?? isHotFromPub;

    int priceVnd;
    int rentalPriceVnd;

    if (free) {
      priceVnd = 0;
      rentalPriceVnd = 0;
    } else if (json['priceVnd'] != null) {
      priceVnd = (json['priceVnd'] as num).toInt();
      rentalPriceVnd = (json['rentalPriceVnd'] as num?)?.toInt() ??
          (priceVnd <= 500
              ? 300
              : priceVnd <= 700
                  ? 500
                  : priceVnd <= 1000
                      ? 500
                      : priceVnd <= 3000
                          ? 1500
                          : 2000);
    } else if (isHot) {
      priceVnd = 5000;
      rentalPriceVnd = 2000;
    } else if (numVal == 2.0) {
      priceVnd = 500;
      rentalPriceVnd = 300;
    } else if (numVal == 3.0) {
      priceVnd = 700;
      rentalPriceVnd = 500;
    } else if (numVal == 4.0) {
      priceVnd = 1000;
      rentalPriceVnd = 500;
    } else if (json['priceCoins'] != null && (json['priceCoins'] as num) > 0) {
      priceVnd = ((json['priceCoins'] as num).toInt() * 60).clamp(500, 5000);
      rentalPriceVnd = (priceVnd * 0.5).round();
    } else {
      priceVnd = 1000;
      rentalPriceVnd = 500;
    }

    final coins = (json['priceCoins'] as num?)?.toInt() ?? (priceVnd ~/ 100);
    final policy = free
        ? ChapterAccessPolicy.free
        : (json['accessPolicy'] != null
            ? ChapterAccessPolicy.fromDynamic(json['accessPolicy'])
            : ChapterAccessPolicy.rentalLimitedViews);
    final maxViews = (json['maxAllowedViews'] as num?)?.toInt() ?? (free ? null : 3);

    return PublicChapterReadDto(
      id: json['id']?.toString() ?? '',
      seriesId: json['seriesId']?.toString() ?? '',
      seriesTitle: json['seriesTitle']?.toString() ?? '',
      readingDirection: ApiReadingDirection.fromDynamic(json['readingDirection']),
      chapterNumber: numVal,
      title: json['title']?.toString(),
      publishedAt: pubAt,
      pages: rawPages
          .map((e) => PublicPageDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      isFree: free,
      isUnlocked: json['isUnlocked'] as bool? ?? free,
      priceCoins: coins,
      priceVnd: priceVnd,
      rentalPriceVnd: rentalPriceVnd,
      accessPolicy: policy,
      maxAllowedViews: maxViews,
      isWeeklyHot: isHot,
      cbzPackageUrl: json['cbzPackageUrl']?.toString(),
      manifestUrl: json['manifestUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'seriesId': seriesId,
        'seriesTitle': seriesTitle,
        'readingDirection': readingDirection.apiValue,
        'chapterNumber': chapterNumber,
        if (title != null) 'title': title,
        if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
        'pages': pages.map((p) => {'id': p.id, 'pageNumber': p.pageNumber, 'imageUrl': p.relativeImageUrl}).toList(),
        'isFree': isFree,
        'isUnlocked': isUnlocked,
        'priceCoins': priceCoins,
        'priceVnd': priceVnd,
        'rentalPriceVnd': rentalPriceVnd,
        'accessPolicy': accessPolicy.value,
        if (maxAllowedViews != null) 'maxAllowedViews': maxAllowedViews,
        'isWeeklyHot': isWeeklyHot,
        if (cbzPackageUrl != null) 'cbzPackageUrl': cbzPackageUrl,
        if (manifestUrl != null) 'manifestUrl': manifestUrl,
      };

  String? get fullCbzPackageUrl =>
      cbzPackageUrl != null ? ApiConfig.resolveUrl(cbzPackageUrl!) : null;

  String? get fullManifestUrl =>
      manifestUrl != null ? ApiConfig.resolveUrl(manifestUrl!) : null;

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
  final NormalizedBounds? _explicitBounds;

  NormalizedBounds? get bounds => _explicitBounds ?? NormalizedBounds.tryParse(boundingBox);

  PreviewPanelDto({
    required this.panelId,
    required this.panelNumber,
    required this.boundingBox,
    NormalizedBounds? bounds,
  }) : _explicitBounds = bounds;

  factory PreviewPanelDto.fromJson(Map<String, dynamic> json) {
    final rawBox = json['boundingBox']?.toString() ?? '';
    return PreviewPanelDto(
      panelId: json['panelId']?.toString() ?? '',
      panelNumber: (json['panelNumber'] as num?)?.toInt() ?? 1,
      boundingBox: rawBox,
      bounds: json['bounds'] is Map<String, dynamic>
          ? NormalizedBounds.fromJson(json['bounds'] as Map<String, dynamic>)
          : NormalizedBounds.tryParse(rawBox),
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
  final List<TextRegion> textRegions;

  PreviewPageDto({
    required this.pageId,
    required this.pageNumber,
    required this.assetReferenceId,
    required this.versionNumber,
    required this.relativeImageUrl,
    required this.panels,
    this.textRegions = const [],
  });

  factory PreviewPageDto.fromJson(Map<String, dynamic> json) {
    final rawPanels = json['panels'] as List<dynamic>? ?? [];
    final rawTextRegions = json['textRegions'] as List<dynamic>? ?? [];
    return PreviewPageDto(
      pageId: json['pageId']?.toString() ?? '',
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      assetReferenceId: json['assetReferenceId']?.toString() ?? '',
      versionNumber: (json['versionNumber'] as num?)?.toInt() ?? 1,
      relativeImageUrl: json['imageUrl']?.toString() ?? '',
      panels: rawPanels
          .map((e) => PreviewPanelDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      textRegions: rawTextRegions
          .map((e) => TextRegion.fromJson(e as Map<String, dynamic>))
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
  final String? cbzPackageUrl;
  final String? manifestUrl;
  final List<PanelInfo> panels;
  final List<TextRegion> textRegions;

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
    this.cbzPackageUrl,
    this.manifestUrl,
    this.panels = const [],
    this.textRegions = const [],
  });

  factory PreviewChapterDto.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>? ?? [];
    final rawPanels = (json['panels'] ?? json['metadata']?['panels']) as List<dynamic>? ?? [];
    final rawTextRegions = (json['textRegions'] ?? json['metadata']?['textRegions']) as List<dynamic>? ?? [];
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
      cbzPackageUrl: json['cbzPackageUrl']?.toString(),
      manifestUrl: json['manifestUrl']?.toString(),
      panels: rawPanels
          .map((e) => PanelInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      textRegions: rawTextRegions
          .map((e) => TextRegion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime {
    if (isExpired) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }
}

/// DTO gửi phản hồi/góp ý bản thảo cho backend .NET 8 (kèm tọa độ khung/vùng thoại)
class PreviewFeedbackRequest {
  final String token;
  final String message;
  final String? pageId;
  final String? panelId;
  final String? textRegionId;
  final NormalizedBounds? bounds;

  const PreviewFeedbackRequest({
    required this.token,
    required this.message,
    this.pageId,
    this.panelId,
    this.textRegionId,
    this.bounds,
  });

  Map<String, dynamic> toJson() => {
        'token': token.trim(),
        'message': message.trim(),
        if (pageId != null && pageId!.isNotEmpty) 'pageId': pageId,
        if (panelId != null && panelId!.isNotEmpty) 'panelId': panelId,
        if (textRegionId != null && textRegionId!.isNotEmpty) 'textRegionId': textRegionId,
        if (bounds != null) 'bounds': bounds!.toJson(),
      };
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

// ─────────────────────────────────────────────────────────────────────────────
// MONETIZATION & WALLET DTOs (Thu phí người dùng)
// ─────────────────────────────────────────────────────────────────────────────

/// Định dạng tiền tệ VNĐ chuẩn với dấu chấm phân cách hàng nghìn (vd: 20.000đ, 5.000đ)
String formatVnd(int amount, {bool showSign = false}) {
  final isNegative = amount < 0;
  final abs = amount.abs().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < abs.length; i++) {
    if (i > 0 && (abs.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(abs[i]);
  }
  final formatted = buffer.toString();
  if (showSign) {
    return isNegative ? '-$formattedđ' : '+$formattedđ';
  }
  return isNegative ? '-$formattedđ' : '$formattedđ';
}

/// DTO Lịch sử giao dịch ví (Nạp tiền, Mua chapter)
class WalletTransactionDto {
  final String id;
  final String title;
  final int amountVnd;
  final DateTime createdAt;
  final int balanceAfter;

  const WalletTransactionDto({
    required this.id,
    required this.title,
    required this.amountVnd,
    required this.createdAt,
    required this.balanceAfter,
  });

  factory WalletTransactionDto.fromJson(Map<String, dynamic> json) {
    return WalletTransactionDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amountVnd: (json['amountVnd'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      balanceAfter: (json['balanceAfter'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amountVnd': amountVnd,
        'createdAt': createdAt.toIso8601String(),
        'balanceAfter': balanceAfter,
      };
}

class UserWalletDto {
  final int balanceVnd;
  final bool isVip;
  final DateTime? vipExpiresAt;
  final List<WalletTransactionDto> transactions;

  const UserWalletDto({
    required this.balanceVnd,
    this.isVip = false,
    this.vipExpiresAt,
    this.transactions = const [],
  });

  /// Getter tương thích ngược cho ForgeCoins
  int get balanceCoins => balanceVnd ~/ 100;

  factory UserWalletDto.fromJson(Map<String, dynamic> json) {
    int balance;
    if (json['balanceVnd'] != null) {
      balance = (json['balanceVnd'] as num).toInt();
    } else if (json['balanceCoins'] != null) {
      balance = (json['balanceCoins'] as num).toInt() * 100;
    } else {
      balance = 50000;
    }

    final rawTx = json['transactions'] as List<dynamic>? ?? [];
    final txList = rawTx
        .map((e) => WalletTransactionDto.fromJson(e as Map<String, dynamic>))
        .toList();

    return UserWalletDto(
      balanceVnd: balance,
      isVip: json['isVip'] as bool? ?? false,
      vipExpiresAt: json['vipExpiresAt'] != null
          ? DateTime.tryParse(json['vipExpiresAt'].toString())
          : null,
      transactions: txList,
    );
  }

  Map<String, dynamic> toJson() => {
        'balanceVnd': balanceVnd,
        'balanceCoins': balanceCoins,
        'isVip': isVip,
        if (vipExpiresAt != null) 'vipExpiresAt': vipExpiresAt!.toIso8601String(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };
}

class UnlockChapterRequest {
  final String chapterId;
  final int? priceVnd;
  final String? seriesId;
  final bool isPermanent;
  final int? rentalViews;

  const UnlockChapterRequest({
    required this.chapterId,
    this.priceVnd,
    this.seriesId,
    this.isPermanent = true,
    this.rentalViews,
  });

  factory UnlockChapterRequest.fromJson(Map<String, dynamic> json) {
    return UnlockChapterRequest(
      chapterId: json['chapterId']?.toString() ?? '',
      priceVnd: (json['priceVnd'] as num?)?.toInt(),
      seriesId: json['seriesId']?.toString(),
      isPermanent: json['isPermanent'] as bool? ?? true,
      rentalViews: (json['rentalViews'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'chapterId': chapterId,
        if (priceVnd != null) 'priceVnd': priceVnd,
        if (seriesId != null) 'seriesId': seriesId,
        'isPermanent': isPermanent,
        if (rentalViews != null) 'rentalViews': rentalViews,
      };
}

class UnlockChapterResponse {
  final String chapterId;
  final bool success;
  final int remainingCoins;
  final int remainingBalanceVnd;
  final String? cbzDownloadUrl;
  final String? message;
  final bool isPermanent;
  final int? remainingViews;

  const UnlockChapterResponse({
    required this.chapterId,
    required this.success,
    required this.remainingCoins,
    required this.remainingBalanceVnd,
    this.cbzDownloadUrl,
    this.message,
    this.isPermanent = true,
    this.remainingViews,
  });

  factory UnlockChapterResponse.fromJson(Map<String, dynamic> json) {
    final remVnd = (json['remainingBalanceVnd'] as num?)?.toInt() ??
        ((json['remainingCoins'] as num?)?.toInt() != null
            ? (json['remainingCoins'] as num).toInt() * 100
            : 0);
    final remCoins = (json['remainingCoins'] as num?)?.toInt() ?? (remVnd ~/ 100);

    return UnlockChapterResponse(
      chapterId: json['chapterId']?.toString() ?? '',
      success: json['success'] as bool? ?? false,
      remainingCoins: remCoins,
      remainingBalanceVnd: remVnd,
      cbzDownloadUrl: json['cbzDownloadUrl']?.toString() ?? json['cbzPackageUrl']?.toString(),
      message: json['message']?.toString(),
      isPermanent: json['isPermanent'] as bool? ?? true,
      remainingViews: (json['remainingViews'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'chapterId': chapterId,
        'success': success,
        'remainingCoins': remainingCoins,
        'remainingBalanceVnd': remainingBalanceVnd,
        if (cbzDownloadUrl != null) 'cbzDownloadUrl': cbzDownloadUrl,
        if (message != null) 'message': message,
        'isPermanent': isPermanent,
        if (remainingViews != null) 'remainingViews': remainingViews,
      };

  String? get fullCbzDownloadUrl =>
      cbzDownloadUrl != null ? ApiConfig.resolveUrl(cbzDownloadUrl!) : null;
}

class SubscribeVipRequest {
  final String plan; // 'monthly' | 'yearly'

  const SubscribeVipRequest({required this.plan});

  factory SubscribeVipRequest.fromJson(Map<String, dynamic> json) {
    return SubscribeVipRequest(
      plan: json['plan']?.toString() ?? 'monthly',
    );
  }

  Map<String, dynamic> toJson() => {'plan': plan};
}

class SubscribeVipResponse {
  final bool success;
  final bool isVip;
  final DateTime? vipExpiresAt;
  final int remainingCoins;
  final String? message;

  const SubscribeVipResponse({
    required this.success,
    required this.isVip,
    this.vipExpiresAt,
    required this.remainingCoins,
    this.message,
  });

  factory SubscribeVipResponse.fromJson(Map<String, dynamic> json) {
    return SubscribeVipResponse(
      success: json['success'] as bool? ?? false,
      isVip: json['isVip'] as bool? ?? false,
      vipExpiresAt: json['vipExpiresAt'] != null
          ? DateTime.tryParse(json['vipExpiresAt'].toString())
          : null,
      remainingCoins: (json['remainingCoins'] as num?)?.toInt() ?? 0,
      message: json['message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'isVip': isVip,
        if (vipExpiresAt != null) 'vipExpiresAt': vipExpiresAt!.toIso8601String(),
        'remainingCoins': remainingCoins,
        if (message != null) 'message': message,
      };
}

class TopupRequest {
  final int coinsAmount;
  final int amountVnd;
  final String paymentMethod; // 'vietqr' | 'momo' | 'bank'

  const TopupRequest({
    required this.coinsAmount,
    required this.amountVnd,
    this.paymentMethod = 'vietqr',
  });

  factory TopupRequest.fromJson(Map<String, dynamic> json) {
    return TopupRequest(
      coinsAmount: (json['coinsAmount'] as num?)?.toInt() ?? 0,
      amountVnd: (json['amountVnd'] as num?)?.toInt() ?? 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'vietqr',
    );
  }

  Map<String, dynamic> toJson() => {
        'coinsAmount': coinsAmount,
        'amountVnd': amountVnd,
        'paymentMethod': paymentMethod,
      };
}

class TopupResponse {
  final String orderId;
  final int coins;
  final int amountVnd;
  final String? qrCodeUrl;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final String? transferContent;
  final bool isCompleted;

  const TopupResponse({
    required this.orderId,
    required this.coins,
    required this.amountVnd,
    this.qrCodeUrl,
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.transferContent,
    this.isCompleted = false,
  });

  factory TopupResponse.fromJson(Map<String, dynamic> json) {
    return TopupResponse(
      orderId: json['orderId']?.toString() ?? '',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      amountVnd: (json['amountVnd'] as num?)?.toInt() ?? 0,
      qrCodeUrl: json['qrCodeUrl']?.toString(),
      bankName: json['bankName']?.toString() ?? 'Vietcombank',
      accountNumber: json['accountNumber']?.toString() ?? '9876543210',
      accountName: json['accountName']?.toString() ?? 'PANELFORGE COMICS',
      transferContent: json['transferContent']?.toString() ?? 'PFCOINS ${json['orderId'] ?? ''}',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'coins': coins,
        'amountVnd': amountVnd,
        if (qrCodeUrl != null) 'qrCodeUrl': qrCodeUrl,
        if (bankName != null) 'bankName': bankName,
        if (accountNumber != null) 'accountNumber': accountNumber,
        if (accountName != null) 'accountName': accountName,
        if (transferContent != null) 'transferContent': transferContent,
        'isCompleted': isCompleted,
      };
}

