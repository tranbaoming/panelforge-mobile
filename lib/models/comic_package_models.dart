import 'dart:convert';

/// Khung toạ độ chuẩn hoá (0.0 đến 1.0) độc lập với kích thước và độ phân giải màn hình.
class NormalizedBounds {
  final double x;
  final double y;
  final double w;
  final double h;

  const NormalizedBounds({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory NormalizedBounds.fromJson(Map<String, dynamic> json) {
    return NormalizedBounds(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      w: (json['w'] as num?)?.toDouble() ?? 1.0,
      h: (json['h'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Phân tích linh hoạt từ Map hoặc chuỗi (JSON hoặc "x,y,w,h")
  static NormalizedBounds? tryParse(dynamic val) {
    if (val == null) return null;
    if (val is NormalizedBounds) return val;
    if (val is Map<String, dynamic>) {
      return NormalizedBounds.fromJson(val);
    }
    if (val is String) {
      final trimmed = val.trim();
      if (trimmed.isEmpty || trimmed == '{}' || trimmed == '[]') return null;
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) {
            return NormalizedBounds.fromJson(decoded);
          }
        } catch (_) {}
      }
      final parts = trimmed.split(',').map((p) => double.tryParse(p.trim())).toList();
      if (parts.length == 4 && parts.every((p) => p != null)) {
        return NormalizedBounds(
          x: parts[0]!,
          y: parts[1]!,
          w: parts[2]!,
          h: parts[3]!,
        );
      }
    }
    return null;
  }

  /// Kiểm tra xem điểm chuẩn hóa (px, py) có nằm trong khung này không
  bool containsPoint(double px, double py) {
    return px >= x && px <= (x + w) && py >= y && py <= (y + h);
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'w': w,
        'h': h,
      };

  NormalizedBounds copyWith({
    double? x,
    double? y,
    double? w,
    double? h,
  }) {
    return NormalizedBounds(
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
    );
  }

  @override
  String toString() => 'NormalizedBounds(x: $x, y: $y, w: $w, h: $h)';
}

/// Thông tin khung tranh (Panel) ánh xạ từ `metadata/panels.json`.
class PanelInfo {
  final String id;
  final int pageIndex;
  final int readingOrder;
  final NormalizedBounds bounds;

  const PanelInfo({
    required this.id,
    required this.pageIndex,
    required this.readingOrder,
    required this.bounds,
  });

  factory PanelInfo.fromJson(Map<String, dynamic> json) {
    return PanelInfo(
      id: json['id']?.toString() ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      readingOrder: (json['readingOrder'] as num?)?.toInt() ?? 0,
      bounds: json['bounds'] is Map<String, dynamic>
          ? NormalizedBounds.fromJson(json['bounds'] as Map<String, dynamic>)
          : const NormalizedBounds(x: 0, y: 0, w: 1, h: 1),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pageIndex': pageIndex,
        'readingOrder': readingOrder,
        'bounds': bounds.toJson(),
      };

  @override
  String toString() => 'PanelInfo(id: $id, page: $pageIndex, order: $readingOrder)';
}

/// Vùng văn bản (bóng thoại, suy nghĩ, thuyết minh) ánh xạ từ `metadata/text-regions.json`.
class TextRegion {
  final String id;
  final int pageIndex;
  final NormalizedBounds bounds;
  final String type; // 'speech', 'thought', 'narration', 'sfx'

  const TextRegion({
    required this.id,
    required this.pageIndex,
    required this.bounds,
    this.type = 'speech',
  });

  factory TextRegion.fromJson(Map<String, dynamic> json) {
    return TextRegion(
      id: json['id']?.toString() ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      bounds: json['bounds'] is Map<String, dynamic>
          ? NormalizedBounds.fromJson(json['bounds'] as Map<String, dynamic>)
          : const NormalizedBounds(x: 0, y: 0, w: 1, h: 1),
      type: json['type']?.toString() ?? 'speech',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pageIndex': pageIndex,
        'bounds': bounds.toJson(),
        'type': type,
      };

  @override
  String toString() => 'TextRegion(id: $id, page: $pageIndex, type: $type)';
}

/// Bản dịch của một vùng văn bản, ánh xạ từ `metadata/translations/{vi,en,ja}.json`.
class TranslationEntry {
  final String regionId;
  final String text;
  final String? furiganaOrNote;
  final String? ttsText;

  const TranslationEntry({
    required this.regionId,
    required this.text,
    this.furiganaOrNote,
    this.ttsText,
  });

  factory TranslationEntry.fromJson(Map<String, dynamic> json) {
    return TranslationEntry(
      regionId: json['regionId']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      furiganaOrNote: json['furiganaOrNote']?.toString() ?? json['note']?.toString(),
      ttsText: json['ttsText']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'regionId': regionId,
        'text': text,
        if (furiganaOrNote != null) 'furiganaOrNote': furiganaOrNote,
        if (ttsText != null) 'ttsText': ttsText,
      };

  @override
  String toString() => 'TranslationEntry(regionId: $regionId, text: $text)';
}

/// Manifest gói truyện, ánh xạ từ `manifest.json`.
class ComicManifest {
  final String version;
  final String seriesId;
  final String chapterId;
  final String readingDirection; // "RTL", "LTR", "VERTICAL"
  final List<String> pageFiles; // VD: ["001.webp", "002.webp"]
  final double webtoonTileSpacing;

  const ComicManifest({
    this.version = '1.0',
    required this.seriesId,
    required this.chapterId,
    this.readingDirection = 'LTR',
    this.pageFiles = const [],
    this.webtoonTileSpacing = 0.0,
  });

  factory ComicManifest.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pageFiles'] as List<dynamic>? ?? [];
    return ComicManifest(
      version: json['version']?.toString() ?? '1.0',
      seriesId: json['seriesId']?.toString() ?? '',
      chapterId: json['chapterId']?.toString() ?? '',
      readingDirection: json['readingDirection']?.toString().toUpperCase() ?? 'LTR',
      pageFiles: rawPages.map((e) => e.toString()).toList(),
      webtoonTileSpacing: (json['webtoonTileSpacing'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'seriesId': seriesId,
        'chapterId': chapterId,
        'readingDirection': readingDirection,
        'pageFiles': pageFiles,
        'webtoonTileSpacing': webtoonTileSpacing,
      };

  String toJsonString() => jsonEncode(toJson());

  @override
  String toString() => 'ComicManifest(v: $version, chapter: $chapterId, pages: ${pageFiles.length})';
}

/// Thực thể đại diện cho một gói truyện hoàn chỉnh đã được giải nén và nạp vào bộ nhớ.
class LoadedComicPackage {
  final ComicManifest manifest;
  final List<PanelInfo> panels;
  final List<TextRegion> textRegions;
  /// Ngôn ngữ -> regionId -> TranslationEntry (VD: {"vi": {"reg_1": ...}, "en": ...})
  final Map<String, Map<String, TranslationEntry>> translations;
  /// Đường dẫn thư mục cục bộ lưu trữ các file .webp và metadata đã giải nén
  final String localDirectoryPath;

  const LoadedComicPackage({
    required this.manifest,
    this.panels = const [],
    this.textRegions = const [],
    this.translations = const {},
    required this.localDirectoryPath,
  });

  /// Danh sách các mã ngôn ngữ có sẵn trong gói truyện (VD: ['vi', 'en', 'ja'])
  List<String> get availableLanguages => translations.keys.toList();

  /// Lấy toàn bộ panels thuộc về một trang cụ thể (0-based) sắp xếp theo thứ tự đọc
  List<PanelInfo> getPanelsForPage(int pageIndex) {
    final result = panels.where((p) => p.pageIndex == pageIndex).toList();
    result.sort((a, b) => a.readingOrder.compareTo(b.readingOrder));
    return result;
  }

  /// Lấy toàn bộ vùng văn bản (bóng thoại, text region) của một trang cụ thể (0-based)
  List<TextRegion> getTextRegionsForPage(int pageIndex) {
    return textRegions.where((r) => r.pageIndex == pageIndex).toList();
  }

  /// Lấy bản dịch cho một vùng văn bản theo ngôn ngữ chỉ định
  TranslationEntry? getTranslation(String languageCode, String regionId) {
    final langMap = translations[languageCode.toLowerCase()];
    if (langMap != null && langMap.containsKey(regionId)) {
      return langMap[regionId];
    }
    // Fallback thử tìm trong bất kỳ ngôn ngữ nào nếu ngôn ngữ chỉ định chưa có
    for (final map in translations.values) {
      if (map.containsKey(regionId)) {
        return map[regionId];
      }
    }
    return null;
  }

  /// Đường dẫn tuyệt đối đến file ảnh trang thứ [pageIndex] (0-based)
  String? getPageFilePath(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= manifest.pageFiles.length) {
      return null;
    }
    final fileName = manifest.pageFiles[pageIndex];
    // Chuẩn hoá đường dẫn gạch chéo
    final dir = localDirectoryPath.endsWith('/') || localDirectoryPath.endsWith('\\')
        ? localDirectoryPath.substring(0, localDirectoryPath.length - 1)
        : localDirectoryPath;
    return '$dir/$fileName';
  }

  int get totalPages => manifest.pageFiles.length;

  @override
  String toString() =>
      'LoadedComicPackage(chapter: ${manifest.chapterId}, pages: $totalPages, langs: $availableLanguages)';
}

