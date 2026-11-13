import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/screens/explore/series_grid_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/main.dart';
import 'package:panelforge/navigation/app_router.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/screens/auth/login_page.dart';
import 'package:panelforge/screens/reader/comic_reader_page.dart';
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
    // Lazy Authentication: mở app vào thẳng Trang chủ, không qua màn Đăng nhập.
    Future<void> openApp(WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: PanelForgeApp()));
      await tester.pumpAndSettle();
    }

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(PanelForgeApp)));

    void signInAsReader(WidgetTester tester) {
      containerOf(tester)
          .read(authStateProvider.notifier)
          .updateState(
            const AuthState(
              role: MobileAuthRole.reader,
              user: AuthUser(id: 'u1', email: 'reader@example.com', fullName: 'Reader', isActive: true),
            ),
          );
    }

    testWidgets('App opens straight to Home with 5 tabs when not signed in', (WidgetTester tester) async {
      await openApp(tester);

      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(ForgeBrandLogo), findsOneWidget);
      for (final tab in ['Trang chủ', 'Khám phá', 'Tìm kiếm', 'Cá nhân', 'Thông báo']) {
        expect(find.byTooltip(tab), findsOneWidget);
      }
    });

    testWidgets('Opening a chapter while signed out asks to sign in; closing returns to browsing', (
      WidgetTester tester,
    ) async {
      await openApp(tester);

      containerOf(tester).read(appRouterProvider).push('/reader/s1?chapterId=c1');
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(ComicReaderPage), findsNothing);
      // Không còn lối "Khách" — đóng bằng nút ← (tooltip Đóng).
      expect(find.text('Tiếp tục với tư cách Khách (Guest)'), findsNothing);

      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byTooltip('Trang chủ'), findsOneWidget);
    });

    testWidgets('After signing in from a chapter link, the requested chapter opens', (WidgetTester tester) async {
      await openApp(tester);

      final router = containerOf(tester).read(appRouterProvider);
      router.push('/reader/s1?chapterId=c1');
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      signInAsReader(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginPage), findsNothing);
      final reader = tester.widget<ComicReaderPage>(find.byType(ComicReaderPage));
      expect(reader.seriesId, 's1');
      expect(reader.chapterId, 'c1');
    });

    testWidgets('Home top bar shows only the brand logo (no sign-in / theme buttons) and offline error state',
        (WidgetTester tester) async {
      await openApp(tester);

      expect(find.text('PANEL'), findsOneWidget);
      expect(find.text('FORGE'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsNothing);
      expect(find.byType(ThemeToggleButton), findsNothing);

      // Backend is unreachable in tests → clear error state with retry.
      expect(find.text('Không thể kết nối đến máy chủ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('Explore tab is a genre grid; tapping a genre opens its series grid', (WidgetTester tester) async {
      await openApp(tester);

      // Thanh điều hướng chỉ có biểu tượng, không chữ chú thích.
      expect(find.text('Khám phá'), findsNothing);
      await tester.tap(find.byTooltip('Khám phá'));
      await tester.pumpAndSettle();

      for (final f in ['Comic', 'Manga', 'Webtoon']) {
        expect(find.text(genreLabel(f)), findsOneWidget);
      }
      expect(find.text('Tất Cả'), findsNothing);

      await tester.tap(find.text(genreLabel('Manga')));
      await tester.pumpAndSettle();
      expect(find.byType(SeriesGridPage), findsOneWidget);
      expect(find.text(genreLabel('Manga')), findsOneWidget); // tiêu đề màn lưới

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(SeriesGridPage), findsNothing);
    });

    testWidgets('Search tab responds to text input', (WidgetTester tester) async {
      await openApp(tester);

      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Solo Leveling');
      await tester.pumpAndSettle();

      expect(find.text('Solo Leveling'), findsOneWidget);
    });

    testWidgets('Theme setting in Profile switches between dark and light and is remembered', (WidgetTester tester) async {
      await openApp(tester);
      expect(ForgeColors.isDark, isTrue);

      Future<void> pickTheme(String label) async {
        await tester.tap(find.byTooltip('Cá nhân'));
        await tester.pumpAndSettle();
        final themeRow = find.text('Giao diện');
        await tester.ensureVisible(themeRow);
        await tester.tap(themeRow);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        if (find.text(label).evaluate().isNotEmpty) {
          await tester.tapAt(const Offset(10, 10)); // đóng sheet nếu còn mở
          await tester.pumpAndSettle();
        }
      }

      await pickTheme('Sáng');
      expect(ForgeColors.isDark, isFalse);
      expect(PreferencesService.getAppThemeMode(), 'light');

      await pickTheme('Tối');
      await tester.pumpAndSettle();
      expect(ForgeColors.isDark, isTrue);
      expect(PreferencesService.getAppThemeMode(), 'dark');
    });

    testWidgets('Profile tab shows sign-in prompt, my lists, settings and contact groups', (WidgetTester tester) async {
      await openApp(tester);

      await tester.tap(find.byTooltip('Cá nhân'));
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
      // Chưa đăng nhập: không có Đổi mật khẩu / Xoá tài khoản / Đăng xuất.
      expect(find.text('Xoá tài khoản'), findsNothing);
      expect(find.text('ĐĂNG XUẤT'), findsNothing);
    });

    testWidgets('Keep-screen-on switch is saved to preferences', (WidgetTester tester) async {
      await openApp(tester);
      await tester.tap(find.byTooltip('Cá nhân'));
      await tester.pumpAndSettle();

      final toggle = find.byType(Switch);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(PreferencesService.getKeepScreenOn(), isTrue);
    });

    testWidgets('Notifications tab lists activity and links to Review center', (WidgetTester tester) async {
      await openApp(tester);
      await tester.tap(find.byTooltip('Thông báo'));
      await tester.pumpAndSettle();

      expect(find.text('GIAO DỊCH VÍ'), findsOneWidget);
      expect(find.text('ĐỌC GẦN ĐÂY'), findsOneWidget);
      expect(find.text('Trung tâm Review bản thảo'), findsOneWidget);
    });

    testWidgets('Navigates smoothly to Review Hub tab and verifies Dark Obsidian UI elements', (
      WidgetTester tester,
    ) async {
      await openApp(tester);

      // Review Hub mở từ dòng "Trung tâm Review bản thảo" ở tab Cá nhân.
      await tester.tap(find.byTooltip('Cá nhân'));
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
