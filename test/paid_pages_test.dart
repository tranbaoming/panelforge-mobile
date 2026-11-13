import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/models/api_dtos.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/services/catalog_service.dart';
import 'package:panelforge/services/cbz_package_service.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/widgets/locked_page_tile.dart';
import 'package:panelforge/widgets/reading_mode_switcher.dart';

/// CatalogService giả: trả sẵn một chương thay vì gọi mạng.
class _FakeCatalog extends CatalogService {
  final PublicChapterReadDto chapter;
  _FakeCatalog(this.chapter);

  @override
  Future<PublicChapterReadDto> readChapter(String chapterId, {String? lang}) async => chapter;
}

/// Chương trả phí 2 trang: trang 1 xem trước, trang 2 khóa đến khi mua chương.
PublicChapterReadDto _chapterDto({required bool bought}) => PublicChapterReadDto.fromJson({
  'id': 'chap-1',
  'seriesId': 'series-1',
  'seriesTitle': 'Moon Blade',
  'readingDirection': 'LeftToRight',
  'chapterNumber': 1,
  'title': 'Khởi đầu',
  'isLocked': true,
  'priceVnd': 10000,
  'isUnlocked': bought,
  'isFree': false,
  'pages': [
    {
      'id': 'p1',
      'pageNumber': 1,
      'imageUrl': '/api/catalog/chapters/chap-1/pages/p1/image',
      'isPreview': true,
    },
    {
      'id': 'p2',
      'pageNumber': 2,
      'imageUrl': bought ? '/api/catalog/chapters/chap-1/pages/p2/image' : null,
      'isLocked': true,
      'isUnlocked': bought,
    },
  ],
});

ChapterItem _previewChapter() => ChapterItem(
  id: 'chap-1',
  number: 1,
  title: 'Khởi đầu',
  releaseDate: '',
  pageCount: 1,
  pages: const [ComicPageData(pageNumber: 1, title: 'Trang 1', pageId: 'p1', isLocked: true, isUnlocked: false)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  test('Chương trả phí chưa mua: trang xem trước có ảnh, trang khác bị khóa và không giữ ảnh', () {
    final dto = _chapterDto(bought: false);

    expect(dto.isUnlocked, isFalse);
    expect(dto.pages[0].isPreview, isTrue);
    expect(dto.pages[0].isPaywalled, isFalse);
    expect(dto.pages[1].isPaywalled, isTrue);

    final mapped = ComicPageData.fromPublicPage(dto.pages[1]);
    expect(mapped.isPaywalled, isTrue);
    expect(mapped.imageUrl, isNull);
    expect(ComicPageData.fromPublicPage(dto.pages[0]).isPreview, isTrue);

    // Mua chương → mọi trang có ảnh.
    final bought = _chapterDto(bought: true);
    expect(bought.pages.every((p) => !p.isPaywalled), isTrue);
    expect(ComicPageData.fromPublicPage(bought.pages[1]).imageUrl, contains('/pages/p2/image'));
  });

  for (final mode in [ReadingMode.ltr, ReadingMode.rtl, ReadingMode.webtoon]) {
    testWidgets('Trang ngoài phần xem trước hiện ô làm mờ + một nút mở khóa chương ($mode)', (tester) async {
      ComicPageData? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingModeSwitcher(
              chapter: _previewChapter(),
              mode: mode,
              themeMode: ReaderThemeMode.night,
              onPageChanged: (_) {},
              onTapScreen: () {},
              onUnlockPage: (p) => tapped = p,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LockedPageTile), findsOneWidget);
      expect(find.text('Mở khóa chương'), findsOneWidget);
      expect(find.text('Mở khóa trang'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('unlock-chapter-from-page-1')));
      expect(tapped?.pageId, 'p1');
    });
  }

  test('Gói CBZ offline chỉ tải khi đọc được mọi trang (chưa mua chương thì chặn)', () async {
    final preview = CbzPackageService(catalogService: _FakeCatalog(_chapterDto(bought: false)));
    expect(preview.ensureNoLockedPagesForOffline('chap-1'), throwsA(isA<LockedPagesOfflineException>()));

    final bought = CbzPackageService(catalogService: _FakeCatalog(_chapterDto(bought: true)));
    await bought.ensureNoLockedPagesForOffline('chap-1');
  });
}
