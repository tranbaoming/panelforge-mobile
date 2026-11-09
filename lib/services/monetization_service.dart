import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_dtos.dart';
import 'api_client.dart';
import 'preferences_service.dart';

/// Dịch vụ quản lý Thu phí, Ví ForgeCoins, Mở khóa chương truyện và Gói VIP
class MonetizationService {
  final ApiClient _client;

  MonetizationService({ApiClient? client, Dio? dio})
      : _client = client ?? (dio != null ? ApiClient(customDio: dio) : ApiClient());

  Dio get _dio => _client.dio;

  /// Lấy thông tin ví và trạng thái VIP của người dùng hiện tại từ máy chủ
  Future<UserWalletDto> getMyWallet() async {
    try {
      final response = await _dio.get('/api/wallet/me');
      if (response.statusCode == 200 && response.data != null) {
        final wallet = UserWalletDto.fromJson(response.data as Map<String, dynamic>);
        // Đồng bộ cache cục bộ
        await PreferencesService.setLocalBalanceVnd(wallet.balanceVnd);
        await PreferencesService.setLocalVip(
          isVip: wallet.isVip,
          expiresAt: wallet.vipExpiresAt,
        );
        return UserWalletDto(
          balanceVnd: wallet.balanceVnd,
          isVip: wallet.isVip,
          vipExpiresAt: wallet.vipExpiresAt,
          transactions: PreferencesService.getWalletTransactions(),
        );
      }
      throw ApiException('Máy chủ phản hồi không hợp lệ (${response.statusCode})');
    } catch (e) {
      debugPrint('[MonetizationService] API /api/wallet/me thất bại: $e');
      rethrow;
    }
  }

  /// Mở khóa một chương truyện bằng tiền trong Ví (VNĐ) hoặc đặc quyền VIP
  /// [isPermanent] = true: Mua vĩnh viễn (cho phép tải .CBZ offline)
  /// [isPermanent] = false: Thuê xem theo lượt ([rentalViews] lượt đọc)
  Future<UnlockChapterResponse> unlockChapter({
    required String chapterId,
    int priceVnd = 3000,
    int? priceCoins,
    String? seriesId,
    String? chapterTitle,
    bool isPermanent = true,
    int? rentalViews,
  }) async {
    final actualPriceVnd = priceCoins != null && priceVnd == 3000
        ? priceCoins * 100
        : priceVnd;

    final assignedViews = isPermanent ? null : (rentalViews ?? 3);

    // 1. Kiểm tra đặc quyền VIP
    final isVip = PreferencesService.getLocalIsVip();
    if (isVip) {
      await PreferencesService.saveChapterEntitlement(
        ChapterEntitlement(
          chapterId: chapterId,
          isPermanent: true,
          unlockedAt: DateTime.now(),
        ),
      );
      final currentVnd = PreferencesService.getLocalBalanceVnd();
      return UnlockChapterResponse(
        chapterId: chapterId,
        success: true,
        remainingCoins: currentVnd ~/ 100,
        remainingBalanceVnd: currentVnd,
        isPermanent: true,
        message: 'Đặc quyền VIP: Mở khóa chương truyện miễn phí!',
      );
    }

    final currentVnd = PreferencesService.getLocalBalanceVnd();
    if (currentVnd < actualPriceVnd) {
      final missing = actualPriceVnd - currentVnd;
      throw ApiException(
        'Số dư trong Ví không đủ để mở khóa chương (thiếu ${formatVnd(missing)}). Vui lòng nạp thêm.',
      );
    }

    final String txTitle = isPermanent
        ? (chapterTitle != null ? 'Mua vĩnh viễn $chapterTitle' : 'Mua vĩnh viễn chương truyện')
        : (chapterTitle != null ? 'Thuê đọc $chapterTitle ($assignedViews lượt)' : 'Thuê đọc chương truyện ($assignedViews lượt)');

    try {
      final response = await _dio.post(
        '/api/wallet/unlock-chapter',
        data: UnlockChapterRequest(
          chapterId: chapterId,
          priceVnd: actualPriceVnd,
          seriesId: seriesId,
          isPermanent: isPermanent,
          rentalViews: assignedViews,
        ).toJson(),
      );
      if (response.statusCode == 200 && response.data != null) {
        final resp = UnlockChapterResponse.fromJson(response.data as Map<String, dynamic>);
        await PreferencesService.saveChapterEntitlement(
          ChapterEntitlement(
            chapterId: chapterId,
            isPermanent: isPermanent,
            remainingViews: assignedViews,
            unlockedAt: DateTime.now(),
          ),
        );
        await PreferencesService.setLocalBalanceVnd(resp.remainingBalanceVnd);
        await PreferencesService.addWalletTransaction(
          WalletTransactionDto(
            id: 'tx-unlock-${DateTime.now().millisecondsSinceEpoch}',
            title: txTitle,
            amountVnd: -actualPriceVnd,
            createdAt: DateTime.now(),
            balanceAfter: resp.remainingBalanceVnd,
          ),
        );
        return resp;
      }
    } catch (e) {
      debugPrint('[MonetizationService] API /api/wallet/unlock-chapter fallback: $e');
    }

    // Fallback xử lý giao dịch cục bộ
    final newBalance = currentVnd - actualPriceVnd;
    await PreferencesService.setLocalBalanceVnd(newBalance);
    await PreferencesService.saveChapterEntitlement(
      ChapterEntitlement(
        chapterId: chapterId,
        isPermanent: isPermanent,
        remainingViews: assignedViews,
        unlockedAt: DateTime.now(),
      ),
    );
    await PreferencesService.addWalletTransaction(
      WalletTransactionDto(
        id: 'tx-unlock-${DateTime.now().millisecondsSinceEpoch}',
        title: txTitle,
        amountVnd: -actualPriceVnd,
        createdAt: DateTime.now(),
        balanceAfter: newBalance,
      ),
    );

    final String successMessage = isPermanent
        ? 'Đã trừ ${formatVnd(actualPriceVnd)} trong Ví. Mở khóa vĩnh viễn thành công!'
        : 'Đã trừ ${formatVnd(actualPriceVnd)} trong Ví. Bạn có $assignedViews lượt đọc cho chương này!';

    return UnlockChapterResponse(
      chapterId: chapterId,
      success: true,
      remainingCoins: newBalance ~/ 100,
      remainingBalanceVnd: newBalance,
      isPermanent: isPermanent,
      remainingViews: assignedViews,
      message: successMessage,
    );
  }

