import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/screens/explore/search_page.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/widgets/forge_ui.dart';

SeriesItem _series(String id, String title, String studio) => SeriesItem(
  id: id,
  title: title,
  author: studio,
  artist: studio,
  format: ComicFormat.manga,
  coverGradientStart: '',
  coverGradientEnd: '',
  synopsisQuote: '',
  fullSynopsis: '',
  views: 0,
  readProgressChapter: 0,
  totalChapters: 7,
  genres: const ['Action'],
  chapters: const [],
  editorialNote: '',
);

final _catalog = [
  _series('s1', 'Moon Blade', 'Studio Aurora'),
  _series('s2', 'Iron Lotus', 'Kite Works'),
  _series('s3', 'Sky Harbor', 'Studio Aurora'),
];

Widget _app() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => SearchPage(loadCatalog: () async => _catalog),
      ),
      GoRoute(path: '/series/:id', builder: (_, state) => Text('detail ${state.pathParameters['id']}')),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  filterTests();

  testWidgets('shows the search box and the full A–Z list while the query is empty', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Tìm theo tên truyện, tác giả...'), findsOneWidget);
    expect(find.text('Truyện (A–Z)'), findsOneWidget);
    final iron = tester.getTopLeft(find.text('Iron Lotus')).dy;
    final moon = tester.getTopLeft(find.text('Moon Blade')).dy;
    final sky = tester.getTopLeft(find.text('Sky Harbor')).dy;
    expect(iron < moon && moon < sky, isTrue, reason: 'A–Z order');
    expect(find.text('Không tìm thấy bộ truyện nào phù hợp'), findsNothing);
  });

  testWidgets('list covers are portrait 3:4 and shown whole, not cropped', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final covers = find.byType(SeriesCover);
    expect(covers, findsNWidgets(_catalog.length));
    final size = tester.getSize(covers.first);
    expect(size.width / size.height, closeTo(3 / 4, 0.01));
    expect(find.byType(FittedBox), findsNothing);
  });

  testWidgets('filters by title, case-insensitive, as the user types', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-field')), 'moon');
    await tester.pump();

    expect(find.text('Moon Blade'), findsOneWidget);
    expect(find.text('Iron Lotus'), findsNothing);
  });

  testWidgets('filters by studio and opens the series detail on tap', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-field')), 'AURORA');
    await tester.pump();

    expect(find.text('Moon Blade'), findsOneWidget);
    expect(find.text('Sky Harbor'), findsOneWidget);
    expect(find.text('Iron Lotus'), findsNothing);

    await tester.tap(find.text('Sky Harbor'));
    await tester.pumpAndSettle();
    expect(find.text('detail s3'), findsOneWidget);
  });

  testWidgets('shows the not-found message when nothing matches', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-field')), 'zzz');
    await tester.pump();

    expect(find.text('Không tìm thấy bộ truyện nào phù hợp'), findsOneWidget);
  });

  testWidgets('clear button empties the query and brings back the full list', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-field')), 'iron');
    await tester.pump();
    expect(find.text('Iron Lotus'), findsOneWidget);

    expect(find.text('Moon Blade'), findsNothing);

    await tester.tap(find.byTooltip('Xóa'));
    await tester.pump();
    expect(find.text('Truyện (A–Z)'), findsOneWidget);
    expect(find.text('Moon Blade'), findsOneWidget);
  });
}

SeriesItem _rich(String id, String title, {required List<String> genres, int views = 0, bool completed = false}) =>
    SeriesItem(
      id: id,
      title: title,
      author: 'Studio',
      artist: 'Studio',
      format: ComicFormat.manga,
      coverGradientStart: '',
      coverGradientEnd: '',
      synopsisQuote: '',
      fullSynopsis: '',
      views: views,
      readProgressChapter: 0,
      totalChapters: 3,
      genres: genres,
      chapters: const [],
      editorialNote: '',
      isCompleted: completed,
    );

final _richCatalog = [
  _rich('a', 'Alpha', genres: ['Action'], views: 10),
  _rich('b', 'Bravo', genres: ['Romance'], views: 50, completed: true),
  _rich('c', 'Charlie', genres: ['Action', 'Romance'], views: 30, completed: true),
];

Widget _richApp() => MaterialApp.router(
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => SearchPage(loadCatalog: () async => _richCatalog),
      ),
      GoRoute(path: '/series/:id', builder: (_, state) => Text('detail ${state.pathParameters['id']}')),
    ],
  ),
);

Future<void> _pick(WidgetTester tester, String chipKey, String item) async {
  await tester.tap(find.byKey(ValueKey(chipKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void filterTests() {
  group('filters, sort and search history', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.init();
    });

    testWidgets('genre and status filters narrow the list', (tester) async {
      await tester.pumpWidget(_richApp());
      await tester.pumpAndSettle();

      await _pick(tester, 'filter-genre', 'Romance');
      expect(find.text('Kết quả (2)'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);

      await _pick(tester, 'filter-status', 'Hoàn thành');
      expect(find.text('Kết quả (2)'), findsOneWidget);

      await tester.tap(find.text('Bỏ lọc'));
      await tester.pumpAndSettle();
      expect(find.text('Truyện (A–Z)'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
    });

    testWidgets('sorting by views puts the most-read first', (tester) async {
      await tester.pumpWidget(_richApp());
      await tester.pumpAndSettle();

      await _pick(tester, 'filter-sort', 'Xem nhiều');
      final bravo = tester.getTopLeft(find.text('Bravo')).dy;
      final charlie = tester.getTopLeft(find.text('Charlie')).dy;
      final alpha = tester.getTopLeft(find.text('Alpha')).dy;
      expect(bravo < charlie && charlie < alpha, isTrue);
    });

    testWidgets('submitted searches are remembered and can be reused or removed', (tester) async {
      await tester.pumpWidget(_richApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('search-field')), 'char');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(PreferencesService.getRecentSearches(), ['char']);

      await tester.tap(find.byTooltip('Xóa'));
      await tester.pumpAndSettle();
      expect(find.text('Tìm gần đây'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('recent-char')));
      await tester.pumpAndSettle();
      expect(find.text('Kết quả (1)'), findsOneWidget);

      await tester.tap(find.byTooltip('Xóa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Tìm gần đây'), findsNothing);
      expect(PreferencesService.getRecentSearches(), isEmpty);
    });
  });
}
