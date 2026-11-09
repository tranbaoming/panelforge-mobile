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
          data: {'balanceVnd': 20000, 'balanceCoins': 200, 'isVip': false},
        ));
      }
      if (options.path.endsWith('/api/wallet/topup')) {
        return handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'orderId': 'order-123',
            'coins': 500,
            'amountVnd': 50000,
            'qrCodeUrl': 'https://img.vietqr.io/image/970436-123-compact2.png',
            'bankName': 'Vietcombank',
            'accountNo': '123456789',
            'accountName': 'PANELFORGE JSC',
            'description': 'PFWALLET 123',
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
    await PreferencesService.setLocalBalanceVnd(20000); // 20.000đ
    await PreferencesService.setLocalVip(isVip: false);
    await PreferencesService.saveAuthUser({
      'id': 'reader-test-1',
      'email': 'reader@test.com',
      'fullName': 'Test Reader',
      'isActive': true,
      'role': 'User',
    });
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

      expect(wallet.balanceVnd, 20000);
      expect(wallet.isVip, isFalse);
    });

    test('unlockChapter succeeds and deducts VNĐ when balance is sufficient', () async {
      final service = MonetizationService();
      expect(PreferencesService.isChapterUnlocked('chap-1'), isFalse);

      final resp = await service.unlockChapter(
        chapterId: 'chap-1',
        priceVnd: 5000,
        chapterTitle: 'Chương 1',
      );

      expect(resp.success, isTrue);
      expect(resp.remainingBalanceVnd, 15000);
      expect(PreferencesService.isChapterUnlocked('chap-1'), isTrue);
      expect(PreferencesService.getLocalBalanceVnd(), 15000);
      expect(PreferencesService.getWalletTransactions().isNotEmpty, isTrue);
    });

    test('unlockChapter throws exception when balance is insufficient', () async {
      final service = MonetizationService();
      await PreferencesService.setLocalBalanceVnd(2000);

      expect(
        () => service.unlockChapter(chapterId: 'chap-2', priceVnd: 5000),
        throwsA(isA<Exception>()),
      );
      expect(PreferencesService.isChapterUnlocked('chap-2'), isFalse);
    });

    test('unlockChapter is free for VIP users without deducting VNĐ', () async {
      final service = MonetizationService();
      await PreferencesService.setLocalVip(
        isVip: true,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      await PreferencesService.setLocalBalanceVnd(20000);

      final resp = await service.unlockChapter(chapterId: 'chap-vip-1', priceVnd: 5000);

      expect(resp.success, isTrue);
      expect(resp.remainingBalanceVnd, 20000); // Did not deduct money
      expect(PreferencesService.isChapterUnlocked('chap-vip-1'), isTrue);
    });

    test('subscribeVip activates VIP pass and deducts plan cost', () async {
      final service = MonetizationService();
      await PreferencesService.setLocalBalanceVnd(50000);

      final resp = await service.subscribeVip(plan: 'monthly');

      expect(resp.success, isTrue);
      expect(resp.isVip, isTrue);
      expect(PreferencesService.getLocalIsVip(), isTrue);
    });

    test('requestTopup and completeTopup generate VietQR and add VNĐ to wallet', () async {
      final mockDio = createMockDio();
      final service = MonetizationService(dio: mockDio);
      final topup = await service.requestTopup(amountVnd: 50000);

      expect(topup.amountVnd, 50000);
      expect(topup.qrCodeUrl, contains('vietqr.io'));
      expect(topup.bankName, 'Vietcombank');

      final updated = await service.completeTopup(
        orderId: topup.orderId,
        amountVnd: topup.amountVnd,
      );

      expect(updated.balanceVnd, 70000); // 20.000 + 50.000
      expect(PreferencesService.getLocalBalanceVnd(), 70000);
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

      expect(find.text('20.000đ'), findsNothing);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsNothing);
    });

    testWidgets('WalletChip displays VNĐ and opens WalletTopupDialog on tap when server is connected', (WidgetTester tester) async {
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

      expect(find.text('20.000đ'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);

      // Tap on WalletChip
      await tester.tap(find.byType(WalletChip));
      await tester.pumpAndSettle();

      // Verify WalletTopupDialog is opened with 2 tabs
      expect(find.text('Ví Tiền PanelForge'), findsOneWidget);
      expect(find.text('Nạp Tiền Vào Ví'), findsOneWidget);
      expect(find.text('Lịch Sử Giao Dịch'), findsOneWidget);
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
        priceVnd: 5000,
        isWeeklyHot: true,
        pages: [],
      );

      const series = SeriesItem(
        id: 'series-1',
        title: 'Solo Leveling',
        author: 'Chugong',
        artist: 'DUBU',
        format: ComicFormat.webtoon,
        coverGradientStart: '0xFF112233',
        coverGradientEnd: '0xFF000000',
        synopsisQuote: 'Quote',
        fullSynopsis: 'Full synopsis',
        rating: 4.9,
        views: 100000,
        readProgressChapter: 0,
        totalChapters: 50,
        genres: ['Action'],
        chapters: [chapter],
        editorialNote: 'Note',
        baseChapterPriceVnd: 3000,
        hotChapterPriceVnd: 5000,
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
                      series: series,
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

      expect(find.text('Chương Bí Mật'), findsOneWidget);
      expect(find.text('20.000đ'), findsOneWidget); // Số dư hiện tại
      expect(find.text('-5.000đ'), findsOneWidget); // Giá mở khóa
      expect(find.text('15.000đ'), findsOneWidget); // Số dư sau thanh toán
      expect(find.text('Thanh toán 5.000đ & Đọc ngay'), findsOneWidget);

      // Tap Unlock button
      await tester.tap(find.text('Thanh toán 5.000đ & Đọc ngay'));
      await tester.pumpAndSettle();

      expect(unlockedCallbackCalled, isTrue);
      expect(PreferencesService.isChapterUnlocked('ch-test-10'), isTrue);
      expect(PreferencesService.getLocalBalanceVnd(), 15000);
    });

    test('unlockChapter with rental limited views and consumeChapterView lifecycle', () async {
      final service = MonetizationService();
      await PreferencesService.setLocalBalanceVnd(20000);

      // 1. Mở khóa tập theo gói thuê 3 lượt xem với giá 700đ
      final resp = await service.unlockChapter(
        chapterId: 'chap-rental-1',
        priceVnd: 700,
        isPermanent: false,
        rentalViews: 3,
        chapterTitle: 'Tập 3',
      );

      expect(resp.success, isTrue);
      expect(resp.remainingBalanceVnd, 19300); // 20.000 - 700 = 19.300đ
      expect(resp.isPermanent, isFalse);
      expect(resp.remainingViews, 3);
      expect(PreferencesService.isChapterUnlocked('chap-rental-1'), isTrue);

      final ent = PreferencesService.getChapterEntitlement('chap-rental-1');
      expect(ent, isNotNull);
      expect(ent!.isPermanent, isFalse);
      expect(ent.remainingViews, 3);

      // 2. Lần đầu mở xem: Tiêu hao 1 lượt (còn 2/3)
      final consume1 = await service.consumeChapterView('chap-rental-1');
      expect(consume1.didConsume, isTrue);
      expect(consume1.remainingViews, 2);
      expect(consume1.message, contains('2/3'));

      // 3. Mở lại ngay (trong vòng 10 phút): Không bị trừ thêm lượt xem
      final consumeDuplicate = await service.consumeChapterView('chap-rental-1');
      expect(consumeDuplicate.didConsume, isFalse);
      expect(consumeDuplicate.remainingViews, 2);

      // 4. Giả lập mở lại sau 15 phút: Tiêu hao lượt thứ 2 (còn 1/3)
      final ent2 = PreferencesService.getChapterEntitlement('chap-rental-1')!;
      await PreferencesService.saveChapterEntitlement(
        ent2.copyWith(lastOpenedAt: DateTime.now().subtract(const Duration(minutes: 15))),
      );
      final consume2 = await service.consumeChapterView('chap-rental-1');
      expect(consume2.didConsume, isTrue);
      expect(consume2.remainingViews, 1);

      // 5. Giả lập mở lại sau 15 phút: Tiêu hao lượt thứ 3 (còn 0/3) -> Tự động khóa lại
      final ent3 = PreferencesService.getChapterEntitlement('chap-rental-1')!;
      await PreferencesService.saveChapterEntitlement(
        ent3.copyWith(lastOpenedAt: DateTime.now().subtract(const Duration(minutes: 15))),
      );
      final consume3 = await service.consumeChapterView('chap-rental-1');
      expect(consume3.didConsume, isTrue);
      expect(consume3.remainingViews, 0);
      expect(PreferencesService.isChapterUnlocked('chap-rental-1'), isFalse);
    });

    testWidgets('UnlockChapterBottomSheet switches to Rental option and calculates exact 15.000đ - 700đ = 14.300đ', (WidgetTester tester) async {
      await PreferencesService.setLocalBalanceVnd(15000);

      const chapter = ChapterItem(
        id: 'chap-flex-3',
        number: 3,
        title: 'Tập 3 Đặc Biệt',
        releaseDate: '01/11/2026',
        pageCount: 22,
        isFree: false,
        isUnlocked: false,
        priceVnd: 1000,
        rentalPriceVnd: 700,
        pages: [],
      );

      bool unlocked = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    UnlockChapterBottomSheet.show(
                      context,
                      chapter: chapter,
                      onUnlocked: () => unlocked = true,
                    );
                  },
                  child: const Text('Open Rental Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Rental Sheet'));
      await tester.pumpAndSettle();

      // Ban đầu mặc định chọn Mua Vĩnh Viễn (1.000đ): 15.000 - 1.000 = 14.000đ
      expect(find.text('Mua Vĩnh Viễn'), findsOneWidget);
      expect(find.text('Thuê Xem 3 Lần'), findsOneWidget);
      expect(find.text('-1.000đ'), findsOneWidget);
      expect(find.text('14.000đ'), findsOneWidget);

      // Chuyển sang chọn Thuê Xem 3 Lần (700đ): Tính toán chính xác 15.000đ - 700đ = 14.300đ
      await tester.tap(find.text('Thuê Xem 3 Lần'));
      await tester.pumpAndSettle();

      expect(find.text('-700đ'), findsOneWidget);
      expect(find.text('14.300đ'), findsOneWidget);
      expect(find.text('Thanh toán 700đ & Đọc ngay'), findsOneWidget);

      // Bấm Thanh toán 700đ & Đọc ngay
      await tester.tap(find.text('Thanh toán 700đ & Đọc ngay'));
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
      expect(PreferencesService.getLocalBalanceVnd(), 14300);
      expect(PreferencesService.isChapterUnlocked('chap-flex-3'), isTrue);

      final ent = PreferencesService.getChapterEntitlement('chap-flex-3');
      expect(ent?.isPermanent, isFalse);
      expect(ent?.remainingViews, 3);
    });
  });
}
