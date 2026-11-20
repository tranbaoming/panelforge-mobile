import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/providers/catalog_providers.dart';
import 'package:panelforge/providers/notification_providers.dart';
import 'package:panelforge/screens/profile/activity_page.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/notification_service.dart';
import 'package:panelforge/services/preferences_service.dart';

/// Backend giả theo hợp đồng `NotificationsController` (.NET).
class _FakeNotificationsBackend {
  final List<Map<String, dynamic>> items = [
    {
      'id': 'n1',
      'type': 'ChapterPublished',
      'title': 'Chương 3 đã phát hành',
      'message': 'Mặc Kiếm Lục: chương 3 đã lên kệ.',
      'assignmentId': null,
      'chapterId': 'c3',
      'readAt': null,
      'createdAt': '2026-11-20T08:00:00Z',
    },
    {
      'id': 'n2',
      'type': 'AssignmentApproved',
      'title': 'Việc đã được duyệt',
      'message': '',
      'assignmentId': 'a1',
      'chapterId': null,
      'readAt': '2026-11-19T08:00:00Z',
      'createdAt': '2026-11-19T07:00:00Z',
    },
  ];
  final List<String> calls = [];
  bool failMarkRead = false;

  Dio createDio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add('${options.method} ${options.path}');
          Response<dynamic> ok(dynamic data) => Response(requestOptions: options, statusCode: 200, data: data);
          final path = options.path;
          if (options.method == 'GET' && path == '/api/notifications') {
            return handler.resolve(
              ok({
                'items': items,
                'totalCount': items.length,
                'unreadCount': items.where((n) => n['readAt'] == null).length,
                'pageIndex': 1,
                'pageSize': 30,
              }),
            );
          }
          if (path.endsWith('/read') || path.endsWith('/read-all')) {
            if (failMarkRead) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(requestOptions: options, statusCode: 500, data: {'message': 'Lỗi'}),
                ),
              );
            }
            for (final n in items) {
              if (path.endsWith('/read-all') || path.contains('/${n['id']}/')) {
                n['readAt'] ??= '2026-11-20T09:00:00Z';
              }
            }
            return handler.resolve(ok({'marked': 1}));
          }
          return handler.reject(DioException(requestOptions: options, message: 'unexpected $path'));
        },
      ),
    );
    return dio;
  }
}

const _reader = AuthState(
  role: MobileAuthRole.reader,
  user: AuthUser(id: 'u1', email: 'reader@example.com', fullName: 'Reader', isActive: true),
);

