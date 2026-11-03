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
    Future<void> enterExploreAsGuest(WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: PanelForgeApp(),
        ),
      );
      await tester.pumpAndSettle();

      final guestBtn = find.text('Tiếp tục với tư cách Khách (Guest)');
      if (guestBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(guestBtn);
        await tester.pumpAndSettle();
        await tester.tap(guestBtn);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('App initially displays LoginPage when unauthenticated and routes to Explore after choosing Guest', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: PanelForgeApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that LoginPage is shown first
      expect(find.text('Đăng Nhập Độc Giả'), findsOneWidget);
      expect(find.text('Tiếp tục với tư cách Khách (Guest)'), findsOneWidget);
      // Bottom navigation bar should NOT be shown on LoginPage
      expect(find.text('Review & Cộng Tác'), findsNothing);

      // Scroll to button and tap continue as Guest
      final guestBtn = find.text('Tiếp tục với tư cách Khách (Guest)');
      await tester.ensureVisible(guestBtn);
      await tester.pumpAndSettle();
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();

      // Now ExplorePage is shown with bottom nav
      expect(find.text('Khám Phá Truyện Tranh'), findsOneWidget);
      expect(find.text('Khám Phá'), findsOneWidget);
      expect(find.text('Review & Cộng Tác'), findsOneWidget);
    });

    testWidgets('Renders app in Dark Obsidian theme and displays Explore Screen', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);

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
      // Verify Logout action button is directly visible on header
      expect(find.byIcon(Icons.logout_rounded), findsWidgets);
    });

    testWidgets('Long pressing Brand Header opens configuration dialog', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);

      final brandHeader = find.text('Khám Phá Truyện Tranh');
      expect(brandHeader, findsOneWidget);
      await tester.longPress(brandHeader);
      await tester.pumpAndSettle();

      expect(find.text('Cấu Hình Máy Chủ'), findsOneWidget);
      expect(find.text('Địa chỉ máy chủ API:'), findsOneWidget);
      expect(find.text('Lưu & Thử kết nối'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping format filter chips updates selection', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);

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
      await enterExploreAsGuest(tester);

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Solo Leveling');
      await tester.pumpAndSettle();

      expect(find.text('Solo Leveling'), findsOneWidget);
    });

    testWidgets('Navigates smoothly to Review Hub tab and verifies Dark Obsidian UI elements', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);

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
