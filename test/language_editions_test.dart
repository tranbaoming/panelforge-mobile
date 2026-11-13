import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/models/api_dtos.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/widgets/edition_language_menu.dart';
import 'package:panelforge/widgets/series_rating_bar.dart';

SeriesItem _series() => const SeriesItem(
  id: 'series-1',
  title: 'Moon Blade',
  author: 'Studio Moon',
  artist: 'Studio Moon',
  format: ComicFormat.manga,
  coverGradientStart: '0xFF000000',
  coverGradientEnd: '0xFF000000',
  synopsisQuote: '',
  fullSynopsis: '',
  views: 0,
  readProgressChapter: 0,
  totalChapters: 1,
  genres: ['Action'],
  chapters: [],
  editorialNote: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  test('Đọc bản ngôn ngữ + giá theo ngôn ngữ từ API chương và chi tiết bộ truyện', () {
    final read = PublicChapterReadDto.fromJson({
      'id': 'chap-1',
      'seriesId': 'series-1',
      'seriesTitle': 'Moon Blade',
      'readingDirection': 'LeftToRight',
      'chapterNumber': 1,
      'isLocked': true,
      'priceVnd': 15000,
      'isUnlocked': true,
      'language': 'en',
      'languages': [
        {'language': 'vi', 'priceVnd': 10000, 'isUnlocked': false},
        {'language': 'en', 'priceVnd': 15000, 'isUnlocked': true},
      ],
      'pages': const [],
    });
    expect(read.language, 'en');
    expect(read.languages.map((l) => l.language), ['vi', 'en']);
    expect(read.languages.first.isUnlocked, isFalse);
    expect(read.toJson()['languages'], hasLength(2));

    final detail = PublicSeriesDetailDto.fromJson({
      'id': 'series-1',
      'title': 'Moon Blade',
      'genre': 'Action',
      'format': 'Manga',
      'readingDirection': 'LeftToRight',
      'studioName': 'Studio Moon',
      'ratingAverage': 4.5,
      'ratingCount': 2,
      'myRating': 5,
      'chapters': [
        {
          'id': 'chap-1',
          'chapterNumber': 1,
          'isLocked': true,
          'priceVnd': 10000,
          'languages': [
            {'language': 'vi', 'priceVnd': 10000, 'isUnlocked': false},
          ],
        },
      ],
    });
    expect(detail.ratingAverage, 4.5);
    expect(detail.myRating, 5);
    expect(detail.chapters.single.languages.single.priceVnd, 10000);
  });

  test('Yêu cầu mua chương gửi kèm ngôn ngữ; ngôn ngữ đọc lưu trong Preferences', () async {
    expect(const UnlockChapterRequest(chapterId: 'c', language: 'ja').toJson()['language'], 'ja');

    expect(PreferencesService.getContentLanguage(), 'vi');
    await PreferencesService.setContentLanguage('ja');
    expect(PreferencesService.getContentLanguage(), 'ja');
  });

  testWidgets('Menu bản ngôn ngữ hiện ổ khóa + giá cho bản chưa mua', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditionLanguageMenu(
            current: 'vi',
            options: const [
              ChapterLanguageOption(language: 'vi'),
              ChapterLanguageOption(language: 'en', priceVnd: 15000, isUnlocked: false),
            ],
            onSelected: (l) => picked = l,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('edition-language-menu')));
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(picked, 'en');
  });

  testWidgets('Thanh đánh giá hiện điểm trung bình và sao của tôi', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SeriesRatingBar(series: _series(), average: 4.5, count: 2, myRating: 4)),
        ),
      ),
    );

    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('(2 đánh giá)'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5)); // 1 biểu tượng điểm + 4 sao đã chọn
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
  });
}
