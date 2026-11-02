import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class PreferencesService {
  static const String _keyBaseUrl = 'panelforge_custom_base_url';
  static const String _keyReadingMode = 'panelforge_reading_mode';
  static const String _keyReaderTheme = 'panelforge_reader_theme';
  static const String _keyBookmarks = 'panelforge_bookmarks';
  static const String _keyRecentTokens = 'panelforge_recent_tokens';
  static const String _keyOfflineChapters = 'panelforge_offline_chapters';
  static const String _keyUnlockedChapters = 'panelforge_unlocked_chapters';
  static const String _keyWalletBalance = 'panelforge_wallet_balance';
  static const String _keyIsVip = 'panelforge_is_vip';
  static const String _keyVipExpiresAt = 'panelforge_vip_expires_at';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedUrl = _prefs?.getString(_keyBaseUrl);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      ApiConfig.setCustomBaseUrl(savedUrl);
    }
  }

  // ─── Base URL ─────────────────────────────────────────────────────────────
  static String? getCustomBaseUrl() {
    return _prefs?.getString(_keyBaseUrl);
  }

  static Future<void> setCustomBaseUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await _prefs?.remove(_keyBaseUrl);
      ApiConfig.setCustomBaseUrl(null);
    } else {
      await _prefs?.setString(_keyBaseUrl, url.trim());
      ApiConfig.setCustomBaseUrl(url.trim());
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

  // ─── Reading Mode & Theme ─────────────────────────────────────────────────
  static String? getReadingMode() {
    return _prefs?.getString(_keyReadingMode);
  }

  static Future<void> setReadingMode(String mode) async {
    await _prefs?.setString(_keyReadingMode, mode);
  }

  static String? getReaderTheme() {
    return _prefs?.getString(_keyReaderTheme);
  }

  static Future<void> setReaderTheme(String theme) async {
    await _prefs?.setString(_keyReaderTheme, theme);
  }

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
  }

  static bool isChapterDownloaded(String chapterId) {
    return getOfflineChapterIds().contains(chapterId.trim());
  }

  // ─── Unlocked Chapters & Monetization ─────────────────────────────────────
  static Set<String> getUnlockedChapterIds() {
    final list = _prefs?.getStringList(_keyUnlockedChapters) ?? [];
    return list.toSet();
  }

  static Future<void> addUnlockedChapterId(String chapterId) async {
    final clean = chapterId.trim();
    if (clean.isEmpty) return;
    final current = getUnlockedChapterIds();
    current.add(clean);
    await _prefs?.setStringList(_keyUnlockedChapters, current.toList());
  }

  static bool isChapterUnlocked(String chapterId) {
    return getUnlockedChapterIds().contains(chapterId.trim());
  }

  // ─── Local Wallet & VIP Cache ─────────────────────────────────────────────
  static int getLocalBalanceCoins() {
    return _prefs?.getInt(_keyWalletBalance) ?? 0;
  }

  static Future<void> setLocalBalanceCoins(int coins) async {
    await _prefs?.setInt(_keyWalletBalance, coins);
  }

  static bool getLocalIsVip() {
    final isVip = _prefs?.getBool(_keyIsVip) ?? false;
    if (!isVip) return false;
    final exp = getLocalVipExpiresAt();
    if (exp != null && exp.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  static DateTime? getLocalVipExpiresAt() {
    final str = _prefs?.getString(_keyVipExpiresAt);
    if (str != null && str.isNotEmpty) {
      return DateTime.tryParse(str);
    }
    return null;
  }

  static Future<void> setLocalVip({required bool isVip, DateTime? expiresAt}) async {
    await _prefs?.setBool(_keyIsVip, isVip);
    if (expiresAt != null) {
      await _prefs?.setString(_keyVipExpiresAt, expiresAt.toIso8601String());
    } else {
      await _prefs?.remove(_keyVipExpiresAt);
    }
  }
}

