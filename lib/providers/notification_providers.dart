import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic_model.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import 'api_providers.dart';
import 'catalog_providers.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(apiClientProvider)),
);

/// Thông báo của người dùng đang đăng nhập. Khách → [NotificationPage.empty], không gọi API.
/// Tự tải lại khi đăng nhập / đăng xuất.
final notificationsProvider = AsyncNotifierProvider<NotificationsNotifier, NotificationPage>(NotificationsNotifier.new);

/// Số thông báo chưa đọc cho chấm đỏ trên chuông (0 khi chưa tải được).
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).asData?.value.unreadCount ?? 0,
);

class NotificationsNotifier extends AsyncNotifier<NotificationPage> {
  NotificationService get _service => ref.read(notificationServiceProvider);

  @override
  Future<NotificationPage> build() async {
    final signedIn = ref.watch(authStateProvider.select((a) => a.isAuthenticated));
    if (!signedIn) return NotificationPage.empty;
    return _service.getMine();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Đánh dấu một thông báo đã đọc: cập nhật ngay trên màn hình, rồi báo server.
  Future<void> markRead(String id) async {
    final page = state.asData?.value;
    if (page == null) return;
    final target = page.items.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return;
    final now = DateTime.now();
    state = AsyncData(
      NotificationPage(
        items: [for (final n in page.items) n.id == id ? n.markedRead(now) : n],
        totalCount: page.totalCount,
        unreadCount: (page.unreadCount - 1).clamp(0, page.totalCount),
      ),
    );
    try {
      await _service.markRead(id);
    } catch (_) {
      state = AsyncData(page);
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final page = state.asData?.value;
    if (page == null || page.unreadCount == 0) return;
    final now = DateTime.now();
    state = AsyncData(
      NotificationPage(
        items: [for (final n in page.items) n.markedRead(now)],
        totalCount: page.totalCount,
        unreadCount: 0,
      ),
    );
    try {
      await _service.markAllRead();
    } catch (_) {
      state = AsyncData(page);
      rethrow;
    }
  }
}

/// Bộ truyện đang theo dõi có chương phát hành sau lần cuối độc giả xem (tính tại máy từ catalog thật).
/// Backend chưa gửi thông báo cho độc giả nên app tự so `latestPublishedAt` với mốc đã xem.
final followUpdatesProvider = NotifierProvider<FollowUpdatesNotifier, List<SeriesItem>>(FollowUpdatesNotifier.new);

class FollowUpdatesNotifier extends Notifier<List<SeriesItem>> {
  @override
  List<SeriesItem> build() {
    final catalog = ref.watch(catalogSeriesProvider).asData?.value ?? const <SeriesItem>[];
    return _compute(catalog);
  }

  List<SeriesItem> _compute(List<SeriesItem> catalog) {
    final follows = PreferencesService.getFollows();
    if (follows.isEmpty) return const [];
    final seen = PreferencesService.getFollowSeenAt();
    final now = DateTime.now();
    final updates = <SeriesItem>[];
    for (final s in catalog) {
      if (!follows.contains(s.id)) continue;
      final seenAt = seen[s.id];
      if (seenAt == null) {
        // Theo dõi từ trước khi có tính năng này: lấy mốc hiện tại, không báo dồn chương cũ.
        PreferencesService.setFollowSeenAt(s.id, now);
        continue;
      }
      final latest = s.latestPublishedAt;
      if (latest != null && latest.isAfter(seenAt)) updates.add(s);
    }
    updates.sort((a, b) => b.latestPublishedAt!.compareTo(a.latestPublishedAt!));
    return updates;
  }

  /// Độc giả đã xem bộ truyện (mở trang chi tiết / chạm thông báo) → bỏ khỏi danh sách.
  Future<void> markSeen(String seriesId) async {
    await PreferencesService.setFollowSeenAt(seriesId, DateTime.now());
    state = state.where((s) => s.id != seriesId).toList();
  }

  /// Gọi lại sau khi bật / tắt theo dõi.
  void recompute() => state = _compute(ref.read(catalogSeriesProvider).asData?.value ?? const []);
}

/// Tổng số trên chuông: thông báo server chưa đọc + bộ theo dõi có chương mới.
final bellBadgeCountProvider = Provider<int>(
  (ref) => ref.watch(unreadNotificationCountProvider) + ref.watch(followUpdatesProvider).length,
);
