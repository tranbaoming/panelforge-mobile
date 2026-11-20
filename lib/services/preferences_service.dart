import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_dtos.dart';

class PreferencesService {
  static const String _keyBaseUrl = 'panelforge_custom_base_url';
  static const String _keyReadingMode = 'panelforge_reading_mode';
  static const String _keyReaderTheme = 'panelforge_reader_theme';
  static const String _keyReaderSeriesSettings = 'panelforge_reader_series_settings';
  static const String _keyAutoNextChapter = 'panelforge_auto_next_chapter';
  static const String _keyContentLanguage = 'panelforge_content_language';
  static const String _keyBookmarks = 'panelforge_bookmarks';
  static const String _keyReadingHistory = 'panelforge_reading_history';
  static const String _keyFavorites = 'panelforge_favorites';
  static const String _keyAppThemeMode = 'panelforge_app_theme_mode';
  static const String _keyFollows = 'panelforge_follows';
  static const String _keyFollowSeenAt = 'panelforge_follow_seen_at';
  static const String _keyKeepScreenOn = 'panelforge_keep_screen_on';
  static const String _keyLastSyncAt = 'panelforge_last_sync_at';
  static const String _keyPromoSeenSeries = 'panelforge_promo_seen_series';
  static const String _keyRecentTokens = 'panelforge_recent_tokens';
  static const String _keyRecentSearches = 'panelforge_recent_searches';
  static const String _keyOfflineChapters = 'panelforge_offline_chapters';
  static const String _keyOfflineChapterMeta = 'panelforge_offline_chapter_meta';
  static const String _keyUnlockedChapters = 'panelforge_unlocked_chapters';
  static const String _keyChapterEntitlements = 'panelforge_chapter_entitlements';
  static const String _keyWalletBalance = 'panelforge_wallet_balance';
  static const String _keyWalletBalanceVnd = 'panelforge_wallet_balance_vnd';
  static const String _keyWalletTransactions = 'panelforge_wallet_transactions';

