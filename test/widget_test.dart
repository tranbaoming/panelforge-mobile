import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/main.dart';

void main() {
  testWidgets('PanelForge smoke test', (WidgetTester tester) async {
    // Build our app with ProviderScope and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: PanelForgeApp()));
    await tester.pumpAndSettle();

    // Lazy Authentication: mở app vào thẳng Trang chủ (logo PANELFORGE), không qua màn Đăng nhập.
    expect(find.bySemanticsLabel('PANELFORGE'), findsWidgets);
    expect(find.byTooltip('Trang chủ'), findsOneWidget);
  });
}
