import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/google_play_billing_service.dart';
import 'package:panelforge/services/monetization_service.dart';

void main() {
  group('GooglePlayBillingService SKU Catalog & DTOs', () {
    test('maps supported VND topup amounts to Google Play product IDs', () {
      expect(GooglePlayBillingService.productIdForAmount(10000), 'panelforge_topup_10k');
      expect(GooglePlayBillingService.productIdForAmount(20000), 'panelforge_topup_20k');
      expect(GooglePlayBillingService.productIdForAmount(50000), 'panelforge_topup_50k');
      expect(GooglePlayBillingService.productIdForAmount(100000), 'panelforge_topup_100k');
      expect(GooglePlayBillingService.productIdForAmount(200000), 'panelforge_topup_200k');
      expect(GooglePlayBillingService.productIdForAmount(500000), 'panelforge_topup_500k');
      expect(GooglePlayBillingService.productIdForAmount(99999), isNull);
    });

    test('parses GooglePlayVerifyResult from backend JSON', () {
      final result = GooglePlayVerifyResult.fromJson({
        'success': true,
        'balanceVnd': 150000,
        'creditedVnd': 50000,
        'orderCode': 'GP1234567890ABCDEF',
        'alreadyProcessed': false,
        'message': 'Đã nạp thành công 50,000 VNĐ',
      });

      expect(result.success, isTrue);
      expect(result.balanceVnd, 150000);
      expect(result.creditedVnd, 50000);
      expect(result.orderCode, 'GP1234567890ABCDEF');
      expect(result.alreadyProcessed, isFalse);
    });
  });

  group('GooglePlayBillingService purchase handling', () {
    PurchaseDetails purchase(PurchaseStatus status, {String token = 'tok-1'}) => PurchaseDetails(
          productID: 'panelforge_topup_50k',
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: token,
            source: 'google_play',
          ),
          transactionDate: '0',
          status: status,
        );

    const ok = GooglePlayVerifyResult(
      success: true,
      balanceVnd: 50000,
      creditedVnd: 50000,
      orderCode: 'GP1',
      alreadyProcessed: false,
      message: 'ok',
    );

    late List<PurchaseDetails> verified;
    late List<PurchaseDetails> finished;
    late List<BillingEvent> events;
    late bool loggedIn;
    late Future<GooglePlayVerifyResult> Function() verifyResult;
    late GooglePlayBillingService service;

    setUp(() {
      verified = [];
      finished = [];
      events = [];
      loggedIn = true;
      verifyResult = () async => ok;
      service = GooglePlayBillingService(
        verify: (p) {
          verified.add(p);
          return verifyResult();
        },
        isLoggedIn: () => loggedIn,
        finish: (p) async => finished.add(p),
      );
      service.events.listen(events.add);
    });

    tearDown(() => service.dispose());

    Future<void> handle(PurchaseDetails p) async {
      await service.handlePurchase(p);
      await Future<void>.delayed(Duration.zero);
    }

    test('canceled purchase emits BillingCanceled so the spinner stops', () async {
      await handle(purchase(PurchaseStatus.canceled));
      expect(events.single, isA<BillingCanceled>());
      expect(verified, isEmpty);
    });

    test('pending purchase emits BillingPending and is not verified yet', () async {
      await handle(purchase(PurchaseStatus.pending));
      expect(events.single, isA<BillingPending>());
      expect(verified, isEmpty);
    });

    test('purchased: consumes only after the server verified it', () async {
      await handle(purchase(PurchaseStatus.purchased));
      expect(verified, hasLength(1));
      expect(finished, hasLength(1));
      expect((events.single as BillingVerified).result.creditedVnd, 50000);
    });

    test('server unreachable: purchase kept (not consumed) and marked retryable', () async {
      verifyResult = () async => throw ApiException('Máy chủ bận', statusCode: 503);
      await handle(purchase(PurchaseStatus.purchased));
      expect(finished, isEmpty);
      expect((events.single as BillingFailed).retryable, isTrue);
    });

    test('server rejects token: not consumed, not retryable', () async {
      verifyResult = () async => throw ApiException('Google Play không tìm thấy giao dịch này.', statusCode: 400);
      await handle(purchase(PurchaseStatus.purchased));
      expect(finished, isEmpty);
      expect((events.single as BillingFailed).retryable, isFalse);
    });

    test('logged out: does not send token, keeps purchase for later', () async {
      loggedIn = false;
      await handle(purchase(PurchaseStatus.restored));
      expect(verified, isEmpty);
      expect(finished, isEmpty);
      expect((events.single as BillingFailed).retryable, isTrue);
    });

    test('purchase stream delivered twice at once is verified only once', () async {
      final p = purchase(PurchaseStatus.purchased);
      await Future.wait([service.handlePurchase(p), service.handlePurchase(p)]);
      expect(verified, hasLength(1));
    });
  });
}
