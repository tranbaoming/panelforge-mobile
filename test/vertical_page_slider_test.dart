import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/widgets/vertical_page_slider.dart';

Widget _host({required ValueChanged<int> onPage, required ScrollController scroll, int current = 1}) => MaterialApp(
  home: Scaffold(
    body: VerticalPageScrubber(
      currentPage: current,
      totalPages: 11,
      trackMargin: const EdgeInsets.only(top: 50, bottom: 50),
      onPageSelected: onPage,
      child: ListView.builder(
        controller: scroll,
        itemCount: 40,
        itemBuilder: (_, i) => SizedBox(height: 200, child: Text('Trang ${i + 1}')),
      ),
    ),
  ),
);

double _opacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: find.byKey(const ValueKey('vertical-page-slider')), matching: find.byType(AnimatedOpacity)),
    )
    .opacity;

void main() {
  testWidgets('Bình thường ẩn; lướt ở mép phải vẫn cuộn nội dung', (tester) async {
    final scroll = ScrollController();
    final pages = <int>[];
    await tester.pumpWidget(_host(onPage: pages.add, scroll: scroll));

    expect(_opacity(tester), 0);
    final size = tester.getSize(find.byType(Scaffold));
    await tester.dragFrom(Offset(size.width - 10, 400), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(scroll.offset, greaterThan(0));
    expect(pages, isEmpty);
    expect(_opacity(tester), 0);
  });

  testWidgets('Bấm đè ở mép phải hiện thanh trượt, kéo để nhảy trang, nhấc tay thì ẩn', (tester) async {
    final scroll = ScrollController();
    final pages = <int>[];
    await tester.pumpWidget(_host(onPage: pages.add, scroll: scroll));

    final size = tester.getSize(find.byType(Scaffold));
    final x = size.width - 10;
    final gesture = await tester.startGesture(Offset(x, size.height / 2));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
    expect(find.text('6 / 11'), findsOneWidget);

    await gesture.moveTo(Offset(x, size.height - 51));
    await tester.pump();
    expect(pages.last, 11);
    expect(find.text('11 / 11'), findsOneWidget);
    expect(scroll.offset, 0, reason: 'đang tua trang thì không cuộn nội dung');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_opacity(tester), 0);
    expect(find.text('11 / 11'), findsNothing);
  });

  testWidgets('Bấm đè giữa màn hình không hiện thanh trượt', (tester) async {
    final pages = <int>[];
    await tester.pumpWidget(_host(onPage: pages.add, scroll: ScrollController()));

    final size = tester.getSize(find.byType(Scaffold));
    await tester.longPressAt(Offset(size.width / 2, size.height / 2));
    await tester.pumpAndSettle();

    expect(pages, isEmpty);
    expect(_opacity(tester), 0);
  });
}