  /// Ghi nhận và tiêu hao 1 lượt xem khi người dùng đọc một tập có giới hạn số lần xem
  /// Nếu mở lại trong vòng 10 phút thì không trừ lượt xem để tránh lỗi mạng/tải lại
  Future<ConsumeViewResult> consumeChapterView(String chapterId) async {
    if (PreferencesService.getLocalIsVip()) {
      return const ConsumeViewResult(
        didConsume: false,
        isPermanent: true,
      );
    }

    final ent = PreferencesService.getChapterEntitlement(chapterId);
    if (ent == null) {
      // Nếu không có trong entitlement nhưng có trong danh sách unlocked cũ
      if (PreferencesService.isChapterUnlocked(chapterId)) {
        return const ConsumeViewResult(
          didConsume: false,
          isPermanent: true,
        );
      }
      return const ConsumeViewResult(
        didConsume: false,
        isPermanent: false,
        remainingViews: 0,
        message: 'Bạn chưa mở khóa chương truyện này.',
      );
    }

    if (ent.isPermanent) {
      return const ConsumeViewResult(
        didConsume: false,
        isPermanent: true,
      );
    }

    final now = DateTime.now();
    // Nếu mở lại cùng một tập trong vòng 10 phút, không trừ thêm lượt xem
    if (ent.lastOpenedAt != null && now.difference(ent.lastOpenedAt!).inMinutes < 10) {
      return ConsumeViewResult(
        didConsume: false,
        isPermanent: false,
        remainingViews: ent.remainingViews,
        message: 'Bạn còn ${ent.remainingViews}/3 lượt xem cho tập này.',
      );
    }

    // Trừ 1 lượt xem
    final currentRemaining = ent.remainingViews ?? 3;
    final newRemaining = (currentRemaining - 1).clamp(0, 999);
    final updatedEnt = ent.copyWith(
      remainingViews: newRemaining,
      lastOpenedAt: now,
    );
    await PreferencesService.saveChapterEntitlement(updatedEnt);

    if (newRemaining == 0) {
      return const ConsumeViewResult(
        didConsume: true,
        isPermanent: false,
        remainingViews: 0,
        message: 'Bạn đã dùng hết 3/3 lượt xem của tập này. Vui lòng mua thêm để tiếp tục đọc.',
      );
    }

    return ConsumeViewResult(
      didConsume: true,
      isPermanent: false,
      remainingViews: newRemaining,
      message: 'Bạn còn $newRemaining/3 lượt xem cho tập này.',
    );
  }

