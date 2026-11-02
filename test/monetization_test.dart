import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/widgets/unlock_chapter_bottom_sheet.dart';
import 'package:panelforge/widgets/wallet_chip.dart';

Dio createMockDio() {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path.endsWith('/api/wallet/me')) {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'balanceCoins': 150, 'isVip': false},
        ));
      }
      if (options.path.endsWith('/api/wallet/topup')) {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'orderId': 'order-123',
            'coins': 500,
            'amountVnd': 90000,
            'qrCodeUrl': 'https://img.vietqr.io/image/970436-123-compact2.png',
            'bankName': 'Vietcombank',
            'accountNo': '123456789',
            'accountName': 'PANELFORGE JSC',
            'description': 'NAP500 PF123',
            'expiresAt': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
          },
        ));
      }
      return handler.next(options);
    },
  ));
  return dio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
    await PreferencesService.setLocalBalanceCoins(150);
    await PreferencesService.setLocalVip(isVip: false);
  });

  group('MonetizationService & Wallet Tests', () {
    test('getMyWallet throws when backend is offline/unreachable', () async {
      final service = MonetizationService();
      expect(() => service.getMyWallet(), throwsA(isA<Exception>()));
    });

    test('getMyWallet retrieves balance and VIP state when backend responds', () async {
      final mockDio = createMockDio();
      final service = MonetizationService(dio: mockDio);
      final wallet = await service.getMyWallet();

      expect(wallet.balanceCoins, 150);
      expect(wallet.isVip, isFalse);
    });

    test('unlockChapter succeeds and deducts coins when balance is sufficient', () async {
      final service = MonetizationService();
      expect(PreferencesService.isChapterUnlocked('chap-1'), isFalse);

      final resp = await service.unlockChapter(chapterId: 'chap-1', priceCoins: 50);

      expect(resp.success, isTrue);
      expect(resp.remainingCoins, 100);
      expect(PreferencesService.isChapterUnlocked('chap-1'), isTrue);
      expect(PreferencesService.getLocalBalanceCoins(), 100);
    });

    test('unlockChapter throws exception when balance is insufficient', () async {
      final service = MonetizationService();
      await PreferencesService.setLocalBalanceCoins(20);

      expect(
        () => service.unlockChapter(chapterId: 'chap-2', priceCoins: 50),
        throwsA(isA<Exception>()),
      );
      expect(PreferencesService.isChapterUnlocked('chap-2'), isFalse);
    });

    test('unlockChapter is free for VIP users without deducting coins', () async {
      final service = MonetizationService();
      await PreferencesService.setLocalVip(
        isVip: true,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      await PreferencesService.setLocalBalanceCoins(150);

      final resp = await service.unlockChapter(chapterId: 'chap-vip-1', priceCoins: 50);

      expect(resp.success, isTrue);
      expect(resp.remainingCoins, 150); // Did not deduct coins!
      expect(PreferencesService.isChapterUnlocked('chap-vip-1'), isTrue);
    });

    test('subscribeVip activates VIP pass and deducts plan cost', () async {
      final service = MonetizationService();
      await PreferencesService.setLocalBalanceCoins(500);

      final resp = await service.subscribeVip(plan: 'monthly');

      expect(resp.success, isTrue);
      expect(resp.isVip, isTrue);
      expect(resp.remainingCoins, 301); // 500 - 199 = 301
      expect(PreferencesService.getLocalIsVip(), isTrue);
      expect(PreferencesService.getLocalBalanceCoins(), 301);
    });

    test('requestTopup throws when backend is offline/unreachable', () async {
      final service = MonetizationService();
      expect(
        () => service.requestTopup(coinsAmount: 500, amountVnd: 90000),
        throwsA(isA<Exception>()),
      );
    });

    test('requestTopup and completeTopup generate VietQR and add coins to wallet when online', () async {
      final mockDio = createMockDio();
      final service = MonetizationService(dio: mockDio);
      final topup = await service.requestTopup(coinsAmount: 500, amountVnd: 90000);

      expect(topup.coins, 500);
      expect(topup.amountVnd, 90000);
      expect(topup.qrCodeUrl, contains('vietqr.io'));
      expect(topup.bankName, 'Vietcombank');

      final updated = await service.completeTopup(
        orderId: topup.orderId,
        coinsAmount: topup.coins,
      );

      expect(updated.balanceCoins, 650); // 150 + 500
      expect(PreferencesService.getLocalBalanceCoins(), 650);
    });
  });

  group('Monetization Widgets & Dialogs Tests', () {
    testWidgets('WalletChip hides completely (SizedBox.shrink) when offline or disconnected', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: WalletChip(isServerConnected: false)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('150'), findsNothing);
      expect(find.byIcon(Icons.monetization_on_rounded), findsNothing);
    });

    testWidgets('WalletChip displays coins and opens WalletTopupDialog on tap when server is connected', (WidgetTester tester) async {
      final mockDio = createMockDio();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monetizationServiceProvider.overrideWithValue(MonetizationService(dio: mockDio)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: WalletChip(isServerConnected: true)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('150'), findsOneWidget);
      expect(find.byIcon(Icons.monetization_on_rounded), findsOneWidget);

      // Tap on WalletChip
      await tester.tap(find.byType(WalletChip));
      await tester.pumpAndSettle();

      // Verify WalletTopupDialog is opened
      expect(find.text('Ví ForgeCoins & Gói VIP'), findsOneWidget);
      expect(find.text('Nạp ForgeCoins'), findsOneWidget);
      expect(find.text('Gói VIP Pass'), findsOneWidget);
    });

    testWidgets('UnlockChapterBottomSheet displays price, balance and unlocks chapter', (WidgetTester tester) async {
      final mockDio = createMockDio();
      const chapter = ChapterItem(
        id: 'ch-test-10',
        number: 10,
        title: 'Chương Bí Mật',
        releaseDate: '31/10/2026',
        pageCount: 20,
        isFree: false,
        isUnlocked: false,
        priceCoins: 50,
        pages: [],
      );

      bool unlockedCallbackCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monetizationServiceProvider.overrideWithValue(MonetizationService(dio: mockDio)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    UnlockChapterBottomSheet.show(
                      context,
                      chapter: chapter,
                      onUnlocked: () => unlockedCallbackCalled = true,
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Mở Khóa Chương Truyện'), findsOneWidget);
      expect(find.text('50 Coins'), findsOneWidget);
      expect(find.text('150 Coins'), findsOneWidget);
      expect(find.text('Mở Khóa Ngay (-50 Coins)'), findsOneWidget);

      // Tap Unlock button
      await tester.tap(find.text('Mở Khóa Ngay (-50 Coins)'));
      await tester.pumpAndSettle();

      expect(unlockedCallbackCalled, isTrue);
      expect(PreferencesService.isChapterUnlocked('ch-test-10'), isTrue);
      expect(PreferencesService.getLocalBalanceCoins(), 100);
    });
  });
}
