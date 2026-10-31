import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/api_dtos.dart';
import '../models/comic_package_models.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'catalog_service.dart';
import 'preferences_service.dart';

/// Trạng thái tải gói truyện offline
enum DownloadStatus {
  idle,
  downloading,
  extracting,
  completed,
  failed,
}

/// Dịch vụ xử lý định dạng Comic Package v1.0 (CBZ + Custom Manifest)
class CbzPackageService {
  final ApiClient _client;
  final CatalogService _catalogService;

  CbzPackageService({
    ApiClient? client,
    CatalogService? catalogService,
  })  : _client = client ?? ApiClient(),
        _catalogService = catalogService ?? CatalogService();

  Dio get _dio => _client.dio;

  // ─── 1. SINGLE-FILE CBZ: DOWNLOAD & EXTRACTION (OFFLINE) ─────────────────

  /// Thư mục bảo mật nội bộ lưu trữ các gói truyện offline
  Future<Directory> _getOfflineStorageDirectory() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final offlineDir = Directory('${appSupportDir.path}/offline_packages');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir;
  }

  /// Thư mục lưu trữ của một chapter cụ thể
  Future<Directory> getChapterOfflineDirectory(String chapterId) async {
    final rootDir = await _getOfflineStorageDirectory();
    return Directory('${rootDir.path}/$chapterId');
  }

  /// Tải gói Single-file CBZ và giải nén vào thư mục offline của ứng dụng
  Future<LoadedComicPackage> downloadAndExtractCbzPackage({
    required String chapterId,
    String? customDownloadUrl,
    void Function(double progress, int receivedBytes, int totalBytes)? onProgress,
    void Function(DownloadStatus status)? onStatusChanged,
  }) async {
    onStatusChanged?.call(DownloadStatus.downloading);

    final targetDir = await getChapterOfflineDirectory(chapterId);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final tempZipFile = File('${targetDir.path}/download_temp.cbz');

    try {
      // 1. Xác định URL tải gói .cbz
      String downloadUrl = customDownloadUrl?.trim() ?? '';
      if (downloadUrl.isEmpty) {
        downloadUrl = ApiConfig.resolveUrl('/api/catalog/chapters/$chapterId/package');
      } else if (!downloadUrl.startsWith('http://') && !downloadUrl.startsWith('https://')) {
        downloadUrl = ApiConfig.resolveUrl(downloadUrl);
      }

      debugPrint('[CbzService] Bắt đầu tải CBZ từ: $downloadUrl');

      // 2. Tải file .cbz về bộ nhớ tạm nội bộ
      await _dio.download(
        downloadUrl,
        tempZipFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            final p = (received / total).clamp(0.0, 1.0);
            onProgress(p, received, total);
          }
        },
      );

      onStatusChanged?.call(DownloadStatus.extracting);
      debugPrint('[CbzService] Tải xong. Bắt đầu giải nén CBZ...');

      // 3. Giải nén file .cbz bằng thư viện archive
      final zipBytes = await tempZipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      for (final archiveFile in archive) {
        final filename = archiveFile.name;
        // Bỏ qua thư mục rác __MACOSX
        if (filename.startsWith('__MACOSX/')) continue;

        if (archiveFile.isFile) {
          final data = archiveFile.content as List<int>;
          final outFile = File('${targetDir.path}/$filename');
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(data, flush: true);
        }
      }

      // 4. Nếu bên trong có file con `content.cbz` (nested), tiếp tục giải nén
      final nestedContentCbz = File('${targetDir.path}/content.cbz');
      if (await nestedContentCbz.exists()) {
        debugPrint('[CbzService] Phát hiện content.cbz con, tiến hành giải nén ảnh...');
        try {
          final contentBytes = await nestedContentCbz.readAsBytes();
          final contentArchive = ZipDecoder().decodeBytes(contentBytes);
          for (final cFile in contentArchive) {
            if (cFile.isFile) {
              final cData = cFile.content as List<int>;
              final cOutFile = File('${targetDir.path}/${cFile.name}');
              await cOutFile.parent.create(recursive: true);
              await cOutFile.writeAsBytes(cData, flush: true);
            }
          }
        } catch (e) {
          debugPrint('[CbzService Warning] Lỗi giải nén content.cbz: $e');
        }
      }

      // Xoá file tải tạm để tiết kiệm bộ nhớ
      if (await tempZipFile.exists()) {
        await tempZipFile.delete();
      }

      // 5. Nạp cấu trúc Comic Package v1.0 từ thư mục đã giải nén
      final loadedPackage = await _parsePackageDirectory(targetDir, chapterId);

      // 6. Ghi nhớ trạng thái đã tải vào Preferences
      await PreferencesService.addOfflineChapterId(chapterId);

      onStatusChanged?.call(DownloadStatus.completed);
      debugPrint('[CbzService] Hoàn tất nạp gói truyện: ${loadedPackage.manifest.chapterId}');
      return loadedPackage;
    } catch (e) {
      onStatusChanged?.call(DownloadStatus.failed);
      debugPrint('[CbzService Error] Lỗi tải/giải nén CBZ: $e');
      // Dọn dẹp nếu có lỗi
      if (await tempZipFile.exists()) {
        await tempZipFile.delete();
      }
      rethrow;
    }
  }

  // ─── 2. SPLIT-PACKAGE & ONLINE STREAMING WITH FALLBACK ───────────────────

  /// Đọc gói truyện với hỗ trợ Split-package hoặc tự động fallback luồng API cũ
  Future<LoadedComicPackage> loadPackage({
    required String chapterId,
    String? manifestUrl,
    String? cbzUrl,
    bool forceRefresh = false,
  }) async {
    // A. Kiểm tra nếu đã có sẵn trong bộ nhớ Offline
    if (!forceRefresh && await isChapterDownloaded(chapterId)) {
      final offlinePkg = await loadOfflinePackage(chapterId);
      if (offlinePkg != null) {
        debugPrint('[CbzService] Đọc từ bộ nhớ Offline: $chapterId');
        return offlinePkg;
      }
    }

    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/panelforge_cache/$chapterId');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    // B. Thử tải Split-package (manifest.json + metadata/ + content.cbz)
    try {
      if (manifestUrl != null && manifestUrl.trim().isNotEmpty) {
        final fullManifestUrl = ApiConfig.resolveUrl(manifestUrl.trim());
        final manifestRes = await _dio.get(fullManifestUrl);
        if (manifestRes.data != null) {
          final manifestMap = manifestRes.data is Map<String, dynamic>
              ? manifestRes.data as Map<String, dynamic>
              : jsonDecode(manifestRes.data.toString()) as Map<String, dynamic>;
          final manifest = ComicManifest.fromJson(manifestMap);

          // Tải và giải nén content.cbz nếu có URL
          if (cbzUrl != null && cbzUrl.trim().isNotEmpty) {
            final fullCbzUrl = ApiConfig.resolveUrl(cbzUrl.trim());
            final tempCbzFile = File('${cacheDir.path}/content.cbz');
            await _dio.download(fullCbzUrl, tempCbzFile.path);

            final cBytes = await tempCbzFile.readAsBytes();
            final cArchive = ZipDecoder().decodeBytes(cBytes);
            for (final f in cArchive) {
              if (f.isFile) {
                final outFile = File('${cacheDir.path}/${f.name}');
                await outFile.parent.create(recursive: true);
                await outFile.writeAsBytes(f.content as List<int>, flush: true);
              }
            }
          }

          return LoadedComicPackage(
            manifest: manifest,
            localDirectoryPath: cacheDir.path,
          );
        }
      }
    } catch (e) {
      debugPrint('[CbzService] Không thể tải Split-package ($e). Bắt đầu fallback luồng chuẩn...');
    }

    // C. CƠ CHẾ FALLBACK THÔNG MINH:
    // Gọi API Catalog chuẩn: GET /api/catalog/chapters/{chapterId}
    debugPrint('[CbzService] Fallback về API Catalog chuẩn cho chapter: $chapterId');
    final chapterReadDto = await _catalogService.readChapter(chapterId);

    // Chuyển đổi hướng đọc chuẩn
    String readingDir = 'LTR';
    if (chapterReadDto.readingDirection == ApiReadingDirection.rightToLeft) {
      readingDir = 'RTL';
    } else if (chapterReadDto.readingDirection == ApiReadingDirection.vertical) {
      readingDir = 'VERTICAL';
    }

    final pageUrls = chapterReadDto.pages.map((p) => p.fullImageUrl ?? '').toList();

    final fallbackManifest = ComicManifest(
      version: '1.0',
      seriesId: chapterReadDto.seriesId,
      chapterId: chapterReadDto.id,
      readingDirection: readingDir,
      pageFiles: pageUrls,
      webtoonTileSpacing: 0.0,
    );

    return LoadedComicPackage(
      manifest: fallbackManifest,
      panels: const [],
      textRegions: const [],
      translations: const {},
      localDirectoryPath: cacheDir.path,
    );
  }

  // ─── 3. OFFLINE STORAGE MANAGEMENT ───────────────────────────────────────

  /// Nạp gói truyện offline đã lưu trên máy
  Future<LoadedComicPackage?> loadOfflinePackage(String chapterId) async {
    final targetDir = await getChapterOfflineDirectory(chapterId);
    if (!await targetDir.exists()) {
      await PreferencesService.removeOfflineChapterId(chapterId);
      return null;
    }
    return await _parsePackageDirectory(targetDir, chapterId);
  }

  /// Kiểm tra xem chapter đã được tải offline đầy đủ chưa
  Future<bool> isChapterDownloaded(String chapterId) async {
    if (!PreferencesService.isChapterDownloaded(chapterId)) {
      return false;
    }
    final targetDir = await getChapterOfflineDirectory(chapterId);
    return await targetDir.exists();
  }

  /// Tính tổng dung lượng (bytes) của gói chapter đã tải
  Future<int> getDownloadedPackageSize(String chapterId) async {
    final targetDir = await getChapterOfflineDirectory(chapterId);
    if (!await targetDir.exists()) return 0;

    int totalBytes = 0;
    try {
      await for (final entity in targetDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
    } catch (_) {}
    return totalBytes;
  }

  /// Xoá gói offline của một chương để giải phóng dung lượng
  Future<void> deleteOfflinePackage(String chapterId) async {
    final targetDir = await getChapterOfflineDirectory(chapterId);
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
    await PreferencesService.removeOfflineChapterId(chapterId);
    debugPrint('[CbzService] Đã xoá gói offline cho chapter: $chapterId');
  }

  /// Xoá toàn bộ các gói truyện offline
  Future<void> clearAllOfflinePackages() async {
    final rootDir = await _getOfflineStorageDirectory();
    if (await rootDir.exists()) {
      await rootDir.delete(recursive: true);
    }
    final allIds = PreferencesService.getOfflineChapterIds();
    for (final id in allIds) {
      await PreferencesService.removeOfflineChapterId(id);
    }
  }

  /// Format dung lượng bytes thành chuỗi dễ đọc (KB, MB, GB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }

  // ─── HELPER: PARSE PACKAGE DIRECTORY ──────────────────────────────────────

  Future<LoadedComicPackage> _parsePackageDirectory(Directory dir, String chapterId) async {
    final dirPath = dir.path;

    // 1. Đọc manifest.json
    ComicManifest manifest;
    final manifestFile = File('$dirPath/manifest.json');
    if (await manifestFile.exists()) {
      try {
        final content = await manifestFile.readAsString();
        manifest = ComicManifest.fromJson(jsonDecode(content) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[CbzService Warning] Lỗi đọc manifest.json: $e');
        manifest = ComicManifest(seriesId: '', chapterId: chapterId);
      }
    } else {
      manifest = ComicManifest(seriesId: '', chapterId: chapterId);
    }

    // 2. Tự động nhận diện các file ảnh trang nếu manifest trống
    List<String> pageFiles = List<String>.from(manifest.pageFiles);
    if (pageFiles.isEmpty) {
      final imageEntities = await dir.list().where((e) {
        if (e is! File) return false;
        final name = e.path.toLowerCase();
        return name.endsWith('.webp') ||
            name.endsWith('.png') ||
            name.endsWith('.jpg') ||
            name.endsWith('.jpeg');
      }).toList();

      imageEntities.sort((a, b) => a.path.compareTo(b.path));
      pageFiles = imageEntities.map((e) => e.uri.pathSegments.last).toList();
      manifest = ComicManifest(
        version: manifest.version,
        seriesId: manifest.seriesId,
        chapterId: manifest.chapterId,
        readingDirection: manifest.readingDirection,
        pageFiles: pageFiles,
        webtoonTileSpacing: manifest.webtoonTileSpacing,
      );
    }

    // 3. Đọc metadata/panels.json
    final List<PanelInfo> panels = [];
    final panelsFile = File('$dirPath/metadata/panels.json');
    if (await panelsFile.exists()) {
      try {
        final raw = jsonDecode(await panelsFile.readAsString());
        final list = raw is List ? raw : (raw is Map ? (raw['panels'] as List? ?? []) : []);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            panels.add(PanelInfo.fromJson(item));
          }
        }
      } catch (e) {
        debugPrint('[CbzService] Lỗi đọc panels.json: $e');
      }
    }

    // 4. Đọc metadata/text-regions.json
    final List<TextRegion> textRegions = [];
    final textRegionsFile = File('$dirPath/metadata/text-regions.json');
    if (await textRegionsFile.exists()) {
      try {
        final raw = jsonDecode(await textRegionsFile.readAsString());
        final list = raw is List ? raw : (raw is Map ? (raw['regions'] as List? ?? raw['textRegions'] as List? ?? []) : []);
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            textRegions.add(TextRegion.fromJson(item));
          }
        }
      } catch (e) {
        debugPrint('[CbzService] Lỗi đọc text-regions.json: $e');
      }
    }

    // 5. Đọc metadata/translations/*.json
    final Map<String, Map<String, TranslationEntry>> translations = {};
    final transDir = Directory('$dirPath/metadata/translations');
    if (await transDir.exists()) {
      try {
        await for (final entity in transDir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            final fileName = entity.uri.pathSegments.last;
            final langCode = fileName.replaceAll('.json', '').toLowerCase();
            final raw = jsonDecode(await entity.readAsString());

            final Map<String, TranslationEntry> langMap = {};
            if (raw is Map<String, dynamic>) {
              raw.forEach((key, val) {
                if (val is Map<String, dynamic>) {
                  langMap[key] = TranslationEntry.fromJson(val);
                } else if (val is String) {
                  langMap[key] = TranslationEntry(regionId: key, text: val);
                }
              });
            } else if (raw is List) {
              for (final item in raw) {
                if (item is Map<String, dynamic>) {
                  final entry = TranslationEntry.fromJson(item);
                  langMap[entry.regionId] = entry;
                }
              }
            }
            translations[langCode] = langMap;
          }
        }
      } catch (e) {
        debugPrint('[CbzService] Lỗi đọc translations: $e');
      }
    }

    return LoadedComicPackage(
      manifest: manifest,
      panels: panels,
      textRegions: textRegions,
      translations: translations,
      localDirectoryPath: dirPath,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIVERPOD PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Provider khởi tạo CbzPackageService
final cbzPackageServiceProvider = Provider<CbzPackageService>((ref) {
  return CbzPackageService();
});

/// Notifier quản lý tiến trình download của từng chapter (chapterId -> 0.0 to 1.0)
class DownloadProgressNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => const {};

  void setProgress(String chapterId, double progress) {
    state = {...state, chapterId: progress};
  }
}

