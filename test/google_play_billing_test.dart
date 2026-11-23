import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/services/google_play_billing_service.dart';
import 'package:panelforge/services/monetization_service.dart';

void main() {
  group('GooglePlayBillingService SKU Catalog & DTOs', () {
    test('maps supported VND topup amounts to Google Play product IDs', () {
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
}
