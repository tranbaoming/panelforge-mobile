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
  final bool isFree;
  final bool isUnlocked;
  final int priceCoins;
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
    this.cbzPackageUrl,
    this.manifestUrl,
  });

  factory PublicChapterSummaryDto.fromJson(Map<String, dynamic> json) {
    final free = json['isFree'] as bool? ?? true;
    return PublicChapterSummaryDto(
      id: json['id']?.toString() ?? '',
      chapterNumber: (json['chapterNumber'] as num?)?.toDouble() ?? 1.0,
      title: json['title']?.toString(),
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : null,
      isFree: free,
      isUnlocked: json['isUnlocked'] as bool? ?? free,
      priceCoins: (json['priceCoins'] as num?)?.toInt() ?? 0,
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
  final bool isFree;
  final bool isUnlocked;
  final int priceCoins;
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
    this.cbzPackageUrl,
    this.manifestUrl,
  });

  factory PublicChapterReadDto.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'] as List<dynamic>? ?? [];
    final free = json['isFree'] as bool? ?? true;
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
      isFree: free,
      isUnlocked: json['isUnlocked'] as bool? ?? free,
      priceCoins: (json['priceCoins'] as num?)?.toInt() ?? 0,
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

class UserWalletDto {
  final int balanceCoins;
  final bool isVip;
  final DateTime? vipExpiresAt;

  const UserWalletDto({
    required this.balanceCoins,
    this.isVip = false,
    this.vipExpiresAt,
  });

  factory UserWalletDto.fromJson(Map<String, dynamic> json) {
    return UserWalletDto(
      balanceCoins: (json['balanceCoins'] as num?)?.toInt() ?? 0,
      isVip: json['isVip'] as bool? ?? false,
      vipExpiresAt: json['vipExpiresAt'] != null
          ? DateTime.tryParse(json['vipExpiresAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'balanceCoins': balanceCoins,
        'isVip': isVip,
        if (vipExpiresAt != null) 'vipExpiresAt': vipExpiresAt!.toIso8601String(),
      };
}

class UnlockChapterRequest {
  final String chapterId;

  const UnlockChapterRequest({required this.chapterId});

  factory UnlockChapterRequest.fromJson(Map<String, dynamic> json) {
    return UnlockChapterRequest(
      chapterId: json['chapterId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'chapterId': chapterId,
      };
}

class UnlockChapterResponse {
  final String chapterId;
  final bool success;
  final int remainingCoins;
  final String? cbzDownloadUrl;
  final String? message;

  const UnlockChapterResponse({
    required this.chapterId,
    required this.success,
    required this.remainingCoins,
    this.cbzDownloadUrl,
    this.message,
  });

  factory UnlockChapterResponse.fromJson(Map<String, dynamic> json) {
    return UnlockChapterResponse(
      chapterId: json['chapterId']?.toString() ?? '',
      success: json['success'] as bool? ?? false,
      remainingCoins: (json['remainingCoins'] as num?)?.toInt() ?? 0,
      cbzDownloadUrl: json['cbzDownloadUrl']?.toString() ?? json['cbzPackageUrl']?.toString(),
      message: json['message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'chapterId': chapterId,
        'success': success,
        'remainingCoins': remainingCoins,
        if (cbzDownloadUrl != null) 'cbzDownloadUrl': cbzDownloadUrl,
        if (message != null) 'message': message,
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

