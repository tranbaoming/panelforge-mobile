import 'api_client.dart';
import 'preferences_service.dart';

/// Thư viện cá nhân trên server — `ReaderLibraryController` (`/api/users/me/library`, cần đăng nhập).
class LibrarySyncService {
  final ApiClient _client;

  LibrarySyncService(this._client);

  /// `POST /api/users/me/library/merge` — gửi dữ liệu trên máy, nhận lại thư viện đã gộp.
  Future<ServerLibrary> merge(LocalLibrarySnapshot local) async {
    final response = await _client.post('/api/users/me/library/merge', data: local.toJson());
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ApiException('Máy chủ phản hồi không hợp lệ.', statusCode: response.statusCode);
    }
    return ServerLibrary.fromJson(data);
  }

  /// `PUT|DELETE /api/users/me/library/{list}/{seriesId}`.
  Future<void> setItem(LibraryListKind list, String seriesId, {required bool added, DateTime? lastSeenAt}) async {
    final path = '/api/users/me/library/${list.path}/$seriesId';
    if (added) {
      await _client.put(path, data: {'lastSeenAt': lastSeenAt?.toUtc().toIso8601String()});
    } else {
      await _client.delete(path);
    }
  }

  /// `PUT /api/users/me/library/history`.
  Future<void> saveProgress(ReadingHistoryEntry entry) =>
      _client.put('/api/users/me/library/history', data: progressToJson(entry));

  /// `DELETE /api/users/me/library/history`.
  Future<void> clearHistory() => _client.delete('/api/users/me/library/history');

  static Map<String, dynamic> progressToJson(ReadingHistoryEntry e) => {
    'seriesId': e.seriesId,
    'chapterId': e.chapterId,
    'chapterNumber': e.chapterNumber,
    'lastPageNumber': e.lastPageNumber < 1 ? 1 : e.lastPageNumber,
    'totalPages': e.totalPages,
    'language': e.language,
    'readAt': e.readAt.toUtc().toIso8601String(),
  };
}

/// Dữ liệu thư viện đang có trên máy.
class LocalLibrarySnapshot {
  final Set<String> readLater;
  final Map<String, DateTime?> following;
  final Set<String> favorites;
  final List<ReadingHistoryEntry> history;

  const LocalLibrarySnapshot({
    required this.readLater,
    required this.following,
    required this.favorites,
    required this.history,
  });

  factory LocalLibrarySnapshot.fromPreferences() {
    final seen = PreferencesService.getFollowSeenAt();
    return LocalLibrarySnapshot(
      readLater: PreferencesService.getBookmarks(),
      following: {for (final id in PreferencesService.getFollows()) id: seen[id]},
      favorites: PreferencesService.getFavorites(),
      history: PreferencesService.getReadingHistory(),
    );
  }

  Map<String, dynamic> toJson() => {
    'readLater': readLater.toList(),
    'following': [
      for (final e in following.entries) {'seriesId': e.key, 'lastSeenAt': e.value?.toUtc().toIso8601String()},
    ],
    'favorites': favorites.toList(),
    'history': [for (final h in history) LibrarySyncService.progressToJson(h)],
  };
}

/// Thư viện trả về từ server (khớp `ReaderLibraryDto`).
class ServerLibrary {
  final Set<String> readLater;
  final Map<String, DateTime?> following;
  final Set<String> favorites;
  final List<ServerProgress> history;

  const ServerLibrary({
    required this.readLater,
    required this.following,
    required this.favorites,
    required this.history,
  });

  static Set<String> _ids(dynamic raw) => {for (final e in (raw as List? ?? const [])) e.toString()};

  factory ServerLibrary.fromJson(Map<String, dynamic> json) => ServerLibrary(
    readLater: _ids(json['readLater']),
    following: {
      for (final f in (json['following'] as List? ?? const []))
        if (f is Map<String, dynamic>)
          f['seriesId'].toString(): DateTime.tryParse(f['lastSeenAt']?.toString() ?? '')?.toLocal(),
    },
    favorites: _ids(json['favorites']),
    history: [
      for (final h in (json['history'] as List? ?? const []))
        if (h is Map<String, dynamic>) ServerProgress.fromJson(h),
    ],
  );
}

class ServerProgress {
  final String seriesId;
  final String chapterId;
  final double chapterNumber;
  final int lastPageNumber;
  final int totalPages;
  final String language;
  final DateTime readAt;

  const ServerProgress({
    required this.seriesId,
    required this.chapterId,
    required this.chapterNumber,
    required this.lastPageNumber,
    required this.totalPages,
    required this.language,
    required this.readAt,
  });

  factory ServerProgress.fromJson(Map<String, dynamic> json) => ServerProgress(
    seriesId: json['seriesId'].toString(),
    chapterId: json['chapterId'].toString(),
    chapterNumber: (json['chapterNumber'] as num?)?.toDouble() ?? 1,
    lastPageNumber: (json['lastPageNumber'] as num?)?.toInt() ?? 1,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    language: json['language']?.toString() ?? 'vi',
    readAt: DateTime.tryParse(json['readAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
  );

  ReadingHistoryEntry toEntry(String seriesTitle) => ReadingHistoryEntry(
    seriesId: seriesId,
    seriesTitle: seriesTitle,
    chapterId: chapterId,
    chapterNumber: chapterNumber,
    lastPageNumber: lastPageNumber,
    totalPages: totalPages,
    language: language,
    readAt: readAt,
  );
}
