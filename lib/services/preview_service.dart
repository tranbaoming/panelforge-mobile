import '../models/api_dtos.dart';
import '../models/comic_package_models.dart';
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

  /// Gửi phản hồi / góp ý cho trang, khung tranh hoặc vùng thoại cụ thể
  /// POST /api/preview/feedback với body: PreviewFeedbackRequest hoặc { token, message, pageId, panelId, textRegionId, bounds }
  Future<PreviewFeedbackDto> submitFeedback(
    dynamic requestOrToken, {
    String? message,
    String? pageId,
    String? panelId,
    String? textRegionId,
    NormalizedBounds? bounds,
  }) async {
    final Map<String, dynamic> data;
    if (requestOrToken is PreviewFeedbackRequest) {
      data = requestOrToken.toJson();
    } else {
      data = <String, dynamic>{
        'token': requestOrToken.toString().trim(),
        'message': (message ?? '').trim(),
      };
      if (pageId != null && pageId.isNotEmpty) {
        data['pageId'] = pageId;
      }
      if (panelId != null && panelId.isNotEmpty) {
        data['panelId'] = panelId;
      }
      if (textRegionId != null && textRegionId.isNotEmpty) {
        data['textRegionId'] = textRegionId;
      }
      if (bounds != null) {
        data['bounds'] = bounds.toJson();
      }
    }

    final response = await _client.post(
      '/api/preview/feedback',
      data: data,
    );

    return PreviewFeedbackDto.fromJson(response.data as Map<String, dynamic>);
  }
}

