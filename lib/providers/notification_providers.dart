import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import 'api_providers.dart';

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
