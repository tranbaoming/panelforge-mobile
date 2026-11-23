import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelforge/navigation/scaffold_with_nav_bar.dart';
import 'package:panelforge/providers/connectivity_provider.dart';
import 'package:panelforge/services/auth_service.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('Offline Security & Offline-First Banner', () {
    test('AuthService.logout() clears offline downloaded chapter IDs', () async {
      await PreferencesService.addOfflineChapterId('chap-paid-1');
      await PreferencesService.addOfflineChapterId('chap-paid-2');
      expect(PreferencesService.getOfflineChapterIds(), containsAll(['chap-paid-1', 'chap-paid-2']));

      final auth = AuthService();
      await auth.logout();

      expect(PreferencesService.getOfflineChapterIds(), isEmpty);
    });

    testWidgets('Shows offline banner with quick link to /downloads when disconnected', (tester) async {
      var openedDownloads = false;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => ScaffoldWithNavBar(navigationShell: shell),
            branches: [
              for (var i = 0; i < 5; i++)
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: i == 0 ? '/' : '/tab$i',
                      builder: (_, _) => Center(child: Text('Tab $i')),
                    ),
                  ],
                ),
            ],
          ),
          GoRoute(
            path: '/downloads',
            builder: (_, _) {
              openedDownloads = true;
              return const Scaffold(body: Text('Downloads Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOfflineProvider.overrideWith((ref) => Stream.value(true)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
      expect(find.text('Truyện đã tải'), findsOneWidget);

      await tester.tap(find.text('Truyện đã tải'));
      await tester.pumpAndSettle();
      expect(openedDownloads, isTrue);
      expect(find.text('Downloads Screen'), findsOneWidget);
    });

    testWidgets('Hides offline banner when online', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => ScaffoldWithNavBar(navigationShell: shell),
            branches: [
              for (var i = 0; i < 5; i++)
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: i == 0 ? '/' : '/tab$i',
                      builder: (_, _) => Center(child: Text('Tab $i')),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isOfflineProvider.overrideWith((ref) => Stream.value(false)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bạn đang ngoại tuyến'), findsNothing);
    });
  });
}
