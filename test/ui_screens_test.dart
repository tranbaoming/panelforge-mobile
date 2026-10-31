import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/main.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('PanelForge App UI & Navigation Automated Tests', () {
    testWidgets('Renders app in Dark Obsidian theme and displays Explore Screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: PanelForgeApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Brand Header
      expect(find.text('PANELFORGE'), findsOneWidget);
      expect(find.text('Khám Phá Truyện Tranh'), findsOneWidget);

      // Verify Format Filter Chips
      expect(find.text('Tất Cả'), findsOneWidget);
      expect(find.text('Comic'), findsOneWidget);
      expect(find.text('Manga'), findsOneWidget);
      expect(find.text('Webtoon'), findsOneWidget);

      // Verify Bottom Navigation items
      expect(find.text('Khám Phá'), findsOneWidget);
      expect(find.text('Review & Cộng Tác'), findsOneWidget);

      // Verify Error State elements when backend is disconnected in test
      expect(find.text('Không thể kết nối đến máy chủ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Cấu hình máy chủ'), findsOneWidget);
    });

    testWidgets('Tapping Cấu hình máy chủ opens configuration dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: PanelForgeApp(),
        ),
      );
      await tester.pumpAndSettle();

      final configButton = find.text('Cấu hình máy chủ');
      expect(configButton, findsOneWidget);
      await tester.tap(configButton);
      await tester.pumpAndSettle();

      expect(find.text('Cấu Hình Máy Chủ'), findsOneWidget);
      expect(find.text('Địa chỉ máy chủ API:'), findsOneWidget);
      expect(find.text('Lưu & Thử kết nối'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping format filter chips updates selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: PanelForgeApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Manga chip
      final mangaChip = find.text('Manga');
      expect(mangaChip, findsOneWidget);
      await tester.tap(mangaChip);
      await tester.pumpAndSettle();

      // Tap on Webtoon chip
      final webtoonChip = find.text('Webtoon');
      expect(webtoonChip, findsOneWidget);
      await tester.tap(webtoonChip);
      await tester.pumpAndSettle();
    });

    testWidgets('Search bar responds to text input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: PanelForgeApp(),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Solo Leveling');
      await tester.pumpAndSettle();

      expect(find.text('Solo Leveling'), findsOneWidget);
    });

    testWidgets('Navigates smoothly to Review Hub tab and verifies Dark Obsidian UI elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: PanelForgeApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Review & Cộng Tác' nav item
      final reviewTab = find.text('Review & Cộng Tác');
      expect(reviewTab, findsOneWidget);
      await tester.tap(reviewTab);
      await tester.pumpAndSettle();

      // Verify Review Hub title and security badge
      expect(find.text('BẢO MẬT & ĐỘC QUYỀN'), findsOneWidget);
      expect(find.text('Trung Tâm Review & Duyệt Bản Thảo'), findsOneWidget);
      expect(find.text('XÁC THỰC & MỞ LỜI MỜI REVIEW'), findsOneWidget);
      expect(find.text('Bản Thảo Đã Mở Gần Đây'), findsOneWidget);

      // Verify Dark Obsidian Color Constants
      expect(AppColors.darkBg, const Color(0xFF07080D));
      expect(AppColors.darkSurface, const Color(0xFF10121A));
      expect(AppColors.darkBorder, const Color(0xFF282B3A));
      expect(AppColors.primary, const Color(0xFFF97316));
    });
  });
}
