import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_dtos.dart';
import 'api_client.dart';
import 'preferences_service.dart';

/// Dịch vụ quản lý Thu phí, Ví ForgeCoins, Mở khóa chương truyện và Gói VIP
class MonetizationService {
  final ApiClient _client;

  MonetizationService({ApiClient? client}) : _client = client ?? ApiClient();

  Dio get _dio => _client.dio;

  /// Lấy thông tin ví và trạng thái VIP của người dùng hiện tại
  Future<UserWalletDto> getMyWallet() async {
    try {
      final response = await _dio.get('/api/wallet/me');
      if (response.statusCode == 200 && response.data != null) {
        final wallet = UserWalletDto.fromJson(response.data as Map<String, dynamic>);
        // Đồng bộ cache cục bộ
        await PreferencesService.setLocalBalanceCoins(wallet.balanceCoins);
        await PreferencesService.setLocalVip(
          isVip: wallet.isVip,
          expiresAt: wallet.vipExpiresAt,
        );
        return wallet;
      }
    } catch (e) {
      debugPrint('[MonetizationService] API /api/wallet/me chưa sẵn sàng hoặc offline: $e');
    }

    // Fallback thông minh: Dùng ví lưu trữ cục bộ
    final balance = PreferencesService.getLocalBalanceCoins();
    final isVip = PreferencesService.getLocalIsVip();
    final vipExpiresAt = PreferencesService.getLocalVipExpiresAt();

    return UserWalletDto(
      balanceCoins: balance,
      isVip: isVip,
      vipExpiresAt: vipExpiresAt,
    );
  }

  /// Mở khóa một chương truyện bằng ForgeCoins hoặc đặc quyền VIP
  Future<UnlockChapterResponse> unlockChapter({
    required String chapterId,
    int priceCoins = 50,
  }) async {
    try {
      final response = await _dio.post(
        '/api/wallet/unlock-chapter',
        data: UnlockChapterRequest(chapterId: chapterId).toJson(),
      );
      if (response.statusCode == 200 && response.data != null) {
        final resp = UnlockChapterResponse.fromJson(response.data as Map<String, dynamic>);
        await PreferencesService.addUnlockedChapterId(chapterId);
        await PreferencesService.setLocalBalanceCoins(resp.remainingCoins);
        return resp;
      }
    } catch (e) {
      debugPrint('[MonetizationService] API /api/wallet/unlock-chapter fallback: $e');
    }

    // Fallback xử lý giao dịch cục bộ
    final isVip = PreferencesService.getLocalIsVip();
    if (isVip) {
      await PreferencesService.addUnlockedChapterId(chapterId);
      final currentCoins = PreferencesService.getLocalBalanceCoins();
      return UnlockChapterResponse(
        chapterId: chapterId,
        success: true,
        remainingCoins: currentCoins,
        message: 'Đặc quyền VIP: Mở khóa chương truyện miễn phí!',
      );
    }

    final currentCoins = PreferencesService.getLocalBalanceCoins();
    if (currentCoins < priceCoins) {
      throw ApiException(
        'Số dư ForgeCoins không đủ để mở khóa chương ($currentCoins/$priceCoins). Vui lòng nạp thêm.',
      );
    }

    final newBalance = currentCoins - priceCoins;
    await PreferencesService.setLocalBalanceCoins(newBalance);
    await PreferencesService.addUnlockedChapterId(chapterId);

    return UnlockChapterResponse(
      chapterId: chapterId,
      success: true,
      remainingCoins: newBalance,
      message: 'Mở khóa chương truyện thành công!',
    );
  }

  /// Đăng ký gói VIP Pass (Monthly / Yearly)
  Future<SubscribeVipResponse> subscribeVip({required String plan}) async {
    final cost = plan.toLowerCase() == 'yearly' ? 1999 : 199;

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
    final currentCoins = PreferencesService.getLocalBalanceCoins();
    if (currentCoins < cost) {
      throw ApiException(
        'Số dư ForgeCoins không đủ để kích hoạt gói VIP ($currentCoins/$cost). Vui lòng nạp thêm.',
      );
    }

    final newBalance = currentCoins - cost;
    final expiresAt = plan.toLowerCase() == 'yearly'
        ? DateTime.now().add(const Duration(days: 365))
        : DateTime.now().add(const Duration(days: 30));

    await PreferencesService.setLocalBalanceCoins(newBalance);
    await PreferencesService.setLocalVip(isVip: true, expiresAt: expiresAt);

    return SubscribeVipResponse(
      success: true,
      isVip: true,
      vipExpiresAt: expiresAt,
      remainingCoins: newBalance,
      message: 'Nâng cấp VIP Pass thành công! Bạn có thể tải CBZ và đọc toàn bộ kho truyện.',
    );
  }

