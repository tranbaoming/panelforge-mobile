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
  Future<PublicSeriesDetailDto> getSeriesDetail(String seriesId) async {
    final response = await _client.get('/api/catalog/series/$seriesId');
    return PublicSeriesDetailDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Lấy nội dung chương đọc cho Reader: hướng đọc và danh sách URL ảnh các trang
  /// GET /api/catalog/chapters/{chapterId}
  Future<PublicChapterReadDto> readChapter(String chapterId) async {
    final response = await _client.get('/api/catalog/chapters/$chapterId');
    return PublicChapterReadDto.fromJson(response.data as Map<String, dynamic>);
  }
}

