import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/main.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/theme/app_theme.dart';
import 'package:panelforge/widgets/forge_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('PanelForge App UI & Navigation Automated Tests', () {
    Future<void> enterExploreAsGuest(WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: PanelForgeApp()));
      await tester.pumpAndSettle();

      final guestBtn = find.text('Tiếp tục với tư cách Khách (Guest)');
      if (guestBtn.evaluate().isNotEmpty) {
        await tester.ensureVisible(guestBtn);
        await tester.pumpAndSettle();
        await tester.tap(guestBtn);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('App initially displays LoginPage when unauthenticated and routes to Home after choosing Guest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: PanelForgeApp()));
      await tester.pumpAndSettle();

      // Verify that LoginPage is shown first
      expect(find.text('Đăng Nhập Độc Giả'), findsOneWidget);
      expect(find.text('Tiếp tục với tư cách Khách (Guest)'), findsOneWidget);
      // Bottom navigation bar should NOT be shown on LoginPage
      expect(find.text('Trang chủ'), findsNothing);

      final guestBtn = find.text('Tiếp tục với tư cách Khách (Guest)');
      await tester.ensureVisible(guestBtn);
      await tester.pumpAndSettle();
      await tester.tap(guestBtn);
      await tester.pumpAndSettle();

      // Home with 5-tab bottom navigation
      expect(find.byType(ForgeBrandLogo), findsOneWidget);
      for (final tab in ['Trang chủ', 'Khám phá', 'Tìm kiếm', 'Cá nhân', 'Thông báo']) {
        expect(find.text(tab), findsOneWidget);
      }
    });

    testWidgets('Home shows brand logo, guest login and offline error state', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);

      expect(find.text('PANEL'), findsOneWidget);
      expect(find.text('FORGE'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);

      // Backend is unreachable in tests → clear error state with retry.
      expect(find.text('Không thể kết nối đến máy chủ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('Explore tab shows format filter chips that can be toggled', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);

      await tester.tap(find.text('Khám phá'));
      await tester.pumpAndSettle();

      expect(find.text('Tất Cả'), findsOneWidget);
      expect(find.text('Comic'), findsOneWidget);
      await tester.tap(find.text('Manga'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Webtoon'));
      await tester.pumpAndSettle();
    });

    testWidgets('Search tab responds to text input', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);

      await tester.tap(find.text('Tìm kiếm'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Solo Leveling');
      await tester.pumpAndSettle();

      expect(find.text('Solo Leveling'), findsOneWidget);
    });

    testWidgets('Theme toggle switches between dark and light and is remembered', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);
      expect(ForgeColors.isDark, isTrue);

      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();
      expect(ForgeColors.isDark, isFalse);
      expect(PreferencesService.getAppThemeMode(), 'light');

      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      final themeRow = find.text('Giao diện');
      await tester.ensureVisible(themeRow);
      await tester.tap(themeRow);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tối').last);
      await tester.pumpAndSettle();
      expect(ForgeColors.isDark, isTrue);
      expect(PreferencesService.getAppThemeMode(), 'dark');
    });

    testWidgets('Profile tab shows guest prompt, my lists, settings and contact groups', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);

      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập / Đăng ký'), findsOneWidget);
      for (final label in ['ĐỌC SAU', 'THEO DÕI', 'ĐÃ MỞ KHÓA']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final label in [
        'Giao diện',
        'Giữ màn hình sáng khi đọc',
        'Xoá lịch sử đọc',
        'Xoá bộ nhớ đệm',
        'Đồng bộ ngay',
        'Trung tâm Review bản thảo',
        'Phiên bản',
        'Liên Hệ Admin',
        'Chia Sẻ Ứng Dụng',
      ]) {
        final row = find.text(label);
        await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
        expect(row, findsOneWidget);
      }
      // Guest: không có Đổi mật khẩu / Xoá tài khoản / Đăng xuất.
      expect(find.text('Xoá tài khoản'), findsNothing);
      expect(find.text('ĐĂNG XUẤT'), findsNothing);
    });

    testWidgets('Keep-screen-on switch is saved to preferences', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();

      final toggle = find.byType(Switch);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(PreferencesService.getKeepScreenOn(), isTrue);
    });

    testWidgets('Notifications tab lists activity and links to Review center', (WidgetTester tester) async {
      await enterExploreAsGuest(tester);
      await tester.tap(find.text('Thông báo'));
      await tester.pumpAndSettle();

      expect(find.text('GIAO DỊCH VÍ'), findsOneWidget);
      expect(find.text('ĐỌC GẦN ĐÂY'), findsOneWidget);
      expect(find.text('Trung tâm Review bản thảo'), findsOneWidget);
    });

    testWidgets('Navigates smoothly to Review Hub tab and verifies Dark Obsidian UI elements', (
      WidgetTester tester,
    ) async {
      await enterExploreAsGuest(tester);

      // Review Hub mở từ dòng "Trung tâm Review bản thảo" ở tab Cá nhân.
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      final reviewRow = find.text('Trung tâm Review bản thảo');
      await tester.ensureVisible(reviewRow);
      await tester.pumpAndSettle();
      await tester.tap(reviewRow);
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
