import '../models/api_dtos.dart';
import 'api_client.dart';

class PreviewService {
  final ApiClient _client;

  PreviewService({ApiClient? client}) : _client = client ?? ApiClient();

  /// Mở bản thảo xem thử độc quyền bằng Token (hoặc quét qua QR code)
  /// POST /api/preview/open với body: { token }
  /// Trả về 403 nếu token không hợp lệ, bị thu hồi hoặc đã quá hạn
  Future<PreviewChapterDto> openPreview(String token) async {
    final response = await _client.post(
      '/api/preview/open',
      data: {'token': token.trim()},
    );

    return PreviewChapterDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Gửi phản hồi / góp ý cho trang hoặc khung tranh cụ thể
  /// POST /api/preview/feedback với body: { token, message, pageId, panelId }
  Future<PreviewFeedbackDto> submitFeedback({
    required String token,
    required String message,
    String? pageId,
    String? panelId,
  }) async {
    final data = <String, dynamic>{
      'token': token.trim(),
      'message': message.trim(),
    };
    if (pageId != null && pageId.isNotEmpty) {
      data['pageId'] = pageId;
    }
    if (panelId != null && panelId.isNotEmpty) {
      data['panelId'] = panelId;
    }

    final response = await _client.post(
      '/api/preview/feedback',
      data: data,
    );

    return PreviewFeedbackDto.fromJson(response.data as Map<String, dynamic>);
  }
}

