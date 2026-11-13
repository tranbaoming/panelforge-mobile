import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panelforge/models/api_dtos.dart';
import 'package:panelforge/models/comic_model.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/widgets/unlock_chapter_bottom_sheet.dart';
import 'package:panelforge/widgets/wallet_chip.dart';

/// Backend giả lập theo đúng hợp đồng `WalletController` (.NET).
class FakeWalletBackend {
  int balanceVnd;
  bool isVip;
  final Set<String> unlocked = {};
  final List<RequestOptions> requests = [];
  String orderStatus = 'Pending';
  bool unauthorized = false;

  FakeWalletBackend({this.balanceVnd = 20000, this.isVip = false});

  Dio createDio() {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requests.add(options);
        Response<dynamic> ok(dynamic data) =>
            Response(requestOptions: options, statusCode: 200, data: data);
        DioException fail(int code, String message) => DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(requestOptions: options, statusCode: code, data: {'message': message}),
            );

        if (unauthorized) {
          return handler.reject(fail(401, 'Chưa xác thực người dùng.'));
        }
        final path = options.path;
        final body = (options.data as Map<String, dynamic>?) ?? {};

        if (path.endsWith('/api/wallet/me')) {
          return handler.resolve(ok({
            'balanceVnd': balanceVnd,
            'balanceCoins': balanceVnd ~/ 100,
            'isVip': isVip,
            'vipExpiresAt': null,
            'unlockedChapterIds': unlocked.toList(),
            'transactions': [
              {'id': 'PF100001', 'title': 'Nạp ví', 'amountVnd': 20000, 'createdAt': '2026-11-01T00:00:00Z', 'balanceAfter': 20000},
            ],
          }));
        }
        if (path.endsWith('/api/wallet/unlock-chapter')) {
          const price = 5000; // giá do server lấy từ chương
          if (!isVip && balanceVnd < price) {
            return handler.reject(fail(400, 'Số dư trong Ví không đủ để mở khóa chương (thiếu 3.000đ).'));
          }
          if (!isVip) balanceVnd -= price;
          unlocked.add(body['chapterId'] as String);
          return handler.resolve(ok({
            'chapterId': body['chapterId'],
            'success': true,
            'remainingCoins': balanceVnd ~/ 100,
            'remainingBalanceVnd': balanceVnd,
            'message': 'Đã trừ 5.000đ trong Ví. Mở khóa vĩnh viễn thành công!',
            'isPermanent': true,
          }));
        }
        if (path.endsWith('/api/wallet/subscribe-vip')) {
          balanceVnd -= 19900;
          isVip = true;
          return handler.resolve(ok({
            'success': true,
            'isVip': true,
            'vipExpiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
            'remainingCoins': balanceVnd ~/ 100,
          }));
        }
        if (path.endsWith('/api/wallet/topup')) {
          final purpose = body['purpose'];
          final amount = purpose == 'ChapterUnlock' ? 5000 : (body['amountVnd'] as int? ?? 0);
          return handler.resolve(ok({
            'orderId': 'PF123456',
            'coins': amount ~/ 100,
            'amountVnd': amount,
            'qrCodeUrl':
                'https://img.vietqr.io/image/970422-0123456789-compact2.png?amount=$amount&addInfo=PF123456&accountName=MOON%20STUDIO',
            'bankName': 'MB Bank',
            'accountNumber': '0123456789',
            'accountName': 'MOON STUDIO',
            'transferContent': 'PF123456',
            'isCompleted': false,
            'purpose': purpose,
            'status': 'Pending',
          }));
        }
        if (path.endsWith('/api/wallet/transactions/PF123456/status')) {
          if (orderStatus == 'Approved') unlocked.add('ch-qr');
          return handler.resolve(ok({
            'orderCode': 'PF123456',
            'status': orderStatus,
            'isCompleted': orderStatus == 'Approved',
            'amountVnd': 5000,
            'confirmedAt': null,
            'rejectionReason': null,
          }));
        }
        return handler.reject(fail(404, 'Not found'));
      },
    ));
    return dio;
  }

  Map<String, dynamic> lastBody(String pathSuffix) =>
      requests.lastWhere((r) => r.path.endsWith(pathSuffix)).data as Map<String, dynamic>;
}

