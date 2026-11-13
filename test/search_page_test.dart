import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/screens/explore/search_page.dart';

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
  testWidgets('shows only the search box (no app bar, no results) while the query is empty', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Nhập tên truyện hoặc tác giả'), findsOneWidget);
    expect(find.text('Moon Blade'), findsNothing);
    expect(find.text('Không tìm thấy bộ truyện nào phù hợp'), findsNothing);
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

  testWidgets('clear button empties the query and hides the results', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-field')), 'iron');
    await tester.pump();
    expect(find.text('Iron Lotus'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa'));
    await tester.pump();
    expect(find.text('Iron Lotus'), findsNothing);
  });
}
