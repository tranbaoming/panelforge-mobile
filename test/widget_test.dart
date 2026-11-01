import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/main.dart';

void main() {
  testWidgets('PanelForge smoke test', (WidgetTester tester) async {
    // Build our app with ProviderScope and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: PanelForgeApp()));
    await tester.pumpAndSettle();

    // Verify Explore tab loads with brand header
    expect(find.textContaining('PANELFORGE'), findsWidgets);
  });
}
