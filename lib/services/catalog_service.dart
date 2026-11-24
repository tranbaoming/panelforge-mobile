import '../models/api_dtos.dart';
import 'api_client.dart';
import 'preferences_service.dart';

class CatalogService {
  final ApiClient _client;

  CatalogService({ApiClient? client}) : _client = client ?? ApiClient();

  /// true khi lần gọi [getSeries] gần nhất trả dữ liệu đã lưu vì không kết nối được máy chủ.
  bool lastSeriesFromCache = false;

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

    // Chỉ danh sách đầy đủ (không tìm / lọc) được lưu để mở app khi không có mạng.
    final cacheable = queryParams.length == 2;
    lastSeriesFromCache = false;
    try {
      final response = await _client.get('/api/catalog/series', queryParameters: queryParams);
      final json = response.data as Map<String, dynamic>;
      if (cacheable) await PreferencesService.cacheCatalogPage(pageIndex, pageSize, json);
      return PagedCatalogResult.fromJson(json);
    } on ApiException catch (e) {
      final offline = e.statusCode == null || e.statusCode! >= 500;
      final cached = cacheable && offline ? PreferencesService.getCachedCatalogPage(pageIndex, pageSize) : null;
      if (cached == null) rethrow;
      lastSeriesFromCache = true;
      return PagedCatalogResult.fromJson(cached);
    }
  }

  /// Lấy chi tiết Series và danh sách các chương đã Published
  /// GET /api/catalog/series/{seriesId}
  Future<PublicSeriesDetailDto> getSeriesDetail(String seriesId, {String? lang}) async {
    final cleanLang = lang?.trim();
    final response = await _client.get(
      '/api/catalog/series/$seriesId',
      queryParameters: (cleanLang != null && cleanLang.isNotEmpty) ? {'lang': cleanLang} : null,
    );
    return PublicSeriesDetailDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ghi một lượt đọc thật sau khi Reader mở xong chương (Backend gộp lượt đọc lại trong 30 phút).
  /// POST /api/catalog/chapters/{chapterId}/views
  Future<void> recordChapterView(String chapterId, {String? lang}) async {
    final cleanLang = lang?.trim();
    await _client.post(
      (cleanLang != null && cleanLang.isNotEmpty)
          ? '/api/catalog/chapters/$chapterId/views?lang=$cleanLang'
          : '/api/catalog/chapters/$chapterId/views',
    );
  }

  /// Lấy nội dung chương đọc cho Reader: hướng đọc và danh sách URL ảnh các trang
  /// GET /api/catalog/chapters/{chapterId}
  /// [lang]: bản ngôn ngữ (vi/en). 404 (`EDITION_NOT_PUBLISHED`) nếu bản đó chưa phát hành (D9b, không fallback).
  Future<PublicChapterReadDto> readChapter(String chapterId, {String? lang}) async {
    final cleanLang = lang?.trim();
    final response = await _client.get(
      '/api/catalog/chapters/$chapterId',
      queryParameters: (cleanLang != null && cleanLang.isNotEmpty) ? {'lang': cleanLang} : null,
    );
    return PublicChapterReadDto.fromJson(response.data as Map<String, dynamic>);
  }

  /// Lưu ngôn ngữ đọc ưa thích lên tài khoản (BR-34 / RDR-11).
  /// PUT /api/users/me/reading-language
  Future<void> updatePreferredReadingLanguage(String languageCode) async {
    await _client.put(
      '/api/users/me/reading-language',
      data: {'languageCode': languageCode.trim().toLowerCase()},
    );
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

