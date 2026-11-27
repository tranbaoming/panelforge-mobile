import 'dart:convert';
import 'dart:typed_data';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/navigation/app_router.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/screens/auth/login_page.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _ScriptedAdapter(this.handler);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }
}

ResponseBody _json(int status, Map<String, dynamic> data) => ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
    ApiClient.onSessionExpiredCallback = null;
    AuthService.onAuthStateChanged = null;
    AuthService.onSessionExpiredRedirect = null;
  });

  group('Session expiry & silent refresh (AUD-FL-01)', () {
    test('authenticated user with revoked/expired refresh token triggers session expiry and signs out', () async {
      await PreferencesService.saveAuthUser({
        'id': 'u-1',
        'email': 'reader@panelforge.com',
        'fullName': 'Reader',
        'isActive': true,
        'role': 'User',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Build authStateProvider so ApiClient.onSessionExpiredCallback is wired.
      expect(container.read(authStateProvider).isAuthenticated, isTrue);

      final cookieJar = CookieJar();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.httpClientAdapter = _ScriptedAdapter((_) => _json(401, {'message': 'Token expired'}));

      dio.interceptors.add(
        AuthInterceptor(
          dio: dio,
          cookieJar: cookieJar,
          onSessionExpired: () => ApiClient.onSessionExpiredCallback?.call(),
          refreshDioFactory: () => Dio(BaseOptions(baseUrl: 'https://api.example.com'))
            ..httpClientAdapter = _ScriptedAdapter((_) => _json(401, {'message': 'Refresh revoked'})),
        ),
      );

      await expectLater(dio.get('/api/users/me/library'), throwsA(isA<DioException>()));
      // Allow async handleSessionExpired microtasks to finish.
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authStateProvider).isAuthenticated, isFalse);
      expect(PreferencesService.getAuthUser(), isNull);
    });

    test('valid session whose silent refresh succeeds retries request and does NOT sign out', () async {
      await PreferencesService.saveAuthUser({
        'id': 'u-2',
        'email': 'active@panelforge.com',
        'fullName': 'Active Reader',
        'isActive': true,
        'role': 'User',
      });

      var expiredCalled = false;
      var callCount = 0;

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.httpClientAdapter = _ScriptedAdapter((options) {
        callCount++;
        if (callCount == 1) return _json(401, {'message': 'Access token expired'});
        return _json(200, {'ok': true});
      });

      dio.interceptors.add(
        AuthInterceptor(
          dio: dio,
          cookieJar: CookieJar(),
          onSessionExpired: () => expiredCalled = true,
          refreshDioFactory: () => Dio(BaseOptions(baseUrl: 'https://api.example.com'))
            ..httpClientAdapter = _ScriptedAdapter((_) => _json(200, {'ok': true})),
        ),
      );

      final response = await dio.get('/api/users/me/library');
      expect(response.statusCode, 200);
      expect(callCount, 2);
      expect(expiredCalled, isFalse);
      expect(PreferencesService.getAuthUser(), isNotNull);
    });

    test('unauthenticated guest hitting 401 does NOT trigger session expiry', () async {
      var expiredCalled = false;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.httpClientAdapter = _ScriptedAdapter((_) => _json(401, {'message': 'Unauthorized'}));

      dio.interceptors.add(
        AuthInterceptor(
          dio: dio,
          cookieJar: CookieJar(),
          onSessionExpired: () => expiredCalled = true,
        ),
      );

      await expectLater(dio.get('/api/wallet/me'), throwsA(isA<DioException>()));
      expect(expiredCalled, isFalse);
    });

    testWidgets('expired session redirects to /login?redirect=<current route>', (tester) async {
      await PreferencesService.saveAuthUser({
        'id': 'u-3',
        'email': 'reader3@panelforge.com',
        'fullName': 'Reader 3',
        'isActive': true,
        'role': 'User',
      });

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(routerConfig: router);
            },
          ),
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      final router = container.read(appRouterProvider);

      router.go('/shop');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(authStateProvider).isAuthenticated, isTrue);

      // Simulate session expiry callback firing from ApiClient.
      ApiClient.onSessionExpiredCallback?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(container.read(authStateProvider).isAuthenticated, isFalse);
      expect(find.byType(LoginPage), findsOneWidget);
      final loginWidget = tester.widget<LoginPage>(find.byType(LoginPage));
      expect(loginWidget.redirect, '/shop');
    });
  });
}
