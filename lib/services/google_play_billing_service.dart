import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../providers/api_providers.dart';
import 'api_client.dart';
import 'monetization_service.dart';

/// Kết quả một giao dịch Google Play sau khi xử lý, phát ra cho UI qua [GooglePlayBillingService.events].
sealed class BillingEvent {
  const BillingEvent();
}

/// Máy chủ đã xác thực với Google và cộng Ví.
class BillingVerified extends BillingEvent {
  final GooglePlayVerifyResult result;
  const BillingVerified(this.result);
}

/// Người dùng đóng hộp thoại thanh toán Google Play.
class BillingCanceled extends BillingEvent {
  const BillingCanceled();
}

/// Giao dịch đang chờ thanh toán (vd. trả tiền mặt tại cửa hàng) — Ví được cộng khi Google xác nhận.
class BillingPending extends BillingEvent {
  const BillingPending();
}

/// Thanh toán / xác thực thất bại. [retryable] = giao dịch được giữ lại và tự thử lại ở lần mở app sau.
class BillingFailed extends BillingEvent {
  final String message;
  final bool retryable;
  const BillingFailed(this.message, {this.retryable = false});
}

/// Dịch vụ thanh toán Google Play Billing (In-App Purchase) đạt chuẩn CH Play — một thể hiện cho cả app.
///
/// - Lắng nghe `purchaseStream` từ lúc mở app để không bỏ sót giao dịch về khi không màn nào đang mở.
/// - Gửi `purchaseToken` về Backend (`POST /api/wallet/google-play/verify`); Backend hỏi Google rồi mới cộng Ví.
/// - Chỉ **consume** gói nạp sau khi Backend xác thực xong: lỗi mạng / máy chủ thì giao dịch được giữ lại
///   và gửi lại qua [retryPendingPurchases] (Backend chống cộng trùng theo token).
class GooglePlayBillingService {
  static const String androidPackageName = 'com.panelforge.reader';

  /// Bảng ánh xạ Mệnh giá (VNĐ) ↔ SKU trên Google Play Console.
  static const Map<int, String> amountToProductId = {
    10000: 'panelforge_topup_10k',
    20000: 'panelforge_topup_20k',
    50000: 'panelforge_topup_50k',
    100000: 'panelforge_topup_100k',
    200000: 'panelforge_topup_200k',
    500000: 'panelforge_topup_500k',
  };

  static String? productIdForAmount(int amountVnd) => amountToProductId[amountVnd];

  /// Thiết bị dùng Google Play Billing để nạp Ví (Android); nơi khác dùng VietQR.
  static bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  final Future<GooglePlayVerifyResult> Function(PurchaseDetails purchase) _verify;
  final Future<void> Function(PurchaseDetails purchase) _finish;
  final bool Function() _isLoggedIn;
  final InAppPurchase? _iap;
  final _events = StreamController<BillingEvent>.broadcast();
  final Set<String> _inFlight = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  GooglePlayBillingService({
    required this._verify,
    required this._isLoggedIn,
    Future<void> Function(PurchaseDetails purchase)? finish,
    InAppPurchase? iap,
  })  : _iap = iap,
        _finish = finish ?? ((p) => _consumeOrComplete(iap ?? InAppPurchase.instance, p));

  /// Sự kiện giao dịch cho UI (tắt vòng quay, hiện thông báo).
  Stream<BillingEvent> get events => _events.stream;

  InAppPurchase get _store => _iap ?? InAppPurchase.instance;

  /// Bắt đầu nghe luồng giao dịch. [purchaseStream] chỉ truyền khi test.
  void start({Stream<List<PurchaseDetails>>? purchaseStream}) {
    if (_subscription != null) return;
    _subscription = (purchaseStream ?? _store.purchaseStream).listen(
      (purchases) async {
        for (final purchase in purchases) {
          await handlePurchase(purchase);
        }
      },
      onError: (Object err) => _emit(BillingFailed('Lỗi luồng thanh toán Google Play: $err')),
    );
  }

