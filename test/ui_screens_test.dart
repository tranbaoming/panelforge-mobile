import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/screens/explore/series_grid_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/main.dart';
import 'package:panelforge/navigation/app_router.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/screens/auth/login_page.dart';
import 'package:panelforge/screens/profile/legal_page.dart';
import 'package:panelforge/screens/profile/settings_page.dart';
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
      for (final tab in ['Trang chủ', 'Dành cho bạn', 'Tìm kiếm', 'Cửa hàng', 'Cá nhân']) {
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

    testWidgets('Home top bar shows only the brand logo (no sign-in / theme buttons) and offline error state', (
      WidgetTester tester,
    ) async {
      await openApp(tester);

      expect(find.text('PANEL'), findsOneWidget);
      expect(find.text('FORGE'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsNothing);
      expect(find.byType(ThemeToggleButton), findsNothing);

      // Backend is unreachable in tests → clear error state with retry.
      expect(find.text('Không thể kết nối đến máy chủ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('For You tab renders without VIP banner', (WidgetTester tester) async {
      await openApp(tester);

      await tester.tap(find.byTooltip('Dành cho bạn'));
      await tester.pumpAndSettle();
      expect(find.text('VIP PANELFORGE'), findsNothing);
      expect(find.text('Không thể kết nối đến máy chủ'), findsOneWidget);
    });

    testWidgets('Shop tab shows the balance card and the top-up packages', (WidgetTester tester) async {
      await openApp(tester);

      await tester.tap(find.byTooltip('Cửa hàng'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập để xem số dư Ví và nạp tiền.'), findsOneWidget);
      expect(find.text('NẠP VÍ'), findsOneWidget);
      expect(find.text('GÓI VIP'), findsNothing);
      expect(find.text('+10.000đ'), findsOneWidget);
    });

    testWidgets('Genres page is a genre grid; tapping a genre opens its series grid', (WidgetTester tester) async {
      await openApp(tester);

      containerOf(tester).read(appRouterProvider).push('/genres');
      await tester.pumpAndSettle();

      for (final f in ['Comic', 'Manga', 'Webtoon']) {
        expect(find.text(genreLabel(f)), findsOneWidget);
      }

      await tester.tap(find.text(genreLabel('Manga')));
      await tester.pumpAndSettle();
      expect(find.byType(SeriesGridPage), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded).last);
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

    // Cài đặt mở từ bánh răng (tooltip "Cài đặt") ở tab Cá nhân.
    Future<void> openSettings(WidgetTester tester) async {
      if (find.byType(SettingsPage).evaluate().isNotEmpty) return;
      await tester.tap(find.byTooltip('Cá nhân'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cài đặt'));
      await tester.pumpAndSettle();
    }

    Future<void> scrollTo(WidgetTester tester, Finder row) async {
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
    }

    testWidgets('Theme setting in Settings switches between dark and light and is remembered', (
      WidgetTester tester,
    ) async {
      await openApp(tester);
      expect(ForgeColors.isDark, isTrue);

      Future<void> pickTheme(String label) async {
        await openSettings(tester);
        await tester.tap(find.text('Giao diện'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await pickTheme('Sáng');
      expect(ForgeColors.isDark, isFalse);
      expect(PreferencesService.getAppThemeMode(), 'light');

      await pickTheme('Tối');
      expect(ForgeColors.isDark, isTrue);
      expect(PreferencesService.getAppThemeMode(), 'dark');
    });

    testWidgets('Profile tab shows the create-account card, my lists and History / Favorites tabs', (
      WidgetTester tester,
    ) async {
      await openApp(tester);
      await tester.tap(find.byTooltip('Cá nhân'));
      await tester.pumpAndSettle();

      expect(find.text('Tạo tài khoản'), findsOneWidget);
      expect(find.text('Đăng nhập / Đăng ký'), findsOneWidget);
      for (final label in ['ĐỌC SAU', 'THEO DÕI', 'ĐÃ MỞ KHÓA', 'Lịch sử', 'Yêu thích']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Bạn chưa đọc truyện nào.'), findsOneWidget);

      await tester.tap(find.text('Yêu thích'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa có truyện yêu thích'), findsOneWidget);
    });

    testWidgets('Settings lists account, app, help and legal sections (guest)', (WidgetTester tester) async {
      await openApp(tester);
      await openSettings(tester);

      for (final label in [
        'Tài khoản',
        'Đăng nhập / Đăng ký',
        'Cài đặt ứng dụng',
        'Ngôn ngữ',
        'Giao diện',
        'Giữ màn hình sáng khi đọc',
        'Thông báo',
        'Xoá lịch sử đọc',
        'Xoá bộ nhớ đệm',
        'Đồng bộ ngay',
        'Trợ giúp',
        'Câu hỏi thường gặp',
        'Liên hệ hỗ trợ',
        'Khác',
        'Điều khoản sử dụng',
        'Chính sách bảo mật',
        'Bản quyền',
        'Giấy phép mã nguồn mở',
        'Phiên bản',
      ]) {
        final row = find.text(label);
        await scrollTo(tester, row);
        expect(row, findsOneWidget, reason: label);
      }
      // Chưa đăng nhập: không có Đổi mật khẩu / Đăng xuất / Xoá tài khoản / Review.
      expect(find.text('Nhập mã Review'), findsNothing);
      expect(find.text('Đổi mật khẩu'), findsNothing);
      expect(find.text('Xoá tài khoản'), findsNothing);
      expect(find.text('Đăng xuất'), findsNothing);
    });

    testWidgets('Signed-in Settings shows password, trusted device, logout and delete account', (
      WidgetTester tester,
    ) async {
      await openApp(tester);
      signInAsReader(tester);
      await tester.pumpAndSettle();
      await openSettings(tester);

      for (final label in ['Hồ sơ của tôi', 'Đổi mật khẩu', 'Thiết bị tin cậy', 'Lịch sử giao dịch', 'Đăng xuất']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      final delete = find.text('Xoá tài khoản');
      await scrollTo(tester, delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      // Hộp xác nhận nêu rõ hậu quả; Huỷ thì không làm gì.
      expect(find.textContaining('reader@example.com sẽ bị vô hiệu hóa'), findsOneWidget);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
    });

    testWidgets('Terms of Service and FAQ open from Settings', (WidgetTester tester) async {
      await openApp(tester);
      await openSettings(tester);

      final terms = find.text('Điều khoản sử dụng');
      await scrollTo(tester, terms);
      await tester.tap(terms);
      await tester.pumpAndSettle();
      expect(find.byType(LegalPage), findsOneWidget);
      final wallet = find.text('4. Ví PanelForge và thanh toán');
      await scrollTo(tester, wallet);
      expect(wallet, findsOneWidget);

      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      final faq = find.text('Câu hỏi thường gặp');
      await tester.scrollUntilVisible(faq, -200, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      await tester.tap(faq);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mua bản Tiếng Việt có đọc được bản English không?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('mua ngôn ngữ nào đọc ngôn ngữ đó'), findsOneWidget);
    });

    testWidgets('Keep-screen-on switch is saved to preferences', (WidgetTester tester) async {
      await openApp(tester);
      await openSettings(tester);

      final toggle = find.byType(Switch);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(PreferencesService.getKeepScreenOn(), isTrue);
    });

    testWidgets('Notifications page (from Profile) lists activity without Review center', (
      WidgetTester tester,
    ) async {
      await openApp(tester);
      await tester.tap(find.byTooltip('Cá nhân'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thông báo'));
      await tester.pumpAndSettle();

      expect(find.text('GIAO DỊCH VÍ'), findsOneWidget);
      expect(find.text('ĐỌC GẦN ĐÂY'), findsOneWidget);
      expect(find.text('Trung tâm Review bản thảo'), findsNothing);
    });
  });
}
