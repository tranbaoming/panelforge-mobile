import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_dtos.dart';
import '../services/api_client.dart';
import '../services/catalog_service.dart';
import '../services/preview_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final catalogServiceProvider = Provider<CatalogService>((ref) {
  return CatalogService(client: ref.watch(apiClientProvider));
});

final previewServiceProvider = Provider<PreviewService>((ref) {
  return PreviewService(client: ref.watch(apiClientProvider));
});

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

