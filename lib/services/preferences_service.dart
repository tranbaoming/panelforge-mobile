import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_dtos.dart';
import 'api_config.dart';

class PreferencesService {
  static const String _keyBaseUrl = 'panelforge_custom_base_url';
  static const String _keyReadingMode = 'panelforge_reading_mode';
  static const String _keyReaderTheme = 'panelforge_reader_theme';
  static const String _keyBookmarks = 'panelforge_bookmarks';
  static const String _keyRecentTokens = 'panelforge_recent_tokens';
  static const String _keyOfflineChapters = 'panelforge_offline_chapters';
  static const String _keyUnlockedChapters = 'panelforge_unlocked_chapters';
  static const String _keyChapterEntitlements = 'panelforge_chapter_entitlements';
  static const String _keyWalletBalance = 'panelforge_wallet_balance';
  static const String _keyWalletBalanceVnd = 'panelforge_wallet_balance_vnd';
  static const String _keyWalletTransactions = 'panelforge_wallet_transactions';
  static const String _keyIsVip = 'panelforge_is_vip';
  static const String _keyVipExpiresAt = 'panelforge_vip_expires_at';

  // ─── Authentication & Session Keys ─────────────────────────────────────────
  static const String _keyAuthUser = 'panelforge_auth_user';
  static const String _keyRememberDeviceToken = 'panelforge_remember_device_token';
  static const String _keyIsRestrictedReader = 'panelforge_is_restricted_reader';
  static const String _keyRestrictionNotice = 'panelforge_restriction_notice';

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

  // ─── Unlocked Chapters & Entitlements ─────────────────────────────────────
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

  static Future<void> removeUnlockedChapterId(String chapterId) async {
    final clean = chapterId.trim();
    final current = getUnlockedChapterIds();
    current.remove(clean);
    await _prefs?.setStringList(_keyUnlockedChapters, current.toList());
  }

  static Map<String, ChapterEntitlement> getChapterEntitlements() {
    final rawStr = _prefs?.getString(_keyChapterEntitlements);
    if (rawStr == null || rawStr.isEmpty) return {};
    try {
      final decoded = jsonDecode(rawStr) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          ChapterEntitlement.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  static ChapterEntitlement? getChapterEntitlement(String chapterId) {
    final entitlements = getChapterEntitlements();
    return entitlements[chapterId.trim()];
  }

  static Future<void> saveChapterEntitlement(ChapterEntitlement entitlement) async {
    final entitlements = getChapterEntitlements();
    final cleanId = entitlement.chapterId.trim();
    entitlements[cleanId] = entitlement;
    final encoded = jsonEncode(entitlements.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString(_keyChapterEntitlements, encoded);

    if (entitlement.isValid) {
      await addUnlockedChapterId(cleanId);
    } else {
      await removeUnlockedChapterId(cleanId);
    }
  }

  static Future<void> removeChapterEntitlement(String chapterId) async {
    final cleanId = chapterId.trim();
    final entitlements = getChapterEntitlements();
    entitlements.remove(cleanId);
    final encoded = jsonEncode(entitlements.map((k, v) => MapEntry(k, v.toJson())));
    await _prefs?.setString(_keyChapterEntitlements, encoded);
    await removeUnlockedChapterId(cleanId);
  }

  static bool isChapterUnlocked(String chapterId) {
    if (getLocalIsVip()) return true;
    final ent = getChapterEntitlement(chapterId);
    if (ent != null) {
      return ent.isValid;
    }
    return getUnlockedChapterIds().contains(chapterId.trim());
  }

  // ─── Local Wallet & VIP Cache ─────────────────────────────────────────────
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
    if (_prefs?.getInt(_keyWalletBalanceVnd) == null &&
        _prefs?.getInt(_keyWalletBalance) == null) {
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