  /// Đăng ký gói VIP Pass (Monthly / Yearly)
  Future<SubscribeVipResponse> subscribeVip({required String plan}) async {
    final costCoins = plan.toLowerCase() == 'yearly' ? 1999 : 199;
    final costVnd = costCoins * 100;

    try {
      final response = await _dio.post(
        '/api/wallet/subscribe-vip',
        data: SubscribeVipRequest(plan: plan).toJson(),
      );
      if (response.statusCode == 200 && response.data != null) {
        final resp = SubscribeVipResponse.fromJson(response.data as Map<String, dynamic>);
        await PreferencesService.setLocalVip(
          isVip: resp.isVip,
          expiresAt: resp.vipExpiresAt,
        );
        await PreferencesService.setLocalBalanceCoins(resp.remainingCoins);
        return resp;
      }
    } catch (e) {
      debugPrint('[MonetizationService] API /api/wallet/subscribe-vip fallback: $e');
    }

    // Fallback đăng ký VIP cục bộ
    final currentVnd = PreferencesService.getLocalBalanceVnd();
    if (currentVnd < costVnd) {
      throw ApiException(
        'Số dư Ví không đủ để kích hoạt gói VIP (${formatVnd(currentVnd)}/${formatVnd(costVnd)}). Vui lòng nạp thêm.',
      );
    }

    final newBalance = currentVnd - costVnd;
    final expiresAt = plan.toLowerCase() == 'yearly'
        ? DateTime.now().add(const Duration(days: 365))
        : DateTime.now().add(const Duration(days: 30));

    await PreferencesService.setLocalBalanceVnd(newBalance);
    await PreferencesService.setLocalVip(isVip: true, expiresAt: expiresAt);
    await PreferencesService.addWalletTransaction(
      WalletTransactionDto(
        id: 'tx-vip-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Đăng ký VIP Pass (${plan == 'yearly' ? 'Năm' : 'Tháng'})',
        amountVnd: -costVnd,
        createdAt: DateTime.now(),
        balanceAfter: newBalance,
      ),
    );

    return SubscribeVipResponse(
      success: true,
      isVip: true,
      vipExpiresAt: expiresAt,
      remainingCoins: newBalance ~/ 100,
      message: 'Nâng cấp VIP Pass thành công! Bạn có thể tải CBZ và đọc toàn bộ kho truyện.',
    );
  }

