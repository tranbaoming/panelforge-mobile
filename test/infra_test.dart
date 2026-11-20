import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/providers/catalog_providers.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/app_info.dart';
import 'package:panelforge/services/catalog_service.dart';
import 'package:panelforge/services/crash_reporter.dart';
import 'package:panelforge/services/preferences_service.dart';

Map<String, dynamic> _page(List<String> titles) => {
  'items': [
    for (final (i, t) in titles.indexed)
      {'id': 's$i', 'title': t, 'format': 'Manga', 'genres': <String>[], 'publishedChapterCount': 1, 'totalViews': 0},
  ],
  'totalCount': titles.length,
  'pageIndex': 1,
  'pageSize': 50,
  'totalPages': 1,
};

/// Catalog giả: [online] = false → lỗi kết nối (statusCode null) như khi tắt mạng.
class _FakeCatalogBackend {
  bool online = true;
  int status = 200;
  List<String> titles = ['Alpha', 'Bravo'];

  Dio createDio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!online) {
            return handler.reject(
              DioException(requestOptions: options, type: DioExceptionType.connectionError, message: 'offline'),
            );
          }
          if (status != 200) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(requestOptions: options, statusCode: status, data: {'message': 'x'}),
              ),
            );
          }
          return handler.resolve(Response(requestOptions: options, statusCode: 200, data: _page(titles)));
        },
      ),
    );
    return dio;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('catalog offline cache', () {
    test('serves the last saved catalog when the server cannot be reached', () async {
      final backend = _FakeCatalogBackend();
      final service = CatalogService(client: ApiClient(customDio: backend.createDio()));

      final online = await loadWholeCatalog(service);
      expect(online.map((s) => s.title), ['Alpha', 'Bravo']);
      expect(service.lastSeriesFromCache, isFalse);

      backend.online = false;
      final offline = await loadWholeCatalog(service);
      expect(offline.map((s) => s.title), ['Alpha', 'Bravo']);
      expect(service.lastSeriesFromCache, isTrue);
    });

    test('without a saved copy the connection error still surfaces', () async {
      final backend = _FakeCatalogBackend()..online = false;
      final service = CatalogService(client: ApiClient(customDio: backend.createDio()));
      await expectLater(loadWholeCatalog(service), throwsA(isA<ApiException>()));
    });

    test('client errors (4xx) are not hidden behind the cache', () async {
      final backend = _FakeCatalogBackend();
      final service = CatalogService(client: ApiClient(customDio: backend.createDio()));
      await loadWholeCatalog(service);

      backend.status = 400;
      await expectLater(loadWholeCatalog(service), throwsA(isA<ApiException>()));
    });

    test('search results are never cached', () async {
      final backend = _FakeCatalogBackend();
      final service = CatalogService(client: ApiClient(customDio: backend.createDio()));
      await service.getSeries(search: 'alp', pageIndex: 1, pageSize: 50);
      expect(PreferencesService.getCachedCatalogPage(1, 50), isNull);
    });
  });

  group('crash log', () {
    test('records errors newest first and keeps at most 20', () async {
      for (var i = 0; i < 25; i++) {
        CrashReporter.record(StateError('boom $i'), StackTrace.current);
      }
      // Ghi bất đồng bộ — chờ các lần ghi hoàn tất.
      await pumpEventQueue();
      final log = PreferencesService.getCrashLog();
      expect(log.length, 20);
      expect(log.first.error, contains('boom 24'));
      await PreferencesService.clearCrashLog();
      expect(PreferencesService.getCrashLog(), isEmpty);
    });
  });

  test('text scale defaults to the system size and is saved', () async {
    expect(PreferencesService.getTextScale(), 1.0);
    await PreferencesService.setTextScale(1.3);
    expect(PreferencesService.getTextScale(), 1.3);
  });

  test('share link opens the series route inside the app', () {
    final uri = Uri.parse(AppInfo.seriesDeepLink('abc-123'));
    expect(uri.scheme, 'panelforge');
    expect(uri.host, 'app');
    // GoRouter dùng path của link → khớp route /series/:id.
    expect(uri.path, '/series/abc-123');
  });
}
