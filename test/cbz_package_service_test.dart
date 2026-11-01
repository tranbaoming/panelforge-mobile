import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/models/api_dtos.dart';
import 'package:panelforge/models/comic_package_models.dart';
import 'package:panelforge/services/preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ComicPackageModels & Manifest Test Suite', () {
    test('NormalizedBounds serializes and deserializes accurately', () {
      final bounds = NormalizedBounds(x: 0.12, y: 0.34, w: 0.56, h: 0.78);
      final json = bounds.toJson();
      expect(json['x'], 0.12);
      expect(json['y'], 0.34);
      expect(json['w'], 0.56);
      expect(json['h'], 0.78);

      final decoded = NormalizedBounds.fromJson(json);
      expect(decoded.x, 0.12);
      expect(decoded.y, 0.34);
      expect(decoded.w, 0.56);
      expect(decoded.h, 0.78);
    });

    test('PanelInfo parses correctly from JSON', () {
      const rawJson = '''
      {
        "id": "panel-1",
        "pageIndex": 0,
        "readingOrder": 1,
        "bounds": { "x": 0.05, "y": 0.05, "w": 0.9, "h": 0.4 }
      }
      ''';
      final panel = PanelInfo.fromJson(jsonDecode(rawJson) as Map<String, dynamic>);
      expect(panel.id, 'panel-1');
      expect(panel.pageIndex, 0);
      expect(panel.readingOrder, 1);
      expect(panel.bounds.w, 0.9);
    });

    test('TextRegion and TranslationEntry parse correctly', () {
      const regionJson = '''
      {
        "id": "text-1",
        "pageIndex": 0,
        "type": "speech",
        "bounds": { "x": 0.1, "y": 0.1, "w": 0.3, "h": 0.2 }
      }
      ''';
      final region = TextRegion.fromJson(jsonDecode(regionJson) as Map<String, dynamic>);
      expect(region.id, 'text-1');
      expect(region.type, 'speech');

      const transJson = '''
      {
        "regionId": "text-1",
        "text": "Xin chào!",
        "furiganaOrNote": "Konnichiwa",
        "ttsText": "Xin chào thế giới"
      }
      ''';
      final trans = TranslationEntry.fromJson(jsonDecode(transJson) as Map<String, dynamic>);
      expect(trans.regionId, 'text-1');
      expect(trans.text, 'Xin chào!');
      expect(trans.furiganaOrNote, 'Konnichiwa');
    });

    test('ComicManifest parses properly with standard and custom fields', () {
      const manifestJson = '''
      {
        "version": "1.0",
        "seriesId": "series-abc",
        "chapterId": "chap-01",
        "readingDirection": "RTL",
        "pageFiles": ["001.webp", "002.webp"],
        "webtoonTileSpacing": 4.0
      }
      ''';
      final manifest = ComicManifest.fromJson(jsonDecode(manifestJson) as Map<String, dynamic>);
      expect(manifest.version, '1.0');
      expect(manifest.seriesId, 'series-abc');
      expect(manifest.chapterId, 'chap-01');
      expect(manifest.readingDirection, 'RTL');
      expect(manifest.pageFiles.length, 2);
      expect(manifest.webtoonTileSpacing, 4.0);
    });

    test('LoadedComicPackage methods function properly', () {
      final manifest = ComicManifest(
        version: '1.0',
        seriesId: 's1',
        chapterId: 'c1',
        readingDirection: 'VERTICAL',
        pageFiles: ['001.webp'],
        webtoonTileSpacing: 0.0,
      );
      final package = LoadedComicPackage(
        manifest: manifest,
        panels: [
          PanelInfo(
            id: 'p1',
            pageIndex: 0,
            readingOrder: 1,
            bounds: NormalizedBounds(x: 0, y: 0, w: 1, h: 0.5),
          ),
        ],
        textRegions: [
          TextRegion(
            id: 't1',
            pageIndex: 0,
            bounds: NormalizedBounds(x: 0.1, y: 0.1, w: 0.2, h: 0.2),
          ),
        ],
        translations: {
          'vi': {
            't1': TranslationEntry(regionId: 't1', text: 'Tiếng Việt'),
          },
        },
        localDirectoryPath: '/data/user/0/offline/c1',
      );

      expect(package.totalPages, 1);
      expect(package.getPageFilePath(0), '/data/user/0/offline/c1/001.webp');
      expect(package.getPanelsForPage(0).length, 1);
      expect(package.getTextRegionsForPage(0).length, 1);
      expect(package.getTranslation('vi', 't1')?.text, 'Tiếng Việt');
      expect(package.getTranslation('en', 't1')?.text, 'Tiếng Việt'); // Fallback to any available language
      expect(package.getTranslation('en', 'unknown_id'), isNull);
    });
  });

  group('PreferencesService Offline Storage Persistence', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.init();
    });

    test('addOfflineChapterId, isChapterDownloaded, and removeOfflineChapterId work correctly', () async {
      expect(PreferencesService.isChapterDownloaded('ch-100'), isFalse);
      expect(PreferencesService.getOfflineChapterIds().isEmpty, isTrue);

      await PreferencesService.addOfflineChapterId('ch-100');
      expect(PreferencesService.isChapterDownloaded('ch-100'), isTrue);
      expect(PreferencesService.getOfflineChapterIds().contains('ch-100'), isTrue);

      await PreferencesService.addOfflineChapterId('ch-200');
      expect(PreferencesService.getOfflineChapterIds().length, 2);

      await PreferencesService.removeOfflineChapterId('ch-100');
      expect(PreferencesService.isChapterDownloaded('ch-100'), isFalse);
      expect(PreferencesService.isChapterDownloaded('ch-200'), isTrue);
      expect(PreferencesService.getOfflineChapterIds().length, 1);
    });
  });

  group('Monetization & Payment DTOs Test Suite', () {
    test('UserWalletDto deserializes correctly with VIP status', () {
      final now = DateTime.now();
      final json = {
        'balanceCoins': 350,
        'isVip': true,
        'vipExpiresAt': now.toIso8601String(),
      };
      final wallet = UserWalletDto.fromJson(json);
      expect(wallet.balanceCoins, 350);
      expect(wallet.isVip, isTrue);
      expect(wallet.vipExpiresAt, isNotNull);
    });

    test('UnlockChapterRequest and UnlockChapterResponse serialize correctly', () {
      const req = UnlockChapterRequest(chapterId: 'chap-vip-99');
      final reqJson = req.toJson();
      expect(reqJson['chapterId'], 'chap-vip-99');

      final respJson = {
        'chapterId': 'chap-vip-99',
        'success': true,
        'remainingCoins': 300,
        'cbzDownloadUrl': 'https://api.panelforge.app/packages/chap-vip-99.cbz',
      };
      final resp = UnlockChapterResponse.fromJson(respJson);
      expect(resp.success, isTrue);
      expect(resp.remainingCoins, 300);
      expect(resp.cbzDownloadUrl, contains('.cbz'));
    });
  });

  group('CBZ Archive Packaging and Extraction Test Suite', () {
    test('ZipEncoder and ZipDecoder accurately process Comic Package v1.0 structure', () {
      // Build a virtual Comic Package v1.0 in-memory
      final archive = Archive();

      const manifestContent = '{"version":"1.0","seriesId":"s1","chapterId":"c1","readingDirection":"VERTICAL","pageFiles":["001.webp"]}';
      archive.addFile(ArchiveFile('manifest.json', manifestContent.length, utf8.encode(manifestContent)));

      const panelsContent = '[{"id":"p1","pageIndex":0,"readingOrder":1,"bounds":{"x":0,"y":0,"w":1,"h":1}}]';
      archive.addFile(ArchiveFile('metadata/panels.json', panelsContent.length, utf8.encode(panelsContent)));

      // Encode to bytes (.cbz)
      final zipEncoder = ZipEncoder();
      final encodedBytes = zipEncoder.encode(archive);
      expect(encodedBytes, isNotNull);

      // Decode (.cbz)
      final zipDecoder = ZipDecoder();
      final decodedArchive = zipDecoder.decodeBytes(encodedBytes!);
      expect(decodedArchive.length, 2);

      final decodedManifestFile = decodedArchive.firstWhere((f) => f.name == 'manifest.json');
      final decodedManifestString = utf8.decode(decodedManifestFile.content as List<int>);
      final manifestJson = jsonDecode(decodedManifestString) as Map<String, dynamic>;
      final manifest = ComicManifest.fromJson(manifestJson);

      expect(manifest.chapterId, 'c1');
      expect(manifest.readingDirection, 'VERTICAL');
      expect(manifest.pageFiles, ['001.webp']);
    });
  });

  group('NormalizedBounds Flexible Parsing & Geometry Suite', () {
    test('tryParse parses Map, JSON string, and CSV string correctly', () {
      // From Map
      final fromMap = NormalizedBounds.tryParse({'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.4});
      expect(fromMap?.x, 0.1);
      expect(fromMap?.y, 0.2);
      expect(fromMap?.w, 0.3);
      expect(fromMap?.h, 0.4);

      // From JSON string
      final fromJsonStr = NormalizedBounds.tryParse('{"x": 0.05, "y": 0.15, "w": 0.45, "h": 0.55}');
      expect(fromJsonStr?.x, 0.05);
      expect(fromJsonStr?.w, 0.45);

      // From CSV string
      final fromCsv = NormalizedBounds.tryParse('0.1, 0.2, 0.3, 0.4');
      expect(fromCsv?.x, 0.1);
      expect(fromCsv?.h, 0.4);

      // Null and empty
      expect(NormalizedBounds.tryParse(null), isNull);
      expect(NormalizedBounds.tryParse(''), isNull);
      expect(NormalizedBounds.tryParse('{}'), isNull);
    });

    test('containsPoint detects internal and external coordinates', () {
      const bounds = NormalizedBounds(x: 0.1, y: 0.2, w: 0.4, h: 0.4); // x: 0.1..0.5, y: 0.2..0.6
      expect(bounds.containsPoint(0.2, 0.3), isTrue);
      expect(bounds.containsPoint(0.1, 0.2), isTrue); // On corner
      expect(bounds.containsPoint(0.5, 0.6), isTrue); // On opposite corner
      expect(bounds.containsPoint(0.05, 0.3), isFalse); // Left
      expect(bounds.containsPoint(0.6, 0.3), isFalse); // Right
      expect(bounds.containsPoint(0.3, 0.1), isFalse); // Top
      expect(bounds.containsPoint(0.3, 0.7), isFalse); // Bottom
    });
  });

  group('Reviewer & Feedback DTOs Test Suite', () {
    test('PreviewFeedbackRequest serializes correctly with panel, textRegion, and bounds', () {
      const req = PreviewFeedbackRequest(
        token: 'REV-TOKEN-123',
        message: '[Lỗi nét] Nét vẽ bị răng cưa',
        pageId: 'page-1',
        panelId: 'panel-99',
        textRegionId: 'text-bubble-1',
        bounds: NormalizedBounds(x: 0.1, y: 0.2, w: 0.3, h: 0.4),
      );

      final json = req.toJson();
      expect(json['token'], 'REV-TOKEN-123');
      expect(json['message'], contains('[Lỗi nét]'));
      expect(json['pageId'], 'page-1');
      expect(json['panelId'], 'panel-99');
      expect(json['textRegionId'], 'text-bubble-1');
      expect(json['bounds']['x'], 0.1);
      expect(json['bounds']['w'], 0.3);
    });

    test('PreviewChapterDto with textRegions and panels maps correctly to ReviewManuscript', () {
      final dto = PreviewChapterDto(
        chapterId: 'chap-10',
        seriesTitle: 'Đại Chiến Khung Tranh',
        chapterNumber: 1.0,
        readingDirection: ApiReadingDirection.leftToRight,
        recipientEmail: 'reviewer@panelforge.app',
        watermarkText: 'CONFIDENTIAL',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        chapterVersion: 1,
        pages: [
          PreviewPageDto(
            pageId: 'page-1',
            pageNumber: 1,
            assetReferenceId: 'asset-1',
            versionNumber: 1,
            relativeImageUrl: '/images/p1.webp',
            panels: [
              PreviewPanelDto(
                panelId: 'panel-1',
                panelNumber: 1,
                boundingBox: '0.0, 0.0, 0.5, 0.5',
              ),
              PreviewPanelDto(
                panelId: 'panel-2',
                panelNumber: 2,
                boundingBox: '0.5, 0.0, 0.5, 0.5',
              ),
            ],
            textRegions: [
              const TextRegion(
                id: 'tr-1',
                pageIndex: 0,
                type: 'speech',
                bounds: NormalizedBounds(x: 0.1, y: 0.1, w: 0.2, h: 0.2),
              ),
            ],
          ),
        ],
      );

      expect(dto.pages.length, 1);
      expect(dto.pages.first.panels.length, 2);
      expect(dto.pages.first.textRegions.length, 1);
      expect(dto.pages.first.panels.first.bounds, isNotNull);
      expect(dto.pages.first.panels.first.bounds?.w, 0.5);
    });
  });
}
