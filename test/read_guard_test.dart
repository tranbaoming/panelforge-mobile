import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/navigation/read_guard.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/screens/auth/login_page.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/widgets/read_login_prompt_sheet.dart';

/// Trang có nút "Đọc" gọi [openReaderGuarded] như các nút trong app.
class _ReadButtonPage extends ConsumerWidget {
  const _ReadButtonPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: () => openReaderGuarded(context, ref, 's1', 'c 1'),
        child: const Text('Đọc Tiếp'),
      ),
    ),
  );
}

Widget _app() {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _ReadButtonPage()),
      GoRoute(
        path: '/login',
        builder: (_, state) => LoginPage(redirect: state.uri.queryParameters['redirect']),
      ),
      GoRoute(
        path: '/reader/:id',
        builder: (_, state) =>
            Scaffold(body: Text('reader ${state.pathParameters['id']} ${state.uri.queryParameters['chapterId']}')),
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void _signIn(WidgetTester tester) {
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
      .read(authStateProvider.notifier)
      .updateState(
        const AuthState(
          role: MobileAuthRole.reader,
          user: AuthUser(id: 'u1', email: 'reader@example.com', fullName: 'Reader', isActive: true),
        ),
      );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  testWidgets('read button shows the sign-in prompt sheet first', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Đọc Tiếp'));
    await tester.pumpAndSettle();

    expect(find.byType(ReadLoginPromptSheet), findsOneWidget);
    expect(find.text('Đăng nhập để theo dõi truyện bạn yêu thích và lưu lại lịch sử đọc nhé!'), findsOneWidget);
    expect(find.text('Tiếp Theo'), findsOneWidget);
    expect(find.text('Để sau'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('"Để sau" closes the prompt without opening login or the chapter', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Đọc Tiếp'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();

    expect(find.byType(ReadLoginPromptSheet), findsNothing);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.textContaining('reader s1'), findsNothing);
    expect(find.text('Đọc Tiếp'), findsOneWidget);
  });

  testWidgets('"Tiếp Theo" opens login, then the same chapter opens after login', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Đọc Tiếp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp Theo'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.textContaining('reader s1'), findsNothing);

    _signIn(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('reader s1 c 1'), findsOneWidget);
  });

  testWidgets('closing the login screen does not open the chapter', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('Đọc Tiếp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp Theo'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.textContaining('reader s1'), findsNothing);
    expect(find.text('Đọc Tiếp'), findsOneWidget);
  });

  testWidgets('a signed-in reader opens the chapter directly', (tester) async {
    await tester.pumpWidget(_app());
    _signIn(tester);
    await tester.tap(find.text('Đọc Tiếp'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('reader s1 c 1'), findsOneWidget);
  });

  test('only guest/unauthenticated users are blocked from reading', () {
    expect(canReadChapters(AuthState.unauthenticated()), isFalse);
    expect(canReadChapters(AuthState.guest()), isFalse);
    expect(
      canReadChapters(
        const AuthState(
          role: MobileAuthRole.reader,
          user: AuthUser(id: 'u', email: 'e@x', fullName: 'R', isActive: true),
        ),
      ),
      isTrue,
    );
  });

  test('login redirect only accepts in-app paths', () {
    expect(safeLoginRedirect('/reader/s1?chapterId=c1'), '/reader/s1?chapterId=c1');
    expect(safeLoginRedirect(null), isNull);
    expect(safeLoginRedirect(''), isNull);
    expect(safeLoginRedirect('https://evil.example'), isNull);
    expect(safeLoginRedirect('//evil.example'), isNull);
    expect(safeLoginRedirect('/login?redirect=/x'), isNull);
    expect(loginPathFor('/reader/s1?chapterId=c1'), '/login?redirect=%2Freader%2Fs1%3FchapterId%3Dc1');
  });
}
