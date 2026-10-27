import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/main.dart';

void main() {
  testWidgets('PanelForge smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PanelForgeApp());
    await tester.pumpAndSettle();

    // Verify Explore tab loads
    expect(find.text('PANELFORGE'), findsOneWidget);
  });
}
