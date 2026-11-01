import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/models/comic_package_models.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/widgets/reading_mode_switcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('ReadingModeSwitcher & Comic Package Integration Tests', () {
    testWidgets('Renders empty state when chapter has no pages', (tester) async {
      final emptyChapter = ChapterItem(
        id: 'chap-empty',
        number: 1,
        title: 'Chương Trống',
        releaseDate: '01/01/2026',
        pageCount: 0,
        pages: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingModeSwitcher(
              chapter: emptyChapter,
              mode: ReadingMode.ltr,
              themeMode: ReaderThemeMode.night,
              initialPage: 1,
              onPageChanged: (_) {},
              onTapScreen: () {},
            ),
          ),
        ),
      );

      expect(find.text('Chương truyện này chưa có trang nào.'), findsOneWidget);
    });

    testWidgets('Renders comic page and dialogue panels in horizontal mode', (tester) async {
      final testChapter = ChapterItem(
        id: 'chap-1',
        number: 1,
        title: 'Khởi Đầu Mới',
        releaseDate: '01/01/2026',
        pageCount: 1,
        pages: [
          ComicPageData(
            pageNumber: 1,
            title: 'Trang 1',
            panels: [
              ComicPanelData(
                id: 'p-1',
                panelNumber: 1,
                description: 'Cảnh giới thiệu',
                aspectRatio: 1.5,
                colorHex: '0xFF1A1D2D',
                dialogue: 'Thế giới truyện tranh mở ra!',
                soundEffect: 'VROOOM',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingModeSwitcher(
              chapter: testChapter,
              mode: ReadingMode.ltr,
              themeMode: ReaderThemeMode.night,
              initialPage: 1,
              onPageChanged: (_) {},
              onTapScreen: () {},
            ),
          ),
        ),
      );

      expect(find.text('Thế giới truyện tranh mở ra!'), findsOneWidget);
      expect(find.text('VROOOM'), findsOneWidget);
    });

    testWidgets('Renders translation overlay when LoadedComicPackage is supplied', (tester) async {
      final manifest = ComicManifest(
        version: '1.0',
        seriesId: 'series-1',
        chapterId: 'chap-1',
        readingDirection: 'LTR',
        pageFiles: const ['001.webp'],
      );

      final region = TextRegion(
        id: 'reg-1',
        pageIndex: 0,
        bounds: const NormalizedBounds(x: 0.1, y: 0.1, w: 0.8, h: 0.2),
        type: 'speech',
      );

      final translation = TranslationEntry(
        regionId: 'reg-1',
        text: 'Bản dịch tiếng Việt chuẩn Comic Package v1.0',
      );

      final package = LoadedComicPackage(
        manifest: manifest,
        textRegions: [region],
        translations: {
          'vi': {'reg-1': translation},
        },
        localDirectoryPath: '/tmp/test_pkg',
      );

      final testChapter = ChapterItem(
        id: 'chap-1',
        number: 1,
        title: 'Chương 1',
        releaseDate: '01/01/2026',
        pageCount: 1,
        pages: [
          ComicPageData(
            pageNumber: 1,
            title: 'Trang 1',
            imageUrl: 'https://example.com/001.webp',
            panels: const [],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingModeSwitcher(
              chapter: testChapter,
              mode: ReadingMode.ltr,
              themeMode: ReaderThemeMode.night,
              initialPage: 1,
              package: package,
              selectedLanguage: 'vi',
              onPageChanged: (_) {},
              onTapScreen: () {},
            ),
          ),
        ),
      );

      // Verify the translation overlay text is rendered
      expect(find.text('Bản dịch tiếng Việt chuẩn Comic Package v1.0'), findsOneWidget);
    });

    testWidgets('Guided Panel Reading mode navigates panels smoothly', (tester) async {
      final panels = [
        PanelInfo(
          id: 'p-1',
          pageIndex: 0,
          readingOrder: 1,
          bounds: const NormalizedBounds(x: 0.05, y: 0.05, w: 0.4, h: 0.4),
        ),
        PanelInfo(
          id: 'p-2',
          pageIndex: 0,
          readingOrder: 2,
          bounds: const NormalizedBounds(x: 0.55, y: 0.05, w: 0.4, h: 0.4),
        ),
      ];

      final testChapter = ChapterItem(
        id: 'chap-1',
        number: 1,
        title: 'Chương 1',
        releaseDate: '01/01/2026',
        pageCount: 1,
        pages: [
          ComicPageData(
            pageNumber: 1,
            title: 'Trang 1',
            imageUrl: 'https://example.com/001.webp',
            panels: const [],
          ),
        ],
      );

      final manifest = ComicManifest(
        version: '1.0',
        seriesId: 'ser-1',
        chapterId: 'chap-1',
        readingDirection: 'LTR',
        pageFiles: ['001.webp'],
      );

      final package = LoadedComicPackage(
        manifest: manifest,
        panels: panels,
        localDirectoryPath: '/tmp/test_pkg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingModeSwitcher(
              chapter: testChapter,
              mode: ReadingMode.ltr,
              themeMode: ReaderThemeMode.night,
              initialPage: 1,
              isGuidedPanelMode: true,
              package: package,
              onPageChanged: (_) {},
              onTapScreen: () {},
            ),
          ),
        ),
      );

      // Verify GuidedPanelViewer floating badge is displayed
      expect(find.text('Khung 1 / 2'), findsOneWidget);
    });
  });
}
