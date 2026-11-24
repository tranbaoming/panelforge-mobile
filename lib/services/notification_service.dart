import '../models/notification_model.dart';
import 'api_client.dart';

/// Thông báo của chính người dùng — `NotificationsController` (`/api/notifications`, cần đăng nhập).
class NotificationService {
  final ApiClient _client;

  NotificationService(this._client);

  /// `GET /api/notifications?pageIndex=&pageSize=` (server giới hạn pageSize ≤ 50).
  Future<NotificationPage> getMine({int pageIndex = 1, int pageSize = 30}) async {
    final response = await _client.get(
      '/api/notifications',
      queryParameters: {'pageIndex': pageIndex, 'pageSize': pageSize},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ApiException('Máy chủ phản hồi không hợp lệ.', statusCode: response.statusCode);
    }
    return NotificationPage.fromJson(data);
  }

  /// `POST /api/notifications/{id}/read`.
  Future<void> markRead(String id) => _client.post('/api/notifications/$id/read');

  /// `POST /api/notifications/read-all`.
  Future<void> markAllRead() => _client.post('/api/notifications/read-all');
}