const _paidChapter = ChapterItem(
  id: 'ch-test-10',
  number: 10,
  title: 'Chương Bí Mật',
  releaseDate: '31/10/2026',
  pageCount: 20,
  isFree: false,
  isUnlocked: false,
  priceVnd: 5000,
  pages: [],
);

Widget _sheetHost(FakeWalletBackend backend, ChapterItem chapter, VoidCallback onUnlocked) {
  return ProviderScope(
    overrides: [
      monetizationServiceProvider.overrideWithValue(MonetizationService(dio: backend.createDio())),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => UnlockChapterBottomSheet.show(context, chapter: chapter, onUnlocked: onUnlocked),
            child: const Text('Open Sheet'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
    await PreferencesService.saveAuthUser({
      'id': 'reader-test-1',
      'email': 'reader@test.com',
      'fullName': 'Test Reader',
      'isActive': true,
      'role': 'User',
    });
  });

  group('PublicChapterSummaryDto — trạng thái khóa từ Backend', () {
    test('đọc isLocked / priceVnd / isUnlocked, không tự suy diễn giá', () {
      final locked = PublicChapterSummaryDto.fromJson({
        'id': 'c2',
        'chapterNumber': 2,
        'isLocked': true,
        'priceVnd': 15000,
        'isUnlocked': false,
        'isFree': false,
      });
      expect(locked.isLocked, isTrue);
      expect(locked.isFree, isFalse);
      expect(locked.priceVnd, 15000);
      expect(locked.isUnlocked, isFalse);

      final free = PublicChapterSummaryDto.fromJson({'id': 'c3', 'chapterNumber': 3, 'isLocked': false, 'priceVnd': 0});
      expect(free.isLocked, isFalse);
      expect(free.priceVnd, 0);
      expect(free.isUnlocked, isTrue);
    });
  });

  group('MonetizationService ↔ WalletController', () {
    test('getMyWallet đồng bộ số dư, VIP và chương đã mở khóa từ server', () async {
      final backend = FakeWalletBackend(balanceVnd: 20000)..unlocked.add('ch-owned');
      await PreferencesService.addUnlockedChapterId('stale-from-other-account');

      final wallet = await MonetizationService(dio: backend.createDio()).getMyWallet();

      expect(wallet.balanceVnd, 20000);
      expect(wallet.unlockedChapterIds, {'ch-owned'});
      expect(wallet.transactions, hasLength(1));
      expect(PreferencesService.getUnlockedChapterIds(), {'ch-owned'});
    });

    test('getMyWallet ném ApiException 401 khi chưa đăng nhập', () async {
      final backend = FakeWalletBackend()..unauthorized = true;
      await expectLater(
        MonetizationService(dio: backend.createDio()).getMyWallet(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('unlockChapterWithWallet dùng giá server và lưu quyền đọc', () async {
      final backend = FakeWalletBackend(balanceVnd: 20000);
      final resp = await MonetizationService(dio: backend.createDio())
          .unlockChapterWithWallet(chapterId: 'ch-1', seriesId: 'series-1');

      expect(resp.remainingBalanceVnd, 15000);
      expect(backend.lastBody('/unlock-chapter'), containsPair('seriesId', 'series-1'));
      expect(backend.lastBody('/unlock-chapter').containsKey('priceVnd'), isFalse);
      expect(PreferencesService.isChapterUnlocked('ch-1'), isTrue);
    });

    test('unlockChapterWithWallet báo lỗi rõ ràng khi số dư không đủ', () async {
      final backend = FakeWalletBackend(balanceVnd: 2000);
      await expectLater(
        MonetizationService(dio: backend.createDio()).unlockChapterWithWallet(chapterId: 'ch-2'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('không đủ'))),
      );
      expect(PreferencesService.isChapterUnlocked('ch-2'), isFalse);
    });

    test('createVietQrOrder gửi đủ ngữ cảnh và nhận orderCode + tài khoản Studio', () async {
      final backend = FakeWalletBackend();
      final order = await MonetizationService(dio: backend.createDio()).createVietQrOrder(
        purpose: PaymentPurpose.chapterUnlock,
        chapterId: 'ch-qr',
        seriesId: 'series-1',
      );

      expect(backend.lastBody('/topup'), {
        'paymentMethod': 'vietqr',
        'purpose': 'ChapterUnlock',
        'seriesId': 'series-1',
        'chapterId': 'ch-qr',
      });
      expect(order.orderCode, 'PF123456');
      expect(order.requiredTransferContent, 'PF123456');
      expect(order.qrCodeUrl, contains('img.vietqr.io'));
      expect(order.accountName, 'MOON STUDIO');
      expect(order.amountVnd, 5000);
    });

    test('getTransactionStatus phản ánh trạng thái Producer duyệt', () async {
      final backend = FakeWalletBackend();
      final service = MonetizationService(dio: backend.createDio());

      expect((await service.getTransactionStatus('PF123456')).isPending, isTrue);
      backend.orderStatus = 'Approved';
      expect((await service.getTransactionStatus('PF123456')).isApproved, isTrue);
    });

    test('subscribeVipWithWallet kích hoạt VIP', () async {
      final backend = FakeWalletBackend(balanceVnd: 50000);
      final resp = await MonetizationService(dio: backend.createDio()).subscribeVipWithWallet(plan: 'monthly');

      expect(resp.isVip, isTrue);
      expect(PreferencesService.getLocalIsVip(), isTrue);
    });
  });

  group('Widgets thanh toán', () {
    testWidgets('WalletChip ẩn khi mất kết nối máy chủ', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: Center(child: WalletChip(isServerConnected: false)))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsNothing);
    });

    testWidgets('WalletChip hiển thị số dư server và mở Ví', (tester) async {
      final backend = FakeWalletBackend(balanceVnd: 20000);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [monetizationServiceProvider.overrideWithValue(MonetizationService(dio: backend.createDio()))],
          child: const MaterialApp(home: Scaffold(body: Center(child: WalletChip(isServerConnected: true)))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('20.000đ'), findsOneWidget);

      await tester.tap(find.byType(WalletChip));
      await tester.pumpAndSettle();
      expect(find.text('Ví Tiền PanelForge'), findsOneWidget);
      expect(find.text('Lịch Sử Giao Dịch'), findsOneWidget);
    });

    testWidgets('UnlockChapterBottomSheet trừ Ví theo giá chương và mở khóa', (tester) async {
      final backend = FakeWalletBackend(balanceVnd: 20000);
      var unlocked = false;

      await tester.pumpWidget(_sheetHost(backend, _paidChapter, () => unlocked = true));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Chương Bí Mật'), findsOneWidget);
      expect(find.text('-5.000đ'), findsOneWidget);
      expect(find.text('15.000đ'), findsOneWidget);

      await tester.tap(find.text('Thanh toán 5.000đ & Đọc ngay'));
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
      expect(PreferencesService.isChapterUnlocked('ch-test-10'), isTrue);
      expect(PreferencesService.getLocalBalanceVnd(), 15000);
    });

    testWidgets('UnlockChapterBottomSheet: VietQR → chờ Producer → tự mở khóa khi Approved', (tester) async {
      final backend = FakeWalletBackend(balanceVnd: 0);
      var unlocked = false;
      const chapter = ChapterItem(
        id: 'ch-qr',
        number: 11,
        title: 'Chương VietQR',
        releaseDate: '01/11/2026',
        pageCount: 10,
        isFree: false,
        isUnlocked: false,
        priceVnd: 5000,
        pages: [],
      );

      await tester.pumpWidget(_sheetHost(backend, chapter, () => unlocked = true));
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chuyển khoản VietQR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo mã VietQR 5.000đ'));
      // Không dùng pumpAndSettle: placeholder ảnh QR có spinner chạy liên tục.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('PF123456'), findsOneWidget); // Nội dung CK bắt buộc
      expect(find.text('MOON STUDIO'), findsOneWidget);
      expect(backend.lastBody('/topup')['purpose'], 'ChapterUnlock');

      await tester.ensureVisible(find.text('Tôi đã chuyển khoản'));
      await tester.pump();
      await tester.tap(find.text('Tôi đã chuyển khoản'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Đang chờ Studio xác nhận'), findsOneWidget);

      // Producer bấm "Xác nhận đã nhận tiền" trên Web → lần polling kế tiếp nhận Approved.
      backend.orderStatus = 'Approved';
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
      expect(PreferencesService.isChapterUnlocked('ch-qr'), isTrue);
    });
  });
}
