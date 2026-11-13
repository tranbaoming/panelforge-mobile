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
      lastOpenedAt: json['lastOpenedAt'] != null ? DateTime.tryParse(json['lastOpenedAt'].toString()) : null,
      unlockedAt: json['unlockedAt'] != null ? DateTime.tryParse(json['unlockedAt'].toString()) : null,
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

  const ConsumeViewResult({required this.didConsume, this.isPermanent = false, this.remainingViews, this.message});
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

  /// Ảnh bìa bộ truyện (đường dẫn tương đối /api/catalog/series/{id}/cover?v=…); null = chưa có bìa.
  final String? coverUrl;
  final bool isCompleted;
  final DateTime? createdAt;
  /// Lượt đọc thật (bảng chapter_views): tổng và trong 1 / 7 / 30 ngày gần nhất.
  final int viewCount;
  final int viewsLast1Day;
  final int viewsLast7Days;
  final int viewsLast30Days;

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
    this.coverUrl,
    this.isCompleted = false,
    this.createdAt,
    this.viewCount = 0,
    this.viewsLast1Day = 0,
    this.viewsLast7Days = 0,
    this.viewsLast30Days = 0,
  });

  String? get fullCoverUrl => coverUrl != null && coverUrl!.isNotEmpty ? ApiConfig.resolveUrl(coverUrl!) : null;

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
      baseChapterPriceVnd: (json['baseChapterPriceVnd'] as num?)?.toInt() ?? defaultBase,
      hotChapterPriceVnd: (json['hotChapterPriceVnd'] as num?)?.toInt() ?? 5000,
      coverUrl: json['coverUrl']?.toString(),
      isCompleted: json['isCompleted'] == true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      viewsLast1Day: (json['viewsLast1Day'] as num?)?.toInt() ?? 0,
      viewsLast7Days: (json['viewsLast7Days'] as num?)?.toInt() ?? 0,
      viewsLast30Days: (json['viewsLast30Days'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Ngôn ngữ bản phát hành: vi = bản gốc Studio; en/ja = bản dịch (Publisher upload ảnh từng trang).
/// Mua chương/trang theo từng ngôn ngữ.
const List<String> kContentLanguages = ['vi', 'en', 'ja'];

String contentLanguageLabel(String code) => switch (code) {
  'en' => 'English',
  'ja' => '日本語',
  _ => 'Tiếng Việt',
};

/// Một bản ngôn ngữ đã phát hành của chương (`PublicChapterLanguageDto`).
class ChapterLanguageOption {
  final String language;

  /// Giá mở khóa chương trả phí ở ngôn ngữ này (0 với chương miễn phí).
  final int priceVnd;

  /// Người đọc đã có quyền đọc bản này.
  final bool isUnlocked;

  const ChapterLanguageOption({required this.language, this.priceVnd = 0, this.isUnlocked = true});

  factory ChapterLanguageOption.fromJson(Map<String, dynamic> json) => ChapterLanguageOption(
    language: json['language']?.toString() ?? 'vi',
    priceVnd: (json['priceVnd'] as num?)?.toInt() ?? 0,
    isUnlocked: json['isUnlocked'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {'language': language, 'priceVnd': priceVnd, 'isUnlocked': isUnlocked};

  static List<ChapterLanguageOption> listFromJson(dynamic raw) =>
      (raw as List<dynamic>? ?? const []).map((e) => ChapterLanguageOption.fromJson(e as Map<String, dynamic>)).toList();
}

class PublicChapterSummaryDto {
  final String id;
  final double chapterNumber;
  final String? title;
  final DateTime? publishedAt;
  final bool isLocked;
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

  /// Các bản ngôn ngữ đã phát hành (giá + trạng thái mở khóa theo từng bản).
  final List<ChapterLanguageOption> languages;

  PublicChapterSummaryDto({
    required this.id,
    required this.chapterNumber,
    this.title,
    this.publishedAt,
    this.isLocked = false,
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
    this.languages = const [],
  });

  /// Đọc trạng thái khóa trực tiếp từ `GET /api/catalog/series/{id}` (PublicChapterDto):
  /// `isLocked`, `priceVnd`, `isUnlocked` (server đã tính VIP + quyền sở hữu), `isFree`.
  /// Không tự suy diễn giá ở client — giá mở khóa luôn do Producer cấu hình trên Backend.
  factory PublicChapterSummaryDto.fromJson(Map<String, dynamic> json) {
    final numVal = (json['chapterNumber'] as num?)?.toDouble() ?? 1.0;
    final isLocked = json['isLocked'] as bool? ?? false;
    final free = !isLocked;
    final priceVnd = free ? 0 : ((json['priceVnd'] as num?)?.toInt() ?? 0);

    DateTime? pubAt;
    if (json['publishedAt'] != null) {
      pubAt = DateTime.tryParse(json['publishedAt'].toString());
    }
    final bool isHot =
        (json['isWeeklyHot'] as bool?) ?? (pubAt != null && DateTime.now().difference(pubAt).inDays <= 7 && !free);

    return PublicChapterSummaryDto(
      id: json['id']?.toString() ?? '',
      chapterNumber: numVal,
      title: json['title']?.toString(),
      publishedAt: pubAt,
      isLocked: isLocked,
      isFree: free,
      isUnlocked: json['isUnlocked'] as bool? ?? free,
      priceCoins: priceVnd ~/ 100,
      priceVnd: priceVnd,
      rentalPriceVnd: 0,
      accessPolicy: free ? ChapterAccessPolicy.free : ChapterAccessPolicy.permanent,
      maxAllowedViews: null,
      isWeeklyHot: isHot,
      cbzPackageUrl: json['cbzPackageUrl']?.toString(),
      manifestUrl: json['manifestUrl']?.toString(),
      languages: ChapterLanguageOption.listFromJson(json['languages']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'chapterNumber': chapterNumber,
    if (title != null) 'title': title,
    if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
    'isLocked': isLocked,
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

  String? get fullCbzPackageUrl => cbzPackageUrl != null ? ApiConfig.resolveUrl(cbzPackageUrl!) : null;

  String? get fullManifestUrl => manifestUrl != null ? ApiConfig.resolveUrl(manifestUrl!) : null;

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

  /// Ảnh bìa bộ truyện (đường dẫn tương đối /api/catalog/series/{id}/cover?v=…); null = chưa có bìa.
  final String? coverUrl;
  final bool isCompleted;
  final DateTime? createdAt;
  /// Lượt đọc thật (bảng chapter_views).
  final int viewCount;

  /// Đánh giá 1–5 sao của độc giả.
  final double ratingAverage;
  final int ratingCount;

  /// Đánh giá của người đang đăng nhập (null nếu chưa đánh giá).
  final int? myRating;

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
    this.coverUrl,
    this.isCompleted = false,
    this.createdAt,
    this.viewCount = 0,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.myRating,
  });

  String? get fullCoverUrl => coverUrl != null && coverUrl!.isNotEmpty ? ApiConfig.resolveUrl(coverUrl!) : null;

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
      baseChapterPriceVnd: (json['baseChapterPriceVnd'] as num?)?.toInt() ?? defaultBase,
      hotChapterPriceVnd: (json['hotChapterPriceVnd'] as num?)?.toInt() ?? 5000,
      chapters: rawChapters.map((e) => PublicChapterSummaryDto.fromJson(e as Map<String, dynamic>)).toList(),
      coverUrl: json['coverUrl']?.toString(),
      isCompleted: json['isCompleted'] == true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      ratingAverage: (json['ratingAverage'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      myRating: (json['myRating'] as num?)?.toInt(),
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class PublicPageDto {
  final String id;
  final int pageNumber;
  final String? relativeImageUrl;

  /// Trang nằm sau paywall: thuộc chương trả phí và không phải trang xem trước.
  final bool isLocked;

  /// Người đọc đã được xem trang (trang xem trước, đã mua chương, VIP, staff). Khi false server không trả ảnh
  /// ([relativeImageUrl] = null) và endpoint ảnh trả 403 — client chỉ hiển thị lớp làm mờ + nút mở khóa chương.
  final bool isUnlocked;

  /// Trang xem trước của chương trả phí (ai cũng xem được, Publisher chọn trên web).
  final bool isPreview;

  PublicPageDto({
    required this.id,
    required this.pageNumber,
    this.relativeImageUrl,
    this.isLocked = false,
    this.isUnlocked = true,
    this.isPreview = false,
  });

  /// Trang đang bị khóa với người đọc hiện tại.
  bool get isPaywalled => isLocked && !isUnlocked;

  factory PublicPageDto.fromJson(Map<String, dynamic> json) {
    return PublicPageDto(
      id: json['id']?.toString() ?? '',
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      relativeImageUrl: json['imageUrl']?.toString(),
      isLocked: json['isLocked'] as bool? ?? false,
      isUnlocked: json['isUnlocked'] as bool? ?? true,
      isPreview: json['isPreview'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pageNumber': pageNumber,
    'imageUrl': relativeImageUrl,
    'isLocked': isLocked,
    'isUnlocked': isUnlocked,
    'isPreview': isPreview,
  };

  String? get fullImageUrl => relativeImageUrl != null ? ApiConfig.resolveUrl(relativeImageUrl) : null;
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

  /// Bản ngôn ngữ của nội dung trả về.
  final String language;

  /// Các bản ngôn ngữ đã phát hành của chương.
  final List<ChapterLanguageOption> languages;

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
    this.language = 'vi',
    this.languages = const [],
  });

  factory PublicChapterReadDto.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>? ?? [];
    final numVal = (json['chapterNumber'] as num?)?.toDouble() ?? 1.0;
    // Trạng thái khóa & giá lấy nguyên từ Backend (PublicChapterReadDto: IsLocked, PriceVnd, IsUnlocked, IsFree).
    final free = !(json['isLocked'] as bool? ?? false);

    DateTime? pubAt;
    if (json['publishedAt'] != null) {
      pubAt = DateTime.tryParse(json['publishedAt'].toString());
    }

    final bool isHot =
        (json['isWeeklyHot'] as bool?) ?? (pubAt != null && DateTime.now().difference(pubAt).inDays <= 7 && !free);

    final priceVnd = free ? 0 : ((json['priceVnd'] as num?)?.toInt() ?? 0);
    const rentalPriceVnd = 0;
    final coins = priceVnd ~/ 100;
    final policy = free ? ChapterAccessPolicy.free : ChapterAccessPolicy.permanent;
    const int? maxViews = null;

    return PublicChapterReadDto(
      id: json['id']?.toString() ?? '',
      seriesId: json['seriesId']?.toString() ?? '',
      seriesTitle: json['seriesTitle']?.toString() ?? '',
      readingDirection: ApiReadingDirection.fromDynamic(json['readingDirection']),
      chapterNumber: numVal,
      title: json['title']?.toString(),
      publishedAt: pubAt,
      pages: rawPages.map((e) => PublicPageDto.fromJson(e as Map<String, dynamic>)).toList(),
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
      language: json['language']?.toString() ?? 'vi',
      languages: ChapterLanguageOption.listFromJson(json['languages']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'seriesId': seriesId,
    'seriesTitle': seriesTitle,
    'language': language,
    'languages': languages.map((l) => l.toJson()).toList(),
    'readingDirection': readingDirection.apiValue,
    'chapterNumber': chapterNumber,
    if (title != null) 'title': title,
    if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
    'pages': pages.map((p) => p.toJson()).toList(),
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

  String? get fullCbzPackageUrl => cbzPackageUrl != null ? ApiConfig.resolveUrl(cbzPackageUrl!) : null;

  String? get fullManifestUrl => manifestUrl != null ? ApiConfig.resolveUrl(manifestUrl!) : null;

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
      items: rawItems.map((e) => PublicSeriesDto.fromJson(e as Map<String, dynamic>)).toList(),
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
      panels: rawPanels.map((e) => PreviewPanelDto.fromJson(e as Map<String, dynamic>)).toList(),
      textRegions: rawTextRegions.map((e) => TextRegion.fromJson(e as Map<String, dynamic>)).toList(),
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
      pages: rawPages.map((e) => PreviewPageDto.fromJson(e as Map<String, dynamic>)).toList(),
      cbzPackageUrl: json['cbzPackageUrl']?.toString(),
      manifestUrl: json['manifestUrl']?.toString(),
      panels: rawPanels.map((e) => PanelInfo.fromJson(e as Map<String, dynamic>)).toList(),
      textRegions: rawTextRegions.map((e) => TextRegion.fromJson(e as Map<String, dynamic>)).toList(),
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
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
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

  /// Chương đã mở khóa vĩnh viễn trên server (ChapterEntitlement).
  final Set<String> unlockedChapterIds;

  const UserWalletDto({
    required this.balanceVnd,
    this.isVip = false,
    this.vipExpiresAt,
    this.transactions = const [],
    this.unlockedChapterIds = const {},
  });

  /// Getter tương thích ngược cho ForgeCoins
  int get balanceCoins => balanceVnd ~/ 100;

  /// VIP còn hiệu lực (server có thể chưa kịp tắt cờ khi hết hạn).
  bool get hasActiveVip => isVip && (vipExpiresAt == null || vipExpiresAt!.isAfter(DateTime.now()));

  /// `GET /api/wallet/me` → UserWalletDto(BalanceVnd, BalanceCoins, IsVip, VipExpiresAt, UnlockedChapterIds, Transactions)
  factory UserWalletDto.fromJson(Map<String, dynamic> json) {
    final balance = (json['balanceVnd'] as num?)?.toInt() ?? (((json['balanceCoins'] as num?)?.toInt() ?? 0) * 100);

    final rawTx = json['transactions'] as List<dynamic>? ?? [];
    final rawUnlocked = json['unlockedChapterIds'] as List<dynamic>? ?? [];

    return UserWalletDto(
      balanceVnd: balance,
      isVip: json['isVip'] as bool? ?? false,
      vipExpiresAt: json['vipExpiresAt'] != null ? DateTime.tryParse(json['vipExpiresAt'].toString()) : null,
      transactions: rawTx.map((e) => WalletTransactionDto.fromJson(e as Map<String, dynamic>)).toList(),
      unlockedChapterIds: rawUnlocked.map((e) => e.toString()).toSet(),
    );
  }

  UserWalletDto copyWith({
    int? balanceVnd,
    bool? isVip,
    DateTime? vipExpiresAt,
    List<WalletTransactionDto>? transactions,
    Set<String>? unlockedChapterIds,
  }) {
    return UserWalletDto(
      balanceVnd: balanceVnd ?? this.balanceVnd,
      isVip: isVip ?? this.isVip,
      vipExpiresAt: vipExpiresAt ?? this.vipExpiresAt,
      transactions: transactions ?? this.transactions,
      unlockedChapterIds: unlockedChapterIds ?? this.unlockedChapterIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'balanceVnd': balanceVnd,
    'balanceCoins': balanceCoins,
    'isVip': isVip,
    if (vipExpiresAt != null) 'vipExpiresAt': vipExpiresAt!.toIso8601String(),
    'transactions': transactions.map((t) => t.toJson()).toList(),
    'unlockedChapterIds': unlockedChapterIds.toList(),
  };
}

class UnlockChapterRequest {
  final String chapterId;
  final int? priceVnd;
  final String? seriesId;
  final bool isPermanent;
  final int? rentalViews;

  /// Bản ngôn ngữ mua (mua theo từng ngôn ngữ).
  final String? language;

  const UnlockChapterRequest({
    required this.chapterId,
    this.priceVnd,
    this.seriesId,
    this.isPermanent = true,
    this.rentalViews,
    this.language,
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
    if (language != null) 'language': language,
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
    final remVnd =
        (json['remainingBalanceVnd'] as num?)?.toInt() ??
        ((json['remainingCoins'] as num?)?.toInt() != null ? (json['remainingCoins'] as num).toInt() * 100 : 0);
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

  String? get fullCbzDownloadUrl => cbzDownloadUrl != null ? ApiConfig.resolveUrl(cbzDownloadUrl!) : null;
}

class SubscribeVipRequest {
  final String plan; // 'monthly' | 'yearly'

  const SubscribeVipRequest({required this.plan});

  factory SubscribeVipRequest.fromJson(Map<String, dynamic> json) {
    return SubscribeVipRequest(plan: json['plan']?.toString() ?? 'monthly');
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
      vipExpiresAt: json['vipExpiresAt'] != null ? DateTime.tryParse(json['vipExpiresAt'].toString()) : null,
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

/// Mục đích của đơn VietQR — khớp `TopupRequest.Purpose` / `PaymentTransactionType` trên Backend.
enum PaymentPurpose {
  topup('Topup'),
  chapterUnlock('ChapterUnlock'),
  vipSubscription('VipSubscription');

  final String value;
  const PaymentPurpose(this.value);
}

/// `POST /api/wallet/topup` — tạo đơn chuyển khoản VietQR ở trạng thái Pending.
/// Ngữ cảnh (series/chapter/workspace) giúp đơn hiển thị đúng Studio trên màn hình Thanh toán của Producer.
/// Với [PaymentPurpose.chapterUnlock] / [PaymentPurpose.vipSubscription], số tiền do server quyết định.
class TopupRequest {
  final int? amountVnd;
  final String paymentMethod;
  final PaymentPurpose purpose;
  final String? workspaceId;
  final String? seriesId;
  final String? chapterId;
  final String? vipPlan;

  /// Bản ngôn ngữ mua khi trả VietQR trực tiếp để mở chương.
  final String? language;

  const TopupRequest({
    this.amountVnd,
    this.paymentMethod = 'vietqr',
    this.purpose = PaymentPurpose.topup,
    this.workspaceId,
    this.seriesId,
    this.chapterId,
    this.language,
    this.vipPlan,
  });

  Map<String, dynamic> toJson() => {
    if (amountVnd != null) 'amountVnd': amountVnd,
    'paymentMethod': paymentMethod,
    'purpose': purpose.value,
    if (workspaceId != null) 'workspaceId': workspaceId,
    if (seriesId != null) 'seriesId': seriesId,
    if (chapterId != null) 'chapterId': chapterId,
    if (language != null) 'language': language,
    if (vipPlan != null) 'vipPlan': vipPlan,
  };
}

/// Đơn VietQR do Backend sinh: mã đơn PFxxxxxx, ảnh QR (img.vietqr.io) và tài khoản thụ hưởng thật của Studio.
class TopupResponse {
  /// Mã đơn (vd: PF123456) — đồng thời là nội dung chuyển khoản bắt buộc.
  final String orderId;
  final int coins;
  final int amountVnd;
  final String? qrCodeUrl;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final String? transferContent;
  final bool isCompleted;
  final String purpose;
  final String status;

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
    this.purpose = 'Topup',
    this.status = 'Pending',
  });

  String get orderCode => orderId;

  /// Nội dung CK bắt buộc — trùng `addInfo` trong ảnh VietQR.
  String get requiredTransferContent =>
      (transferContent != null && transferContent!.trim().isNotEmpty) ? transferContent! : orderId;

  factory TopupResponse.fromJson(Map<String, dynamic> json) {
    return TopupResponse(
      orderId: json['orderId']?.toString() ?? '',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      amountVnd: (json['amountVnd'] as num?)?.toInt() ?? 0,
      qrCodeUrl: json['qrCodeUrl']?.toString(),
      bankName: json['bankName']?.toString(),
      accountNumber: json['accountNumber']?.toString(),
      accountName: json['accountName']?.toString(),
      transferContent: json['transferContent']?.toString(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      purpose: json['purpose']?.toString() ?? 'Topup',
      status: json['status']?.toString() ?? 'Pending',
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
    'purpose': purpose,
    'status': status,
  };
}

/// `GET /api/wallet/transactions/{orderCode}/status` — Mobile polling chờ Producer duyệt.
class TransactionStatusDto {
  final String orderCode;

  /// Pending | Approved | Rejected | Expired
  final String status;
  final bool isCompleted;
  final int amountVnd;
  final DateTime? confirmedAt;
  final String? rejectionReason;

  const TransactionStatusDto({
    required this.orderCode,
    required this.status,
    required this.isCompleted,
    required this.amountVnd,
    this.confirmedAt,
    this.rejectionReason,
  });

  bool get isPending => status == 'Pending';
  bool get isApproved => status == 'Approved' || isCompleted;
  bool get isRejected => status == 'Rejected';
  bool get isExpired => status == 'Expired';

  factory TransactionStatusDto.fromJson(Map<String, dynamic> json) {
    return TransactionStatusDto(
      orderCode: json['orderCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      isCompleted: json['isCompleted'] as bool? ?? false,
      amountVnd: (json['amountVnd'] as num?)?.toInt() ?? 0,
      confirmedAt: json['confirmedAt'] != null ? DateTime.tryParse(json['confirmedAt'].toString()) : null,
      rejectionReason: json['rejectionReason']?.toString(),
    );
  }
}

