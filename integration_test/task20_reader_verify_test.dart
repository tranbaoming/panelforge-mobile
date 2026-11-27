import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:panelforge/models/api_dtos.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/screens/reader/comic_reader_page.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/api_config.dart';
import 'package:panelforge/services/catalog_service.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/services/reader_image_auth.dart';
import 'package:panelforge/theme/app_theme.dart';

/// Wraps the real [CatalogService] for AC5 memory measurement: repeats the real
/// published 775 KB page image 50 times with distinct `?p=1..50` URLs so
/// [CachedNetworkImage] fetches and decodes 50 distinct pages through the real
/// [ComicReaderPage] + [ReaderImageAuth] + DPR-aware `memCacheWidth` pipeline.
class _FiftyPageCatalogService extends CatalogService {
  final CatalogService _inner = CatalogService();

  @override
  Future<PublicSeriesDetailDto> getSeriesDetail(String seriesId, {String? lang}) =>
      _inner.getSeriesDetail(seriesId, lang: lang);

  @override
  Future<PublicChapterReadDto> readChapter(String chapterId, {String? lang}) async {
    final real = await _inner.readChapter(chapterId, lang: lang);
    final baseUrl = real.pages.firstWhere((p) => p.relativeImageUrl != null && p.relativeImageUrl!.isNotEmpty).relativeImageUrl!;
    final expanded = List.generate(
      50,
      (i) => PublicPageDto(
        id: '${real.pages.first.id}-p${i + 1}',
        pageNumber: i + 1,
        relativeImageUrl: '$baseUrl?p=${i + 1}',
        isLocked: false,
        isUnlocked: true,
        isPreview: false,
      ),
    );
    return PublicChapterReadDto(
      id: real.id,
      seriesId: real.seriesId,
      seriesTitle: real.seriesTitle,
      readingDirection: ApiReadingDirection.vertical,
      chapterNumber: real.chapterNumber,
      title: '${real.title ?? "Chapter"} (50-page stress)',
      publishedAt: real.publishedAt,
      pages: expanded,
      priceVnd: real.priceVnd,
      isUnlocked: real.isUnlocked,
      isFree: real.isFree,
      language: real.language,
      languages: real.languages,
    );
  }

  @override
  Future<void> recordChapterView(String chapterId, {String? lang}) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testEmail = String.fromEnvironment('TEST_EMAIL', defaultValue: 'reader@panelforge.com');
  const testPassword = String.fromEnvironment('TEST_PASSWORD');
  const seriesId = '50f26d75-4c7b-4bdf-a2a8-e3150e5864fb';
  const chapterId = 'bfa340d6-675d-4d59-8a45-3351c3a10e10';
  const pageImagePath = '/api/catalog/chapters/$chapterId/pages/ef6b384a-4fd6-430b-a98d-1be1dedb4ee5/image';

  // Android/iOS-only screen security EventChannel is not implemented on Windows desktop.
  setUpAll(() async {
    const channel = MethodChannel('com.panelforge/screen_security_events');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall call) async => null,
    );

    await PreferencesService.init();
    await ApiClient.initCookieJar();

    expect(testPassword, isNotEmpty, reason: 'Pass --dart-define=TEST_PASSWORD=...');
    final authService = AuthService();
    final loginResp = await authService.login(email: testEmail, password: testPassword);
    expect(loginResp.user?.email.toLowerCase(), testEmail.toLowerCase());
  });

  tearDownAll(() async {
    await AuthService().logout();
  });

  testWidgets('TASK-20 AC2: Owned paid page loads in ComicReaderPage with Cookie header', (tester) async {
    final fullImageUrl = '${ApiConfig.baseUrl}$pageImagePath';
    final authHeaders = await ReaderImageAuth.headersForUrl(fullImageUrl);
    expect(authHeaders['Cookie'], isNotNull, reason: 'ReaderImageAuth must attach Cookie header');
    expect(authHeaders['Cookie'], contains('pf_access='));

    final httpClient = HttpClient();
    try {
      final req = await httpClient.getUrl(Uri.parse(fullImageUrl));
      authHeaders.forEach(req.headers.set);
      final resp = await req.close();
      final bytes = await resp.fold<int>(0, (sum, chunk) => sum + chunk.length);
      // ignore: avoid_print
      print('[TASK20_AC2] paidPageWithCookieStatus=${resp.statusCode} bytes=$bytes');
      expect(resp.statusCode, 200);
      expect(bytes, greaterThan(10000));
    } finally {
      httpClient.close();
    }

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ComicReaderPage(seriesId: seriesId, chapterId: chapterId),
        ),
      ),
    );

    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byType(CachedNetworkImage).evaluate().isNotEmpty) break;
    }

    final imgFinder = find.byType(CachedNetworkImage);
    expect(imgFinder, findsWidgets, reason: 'Paid chapter page must render CachedNetworkImage');
    final imgWidget = tester.widget<CachedNetworkImage>(imgFinder.first);
    expect(imgWidget.imageUrl, fullImageUrl);
    expect(imgWidget.httpHeaders?['Cookie'], contains('pf_access='));
    await tester.pump(const Duration(seconds: 2));
    // ignore: avoid_print
    print('[TASK20_AC2] widgetRenderedUrl=${imgWidget.imageUrl} hasCookieHeader=true memCacheWidth=${imgWidget.memCacheWidth}');
  });

  testWidgets('TASK-20 AC5: Scroll through 50 pages in ComicReaderPage on Windows', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          catalogServiceProvider.overrideWithValue(_FiftyPageCatalogService()),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ComicReaderPage(seriesId: seriesId, chapterId: chapterId),
        ),
      ),
    );

    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byType(Scrollable).evaluate().isNotEmpty && find.byType(CachedNetworkImage).evaluate().isNotEmpty) {
        break;
      }
    }

    final scrollableFinder = find.byType(Scrollable);
    expect(scrollableFinder, findsWidgets);
    final scrollState = tester.state<ScrollableState>(scrollableFinder.first);

    // Scroll steadily from top to bottom through all 50 pages so images load/decode
    // and the external 1s Get-Process sampler captures peak memory.
    // ignore: avoid_print
    print('[TASK20_AC5] starting 50-page scroll (initialMaxExtent=${scrollState.position.maxScrollExtent.round()})');
    for (int step = 1; step <= 50; step++) {
      final maxExtent = scrollState.position.maxScrollExtent;
      final target = maxExtent > 0 ? (maxExtent * (step / 50.0)) : 0.0;
      scrollState.position.jumpTo(target.clamp(0.0, maxExtent));
      await tester.pump(const Duration(milliseconds: 250));
    }
    // Wait briefly at the end so all trailing page decodes settle.
    await tester.pump(const Duration(seconds: 2));
    // ignore: avoid_print
    print(
      '[TASK20_AC5] finished 50-page scroll '
      '(finalOffset=${scrollState.position.pixels.round()}, maxExtent=${scrollState.position.maxScrollExtent.round()})',
    );
    expect(scrollState.position.maxScrollExtent, greaterThan(5000));
  });
}
