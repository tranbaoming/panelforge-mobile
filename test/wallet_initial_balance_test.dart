import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/models/api_dtos.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/services/monetization_service.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/widgets/unlock_chapter_bottom_sheet.dart';
import 'package:panelforge/widgets/wallet_chip.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoadingWalletNotifier extends WalletNotifier {
  @override
  AsyncValue<UserWalletDto> build() => const AsyncLoading();

  @override
  Future<void> refresh({bool silent = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('Initial wallet balance & no fake 50.000đ (AUD-FL-07)', () {
    test('new user has null local balance and no fake welcome transaction after saveAuthUser', () async {
      expect(PreferencesService.getLocalBalanceVnd(), isNull);
      expect(PreferencesService.getLocalBalanceCoins(), isNull);
      expect(PreferencesService.getWalletTransactions(), isEmpty);

      await PreferencesService.saveAuthUser({
        'id': 'u-new-1',
        'email': 'newreader@panelforge.com',
        'fullName': 'New Reader',
        'role': 'User',
      });

      expect(PreferencesService.getLocalBalanceVnd(), isNull);
      expect(PreferencesService.getWalletTransactions(), isEmpty);
    });

    testWidgets('WalletChip shows loading state instead of fake 50.000đ while server is loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [walletNotifierProvider.overrideWith(_LoadingWalletNotifier.new)],
          child: const MaterialApp(home: Scaffold(body: Center(child: WalletChip(isServerConnected: true)))),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('50.000đ'), findsNothing);
    });

    testWidgets('UnlockChapterBottomSheet shows loading state instead of fake 50.000đ while server is loading',
        (tester) async {
      const chapter = ChapterItem(
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [walletNotifierProvider.overrideWith(_LoadingWalletNotifier.new)],
          child: MaterialApp(
            home: Scaffold(
              body: UnlockChapterBottomSheet(chapter: chapter, onUnlocked: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Đang tải...'), findsWidgets);
      expect(find.text('Đang tải số dư...'), findsOneWidget);
      expect(find.text('50.000đ'), findsNothing);
    });
  });
}