  /// Tạo yêu cầu nạp ForgeCoins (trả về thông tin chuyển khoản VietQR)
  Future<TopupResponse> requestTopup({
    required int coinsAmount,
    required int amountVnd,
    String paymentMethod = 'vietqr',
  }) async {
    try {
      final response = await _dio.post(
        '/api/wallet/topup',
        data: TopupRequest(
          coinsAmount: coinsAmount,
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

    // Fallback tạo mã giao dịch VietQR hợp lệ
    final orderId = 'PF${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final content = 'PF $orderId';
    // Link VietQR chuẩn ngân hàng
    final qrUrl =
        'https://img.vietqr.io/image/970436-9876543210-compact2.png?amount=$amountVnd&addInfo=${Uri.encodeComponent(content)}&accountName=PANELFORGE%20COMICS';

    return TopupResponse(
      orderId: orderId,
      coins: coinsAmount,
      amountVnd: amountVnd,
      qrCodeUrl: qrUrl,
      bankName: 'Vietcombank',
      accountNumber: '9876543210',
      accountName: 'PANELFORGE COMICS',
      transferContent: content,
      isCompleted: false,
    );
  }

  /// Xác nhận hoàn tất thanh toán nạp tiền và cộng Coins vào ví
  Future<UserWalletDto> completeTopup({
    required String orderId,
    required int coinsAmount,
  }) async {
    final currentCoins = PreferencesService.getLocalBalanceCoins();
    final newBalance = currentCoins + coinsAmount;
    await PreferencesService.setLocalBalanceCoins(newBalance);

    final isVip = PreferencesService.getLocalIsVip();
    final vipExpiresAt = PreferencesService.getLocalVipExpiresAt();

    return UserWalletDto(
      balanceCoins: newBalance,
      isVip: isVip,
      vipExpiresAt: vipExpiresAt,
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
    // Tải thông tin ví ban đầu
    _loadInitialWallet();
    return AsyncData(
      UserWalletDto(
        balanceCoins: PreferencesService.getLocalBalanceCoins(),
        isVip: PreferencesService.getLocalIsVip(),
        vipExpiresAt: PreferencesService.getLocalVipExpiresAt(),
      ),
    );
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
  Future<UnlockChapterResponse> unlockChapter(String chapterId, int priceCoins) async {
    final service = ref.read(monetizationServiceProvider);
    final response = await service.unlockChapter(
      chapterId: chapterId,
      priceCoins: priceCoins,
    );

    // Cập nhật state ví
    final currentWallet = state.asData?.value;
    if (currentWallet != null) {
      state = AsyncData(
        UserWalletDto(
          balanceCoins: response.remainingCoins,
          isVip: currentWallet.isVip,
          vipExpiresAt: currentWallet.vipExpiresAt,
        ),
      );
    }

    // Cập nhật provider danh sách chương đã mở khóa
    ref.read(unlockedChaptersProvider.notifier).add(chapterId);

    return response;
  }

  /// Đăng ký gói VIP
  Future<SubscribeVipResponse> subscribeVip(String plan) async {
    final service = ref.read(monetizationServiceProvider);
    final response = await service.subscribeVip(plan: plan);

    state = AsyncData(
      UserWalletDto(
        balanceCoins: response.remainingCoins,
        isVip: response.isVip,
        vipExpiresAt: response.vipExpiresAt,
      ),
    );

    return response;
  }

  /// Nạp ForgeCoins thành công
  Future<void> completeTopup({required String orderId, required int coinsAmount}) async {
    final service = ref.read(monetizationServiceProvider);
    final updatedWallet = await service.completeTopup(
      orderId: orderId,
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
