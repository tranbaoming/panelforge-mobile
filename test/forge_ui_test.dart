import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/models/api_dtos.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/widgets/forge_ui.dart';

SeriesItem _series(String id, {int chapters = 12}) => SeriesItem(
  id: id,
  title: 'Moon Blade $id',
  author: 'Studio Moon',
  artist: 'Studio Moon',
  format: ComicFormat.manga,
  coverGradientStart: '0xFF000000',
  coverGradientEnd: '0xFF000000',
  synopsisQuote: '',
  fullSynopsis: '',
  views: 12500,
  readProgressChapter: 0,
  totalChapters: chapters,
  genres: const ['Action', 'Manga'],
  chapters: const [],
  editorialNote: '',
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  test('reading history keeps one entry per series, newest first', () async {
    ReadingHistoryEntry entry(String series, int ch) => ReadingHistoryEntry(
      seriesId: series,
      seriesTitle: series,
      chapterId: '$series-$ch',
      chapterNumber: ch,
      readAt: DateTime.now(),
    );
    await PreferencesService.saveReadingProgress(entry('a', 1));
    await PreferencesService.saveReadingProgress(entry('b', 3));
    await PreferencesService.saveReadingProgress(entry('a', 2));

    final history = PreferencesService.getReadingHistory();
    expect(history.map((e) => e.seriesId), ['a', 'b']);
    expect(PreferencesService.getReadingHistoryFor('a')!.chapterNumber, 2);
  });

  test('favorite toggles on and off', () async {
    expect(await PreferencesService.toggleFavorite('s1'), isTrue);
    expect(PreferencesService.isFavorite('s1'), isTrue);
    expect(await PreferencesService.toggleFavorite('s1'), isFalse);
    expect(PreferencesService.getFavorites(), isEmpty);
  });

  test('formatting helpers', () {
    expect(formatViews(12500), '12.5K');
    expect(timeAgo(DateTime.now().subtract(const Duration(minutes: 10))), '10 Phút Trước');
    expect(genreLabel('Action'), '⚔️ Action');
  });

  testWidgets('ComicCard shows HOT, views, time badge, title and chapter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComicCard(series: _series('1'), width: 160, isHot: true, timeBadge: 'Hôm nay', onTap: () {}),
        ),
      ),
    );

    expect(find.text('HOT'), findsOneWidget);
    expect(find.text('12.5K'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Moon Blade 1'), findsOneWidget);
    expect(find.text('Chapter 12'), findsOneWidget);
  });

  test('catalog DTO maps cover, completed status and created date into SeriesItem', () {
    final dto = PublicSeriesDto.fromJson({
      'id': 's1',
      'title': 'Moon Blade',
      'genre': 'Action',
      'format': 'Manga',
      'readingDirection': 'RightToLeft',
      'studioName': 'Studio Moon',
      'publishedChapterCount': 3,
      'coverUrl': '/api/catalog/series/s1/cover?v=abc',
      'isCompleted': true,
      'createdAt': '2026-10-01T00:00:00Z',
      'viewCount': 1520,
      'viewsLast1Day': 12,
      'viewsLast7Days': 340,
      'viewsLast30Days': 900,
    });
    final item = SeriesItem.fromPublicDto(dto);

    expect(item.coverUrl, endsWith('/api/catalog/series/s1/cover?v=abc'));
    expect(item.coverUrl, startsWith('http'));
    expect(item.isCompleted, isTrue);
    expect(item.createdAt, DateTime.utc(2026, 10, 1));
    expect([item.views, item.viewsLast1Day, item.viewsLast7Days, item.viewsLast30Days], [1520, 12, 340, 900]);
    expect(
      SeriesItem.fromPublicDto(PublicSeriesDto.fromJson({'id': 's3', 'publishedChapterCount': 9})).views,
      0,
      reason: 'không còn lượt xem ước lượng theo số chương',
    );
    expect(SeriesItem.fromPublicDto(PublicSeriesDto.fromJson({'id': 's2'})).coverUrl, isNull);
  });
}
