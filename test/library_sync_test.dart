import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/providers/catalog_providers.dart';
import 'package:panelforge/providers/library_sync_provider.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/library_sync_service.dart';
import 'package:panelforge/services/preferences_service.dart';

/// Server giả theo hợp đồng `ReaderLibraryController` (.NET).
class _FakeLibraryBackend {
  final List<RequestOptions> requests = [];
  Map<String, dynamic> serverLibrary = {
    'readLater': ['srv-1'],
    'following': [
      {'seriesId': 'srv-2', 'lastSeenAt': '2026-11-19T10:00:00Z'},
    ],
    'favorites': <String>[],
    'history': [
      {
        'seriesId': 'srv-1',
        'chapterId': 'c9',
        'chapterNumber': 9,
        'lastPageNumber': 4,
        'totalPages': 20,
        'language': 'vi',
        'readAt': '2026-11-19T12:00:00Z',
      },
    ],
  };

  Dio createDio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final ok = Response(requestOptions: options, statusCode: 200, data: serverLibrary);
          if (options.path.endsWith('/merge')) return handler.resolve(ok);
          return handler.resolve(Response(requestOptions: options, statusCode: 204));
        },
      ),
    );
    return dio;
  }

  Iterable<String> get calls => requests.map((r) => '${r.method} ${r.path}');
}

const _reader = AuthState(
  role: MobileAuthRole.reader,
  user: AuthUser(id: 'u1', email: 'reader@example.com', fullName: 'Reader', isActive: true),
);

void main() {
  late _FakeLibraryBackend backend;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
    backend = _FakeLibraryBackend();
    container = ProviderContainer(
      overrides: [
        librarySyncServiceProvider.overrideWithValue(LibrarySyncService(ApiClient(customDio: backend.createDio()))),
        catalogSeriesProvider.overrideWith((ref) async => const <SeriesItem>[]),
      ],
    );
    container.listen(librarySyncProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('local changes bump version so the Profile tab redraws history right after reading', () async {
    final before = container.read(librarySyncProvider).version;
    await PreferencesService.saveReadingProgress(
      ReadingHistoryEntry(
        seriesId: 's1',
        seriesTitle: 'S1',
        chapterId: 'c1',
        chapterNumber: 1,
        lastPageNumber: 1,
        totalPages: 3,
        readAt: DateTime(2026, 11, 24),
      ),
    );
    expect(container.read(librarySyncProvider).version, greaterThan(before));
  });

  test('guests never call the server, even when they change lists', () async {
    await PreferencesService.toggleBookmark('local-1');
    await container.read(librarySyncProvider.notifier).syncNow();
    expect(backend.requests, isEmpty);
  });

  test('signing in merges device data, then device takes the server copy', () async {
    await PreferencesService.toggleFavorite('local-fav');
    await PreferencesService.saveReadingProgress(
      ReadingHistoryEntry(
        seriesId: 'srv-1',
        seriesTitle: 'Moon Blade',
        chapterId: 'c2',
        chapterNumber: 2,
        readAt: DateTime(2026, 11, 1),
      ),
    );

    container.read(authStateProvider.notifier).updateState(_reader);
    await pumpEventQueue();
    await container.read(librarySyncProvider.notifier).syncNow();

    final merge = backend.requests.firstWhere((r) => r.path.endsWith('/merge'));
    final body = merge.data as Map<String, dynamic>;
    expect(body['favorites'], ['local-fav']);
    expect((body['history'] as List).single['chapterId'], 'c2');

    expect(PreferencesService.getBookmarks(), {'srv-1'});
    expect(PreferencesService.getFollows(), {'srv-2'});
    expect(PreferencesService.getFollowSeenAt()['srv-2'], DateTime.parse('2026-11-19T10:00:00Z').toLocal());
    final history = PreferencesService.getReadingHistory().single;
    expect(history.chapterId, 'c9');
    expect(history.lastPageNumber, 4);
    expect(history.seriesTitle, 'Moon Blade', reason: 'keeps the title known on this device');
    expect(container.read(librarySyncProvider).lastSyncedAt, isNotNull);
    expect(container.read(librarySyncProvider).version, greaterThan(0));
  });

  test('list changes are sent right away while signed in', () async {
    container.read(authStateProvider.notifier).updateState(_reader);
    await container.read(librarySyncProvider.notifier).syncNow();
    backend.requests.clear();

    await PreferencesService.toggleBookmark('s1');
    await PreferencesService.toggleBookmark('s1');
    await PreferencesService.toggleFollow('s2');
    await PreferencesService.clearReadingHistory();
    await pumpEventQueue();

    expect(backend.calls, [
      'PUT /api/users/me/library/read-later/s1',
      'DELETE /api/users/me/library/read-later/s1',
      'PUT /api/users/me/library/following/s2',
      'DELETE /api/users/me/library/history',
    ]);
    expect((backend.requests[2].data as Map)['lastSeenAt'], isNotNull);
  });

  test('reading progress is debounced per series', () async {
    container.read(authStateProvider.notifier).updateState(_reader);
    await container.read(librarySyncProvider.notifier).syncNow();
    backend.requests.clear();

    for (var page = 1; page <= 5; page++) {
      await PreferencesService.saveReadingProgress(
        ReadingHistoryEntry(
          seriesId: 's1',
          seriesTitle: 'S1',
          chapterId: 'c1',
          chapterNumber: 1,
          lastPageNumber: page,
          readAt: DateTime.now(),
        ),
      );
    }
    expect(backend.requests, isEmpty);

    await Future<void>.delayed(LibrarySyncNotifier.progressDebounce + const Duration(milliseconds: 200));
    expect(backend.calls, ['PUT /api/users/me/library/history']);
    expect((backend.requests.single.data as Map)['lastPageNumber'], 5);
  });
}
