import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_dtos.dart';
import 'api_client.dart';
import 'preferences_service.dart';
import '../providers/api_providers.dart' show authStateProvider;

/// Dịch vụ Ví độc giả, mở khóa chương và thanh toán VietQR — kết nối trực tiếp `WalletController`.
///
/// Mọi số dư, giá và quyền sở hữu đều do Backend quyết định. Cache trong [PreferencesService]
/// chỉ dùng để hiển thị nhanh và luôn được ghi đè bằng dữ liệu `GET /api/wallet/me`.
class MonetizationService {
  final ApiClient _client;

  MonetizationService({ApiClient? client, Dio? dio})
    : _client = client ?? (dio != null ? ApiClient(customDio: dio) : ApiClient());

  /// `GET /api/wallet/me` — số dư, chương đã mở khóa và lịch sử giao dịch.
  Future<UserWalletDto> getMyWallet() async {
    final response = await _client.get('/api/wallet/me');
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ApiException('Máy chủ phản hồi không hợp lệ.', statusCode: response.statusCode);
    }
    final wallet = UserWalletDto.fromJson(data);
    await _cacheWallet(wallet);
    return wallet;
  }

  /// `POST /api/wallet/unlock-chapter` — mở khóa vĩnh viễn ấn bản bằng số dư Ví.
  /// Giá trừ do server lấy từ cấu hình ấn bản ngôn ngữ của chương trên web.
  Future<UnlockChapterResponse> unlockChapterWithWallet({
    required String chapterId,
    String? seriesId,
    String? language,
  }) async {
    final response = await _client.post(
      '/api/wallet/unlock-chapter',
      data: UnlockChapterRequest(chapterId: chapterId, seriesId: seriesId, language: language).toJson(),
    );
    final resp = UnlockChapterResponse.fromJson(response.data as Map<String, dynamic>);
    if (!resp.success) {
      throw ApiException(resp.message ?? 'Không thể mở khóa chương.');
    }
    await PreferencesService.setLocalBalanceVnd(resp.remainingBalanceVnd);
    await PreferencesService.saveChapterEntitlement(
      ChapterEntitlement(
        chapterId: chapterId,
        language: language,
        isPermanent: true,
        unlockedAt: DateTime.now(),
      ),
    );
    return resp;
  }

  /// `POST /api/wallet/topup` — tạo đơn VietQR (Pending) để nạp Ví hoặc mở khóa ấn bản.
  ///
  /// - [PaymentPurpose.topup]: nạp [amountVnd] vào Ví.
  /// - [PaymentPurpose.chapterUnlock]: trả trực tiếp để mở [chapterId] (giá do server lấy từ ấn bản).
  Future<TopupResponse> createVietQrOrder({
    PaymentPurpose purpose = PaymentPurpose.topup,
    int? amountVnd,
    String? workspaceId,
    String? seriesId,
    String? chapterId,
    String? language,
  }) async {
    final response = await _client.post(
      '/api/wallet/topup',
      data: TopupRequest(
        amountVnd: amountVnd,
        purpose: purpose,
        workspaceId: workspaceId,
        seriesId: seriesId,
        chapterId: chapterId,
        language: language,
      ).toJson(),
    );
    final order = TopupResponse.fromJson(response.data as Map<String, dynamic>);
    if (order.orderId.isEmpty || order.qrCodeUrl == null) {
      throw ApiException('Máy chủ chưa trả về mã VietQR hợp lệ. Vui lòng thử lại.');
    }
    return order;
  }

  /// `GET /api/wallet/transactions/{orderCode}/status` — kiểm tra đơn đã được duyệt trên web chưa.
  Future<TransactionStatusDto> getTransactionStatus(String orderCode) async {
    final response = await _client.get('/api/wallet/transactions/${Uri.encodeComponent(orderCode)}/status');
    return TransactionStatusDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// `POST /api/wallet/google-play/verify` — xác thực giao dịch Google Play Billing (CH Play) và cộng Ví.
  Future<GooglePlayVerifyResult> verifyGooglePlayPurchase({
    required String productId,
    required String purchaseToken,
    String packageName = 'com.panelforge.reader',
  }) async {
    final response = await _client.post(
      '/api/wallet/google-play/verify',
      data: {
        'productId': productId,
        'purchaseToken': purchaseToken,
        'packageName': packageName,
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ApiException('Máy chủ phản hồi không hợp lệ.', statusCode: response.statusCode);
    }
    final result = GooglePlayVerifyResult.fromJson(data);
    await PreferencesService.setLocalBalanceVnd(result.balanceVnd);
    return result;
  }

  /// `POST /api/wallet/transactions/{orderCode}/dispute` — gửi báo cáo lỗi giao dịch để Admin đối soát.
  Future<String> reportTransactionIssue({
    required String orderCode,
    required String reason,
  }) async {
    final response = await _client.post(
      '/api/wallet/transactions/${Uri.encodeComponent(orderCode)}/dispute',
      data: {'reason': reason.trim()},
    );
    if (response.data is Map<String, dynamic>) {
      return response.data['message']?.toString() ?? 'Đã gửi yêu cầu đối soát giao dịch.';
    }
    return 'Đã gửi yêu cầu đối soát giao dịch.';
  }

  /// Backend chỉ hỗ trợ mở khóa vĩnh viễn: không còn trừ lượt xem phía client.
  Future<ConsumeViewResult> consumeChapterView(String chapterId) async {
    return const ConsumeViewResult(didConsume: false, isPermanent: true);
  }

  /// Xóa cache Ví khi phiên đăng nhập không còn hợp lệ (Guest / đăng xuất / 401).
  Future<void> clearLocalCache() async {
    await PreferencesService.clearLocalWallet();
    await PreferencesService.replaceUnlockedChapterIds(const {});
  }

  Future<void> _cacheWallet(UserWalletDto wallet) async {
    await PreferencesService.setLocalBalanceVnd(wallet.balanceVnd);
    await PreferencesService.replaceUnlockedChapterIds(wallet.unlockedChapterIds);
  }
}

/// Kết quả xác thực nạp tiền qua Google Play Billing (`POST /api/wallet/google-play/verify`).
class GooglePlayVerifyResult {
  final bool success;
  final int balanceVnd;
  final int creditedVnd;
  final String orderCode;
  final bool alreadyProcessed;
  final String message;

  const GooglePlayVerifyResult({
    required this.success,
    required this.balanceVnd,
    required this.creditedVnd,
    required this.orderCode,
    required this.alreadyProcessed,
    required this.message,
  });

  factory GooglePlayVerifyResult.fromJson(Map<String, dynamic> json) {
    return GooglePlayVerifyResult(
      success: json['success'] == true,
      balanceVnd: (json['balanceVnd'] as num?)?.toInt() ?? 0,
      creditedVnd: (json['creditedVnd'] as num?)?.toInt() ?? 0,
      orderCode: json['orderCode']?.toString() ?? '',
      alreadyProcessed: json['alreadyProcessed'] == true,
      message: json['message']?.toString() ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIVERPOD NOTIFIERS & PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final monetizationServiceProvider = Provider<MonetizationService>((ref) {
  return MonetizationService();
});

/// Notifier trạng thái Ví & VIP toàn ứng dụng — luôn đồng bộ từ `GET /api/wallet/me`.
class WalletNotifier extends Notifier<AsyncValue<UserWalletDto>> {
  @override
  AsyncValue<UserWalletDto> build() {
    ref.listen<String?>(authStateProvider.select((s) => s.user?.id), (prev, next) {
      if (prev != next) {
        _syncEntitlementProviders();
        state = const AsyncLoading();
        if (next != null) {
          Future.microtask(_load);
        }
      }
    });
    Future.microtask(_load);
    return const AsyncLoading();
  }

  MonetizationService get _service => ref.read(monetizationServiceProvider);

  Future<void> _load() async {
    try {
      final wallet = await _service.getMyWallet();
      state = AsyncData(wallet);
      _syncEntitlementProviders();
    } catch (e, st) {
      if (e is ApiException && e.statusCode == 401) {
        await _service.clearLocalCache();
        _syncEntitlementProviders();
      } else {
        debugPrint('[WalletNotifier] Không tải được Ví: $e');
      }
      state = AsyncError(e, st);
    }
  }

  /// Làm mới Ví (dùng sau khi đơn được duyệt trên web, đăng nhập lại, kéo để làm mới...).
  /// [silent] = true giữ nguyên dữ liệu đang hiển thị trong lúc tải.
  Future<void> refresh({bool silent = false}) async {
    if (!silent || state.asData == null) state = const AsyncLoading();
    await _load();
  }

  /// Mở khóa chương bằng số dư Ví (hoặc VIP).
  Future<UnlockChapterResponse> unlockChapter(String chapterId, {String? seriesId, String? language}) async {
    final response = await _service.unlockChapterWithWallet(
      chapterId: chapterId,
      seriesId: seriesId,
      language: language,
    );
    final editionKey = ChapterEntitlement.editionKey(chapterId, language);
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          balanceVnd: response.remainingBalanceVnd,
          unlockedChapterIds: {...current.unlockedChapterIds, chapterId, editionKey},
        ),
      );
    }
    ref.read(unlockedChaptersProvider.notifier).add(chapterId, language: language);
    ref.read(chapterEntitlementsProvider.notifier).refresh();
    // Lấy lại lịch sử giao dịch thật từ server mà không làm nháy UI.
    unawaited(refresh(silent: true));
    return response;
  }

  /// Tiêu hao lượt xem — giữ API cho Reader; Backend chỉ có quyền đọc vĩnh viễn.
  Future<ConsumeViewResult> consumeChapterView(String chapterId) => _service.consumeChapterView(chapterId);

  void _syncEntitlementProviders() {
    ref.read(unlockedChaptersProvider.notifier).refresh();
    ref.read(chapterEntitlementsProvider.notifier).refresh();
  }
}

final walletNotifierProvider = NotifierProvider<WalletNotifier, AsyncValue<UserWalletDto>>(WalletNotifier.new);

/// Notifier quản lý danh sách các chapterId / editionKey đã mở khóa (cache của `UnlockedChapterIds` trên server).
class UnlockedChaptersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return PreferencesService.getUnlockedChapterIds();
  }

  void refresh() {
    state = PreferencesService.getUnlockedChapterIds();
  }

  void add(String chapterId, {String? language}) {
    PreferencesService.addUnlockedChapterId(chapterId, language: language);
    final editionKey = ChapterEntitlement.editionKey(chapterId, language);
    state = {...state, chapterId, editionKey};
  }

  void remove(String chapterId, {String? language}) {
    PreferencesService.removeUnlockedChapterId(chapterId, language: language);
    final editionKey = ChapterEntitlement.editionKey(chapterId, language);
    state = state.where((id) => id != chapterId && id != editionKey).toSet();
  }

  bool isUnlocked(String chapterId, {String? language}) {
    final clean = chapterId.trim();
    if (language != null && language.trim().isNotEmpty) {
      final key = ChapterEntitlement.editionKey(clean, language);
      if (state.contains(key)) return true;
      if (state.any((id) => id.startsWith('$clean:'))) return false;
    }
    return state.contains(clean);
  }
}

final unlockedChaptersProvider = NotifierProvider<UnlockedChaptersNotifier, Set<String>>(UnlockedChaptersNotifier.new);

/// Notifier quản lý quyền sở hữu từng chapter (cache cục bộ).
class ChapterEntitlementsNotifier extends Notifier<Map<String, ChapterEntitlement>> {
  @override
  Map<String, ChapterEntitlement> build() {
    return PreferencesService.getChapterEntitlements();
  }

  void refresh() {
    state = PreferencesService.getChapterEntitlements();
  }

  void save(ChapterEntitlement ent) {
    PreferencesService.saveChapterEntitlement(ent);
    state = {...state, ent.chapterId: ent};
  }

  ChapterEntitlement? getEntitlement(String chapterId) {
    return state[chapterId] ?? PreferencesService.getChapterEntitlement(chapterId);
  }
}

final chapterEntitlementsProvider = NotifierProvider<ChapterEntitlementsNotifier, Map<String, ChapterEntitlement>>(
  ChapterEntitlementsNotifier.new,
);
