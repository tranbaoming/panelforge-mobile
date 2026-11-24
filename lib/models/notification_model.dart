/// Thông báo trong ứng dụng (UC-14) — khớp `NotificationDto` của `GET /api/notifications`.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? chapterId;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.chapterId,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime at) => AppNotification(
    id: id,
    type: type,
    title: title,
    message: message,
    chapterId: chapterId,
    readAt: readAt ?? at,
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id']?.toString() ?? '',
    // Server dùng JsonStringEnumConverter nên type là chuỗi; vẫn nhận số cho chắc.
    type: json['type']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    chapterId: json['chapterId']?.toString(),
    readAt: DateTime.tryParse(json['readAt']?.toString() ?? '')?.toLocal(),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
  );
}

/// Một trang thông báo kèm tổng số chưa đọc (`NotificationListDto`).
class NotificationPage {
  final List<AppNotification> items;
  final int totalCount;
  final int unreadCount;

  const NotificationPage({required this.items, required this.totalCount, required this.unreadCount});

  static const empty = NotificationPage(items: [], totalCount: 0, unreadCount: 0);

  factory NotificationPage.fromJson(Map<String, dynamic> json) => NotificationPage(
    items: [
      for (final item in (json['items'] as List? ?? const []))
        if (item is Map<String, dynamic>) AppNotification.fromJson(item),
    ],
    totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
    unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
  );
}