final downloadProgressProvider =
    NotifierProvider<DownloadProgressNotifier, Map<String, double>>(
  DownloadProgressNotifier.new,
);

/// Notifier quản lý trạng thái download của từng chapter (chapterId -> DownloadStatus)
class DownloadStatusNotifier extends Notifier<Map<String, DownloadStatus>> {
  @override
  Map<String, DownloadStatus> build() => const {};

  void setStatus(String chapterId, DownloadStatus status) {
    state = {...state, chapterId: status};
  }
}

final downloadStatusProvider =
    NotifierProvider<DownloadStatusNotifier, Map<String, DownloadStatus>>(
  DownloadStatusNotifier.new,
);

/// Family Provider lấy tiến trình tải của 1 chapter cụ thể (0.0 -> 1.0)
final chapterDownloadProgressProvider = Provider.family<double, String>((ref, chapterId) {
  return ref.watch(downloadProgressProvider)[chapterId] ?? 0.0;
});

/// Family Provider lấy trạng thái tải của 1 chapter cụ thể
final chapterDownloadStatusProvider = Provider.family<DownloadStatus, String>((ref, chapterId) {
  return ref.watch(downloadStatusProvider)[chapterId] ?? DownloadStatus.idle;
});

/// Notifier quản lý danh sách các chapterId đã tải offline
class DownloadedChaptersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return PreferencesService.getOfflineChapterIds();
  }

  void refresh() {
    state = PreferencesService.getOfflineChapterIds();
  }

  void add(String chapterId) {
    PreferencesService.addOfflineChapterId(chapterId);
    state = {...state, chapterId};
  }

  void remove(String chapterId) {
    PreferencesService.removeOfflineChapterId(chapterId);
    state = state.where((id) => id != chapterId).toSet();
  }
}

/// Provider danh sách các Chapter ID đã tải offline
final downloadedChaptersProvider =
    NotifierProvider<DownloadedChaptersNotifier, Set<String>>(
  DownloadedChaptersNotifier.new,
);