void main() {
  followUpdateTests();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  ProviderContainer makeContainer(_FakeNotificationsBackend backend) => ProviderContainer(
    overrides: [
      notificationServiceProvider.overrideWithValue(NotificationService(ApiClient(customDio: backend.createDio()))),
      catalogSeriesProvider.overrideWith((ref) async => const <SeriesItem>[]),
    ],
  );

  Widget app(ProviderContainer container) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const ActivityPage())],
      ),
    ),
  );

  test('guests get no notifications and no API call', () async {
    final backend = _FakeNotificationsBackend();
    final container = makeContainer(backend);
    addTearDown(container.dispose);

    final page = await container.read(notificationsProvider.future);
    expect(page.items, isEmpty);
    expect(container.read(unreadNotificationCountProvider), 0);
    expect(backend.calls, isEmpty);
  });

  test('signed-in reader loads notifications and the unread count', () async {
    final backend = _FakeNotificationsBackend();
    final container = makeContainer(backend);
    addTearDown(container.dispose);
    container.read(authStateProvider.notifier).updateState(_reader);

    final page = await container.read(notificationsProvider.future);
    expect(page.items.map((n) => n.id), ['n1', 'n2']);
    expect(page.items.first.type, 'ChapterPublished');
    expect(page.items.first.isRead, isFalse);
    expect(page.items.last.isRead, isTrue);
    expect(container.read(unreadNotificationCountProvider), 1);
  });

  test('mark read failure restores the previous state', () async {
    final backend = _FakeNotificationsBackend()..failMarkRead = true;
    final container = makeContainer(backend);
    addTearDown(container.dispose);
    container.read(authStateProvider.notifier).updateState(_reader);
    await container.read(notificationsProvider.future);

    await expectLater(container.read(notificationsProvider.notifier).markRead('n1'), throwsA(isA<ApiException>()));
    expect(container.read(unreadNotificationCountProvider), 1);
  });

  testWidgets('activity page lists notifications; tapping one marks it read', (tester) async {
    final backend = _FakeNotificationsBackend();
    final container = makeContainer(backend);
    addTearDown(container.dispose);
    container.read(authStateProvider.notifier).updateState(_reader);

    await tester.pumpWidget(app(container));
    await tester.pumpAndSettle();

    expect(find.text('Chương 3 đã phát hành'), findsOneWidget);
    expect(find.text('Việc đã được duyệt'), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-n1')), findsOneWidget);
    expect(find.text('Đánh dấu đã đọc'), findsOneWidget);

    await tester.tap(find.text('Chương 3 đã phát hành'));
    await tester.pumpAndSettle();

    expect(backend.calls, contains('POST /api/notifications/n1/read'));
    expect(find.byKey(const ValueKey('unread-n1')), findsNothing);
    expect(find.text('Đánh dấu đã đọc'), findsNothing);
    expect(container.read(unreadNotificationCountProvider), 0);
  });

  testWidgets('mark all read clears every unread dot', (tester) async {
    final backend = _FakeNotificationsBackend();
    backend.items.last['readAt'] = null;
    final container = makeContainer(backend);
    addTearDown(container.dispose);
    container.read(authStateProvider.notifier).updateState(_reader);

    await tester.pumpWidget(app(container));
    await tester.pumpAndSettle();
    expect(container.read(unreadNotificationCountProvider), 2);

    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pumpAndSettle();

    expect(backend.calls, contains('POST /api/notifications/read-all'));
    expect(find.byKey(const ValueKey('unread-n1')), findsNothing);
    expect(find.byKey(const ValueKey('unread-n2')), findsNothing);
  });

  testWidgets('guests see a sign-in hint instead of notifications', (tester) async {
    final backend = _FakeNotificationsBackend();
    final container = makeContainer(backend);
    addTearDown(container.dispose);

    await tester.pumpWidget(app(container));
    await tester.pumpAndSettle();

    expect(find.text('Đăng nhập để nhận thông báo.'), findsOneWidget);
    expect(backend.calls, isEmpty);
  });
}

SeriesItem _followed(String id, DateTime? latest) => SeriesItem(
  id: id,
  title: 'Series $id',
  author: 'Studio',
  artist: 'Studio',
  format: ComicFormat.manga,
  coverGradientStart: '',
  coverGradientEnd: '',
  synopsisQuote: '',
  fullSynopsis: '',
  views: 0,
  readProgressChapter: 0,
  totalChapters: 3,
  genres: const [],
  chapters: const [],
  editorialNote: '',
  latestPublishedAt: latest,
);

void followUpdateTests() {
  group('followed series updates', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.init();
    });

    ProviderContainer containerWith(List<SeriesItem> catalog) =>
        ProviderContainer(overrides: [catalogSeriesProvider.overrideWith((ref) async => catalog)]);

    test('only chapters published after following count, and opening clears them', () async {
      final now = DateTime.now();
      await PreferencesService.toggleFollow('a');
      await PreferencesService.toggleFollow('b');
      await PreferencesService.setFollowSeenAt('a', now.subtract(const Duration(days: 2)));
      await PreferencesService.setFollowSeenAt('b', now.subtract(const Duration(days: 2)));

      final container = containerWith([
        _followed('a', now.subtract(const Duration(days: 1))), // mới sau mốc đã xem
        _followed('b', now.subtract(const Duration(days: 3))), // cũ hơn mốc
        _followed('c', now), // không theo dõi
      ]);
      addTearDown(container.dispose);
      await container.read(catalogSeriesProvider.future);

      expect(container.read(followUpdatesProvider).map((s) => s.id), ['a']);
      expect(container.read(bellBadgeCountProvider), 1);

      await container.read(followUpdatesProvider.notifier).markSeen('a');
      expect(container.read(followUpdatesProvider), isEmpty);
      expect(container.read(bellBadgeCountProvider), 0);
    });

    test('follows from before the feature get a baseline instead of a flood of alerts', () async {
      SharedPreferences.setMockInitialValues({
        'panelforge_follows': ['a'],
      });
      await PreferencesService.init();
      final container = containerWith([_followed('a', DateTime.now().subtract(const Duration(hours: 1)))]);
      addTearDown(container.dispose);
      await container.read(catalogSeriesProvider.future);

      expect(container.read(followUpdatesProvider), isEmpty);
      expect(PreferencesService.getFollowSeenAt().containsKey('a'), isTrue);
    });
  });
}
