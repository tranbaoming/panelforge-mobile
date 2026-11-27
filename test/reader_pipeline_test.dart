import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/models/api_dtos.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/models/comic_package_models.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/screens/reader/comic_reader_page.dart';
import 'package:panelforge/services/catalog_service.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/services/reader_image_auth.dart';
import 'package:panelforge/widgets/reading_mode_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountingCatalogService extends CatalogService {
  int readChapterCalls = 0;

  @override
  Future<PublicSeriesDetailDto> getSeriesDetail(String seriesId, {String? lang}) async {
    return PublicSeriesDetailDto.fromJson({
      'id': seriesId,
      'title': 'Test Series',
      'studioName': 'Studio',
      'synopsis': 'Synopsis',
      'genre': 'Action',
      'format': 'Manga',
      'readingDirection': 'LeftToRight',
      'chapters': [
        {
          'id': 'ch-online-1',
          'chapterNumber': 1,
          'title': 'Chương 1',
          'publishedAt': '2026-11-01T00:00:00Z',
          'isFree': true,
          'isLocked': false,
          'isUnlocked': true,
          'priceVnd': 0,
        },
      ],
    });
  }

  @override
  Future<PublicChapterReadDto> readChapter(String chapterId, {String? lang}) async {
    readChapterCalls++;
    return PublicChapterReadDto.fromJson({
      'id': chapterId,
      'seriesId': 'series-online-1',
      'seriesTitle': 'Test Series',
      'chapterNumber': 1,
      'title': 'Chương 1',
      'readingDirection': 'LeftToRight',
      'isFree': true,
      'isUnlocked': true,
      'priceVnd': 0,
      'pages': [
        {'id': 'p1', 'pageNumber': 1, 'isLocked': false},
        {'id': 'p2', 'pageNumber': 2, 'isLocked': false},
      ],
    });
  }

  @override
  Future<void> recordChapterView(String chapterId, {String? lang}) async {}
}

class _SpyCbzPackageService extends CbzPackageService {
  int loadPackageCalls = 0;

  @override
  Future<LoadedComicPackage> loadPackage({
    required String chapterId,
    String? manifestUrl,
    String? cbzUrl,
    bool forceRefresh = false,
  }) async {
    loadPackageCalls++;
    throw StateError('loadPackage must not be called for online chapter open');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderImageAuth (DEC-04 & DPR-aware decode sizing, AUD-FL-06)', () {
    test('headersForUrl attaches session Cookie header from CookieJar', () async {
      final jar = CookieJar();
      final uri = Uri.parse('https://api.panelforge.com/media/ch1/page1.webp');
      await jar.saveFromResponse(uri, [
        Cookie('pf_access', 'secret-access-cookie')..httpOnly = true,
      ]);

      final headers = await ReaderImageAuth.headersForUrl(uri.toString(), cookieJar: jar);
      expect(headers['Cookie'], contains('pf_access=secret-access-cookie'));
      expect(headers['User-Agent'], isNotEmpty);
    });

    test('headersForUrl omits Cookie header when CookieJar has no matching cookies', () async {
      final jar = CookieJar();
      final headers = await ReaderImageAuth.headersForUrl(
        'https://cdn.example.com/public/page1.webp',
        cookieJar: jar,
      );
      expect(headers.containsKey('Cookie'), isFalse);
      expect(headers['User-Agent'], isNotEmpty);
    });

    test('computeMemCacheWidth scales with DPR and clamps within [360, 2048]', () {
      expect(
        ReaderImageAuth.computeMemCacheWidth(logicalWidth: 360, devicePixelRatio: 2.0),
        720,
      );
      expect(
        ReaderImageAuth.computeMemCacheWidth(logicalWidth: 412, devicePixelRatio: 3.0),
        1236,
      );
      // Capped by maxLogicalWidth (680 * 3.0 = 2040)
      expect(
        ReaderImageAuth.computeMemCacheWidth(logicalWidth: 1200, devicePixelRatio: 3.0),
        2040,
      );
      // Clamped at upper bound 2048
      expect(
        ReaderImageAuth.computeMemCacheWidth(logicalWidth: 1200, devicePixelRatio: 4.0),
        2048,
      );
      // Clamped at lower bound 360
      expect(
        ReaderImageAuth.computeMemCacheWidth(logicalWidth: 200, devicePixelRatio: 1.0),
        360,
      );
    });
  });

  group('ReadingModeSwitcher prefetch & pinch-zoom (AUD-FL-06)', () {
    test('computePrefetchIndices returns bounded adjacent pages', () {
      expect(ReadingModeSwitcher.computePrefetchIndices(0, 50), [1, 2]);
      expect(ReadingModeSwitcher.computePrefetchIndices(5, 50), [6, 7, 4]);
      expect(ReadingModeSwitcher.computePrefetchIndices(49, 50), [48]);
      expect(ReadingModeSwitcher.computePrefetchIndices(0, 1), isEmpty);
    });

    testWidgets('Page Mode wraps pages in InteractiveViewer and locks PageView physics while zoomed', (tester) async {
      final switcherKey = GlobalKey<ReadingModeSwitcherState>();
      const chapter = ChapterItem(
        id: 'ch-zoom-1',
        number: 1,
        title: 'Chương 1',
        releaseDate: '01/11/2026',
        pageCount: 3,
        isFree: true,
        isUnlocked: true,
        priceVnd: 0,
        pages: [
          ComicPageData(pageNumber: 1, title: 'Trang 1', panels: []),
          ComicPageData(pageNumber: 2, title: 'Trang 2', panels: []),
          ComicPageData(pageNumber: 3, title: 'Trang 3', panels: []),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingModeSwitcher(
              key: switcherKey,
              chapter: chapter,
              mode: ReadingMode.ltr,
              themeMode: ReaderThemeMode.night,
              onPageChanged: (_) {},
              onTapScreen: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // At 1.0x: InteractiveViewer exists, PageView uses BouncingScrollPhysics
      expect(find.byType(InteractiveViewer), findsOneWidget);
      var pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.physics, isA<BouncingScrollPhysics>());
      expect(switcherKey.currentState!.isZoomed, isFalse);

      // Simulate pinch-zoom to 2.0x: PageView locks scrolling so panning won't flip pages
      switcherKey.currentState!.zoomControllerForTest.value = Matrix4.diagonal3Values(2.0, 2.0, 1.0);
      await tester.pump();

      expect(switcherKey.currentState!.isZoomed, isTrue);
      pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.physics, isA<NeverScrollableScrollPhysics>());

      // Zoom back to 1.0x: PageView swiping is re-enabled
      switcherKey.currentState!.zoomControllerForTest.value = Matrix4.identity();
      await tester.pump();

      expect(switcherKey.currentState!.isZoomed, isFalse);
      pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.physics, isA<BouncingScrollPhysics>());
    });
  });

  group('Online chapter single metadata request (AUD-FL-06)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.init();
    });

    testWidgets('opening an online chapter performs only 1 readChapter request and 0 loadPackage calls',
        (tester) async {
      final catalog = _CountingCatalogService();
      final cbz = _SpyCbzPackageService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogServiceProvider.overrideWithValue(catalog),
            cbzPackageServiceProvider.overrideWithValue(cbz),
          ],
          child: const MaterialApp(
            home: ComicReaderPage(seriesId: 'series-online-1', chapterId: 'ch-online-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(catalog.readChapterCalls, 1);
      expect(cbz.loadPackageCalls, 0);
    });
  });
}
