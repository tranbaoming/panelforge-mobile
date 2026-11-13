import '../models/api_dtos.dart';
import 'api_client.dart';

class CatalogService {
  final ApiClient _client;

  CatalogService({ApiClient? client}) : _client = client ?? ApiClient();

  /// Lấy danh sách Series đã có ít nhất 1 chương Published (BR-23)
  /// GET /api/catalog/series?search=&genre=&pageIndex=1&pageSize=20
  Future<PagedCatalogResult> getSeries({
    String? search,
    String? genre,
    int pageIndex = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'pageIndex': pageIndex,
      'pageSize': pageSize,
    };
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }
    if (genre != null && genre.trim().isNotEmpty) {
      queryParams['genre'] = genre.trim();
    }

    final response = await _client.get(
      '/api/catalog/series',
      queryParameters: queryParams,
    );

    return PagedCatalogResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Lấy chi tiết Series và danh sách các chương đã Published
  /// GET /api/catalog/series/{seriesId}
  Future<PublicSeriesDetailDto> getSeriesDetail(String seriesId, {String? lang}) async {
    final response = await _client.get(
      '/api/catalog/series/$seriesId',
      queryParameters: lang != null && lang != 'vi' ? {'lang': lang} : null,
    );
    return PublicSeriesDetailDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ghi một lượt đọc thật sau khi Reader mở xong chương (Backend gộp lượt đọc lại trong 30 phút).
  /// POST /api/catalog/chapters/{chapterId}/views
  Future<void> recordChapterView(String chapterId, {String? lang}) async {
    await _client.post(lang != null && lang != 'vi'
        ? '/api/catalog/chapters/$chapterId/views?lang=$lang'
        : '/api/catalog/chapters/$chapterId/views');
  }

  /// Lấy nội dung chương đọc cho Reader: hướng đọc và danh sách URL ảnh các trang
  /// GET /api/catalog/chapters/{chapterId}
  /// [lang]: bản ngôn ngữ (vi/en/ja). 404 nếu bản đó chưa phát hành, 403 nếu chưa mua bản đó.
  Future<PublicChapterReadDto> readChapter(String chapterId, {String? lang}) async {
    final response = await _client.get(
      '/api/catalog/chapters/$chapterId',
      queryParameters: lang != null && lang != 'vi' ? {'lang': lang} : null,
    );
    return PublicChapterReadDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Đánh giá 1–5 sao cho bộ truyện (cần đăng nhập). PUT /api/catalog/series/{seriesId}/rating
  /// Trả (điểm trung bình, số lượt đánh giá).
  Future<({double average, int count})> rateSeries(String seriesId, int stars, {String? lang}) async {
    final response = await _client.put(
      '/api/catalog/series/$seriesId/rating',
      data: {'stars': stars, 'language': ?lang},
    );
    final data = response.data as Map<String, dynamic>;
    return (
      average: (data['ratingAverage'] as num?)?.toDouble() ?? 0,
      count: (data['ratingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

