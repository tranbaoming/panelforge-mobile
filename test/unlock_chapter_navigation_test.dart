import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/widgets/unlock_chapter_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnlockBackendAdapter implements HttpClientAdapter {
  int balanceVnd = 50000;
  final Set<String> unlocked = {};

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    Map<String, dynamic> body = {};
    if (path.endsWith('/api/wallet/me')) {
      body = {
        'balanceVnd': balanceVnd,
        'balanceCoins': balanceVnd ~/ 100,
        'isVip': false,
        'unlockedChapterIds': unlocked.toList(),
        'transactions': [],
      };
    } else if (path.endsWith('/api/wallet/unlock-chapter')) {
      final data = options.data as Map<String, dynamic>;
      final chId = data['chapterId'].toString();
      balanceVnd -= 5000;
      unlocked.add(chId);
      body = {
        'chapterId': chId,
        'success': true,
        'remainingBalanceVnd': balanceVnd,
        'remainingCoins': balanceVnd ~/ 100,
        'message': 'Mở khóa thành công!',
        'isPermanent': true,
      };
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _AuthedNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        role: MobileAuthRole.reader,
        user: AuthUser(
          id: 'u1',
          email: 'reader@panelforge.com',
          fullName: 'Reader',
          isActive: true,
          role: 'User',
        ),
      );
}

const _chapter = ChapterItem(
  id: 'ch-1',
  number: 1,
  title: 'Chương 1',
  releaseDate: '01/11/2026',
  pageCount: 10,
  isFree: false,
  isUnlocked: false,
  priceVnd: 5000,
  pages: [],
);

const _series = SeriesItem(
  id: 'series-1',
  title: 'Test Series',
  author: 'Studio',
  artist: 'Artist',
  format: ComicFormat.manga,
  genres: ['Action'],
  totalChapters: 1,
  readProgressChapter: 0,
  synopsisQuote: 'Quote',
  fullSynopsis: 'Full synopsis',
  editorialNote: 'Note',
  coverGradientStart: '#1E293B',
  coverGradientEnd: '#0F172A',
  views: 1000,
  chapters: [_chapter],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('UnlockChapterBottomSheet back-stack navigation (AUD-FL-08)', () {
    testWidgets('unlocking inside Reader reloads in-place without pushing duplicate /reader/ route', (tester) async {
      final adapter = _UnlockBackendAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))..httpClientAdapter = adapter;
      var reloadCount = 0;
      var readerBuilds = 0;

      final router = GoRouter(
        initialLocation: '/series/series-1',
        routes: [
          GoRoute(
            path: '/series/:id',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.push('/reader/series-1?chapterId=ch-1'),
                child: const Text('Open Reader'),
              ),
            ),
          ),
          GoRoute(
            path: '/reader/:id',
            builder: (context, state) {
              readerBuilds++;
              return Scaffold(
                body: Column(
                  children: [
                    const Text('Reader Screen'),
                    ElevatedButton(
                      onPressed: () => UnlockChapterBottomSheet.show(
                        context,
                        chapter: _chapter,
                        series: _series,
                        navigateToReaderOnUnlock: false,
                        onUnlocked: () => reloadCount++,
                      ),
                      child: const Text('Unlock In Reader'),
                    ),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(_AuthedNotifier.new),
            monetizationServiceProvider.overrideWithValue(MonetizationService(dio: dio)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate Series Detail -> Reader
      await tester.tap(find.text('Open Reader'));
      await tester.pumpAndSettle();
      expect(find.text('Reader Screen'), findsOneWidget);
      final buildsBeforeUnlock = readerBuilds;

      // Unlock inside Reader
      await tester.tap(find.text('Unlock In Reader'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thanh toán 5.000đ & Đọc ngay'));
      await tester.pumpAndSettle();

      expect(reloadCount, 1);
      // No second /reader/ route pushed
      expect(readerBuilds, buildsBeforeUnlock);
      expect(find.text('Reader Screen'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/reader/series-1');

      // Pressing Back returns directly to Series Detail (not a stale locked Reader)
      await tester.tap(find.text('Go Back'));
      await tester.pumpAndSettle();
      expect(find.text('Open Reader'), findsOneWidget);
      expect(find.text('Reader Screen'), findsNothing);
    });

    testWidgets('unlocking from Series Detail still pushes /reader/ route', (tester) async {
      final adapter = _UnlockBackendAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))..httpClientAdapter = adapter;
      var onUnlockedCalled = false;

      final router = GoRouter(
        initialLocation: '/series/series-1',
        routes: [
          GoRoute(
            path: '/series/:id',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => UnlockChapterBottomSheet.show(
                  context,
                  chapter: _chapter,
                  series: _series,
                  onUnlocked: () => onUnlockedCalled = true,
                ),
                child: const Text('Unlock From Detail'),
              ),
            ),
          ),
          GoRoute(
            path: '/reader/:id',
            builder: (context, state) => Scaffold(
              body: Text('Reader ${state.pathParameters['id']} ${state.uri.queryParameters['chapterId']}'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(_AuthedNotifier.new),
            monetizationServiceProvider.overrideWithValue(MonetizationService(dio: dio)),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unlock From Detail'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thanh toán 5.000đ & Đọc ngay'));
      await tester.pumpAndSettle();

      expect(onUnlockedCalled, isTrue);
      expect(find.text('Reader series-1 ch-1'), findsOneWidget);
    });
  });
}