  /// Tạo yêu cầu nạp tiền vào Ví VNĐ (trả về thông tin chuyển khoản VietQR từ máy chủ hoặc tạo tức thời)
  Future<TopupResponse> requestTopup({
    required int amountVnd,
    int? coinsAmount,
    String paymentMethod = 'vietqr',
  }) async {
    final coins = coinsAmount ?? (amountVnd ~/ 100);
    final orderId = 'PF${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final transferContent = 'PFWALLET $orderId';
    final qrUrl =
        'https://img.vietqr.io/image/vietcombank-9876543210-compact2.png?amount=$amountVnd&addInfo=${Uri.encodeComponent(transferContent)}&accountName=${Uri.encodeComponent("PANELFORGE COMICS")}';

    try {
      final response = await _dio.post(
        '/api/wallet/topup',
        data: TopupRequest(
          coinsAmount: coins,
          amountVnd: amountVnd,
          paymentMethod: paymentMethod,
        ).toJson(),
      );
      if (response.statusCode == 200 && response.data != null) {
        return TopupResponse.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[MonetizationService] API /api/wallet/topup fallback: $e');
    }

    return TopupResponse(
      orderId: orderId,
      coins: coins,
      amountVnd: amountVnd,
      qrCodeUrl: qrUrl,
      bankName: 'Vietcombank',
      accountNumber: '9876543210',
      accountName: 'PANELFORGE COMICS',
      transferContent: transferContent,
      isCompleted: false,
    );
  }

  /// Xác nhận hoàn tất thanh toán nạp tiền và cộng tiền vào ví VNĐ
  Future<UserWalletDto> completeTopup({
    required String orderId,
    int amountVnd = 0,
    int? coinsAmount,
  }) async {
    final actualVnd =
        amountVnd > 0 ? amountVnd : ((coinsAmount ?? 0) * 100);
    final currentVnd = PreferencesService.getLocalBalanceVnd();
    final newBalance = currentVnd + actualVnd;
    await PreferencesService.setLocalBalanceVnd(newBalance);

    await PreferencesService.addWalletTransaction(
      WalletTransactionDto(
        id: 'tx-topup-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Nạp tiền Ví qua VietQR',
        amountVnd: actualVnd,
        createdAt: DateTime.now(),
        balanceAfter: newBalance,
      ),
    );

    final isVip = PreferencesService.getLocalIsVip();
    final vipExpiresAt = PreferencesService.getLocalVipExpiresAt();

    return UserWalletDto(
      balanceVnd: newBalance,
      isVip: isVip,
      vipExpiresAt: vipExpiresAt,
      transactions: PreferencesService.getWalletTransactions(),
    );
  }

  /// Kiểm tra xem một chapter đã được mở khóa hoặc người dùng có quyền VIP hay không
  bool isChapterUnlocked(String chapterId) {
    if (PreferencesService.getLocalIsVip()) return true;
    return PreferencesService.isChapterUnlocked(chapterId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIVERPOD NOTIFIERS & PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final monetizationServiceProvider = Provider<MonetizationService>((ref) {
  return MonetizationService();
});

/// Notifier quản lý trạng thái Ví & VIP toàn ứng dụng
class WalletNotifier extends Notifier<AsyncValue<UserWalletDto>> {
  @override
  AsyncValue<UserWalletDto> build() {
    // Ban đầu tải ví từ server; khi chưa kết nối thành công thì giữ trạng thái Loading/Error
    _loadInitialWallet();
    return const AsyncLoading();
  }

  Future<void> _loadInitialWallet() async {
    final service = ref.read(monetizationServiceProvider);
    try {
      final wallet = await service.getMyWallet();
      state = AsyncData(wallet);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Làm mới thông tin ví từ máy chủ
  Future<void> refresh() async {
    state = const AsyncLoading();
    final service = ref.read(monetizationServiceProvider);
    try {
      final wallet = await service.getMyWallet();
      state = AsyncData(wallet);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Mở khóa chương truyện
  Future<UnlockChapterResponse> unlockChapter(
    String chapterId,
    int priceVnd, {
    int? priceCoins,
    String? seriesId,
    String? chapterTitle,
    bool isPermanent = true,
    int? rentalViews,
  }) async {
    final service = ref.read(monetizationServiceProvider);
    final response = await service.unlockChapter(
      chapterId: chapterId,
      priceVnd: priceVnd,
      priceCoins: priceCoins,
      seriesId: seriesId,
      chapterTitle: chapterTitle,
      isPermanent: isPermanent,
      rentalViews: rentalViews,
    );

    // Cập nhật state ví
    final currentWallet = state.asData?.value;
    state = AsyncData(
      UserWalletDto(
        balanceVnd: response.remainingBalanceVnd,
        isVip: currentWallet?.isVip ?? false,
        vipExpiresAt: currentWallet?.vipExpiresAt,
        transactions: PreferencesService.getWalletTransactions(),
      ),
    );

    // Cập nhật provider danh sách chương đã mở khóa & quyền sở hữu
    ref.read(unlockedChaptersProvider.notifier).add(chapterId);
    ref.read(chapterEntitlementsProvider.notifier).refresh();

    return response;
  }

  /// Tiêu hao 1 lượt xem khi người dùng đọc tập có giới hạn số lần xem
  Future<ConsumeViewResult> consumeChapterView(String chapterId) async {
    final service = ref.read(monetizationServiceProvider);
    final result = await service.consumeChapterView(chapterId);

    ref.read(chapterEntitlementsProvider.notifier).refresh();
    if (result.remainingViews == 0) {
      ref.read(unlockedChaptersProvider.notifier).remove(chapterId);
    }

    return result;
  }

  /// Đăng ký gói VIP
  Future<SubscribeVipResponse> subscribeVip(String plan) async {
    final service = ref.read(monetizationServiceProvider);
    final response = await service.subscribeVip(plan: plan);

    state = AsyncData(
      UserWalletDto(
        balanceVnd: response.remainingCoins * 100,
        isVip: response.isVip,
        vipExpiresAt: response.vipExpiresAt,
        transactions: PreferencesService.getWalletTransactions(),
      ),
    );

    return response;
  }

  /// Nạp tiền vào ví thành công
  Future<void> completeTopup({
    required String orderId,
    int amountVnd = 0,
    int? coinsAmount,
  }) async {
    final service = ref.read(monetizationServiceProvider);
    final updatedWallet = await service.completeTopup(
      orderId: orderId,
      amountVnd: amountVnd,
      coinsAmount: coinsAmount,
    );
    state = AsyncData(updatedWallet);
  }
}

final walletNotifierProvider =
    NotifierProvider<WalletNotifier, AsyncValue<UserWalletDto>>(WalletNotifier.new);

/// Notifier quản lý danh sách các chapterId đã mở khóa
class UnlockedChaptersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return PreferencesService.getUnlockedChapterIds();
  }

  void refresh() {
    state = PreferencesService.getUnlockedChapterIds();
  }

  void add(String chapterId) {
    PreferencesService.addUnlockedChapterId(chapterId);
    state = {...state, chapterId};
  }

  void remove(String chapterId) {
    PreferencesService.removeUnlockedChapterId(chapterId);
    state = state.where((id) => id != chapterId).toSet();
  }

  bool isUnlocked(String chapterId) {
    final isVip = PreferencesService.getLocalIsVip();
    if (isVip) return true;
    return state.contains(chapterId);
  }
}

final unlockedChaptersProvider =
    NotifierProvider<UnlockedChaptersNotifier, Set<String>>(
  UnlockedChaptersNotifier.new,
);

/// Notifier quản lý danh sách quyền sở hữu và số lượt xem của từng chapter
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

final chapterEntitlementsProvider =
    NotifierProvider<ChapterEntitlementsNotifier, Map<String, ChapterEntitlement>>(
  ChapterEntitlementsNotifier.new,
);
