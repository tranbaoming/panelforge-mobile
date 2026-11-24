import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/screens/profile/downloads_page.dart';
import 'package:panelforge/services/cbz_package_service.dart';
import 'package:panelforge/services/preferences_service.dart';

/// Không đụng tới ổ đĩa: dung lượng giả theo chương, ghi lại các lần xoá.
class _FakeCbz extends CbzPackageService {
  final Map<String, int> sizes;
  final List<String> deleted = [];
  bool clearedAll = false;
  _FakeCbz(this.sizes);

  @override
  Future<int> getDownloadedPackageSize(String chapterId) async => sizes[chapterId] ?? 0;

  @override
  Future<void> deleteOfflinePackage(String chapterId) async {
    deleted.add(chapterId);
    await PreferencesService.removeOfflineChapterId(chapterId);
  }

  @override
  Future<void> clearAllOfflinePackages() async {
    clearedAll = true;
    for (final id in PreferencesService.getOfflineChapterIds()) {
      await PreferencesService.removeOfflineChapterId(id);
    }
  }
}

OfflineChapterInfo _info(String chapterId, String series, double number) => OfflineChapterInfo(
  chapterId: chapterId,
  seriesId: 's-$series',
  seriesTitle: series,
  chapterNumber: number,
  chapterTitle: 'Chương $number',
  downloadedAt: DateTime.now(),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
    for (final info in [_info('c2', 'Moon Blade', 2), _info('c1', 'Moon Blade', 1), _info('d1', 'Iron Lotus', 1)]) {
      await PreferencesService.addOfflineChapterId(info.chapterId);
      await PreferencesService.saveOfflineChapterInfo(info);
    }
  });

  Future<_FakeCbz> pumpPage(WidgetTester tester) async {
    final fake = _FakeCbz({'c1': 1024 * 1024, 'c2': 2 * 1024 * 1024, 'd1': 512 * 1024});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cbzPackageServiceProvider.overrideWithValue(fake)],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => const DownloadsPage())],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('groups downloads by series and shows the total size', (tester) async {
    await pumpPage(tester);

    expect(find.text('3 chương'), findsOneWidget);
    expect(find.text('3.5 MB'), findsOneWidget);
    // A–Z theo tên bộ, chương tăng dần trong mỗi bộ.
    final iron = tester.getTopLeft(find.text('Iron Lotus')).dy;
    final moon = tester.getTopLeft(find.text('Moon Blade')).dy;
    expect(iron < moon, isTrue);
    final c1 = tester.getTopLeft(find.byKey(const ValueKey('download-c1'))).dy;
    final c2 = tester.getTopLeft(find.byKey(const ValueKey('download-c2'))).dy;
    expect(c1 < c2, isTrue);
  });

  testWidgets('deleting one chapter removes it and its metadata', (tester) async {
    final fake = await pumpPage(tester);

    await tester.tap(
      find.descendant(of: find.byKey(const ValueKey('download-c2')), matching: find.byTooltip('Xoá chương đã tải')),
    );
    await tester.pumpAndSettle();

    expect(fake.deleted, ['c2']);
    expect(find.byKey(const ValueKey('download-c2')), findsNothing);
    expect(find.text('2 chương'), findsOneWidget);
    expect(PreferencesService.getOfflineChapterMeta().containsKey('c2'), isFalse);
  });

  testWidgets('delete all asks first, then empties the list', (tester) async {
    final fake = await pumpPage(tester);

    await tester.tap(find.text('Xoá hết'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá tất cả chương đã tải?'), findsOneWidget);

    await tester.tap(find.text('Xoá hết').last);
    await tester.pumpAndSettle();

    expect(fake.clearedAll, isTrue);
    expect(find.textContaining('Chưa tải chương nào'), findsOneWidget);
  });
}
