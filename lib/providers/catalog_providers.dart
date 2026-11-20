import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comic_model.dart';
import '../services/catalog_service.dart';
import '../services/preferences_service.dart';
import 'api_providers.dart';

/// Toàn bộ catalog công khai (mọi trang, tối đa 1000 bộ) — dùng chung cho Trang chủ, Dành cho bạn, Tìm kiếm.
/// Backend chỉ tìm theo tên, nên app tải hết một lần rồi chia khối / lọc tại máy.
final catalogSeriesProvider = FutureProvider<List<SeriesItem>>((ref) async {
  final service = ref.watch(catalogServiceProvider);
  final items = await loadWholeCatalog(service);
  final fromCache = service.lastSeriesFromCache;
  ref.read(isServerConnectedProvider.notifier).setConnected(!fromCache);
  ref.read(catalogFromCacheProvider.notifier).set(fromCache);
  return items;
});

/// true khi catalog đang hiển thị là bản đã lưu (không kết nối được máy chủ).
final catalogFromCacheProvider = NotifierProvider<CatalogFromCacheNotifier, bool>(CatalogFromCacheNotifier.new);

class CatalogFromCacheNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

Future<List<SeriesItem>> loadWholeCatalog(CatalogService service, {int maxPages = 20}) async {
  final all = <SeriesItem>[];
  for (var page = 1; page <= maxPages; page++) {
    final res = await service.getSeries(pageIndex: page, pageSize: 50);
    all.addAll(res.items.map(SeriesItem.fromPublicDto));
    if (page >= res.totalPages || res.items.isEmpty || service.lastSeriesFromCache) break;
  }
  return all;
}

/// Một thể loại cùng các bộ truyện của nó (ảnh đại diện = bìa bộ được đọc nhiều nhất).
typedef GenreGroup = ({String genre, List<SeriesItem> series});

/// Chia catalog thành các khối hiển thị. Mọi tiêu chí đều dựa trên số liệu thật Backend trả về
/// (lượt đọc, ngày tạo, ngày phát hành chương mới nhất) — không có số liệu giả.
class CatalogSections {
  final List<SeriesItem> all;
  final DateTime now;

  CatalogSections(this.all, {DateTime? now}) : now = now ?? DateTime.now();

  static const newWindow = Duration(days: 30);
  static const updatedWindow = Duration(days: 7);

  /// NEW: bộ truyện được tạo trong 30 ngày qua.
  bool isNew(SeriesItem s) => s.createdAt != null && now.difference(s.createdAt!) <= newWindow;

  /// UP: có chương mới phát hành trong 7 ngày qua (và không phải bộ mới).
  bool isUpdated(SeriesItem s) =>
      !isNew(s) && s.latestPublishedAt != null && now.difference(s.latestPublishedAt!) <= updatedWindow;

  List<SeriesItem> get byViews => [...all]..sort((a, b) => b.views.compareTo(a.views));

  List<SeriesItem> get recentlyUpdated =>
      [...all]
        ..sort((a, b) => (b.latestPublishedAt ?? DateTime(1970)).compareTo(a.latestPublishedAt ?? DateTime(1970)));

  List<SeriesItem> get newest =>
      [...all]..sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));

  List<SeriesItem> get alphabetical => [...all]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  /// Xếp theo lượt đọc trong kỳ; bỏ bộ chưa có lượt đọc nào trong kỳ.
  List<SeriesItem> topBy(int Function(SeriesItem) views) =>
      all.where((s) => views(s) > 0).toList()..sort((a, b) => views(b).compareTo(views(a)));

  /// Phổ biến hôm nay (lượt đọc 24h). Rỗng khi chưa ai đọc trong 24h.
  List<SeriesItem> get popularToday => topBy((s) => s.viewsLast1Day);

  /// Bộ nổi bật cho banner đầu Trang chủ: đọc nhiều nhất 7 ngày, nếu chưa có thì nhiều lượt đọc nhất.
  SeriesItem? get featured {
    final week = topBy((s) => s.viewsLast7Days);
    if (week.isNotEmpty) return week.first;
    return all.isEmpty ? null : byViews.first;
  }

  /// Khối "Đề xuất": bộ đọc nhiều nhất 30 ngày khác với banner (nếu có).
  SeriesItem? get spotlight {
    final hero = featured;
    final month = topBy((s) => s.viewsLast30Days).where((s) => s.id != hero?.id);
    if (month.isNotEmpty) return month.first;
    final rest = byViews.where((s) => s.id != hero?.id);
    return rest.isEmpty ? null : rest.first;
  }

  /// Bộ mới nhất trong 30 ngày qua — dùng cho popup giới thiệu truyện mới.
  SeriesItem? get newSeriesPromo {
    final fresh = newest.where(isNew);
    return fresh.isEmpty ? null : fresh.first;
  }

  /// Thể loại (theo trường `genre` của bộ truyện), nhiều truyện nhất trước.
  List<GenreGroup> get genres {
    final map = <String, List<SeriesItem>>{};
    for (final s in byViews) {
      final g = s.genres.isEmpty ? '' : s.genres.first.trim();
      if (g.isEmpty) continue;
      map.putIfAbsent(g, () => []).add(s);
    }
    final groups = [for (final e in map.entries) (genre: e.key, series: e.value)];
    groups.sort((a, b) => b.series.length.compareTo(a.series.length));
    return groups;
  }

  /// Đề xuất cho bạn: cùng thể loại với các bộ trong lịch sử đọc mà chưa đọc.
  /// Chưa có lịch sử → các bộ đọc nhiều nhất 30 ngày (rồi tổng lượt đọc).
  List<SeriesItem> recommendedFor(List<ReadingHistoryEntry> history) {
    final readIds = history.map((h) => h.seriesId).toSet();
    final likedGenres = all.where((s) => readIds.contains(s.id)).expand((s) => s.genres.take(1)).toSet();
    if (likedGenres.isNotEmpty) {
      final picks = byViews.where((s) => !readIds.contains(s.id) && s.genres.any(likedGenres.contains)).toList();
      if (picks.isNotEmpty) return picks;
    }
    final month = topBy((s) => s.viewsLast30Days);
    return month.isNotEmpty ? month : byViews;
  }

  /// Bộ cùng thể loại với [series] (trừ chính nó).
  List<SeriesItem> sameGenre(SeriesItem series) {
    final g = series.genres.isEmpty ? null : series.genres.first;
    if (g == null) return const [];
    return byViews.where((s) => s.id != series.id && s.genres.isNotEmpty && s.genres.first == g).toList();
  }
}
