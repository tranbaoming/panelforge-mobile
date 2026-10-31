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
}
