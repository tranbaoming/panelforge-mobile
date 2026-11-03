import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_dtos.dart';
import '../models/auth_models.dart';
import '../models/comic_package_models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../services/cbz_package_service.dart';
import '../services/preferences_service.dart';
import '../services/preview_service.dart';

export '../models/auth_models.dart';
export '../services/auth_service.dart';

export '../services/cbz_package_service.dart'
    show
        DownloadStatus,
        CbzPackageService,
        cbzPackageServiceProvider,
        downloadProgressProvider,
        downloadStatusProvider,
        chapterDownloadProgressProvider,
        chapterDownloadStatusProvider,
        downloadedChaptersProvider;

export '../services/monetization_service.dart'
    show
        MonetizationService,
        monetizationServiceProvider,
        walletNotifierProvider,
        unlockedChaptersProvider;

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final catalogServiceProvider = Provider<CatalogService>((ref) {
  return CatalogService(client: ref.watch(apiClientProvider));
});

final previewServiceProvider = Provider<PreviewService>((ref) {
  return PreviewService(client: ref.watch(apiClientProvider));
});

class ServerConnectedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
  void setConnected(bool value) => state = value;
}

/// Provider kiểm tra trạng thái kết nối máy chủ thực tế (true khi kết nối thành công)
final isServerConnectedProvider =
    NotifierProvider<ServerConnectedNotifier, bool>(ServerConnectedNotifier.new);

/// Provider tải danh sách Series phát hành từ backend
final publicCatalogProvider = FutureProvider.family<PagedCatalogResult, ({String? search, String? genre})>((ref, filter) async {
  final catalogService = ref.watch(catalogServiceProvider);
  return await catalogService.getSeries(
    search: filter.search,
    genre: filter.genre,
  );
});

/// Provider tải chi tiết Series và danh sách chương
final publicSeriesDetailProvider = FutureProvider.family<PublicSeriesDetailDto, String>((ref, seriesId) async {
  final catalogService = ref.watch(catalogServiceProvider);
  return await catalogService.getSeriesDetail(seriesId);
});

/// Provider tải nội dung chương truyện để đọc
final publicChapterReadProvider = FutureProvider.family<PublicChapterReadDto, String>((ref, chapterId) async {
  final catalogService = ref.watch(catalogServiceProvider);
  return await catalogService.readChapter(chapterId);
});

/// Provider nạp gói Comic Package (CBZ / Online / Fallback) cho Reader
final loadedComicPackageProvider = FutureProvider.family<LoadedComicPackage, ({String chapterId, String? manifestUrl, String? cbzUrl})>((ref, args) async {
  final cbzService = ref.watch(cbzPackageServiceProvider);
  return await cbzService.loadPackage(
    chapterId: args.chapterId,
    manifestUrl: args.manifestUrl,
    cbzUrl: args.cbzUrl,
  );
});

// ─── Authentication & Session Providers ─────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AuthService(client: client);
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    AuthService.onAuthStateChanged = (newState) {
      state = newState;
    };
    ref.onDispose(() {
      AuthService.onAuthStateChanged = null;
    });

    final cachedUser = PreferencesService.getAuthUser();
    if (cachedUser != null) {
      try {
        final user = AuthUser.fromJson(cachedUser);
        final isRestricted = PreferencesService.getIsRestrictedReader();
        final notice = PreferencesService.getRestrictionNotice();
        return AuthState(
          role: isRestricted ? MobileAuthRole.restrictedReader : MobileAuthRole.reader,
          user: user,
          restrictionNotice: notice,
        );
      } catch (_) {}
    }
    // Mặc định ban đầu khi chưa có phiên Reader hợp lệ: unauthenticated (hiển thị LoginPage)
    return AuthState.unauthenticated();
  }

  void continueAsGuest() {
    state = AuthState.guest();
  }

  void setUnauthenticated() {
    state = AuthState.unauthenticated();
  }

  void updateState(AuthState newState) {
    state = newState;
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);