  // ─── Authentication & Session Keys ─────────────────────────────────────────
  static const String _keyAuthUser = 'panelforge_auth_user';
  static const String _keyRememberDeviceToken = 'panelforge_remember_device_token';
  static const String _keyIsRestrictedReader = 'panelforge_is_restricted_reader';
  static const String _keyRestrictionNotice = 'panelforge_restriction_notice';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Màn hình cấu hình máy chủ đã bị gỡ: xóa địa chỉ tùy chỉnh còn lưu từ trước để app luôn dùng ApiConfig mặc định.
    if (_prefs?.containsKey(_keyBaseUrl) ?? false) {
      await _prefs?.remove(_keyBaseUrl);
    }
  }

  // ─── Bookmarks ────────────────────────────────────────────────────────────
  static Set<String> getBookmarks() {
    final list = _prefs?.getStringList(_keyBookmarks) ?? [];
    return list.toSet();
  }

  static Future<bool> toggleBookmark(String seriesId) async {
    final current = getBookmarks();
    final isBookmarked = current.contains(seriesId);
    if (isBookmarked) {
      current.remove(seriesId);
    } else {
      current.add(seriesId);
    }
    await _prefs?.setStringList(_keyBookmarks, current.toList());
    return !isBookmarked;
  }

  static bool isBookmarked(String seriesId) {
    return getBookmarks().contains(seriesId);
  }

  // ─── Chế độ Sáng / Tối của ứng dụng ─────────────────────────────────────
  /// 'dark' (mặc định) | 'light' | 'system'.
  static String getAppThemeMode() => _prefs?.getString(_keyAppThemeMode) ?? 'dark';

  static Future<void> setAppThemeMode(String mode) async => _prefs?.setString(_keyAppThemeMode, mode);

  // ─── Theo dõi (🔔) — tách khỏi Bookmark "Đọc sau" (🔖) ─────────────────
  static Set<String> getFollows() => (_prefs?.getStringList(_keyFollows) ?? const <String>[]).toSet();

  static bool isFollowing(String seriesId) => getFollows().contains(seriesId);

  static Future<bool> toggleFollow(String seriesId) async {
    final current = getFollows();
    final added = current.add(seriesId);
    if (!added) current.remove(seriesId);
    await _prefs?.setStringList(_keyFollows, current.toList());
    // Bắt đầu theo dõi → chỉ báo các chương phát hành sau thời điểm này.
    if (added) await setFollowSeenAt(seriesId, DateTime.now());
    return added;
  }

  /// Lần cuối độc giả đã "thấy" chương mới của từng bộ đang theo dõi (seriesId → thời điểm).
  static Map<String, DateTime> getFollowSeenAt() {
    final raw = _prefs?.getString(_keyFollowSeenAt);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, DateTime>{};
      for (final e in decoded.entries) {
        final t = DateTime.tryParse(e.value.toString());
        if (t != null) result[e.key] = t;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> setFollowSeenAt(String seriesId, DateTime at) async {
    final map = getFollowSeenAt()..[seriesId] = at;
    await _prefs?.setString(_keyFollowSeenAt, jsonEncode(map.map((k, v) => MapEntry(k, v.toIso8601String()))));
  }

  // ─── Cài đặt màn Cá nhân ────────────────────────────────────────────────
  static bool getKeepScreenOn() => _prefs?.getBool(_keyKeepScreenOn) ?? false;

  static Future<void> setKeepScreenOn(bool value) async => _prefs?.setBool(_keyKeepScreenOn, value);

  /// Bộ truyện mới cuối cùng đã hiện popup giới thiệu ở Trang chủ (mỗi bộ chỉ hiện một lần).
  static String? getPromoSeenSeriesId() => _prefs?.getString(_keyPromoSeenSeries);

  static Future<void> setPromoSeenSeriesId(String id) async => _prefs?.setString(_keyPromoSeenSeries, id);

  static DateTime? getLastSyncAt() => DateTime.tryParse(_prefs?.getString(_keyLastSyncAt) ?? '');

  static Future<void> setLastSyncAt(DateTime time) async => _prefs?.setString(_keyLastSyncAt, time.toIso8601String());

  // ─── Favorites (Yêu thích) ──────────────────────────────────────────────
  static Set<String> getFavorites() => (_prefs?.getStringList(_keyFavorites) ?? const <String>[]).toSet();

  static bool isFavorite(String seriesId) => getFavorites().contains(seriesId);

  static Future<bool> toggleFavorite(String seriesId) async {
    final current = getFavorites();
    final added = current.add(seriesId);
    if (!added) current.remove(seriesId);
    await _prefs?.setStringList(_keyFavorites, current.toList());
    return added;
  }

  // ─── Reading History (Tiếp tục đọc) ───────────────────────────────────────
  /// Lịch sử đọc mới nhất trước, mỗi bộ truyện một mục, tối đa 30 mục.
  static List<ReadingHistoryEntry> getReadingHistory() {
    final list = _prefs?.getStringList(_keyReadingHistory) ?? const [];
    final result = <ReadingHistoryEntry>[];
    for (final raw in list) {
      try {
        result.add(ReadingHistoryEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    return result;
  }

  static ReadingHistoryEntry? getReadingHistoryFor(String seriesId) {
    for (final e in getReadingHistory()) {
      if (e.seriesId == seriesId) return e;
    }
    return null;
  }

  static Future<void> clearReadingHistory() async => _prefs?.remove(_keyReadingHistory);

  static Future<void> saveReadingProgress(ReadingHistoryEntry entry) async {
    final rest = getReadingHistory().where((e) => e.seriesId != entry.seriesId);
    final next = [entry, ...rest].take(30).map((e) => jsonEncode(e.toJson())).toList();
    await _prefs?.setStringList(_keyReadingHistory, next);
  }

  // ─── Reading Mode & Theme ─────────────────────────────────────────────────
  static String? getReadingMode() {
    return _prefs?.getString(_keyReadingMode);
  }

  static Future<void> setReadingMode(String mode) async {
    await _prefs?.setString(_keyReadingMode, mode);
  }

  /// Ngôn ngữ bản phát hành độc giả muốn đọc (vi/en/ja); mặc định bản gốc tiếng Việt.
  static String getContentLanguage() {
    final code = _prefs?.getString(_keyContentLanguage);
    return code != null && kContentLanguages.contains(code) ? code : 'vi';
  }

  static Future<void> setContentLanguage(String code) async => _prefs?.setString(_keyContentLanguage, code);

  static String? getReaderTheme() {
    return _prefs?.getString(_keyReaderTheme);
  }

  static Future<void> setReaderTheme(String theme) async {
    await _prefs?.setString(_keyReaderTheme, theme);
  }

  /// Cài đặt đọc riêng của từng bộ truyện (chế độ đọc, nền, độ sáng).
  static ReaderSeriesSettings getReaderSeriesSettings(String seriesId) {
    final raw = _prefs?.getString(_keyReaderSeriesSettings);
    if (raw == null || raw.isEmpty) return const ReaderSeriesSettings();
    try {
      final all = jsonDecode(raw) as Map<String, dynamic>;
      final one = all[seriesId];
      return one is Map<String, dynamic> ? ReaderSeriesSettings.fromJson(one) : const ReaderSeriesSettings();
    } catch (_) {
      return const ReaderSeriesSettings();
    }
  }

  static Future<void> saveReaderSeriesSettings(String seriesId, ReaderSeriesSettings settings) async {
    Map<String, dynamic> all = {};
    try {
      all = jsonDecode(_prefs?.getString(_keyReaderSeriesSettings) ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    all[seriesId] = settings.toJson();
    await _prefs?.setString(_keyReaderSeriesSettings, jsonEncode(all));
  }

  /// Đọc hết trang cuối → tự sang chương sau (nếu chương đó đọc được). Mặc định bật.
  static bool getAutoNextChapter() => _prefs?.getBool(_keyAutoNextChapter) ?? true;

  static Future<void> setAutoNextChapter(bool value) async => _prefs?.setBool(_keyAutoNextChapter, value);

  // ─── Lịch sử tìm kiếm ────────────────────────────────────────────────────
  /// Từ khóa đã tìm, mới nhất trước, tối đa 10, không trùng (không phân biệt hoa thường).
  static List<String> getRecentSearches() => _prefs?.getStringList(_keyRecentSearches) ?? const [];

  static Future<void> addRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final rest = getRecentSearches().where((q) => q.toLowerCase() != clean.toLowerCase());
    await _prefs?.setStringList(_keyRecentSearches, [clean, ...rest].take(10).toList());
  }

  static Future<void> removeRecentSearch(String query) async =>
      _prefs?.setStringList(_keyRecentSearches, getRecentSearches().where((q) => q != query).toList());

  static Future<void> clearRecentSearches() async => _prefs?.remove(_keyRecentSearches);

  // ─── Recent Review Tokens ─────────────────────────────────────────────────
  static List<String> getRecentReviewTokens() {
    return _prefs?.getStringList(_keyRecentTokens) ?? [];
  }

  static Future<void> addRecentReviewToken(String token) async {
    final clean = token.trim();
    if (clean.isEmpty) return;
    final current = getRecentReviewTokens().where((t) => t != clean).toList();
    current.insert(0, clean);
    if (current.length > 10) {
      current.removeLast();
    }
    await _prefs?.setStringList(_keyRecentTokens, current);
  }

  static Future<void> removeRecentReviewToken(String token) async {
    final clean = token.trim();
    final current = getRecentReviewTokens().where((t) => t != clean).toList();
    await _prefs?.setStringList(_keyRecentTokens, current);
  }

  // ─── Offline Downloaded Chapters ──────────────────────────────────────────
  static Set<String> getOfflineChapterIds() {
    final list = _prefs?.getStringList(_keyOfflineChapters) ?? [];
    return list.toSet();
  }

  static Future<void> addOfflineChapterId(String chapterId) async {
    final clean = chapterId.trim();
    if (clean.isEmpty) return;
    final current = getOfflineChapterIds();
    current.add(clean);
    await _prefs?.setStringList(_keyOfflineChapters, current.toList());
  }

  static Future<void> removeOfflineChapterId(String chapterId) async {
    final clean = chapterId.trim();
    final current = getOfflineChapterIds();
    current.remove(clean);
    await _prefs?.setStringList(_keyOfflineChapters, current.toList());
    final meta = getOfflineChapterMeta()..remove(clean);
    await _saveOfflineMeta(meta);
  }

  /// Thông tin hiển thị của chương đã tải (tên bộ, số chương...) cho màn "Đã tải".
  static Map<String, OfflineChapterInfo> getOfflineChapterMeta() {
    final raw = _prefs?.getString(_keyOfflineChapterMeta);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, OfflineChapterInfo.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveOfflineChapterInfo(OfflineChapterInfo info) async {
    final meta = getOfflineChapterMeta()..[info.chapterId] = info;
    await _saveOfflineMeta(meta);
  }

  static Future<void> _saveOfflineMeta(Map<String, OfflineChapterInfo> meta) async =>
      _prefs?.setString(_keyOfflineChapterMeta, jsonEncode(meta.map((k, v) => MapEntry(k, v.toJson()))));

  static bool isChapterDownloaded(String chapterId) {
    return getOfflineChapterIds().contains(chapterId.trim());
  }

  // ─── Unlocked Chapters & Entitlements ─────────────────────────────────────
  static Set<String> getUnlockedChapterIds() {
    final list = _prefs?.getStringList(_keyUnlockedChapters) ?? [];
    return list.toSet();
  }

  static Future<void> addUnlockedChapterId(String chapterId, {String? language}) async {
    final clean = chapterId.trim();
    if (clean.isEmpty) return;
    final current = getUnlockedChapterIds();
    current.add(clean);
    if (!clean.contains(':')) {
      current.add(ChapterEntitlement.editionKey(clean, language));
    }
    await _prefs?.setStringList(_keyUnlockedChapters, current.toList());
  }

  static Future<void> removeUnlockedChapterId(String chapterId, {String? language}) async {
    final clean = chapterId.trim();
    final current = getUnlockedChapterIds();
    current.remove(clean);
    if (!clean.contains(':')) {
      current.remove(ChapterEntitlement.editionKey(clean, language));
    }
    await _prefs?.setStringList(_keyUnlockedChapters, current.toList());
  }

  static Map<String, ChapterEntitlement> getChapterEntitlements() {
    final rawStr = _prefs?.getString(_keyChapterEntitlements);
    if (rawStr == null || rawStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(rawStr) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, ChapterEntitlement.fromJson(value as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  static ChapterEntitlement? getChapterEntitlement(String chapterId, {String? language}) {
    final entitlements = getChapterEntitlements();
    final clean = chapterId.trim();
    if (language != null && language.trim().isNotEmpty) {
      final key = ChapterEntitlement.editionKey(clean, language);
      if (entitlements.containsKey(key)) return entitlements[key];
    }
    return entitlements[clean] ?? entitlements[ChapterEntitlement.editionKey(clean, language)];
  }

  static Future<void> saveChapterEntitlement(ChapterEntitlement entitlement) async {
    final entitlements = getChapterEntitlements();
    final cleanId = entitlement.chapterId.trim();
    final editionKey = ChapterEntitlement.editionKey(cleanId, entitlement.language);
    entitlements[cleanId] = entitlement;
    entitlements[editionKey] = entitlement;
    final encoded = jsonEncode(entitlements.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString(_keyChapterEntitlements, encoded);

    if (entitlement.isValid) {
      await addUnlockedChapterId(cleanId, language: entitlement.language);
    } else {
      await removeUnlockedChapterId(cleanId, language: entitlement.language);
    }
  }

  static Future<void> removeChapterEntitlement(String chapterId, {String? language}) async {
    final cleanId = chapterId.trim();
    final entitlements = getChapterEntitlements();
    entitlements.remove(cleanId);
    entitlements.remove(ChapterEntitlement.editionKey(cleanId, language));
    final encoded = jsonEncode(entitlements.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString(_keyChapterEntitlements, encoded);
    await removeUnlockedChapterId(cleanId, language: language);
  }

  /// Ghi đè cache chương đã mở khóa bằng danh sách quyền sở hữu thật từ `GET /api/wallet/me`
  /// (server là nguồn sự thật; tránh cache của tài khoản cũ còn sót trên thiết bị).
  static Future<void> replaceUnlockedChapterIds(Set<String> serverIds) async {
    final clean = serverIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final entitlements = <String, ChapterEntitlement>{
      for (final id in clean)
        id:
            getChapterEntitlement(id) ??
            ChapterEntitlement(
              chapterId: id.contains(':') ? id.split(':').first : id,
              language: id.contains(':') ? id.split(':').last : null,
              isPermanent: true,
              unlockedAt: DateTime.now(),
            ),
    };
    final encoded = jsonEncode(entitlements.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString(_keyChapterEntitlements, encoded);
    await _prefs?.setStringList(_keyUnlockedChapters, clean.toList());
  }

  static bool isChapterUnlocked(String chapterId, {String? language}) {
    final clean = chapterId.trim();
    final unlocked = getUnlockedChapterIds();
    if (language != null && language.trim().isNotEmpty) {
      final key = ChapterEntitlement.editionKey(clean, language);
      if (unlocked.contains(key)) return true;
      // Nếu trong danh sách đã có khóa theo ngôn ngữ khác của cùng chương (vd "ch1:vi"),
      // thì không tự coi bản "ch1:en" là đã mở khóa (BR-33/Q10: mua ngôn ngữ nào đọc ngôn ngữ đó).
      final hasAnyLanguageSpecific = unlocked.any((id) => id.startsWith('$clean:'));
      if (hasAnyLanguageSpecific) return false;
    }
    final ent = getChapterEntitlement(clean, language: language);
    if (ent != null) {
      return ent.isValid;
    }
    return unlocked.contains(clean);
  }

  // ─── Local Wallet Cache ───────────────────────────────────────────────────
  static int getLocalBalanceVnd() {
    final vnd = _prefs?.getInt(_keyWalletBalanceVnd);
    if (vnd != null) return vnd;
    final coins = _prefs?.getInt(_keyWalletBalance);
    if (coins != null && coins > 0) return coins * 100;
    return 50000;
  }

  static Future<void> setLocalBalanceVnd(int amount) async {
    await _prefs?.setInt(_keyWalletBalanceVnd, amount);
    await _prefs?.setInt(_keyWalletBalance, amount ~/ 100);
  }

  static int getLocalBalanceCoins() {
    return getLocalBalanceVnd() ~/ 100;
  }

  static Future<void> setLocalBalanceCoins(int coins) async {
    await setLocalBalanceVnd(coins * 100);
  }

  static List<WalletTransactionDto> getWalletTransactions() {
    final strList = _prefs?.getStringList(_keyWalletTransactions) ?? [];
    final list = <WalletTransactionDto>[];
    for (final str in strList) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        list.add(WalletTransactionDto.fromJson(map));
      } catch (_) {}
    }
    return list;
  }

  static Future<void> addWalletTransaction(WalletTransactionDto tx) async {
    final list = getWalletTransactions();
    list.insert(0, tx);
    final encoded = list.take(50).map((t) => jsonEncode(t.toJson())).toList();
    await _prefs?.setStringList(_keyWalletTransactions, encoded);
  }

  // ─── Authentication & Session Storage ───────────────────────────────────────
  static Map<String, dynamic>? getAuthUser() {
    final str = _prefs?.getString(_keyAuthUser);
    if (str == null || str.isEmpty) return null;
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> saveAuthUser(Map<String, dynamic> userMap) async {
    await _prefs?.setString(_keyAuthUser, jsonEncode(userMap));
    // Khởi tạo số dư ví mặc định 50.000đ cho độc giả mới nếu chưa có
    if (_prefs?.getInt(_keyWalletBalanceVnd) == null && _prefs?.getInt(_keyWalletBalance) == null) {
      await setLocalBalanceVnd(50000);
      await addWalletTransaction(
        WalletTransactionDto(
          id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Quà tặng chào mừng Độc giả mới',
          amountVnd: 50000,
          createdAt: DateTime.now(),
          balanceAfter: 50000,
        ),
      );
    }
  }

  static String? getRememberDeviceToken() {
    return _prefs?.getString(_keyRememberDeviceToken);
  }

  static Future<void> setRememberDeviceToken(String? token) async {
    if (token == null || token.trim().isEmpty) {
      await _prefs?.remove(_keyRememberDeviceToken);
    } else {
      await _prefs?.setString(_keyRememberDeviceToken, token.trim());
    }
  }

  static bool getIsRestrictedReader() {
    return _prefs?.getBool(_keyIsRestrictedReader) ?? false;
  }

  static Future<void> setIsRestrictedReader(bool isRestricted) async {
    await _prefs?.setBool(_keyIsRestrictedReader, isRestricted);
  }

  static String? getRestrictionNotice() {
    return _prefs?.getString(_keyRestrictionNotice);
  }

  static Future<void> setRestrictionNotice(String? notice) async {
    if (notice == null || notice.trim().isEmpty) {
      await _prefs?.remove(_keyRestrictionNotice);
    } else {
      await _prefs?.setString(_keyRestrictionNotice, notice.trim());
    }
  }

  static Future<void> clearAuthSession() async {
    await _prefs?.remove(_keyAuthUser);
    await _prefs?.remove(_keyIsRestrictedReader);
    await _prefs?.remove(_keyRestrictionNotice);
  }
}

/// Một mục lịch sử đọc: chương gần nhất của một bộ truyện, kèm trang đang đọc dở và ngôn ngữ.
class ReadingHistoryEntry {
  final String seriesId;
  final String seriesTitle;
  final String chapterId;
  final double chapterNumber;
  final int lastPageNumber;
  final int totalPages;
  final String language;
  final DateTime readAt;

  const ReadingHistoryEntry({
    required this.seriesId,
    required this.seriesTitle,
    required this.chapterId,
    required num chapterNumber,
    this.lastPageNumber = 1,
    this.totalPages = 0,
    this.language = 'vi',
    required this.readAt,
  }) : chapterNumber = chapterNumber is double ? chapterNumber : (chapterNumber as int) * 1.0;

  String get chapterNumberLabel {
    if (chapterNumber == chapterNumber.truncateToDouble()) {
      return chapterNumber.toInt().toString();
    }
    return chapterNumber.toString().replaceAll(RegExp(r'\.?0+$'), '');
  }

  factory ReadingHistoryEntry.fromJson(Map<String, dynamic> json) => ReadingHistoryEntry(
    seriesId: json['seriesId'] as String,
    seriesTitle: json['seriesTitle'] as String? ?? '',
    chapterId: json['chapterId'] as String,
    chapterNumber: (json['chapterNumber'] as num?)?.toDouble() ?? 1.0,
    lastPageNumber: (json['lastPageNumber'] as num?)?.toInt() ?? 1,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    language: json['language'] as String? ?? 'vi',
    readAt: DateTime.tryParse(json['readAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'seriesId': seriesId,
    'seriesTitle': seriesTitle,
    'chapterId': chapterId,
    'chapterNumber': chapterNumber,
    'lastPageNumber': lastPageNumber,
    'totalPages': totalPages,
    'language': language,
    'readAt': readAt.toIso8601String(),
  };

  ReadingHistoryEntry copyWith({
    int? lastPageNumber,
    int? totalPages,
    String? language,
    DateTime? readAt,
  }) => ReadingHistoryEntry(
    seriesId: seriesId,
    seriesTitle: seriesTitle,
    chapterId: chapterId,
    chapterNumber: chapterNumber,
    lastPageNumber: lastPageNumber ?? this.lastPageNumber,
    totalPages: totalPages ?? this.totalPages,
    language: language ?? this.language,
    readAt: readAt ?? this.readAt,
  );
}

/// Chương đã tải offline: đủ để hiện trong màn "Đã tải" mà không cần mạng.
class OfflineChapterInfo {
  final String chapterId;
  final String seriesId;
  final String seriesTitle;
  final double chapterNumber;
  final String chapterTitle;
  final DateTime downloadedAt;

  const OfflineChapterInfo({
    required this.chapterId,
    required this.seriesId,
    required this.seriesTitle,
    required this.chapterNumber,
    required this.chapterTitle,
    required this.downloadedAt,
  });

  String get chapterNumberLabel => chapterNumber == chapterNumber.truncateToDouble()
      ? chapterNumber.toInt().toString()
      : chapterNumber.toString();

  factory OfflineChapterInfo.fromJson(Map<String, dynamic> json) => OfflineChapterInfo(
    chapterId: json['chapterId'] as String? ?? '',
    seriesId: json['seriesId'] as String? ?? '',
    seriesTitle: json['seriesTitle'] as String? ?? '',
    chapterNumber: (json['chapterNumber'] as num?)?.toDouble() ?? 0,
    chapterTitle: json['chapterTitle'] as String? ?? '',
    downloadedAt: DateTime.tryParse(json['downloadedAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'chapterId': chapterId,
    'seriesId': seriesId,
    'seriesTitle': seriesTitle,
    'chapterNumber': chapterNumber,
    'chapterTitle': chapterTitle,
    'downloadedAt': downloadedAt.toIso8601String(),
  };
}

/// Cài đặt đọc của một bộ truyện. `null` = chưa chọn, dùng mặc định (hướng đọc do server / nền Đêm).
class ReaderSeriesSettings {
  final String? readingMode;
  final String? theme;
  final double brightness;

  const ReaderSeriesSettings({this.readingMode, this.theme, this.brightness = 1.0});

  ReaderSeriesSettings copyWith({String? readingMode, String? theme, double? brightness}) => ReaderSeriesSettings(
    readingMode: readingMode ?? this.readingMode,
    theme: theme ?? this.theme,
    brightness: brightness ?? this.brightness,
  );

  factory ReaderSeriesSettings.fromJson(Map<String, dynamic> json) => ReaderSeriesSettings(
    readingMode: json['readingMode'] as String?,
    theme: json['theme'] as String?,
    brightness: ((json['brightness'] as num?)?.toDouble() ?? 1.0).clamp(0.2, 1.0),
  );

  Map<String, dynamic> toJson() => {'readingMode': readingMode, 'theme': theme, 'brightness': brightness};
}
