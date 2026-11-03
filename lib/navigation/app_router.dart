import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/api_providers.dart';
import '../screens/auth/login_page.dart';
import '../screens/explore/explore_page.dart';
import '../screens/explore/series_detail_page.dart';
import '../screens/reader/comic_reader_page.dart';
import '../screens/review/review_canvas_page.dart';
import '../screens/review/review_expired_page.dart';
import '../screens/review/review_hub_page.dart';
import '../screens/review/review_invite_page.dart';
import 'scaffold_with_nav_bar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _exploreNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _reviewNavigatorKey = GlobalKey<NavigatorState>();

/// Listenable hỗ trợ GoRouter tự động re-evaluate redirect khi AuthState thay đổi
class AuthRouterListenable extends ChangeNotifier {
  AuthRouterListenable(Ref ref) {
    ref.listen<AuthState>(authStateProvider, (_, _) {
      notifyListeners();
    });
  }
}

/// Provider cung cấp GoRouter có tích hợp Auth Gate
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = AuthRouterListenable(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggingIn = state.matchedLocation == '/login';

      // 1. Khi chưa xác thực: Bắt buộc ở màn hình /login (chặn vào màn hình chính)
      if (authState.isUnauthenticated) {
        return isLoggingIn ? null : '/login';
      }

      // 2. Khi đã là Reader mà đang ở /login: Điều hướng về trang chủ Explore
      if (authState.isAuthenticated && isLoggingIn) {
        return '/';
      }

      // 3. Ở chế độ Guest hoặc Reader: Cho phép vào các trang thông thường
      return null;
    },
    routes: [
      // Màn hình Đăng nhập độc lập (Không có Bottom Navigation Bar)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),

      // Bottom Navigation Stateful Shell Route
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Khám Phá (Explore)
          StatefulShellBranch(
            navigatorKey: _exploreNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const ExplorePage(),
              ),
            ],
          ),

          // Tab 2: Mở Review & Cộng Tác (Review Hub)
          StatefulShellBranch(
            navigatorKey: _reviewNavigatorKey,
            routes: [
              GoRoute(
                path: '/review',
                builder: (context, state) => const ReviewHubPage(),
              ),
            ],
          ),
        ],
      ),

      // Pushable Sub-routes on Root Navigator:
      // 1. Series Detail Page: /series/:id
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/series/:id',
        builder: (context, state) {
          final seriesId = state.pathParameters['id'] ?? '';
          return SeriesDetailPage(seriesId: seriesId);
        },
      ),

      // 2. Comic Reader Page: /reader/:id?chapterId=...
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/reader/:id',
        builder: (context, state) {
          final seriesId = state.pathParameters['id'] ?? '';
          final chapterId = state.uri.queryParameters['chapterId'];
          return ComicReaderPage(
            seriesId: seriesId,
            chapterId: chapterId,
          );
        },
      ),

      // 3. Review Invite Page: /review/invite/:token
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/review/invite/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return ReviewInvitePage(token: token);
        },
      ),

      // 4. Review Canvas Page: /review/canvas/:token
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/review/canvas/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return ReviewCanvasPage(token: token);
        },
      ),

      // 5. Review Expired Page: /review/expired/:token
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/review/expired/:token',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          return ReviewExpiredPage(token: token);
        },
      ),
    ],
  );
});

/// Router dự phòng tương thích ngược nếu được gọi tĩnh
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const ExplorePage(),
    ),
  ],
);
