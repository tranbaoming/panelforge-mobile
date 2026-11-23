import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'monetization_service.dart';

/// Dịch vụ thanh toán Google Play Billing (In-App Purchase) đạt chuẩn CH Play.
///
/// Mỗi mệnh giá nạp Ví ánh xạ tới 1 Consumable Product ID cấu hình trên Google Play Console.
/// Sau khi Google Play xác nhận thanh toán, `purchaseToken` được gửi về Backend
/// (`POST /api/wallet/google-play/verify`) để xác thực, chống cộng trùng và cộng số dư Ví.
class GooglePlayBillingService {
  static const String androidPackageName = 'com.panelforge.reader';

  /// Bảng ánh xạ Mệnh giá (VNĐ) ↔ SKU trên Google Play Console.
  static const Map<int, String> amountToProductId = {
    20000: 'panelforge_topup_20k',
    50000: 'panelforge_topup_50k',
    100000: 'panelforge_topup_100k',
    200000: 'panelforge_topup_200k',
    500000: 'panelforge_topup_500k',
  };

  static String? productIdForAmount(int amountVnd) => amountToProductId[amountVnd];

  final MonetizationService _monetization;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  GooglePlayBillingService({MonetizationService? monetization})
      : _monetization = monetization ?? MonetizationService();

  /// Kiểm tra Google Play Billing có sẵn trên thiết bị hiện tại không.
  Future<bool> isAvailable() async {
    try {
      return await InAppPurchase.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Tải thông tin giá hiển thị từ Google Play Store cho các gói nạp Ví.
  Future<List<ProductDetails>> queryTopupProducts() async {
    if (!await isAvailable()) return const [];
    final response = await InAppPurchase.instance.queryProductDetails(amountToProductId.values.toSet());
    return response.productDetails;
  }

  /// Lắng nghe luồng giao dịch Google Play và tự động xác thực với Backend.
  void listenPurchases({
    required void Function(GooglePlayVerifyResult result) onVerified,
    required void Function(String errorMessage) onError,
  }) {
    _subscription?.cancel();
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          await _handlePurchase(purchase, onVerified: onVerified, onError: onError);
        }
      },
      onError: (Object err) {
        onError('Lỗi luồng thanh toán Google Play: $err');
      },
    );
  }

  /// Khởi chạy hộp thoại thanh toán chính chủ Google Play cho gói nạp [amountVnd].
  Future<bool> buyTopupAmount(int amountVnd) async {
    final productId = productIdForAmount(amountVnd);
    if (productId == null) {
      throw ArgumentError('Mệnh giá $amountVnd VNĐ chưa có SKU trên Google Play.');
    }
    final products = await queryTopupProducts();
    final product = products.where((p) => p.id == productId).firstOrNull;
    if (product == null) {
      return false;
    }
    final param = PurchaseParam(productDetails: product);
    return InAppPurchase.instance.buyConsumable(purchaseParam: param, autoConsume: true);
  }

  Future<void> _handlePurchase(
    PurchaseDetails purchase, {
    required void Function(GooglePlayVerifyResult result) onVerified,
    required void Function(String errorMessage) onError,
  }) async {
    if (purchase.status == PurchaseStatus.error) {
      onError(purchase.error?.message ?? 'Thanh toán Google Play thất bại.');
      return;
    }

    if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
      try {
        final token = purchase.verificationData.serverVerificationData;
        final result = await _monetization.verifyGooglePlayPurchase(
          productId: purchase.productID,
          purchaseToken: token,
          packageName: androidPackageName,
        );
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
        onVerified(result);
      } catch (e) {
        debugPrint('[GooglePlayBilling] Lỗi xác thực giao dịch: $e');
        onError('Không thể xác thực giao dịch Google Play với máy chủ: $e');
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