  /// Gửi lại các giao dịch đã trả tiền nhưng chưa xác thực xong (vd. mất mạng lúc mua).
  Future<void> retryPendingPurchases() async {
    if (!_isLoggedIn()) return;
    try {
      if (await _store.isAvailable()) await _store.restorePurchases();
    } catch (e) {
      debugPrint('[GooglePlayBilling] Không tải lại được giao dịch dang dở: $e');
    }
  }

  /// Tải thông tin giá hiển thị từ Google Play Store cho các gói nạp Ví.
  Future<List<ProductDetails>> queryTopupProducts() async {
    if (!await _store.isAvailable()) return const [];
    final response = await _store.queryProductDetails(amountToProductId.values.toSet());
    return response.productDetails;
  }

  /// Mở hộp thoại thanh toán Google Play cho gói [amountVnd]. Trả `false` nếu gói chưa có trên Store.
  Future<bool> buyTopupAmount(int amountVnd) async {
    final productId = productIdForAmount(amountVnd);
    if (productId == null) {
      throw ArgumentError('Mệnh giá $amountVnd VNĐ chưa có SKU trên Google Play.');
    }
    final products = await queryTopupProducts();
    final product = products.where((p) => p.id == productId).firstOrNull;
    if (product == null) return false;
    // autoConsume = false: chỉ consume sau khi Backend xác thực, tránh mất tiền khi máy chủ lỗi.
    return _store.buyConsumable(purchaseParam: PurchaseParam(productDetails: product), autoConsume: false);
  }

  @visibleForTesting
  Future<void> handlePurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        _emit(const BillingPending());
        return;
      case PurchaseStatus.canceled:
        _emit(const BillingCanceled());
        return;
      case PurchaseStatus.error:
        _emit(BillingFailed(purchase.error?.message ?? 'Thanh toán Google Play thất bại.'));
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        break;
    }

    if (!amountToProductId.containsValue(purchase.productID)) return;
    if (!_isLoggedIn()) {
      _emit(const BillingFailed('Đăng nhập lại để hoàn tất giao dịch nạp Ví.', retryable: true));
      return;
    }

    final token = purchase.verificationData.serverVerificationData;
    if (!_inFlight.add(token)) return;
    try {
      final result = await _verify(purchase);
      await _finish(purchase);
      _emit(BillingVerified(result));
    } on ApiException catch (e) {
      final code = e.statusCode;
      final rejected = code == 400 || code == 409;
      _emit(BillingFailed(
        rejected ? e.message : 'Chưa xác thực được giao dịch, PanelForge sẽ tự thử lại khi bạn mở app. (${e.message})',
        retryable: !rejected,
      ));
    } catch (e) {
      debugPrint('[GooglePlayBilling] Lỗi xác thực giao dịch: $e');
      _emit(const BillingFailed(
        'Chưa xác thực được giao dịch, PanelForge sẽ tự thử lại khi bạn mở app.',
        retryable: true,
      ));
    } finally {
      _inFlight.remove(token);
    }
  }

  static Future<void> _consumeOrComplete(InAppPurchase store, PurchaseDetails purchase) async {
    if (!kIsWeb && Platform.isAndroid) {
      final android = store.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      await android.consumePurchase(purchase);
      return;
    }
    if (purchase.pendingCompletePurchase) await store.completePurchase(purchase);
  }

  void _emit(BillingEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _events.close();
  }
}

/// Một thể hiện Billing cho cả app; khởi động ở `PanelForgeApp` (chỉ trên Android).
final googlePlayBillingProvider = Provider<GooglePlayBillingService>((ref) {
  final monetization = ref.watch(monetizationServiceProvider);
  final service = GooglePlayBillingService(
    isLoggedIn: () => ref.read(authStateProvider).isAuthenticated,
    verify: (p) => monetization.verifyGooglePlayPurchase(
      productId: p.productID,
      purchaseToken: p.verificationData.serverVerificationData,
      packageName: GooglePlayBillingService.androidPackageName,
    ),
  );
  ref.onDispose(service.dispose);
  return service;
});
