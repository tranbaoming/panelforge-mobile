import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
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
