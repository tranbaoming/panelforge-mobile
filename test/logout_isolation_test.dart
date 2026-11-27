import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/models/api_dtos.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/auth_service.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OkAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({'message': 'OK'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
    AuthService.imageCacheClearer = null;
  });

  tearDown(() {
    AuthService.imageCacheClearer = null;
  });

  group('Logout & cross-user data isolation (AUD-FL-05)', () {
    Future<void> seedUserAData() async {
      await PreferencesService.saveAuthUser({
        'id': 'user-A',
        'email': 'a@panelforge.com',
        'fullName': 'Reader A',
        'isActive': true,
        'role': 'User',
      });
      await PreferencesService.setRememberDeviceToken('device-token-A');
      await PreferencesService.setLocalBalanceVnd(125000);
      await PreferencesService.addWalletTransaction(
        WalletTransactionDto(
          id: 'tx-a-1',
          title: 'Nạp ví A',
          amountVnd: 125000,
          createdAt: DateTime.utc(2026, 11, 1),
          balanceAfter: 125000,
        ),
      );
      await PreferencesService.replaceUnlockedChapterIds({'ch-paid-A', 'ch-paid-A:vi'});
      await PreferencesService.saveChapterEntitlement(
        ChapterEntitlement(
          chapterId: 'ch-paid-A',
          isPermanent: true,
          unlockedAt: DateTime.utc(2026, 11, 1),
          language: 'vi',
        ),
      );
      await PreferencesService.toggleBookmark('series-A');
      await PreferencesService.toggleFollow('series-A');
      await PreferencesService.toggleFavorite('series-A');
      await PreferencesService.saveReadingProgress(
        ReadingHistoryEntry(
          seriesId: 'series-A',
          seriesTitle: 'Truyện của A',
          chapterId: 'ch-paid-A',
          chapterNumber: 5,
          lastPageNumber: 12,
          totalPages: 20,
          readAt: DateTime.utc(2026, 11, 1),
        ),
      );
      await PreferencesService.addRecentSearch('secret search A');
      // Device-level preference should survive logout
      await PreferencesService.setAppThemeMode('light');
      await PreferencesService.setTextScale(1.2);
    }

    test('logout clears all user-scoped preferences and evicts image caches, isolating User B', () async {
      await seedUserAData();

      var imageCacheClearedCount = 0;
      AuthService.imageCacheClearer = () async {
        imageCacheClearedCount++;
      };

      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))..httpClientAdapter = _OkAdapter();
      final authService = AuthService(client: ApiClient(customDio: dio));

      await authService.logout();

      // Verify image caches were cleared
      expect(imageCacheClearedCount, 1);

      // Verify all user-scoped data of A is gone
      expect(PreferencesService.getAuthUser(), isNull);
      expect(PreferencesService.getRememberDeviceToken(), isNull);
      expect(PreferencesService.getLocalBalanceVnd(), isNull);
      expect(PreferencesService.getWalletTransactions(), isEmpty);
      expect(PreferencesService.getUnlockedChapterIds(), isEmpty);
      expect(PreferencesService.isChapterUnlocked('ch-paid-A', language: 'vi'), isFalse);
      expect(PreferencesService.getChapterEntitlement('ch-paid-A', language: 'vi'), isNull);
      expect(PreferencesService.getBookmarks(), isEmpty);
      expect(PreferencesService.getFollows(), isEmpty);
      expect(PreferencesService.getFavorites(), isEmpty);
      expect(PreferencesService.getReadingHistory(), isEmpty);
      expect(PreferencesService.getRecentSearches(), isEmpty);

      // Device-level UI preferences remain intact
      expect(PreferencesService.getAppThemeMode(), 'light');
      expect(PreferencesService.getTextScale(), 1.2);

      // User B logs in: must not inherit any of User A's data
      await PreferencesService.saveAuthUser({
        'id': 'user-B',
        'email': 'b@panelforge.com',
        'fullName': 'Reader B',
        'isActive': true,
        'role': 'User',
      });

      expect(PreferencesService.getAuthUser()?['id'], 'user-B');
      expect(PreferencesService.getLocalBalanceVnd(), isNull);
      expect(PreferencesService.getBookmarks(), isEmpty);
      expect(PreferencesService.getReadingHistory(), isEmpty);
      expect(PreferencesService.isChapterUnlocked('ch-paid-A', language: 'vi'), isFalse);
    });

    test('direct user switch in saveAuthUser wipes previous user data', () async {
      await seedUserAData();

      await PreferencesService.saveAuthUser({
        'id': 'user-B',
        'email': 'b@panelforge.com',
        'fullName': 'Reader B',
        'isActive': true,
        'role': 'User',
      });

      expect(PreferencesService.getAuthUser()?['id'], 'user-B');
      expect(PreferencesService.getLocalBalanceVnd(), isNull);
      expect(PreferencesService.getWalletTransactions(), isEmpty);
      expect(PreferencesService.getBookmarks(), isEmpty);
      expect(PreferencesService.getFollows(), isEmpty);
      expect(PreferencesService.getFavorites(), isEmpty);
      expect(PreferencesService.getReadingHistory(), isEmpty);
      expect(PreferencesService.getRememberDeviceToken(), isNull);
      expect(PreferencesService.getRecentSearches(), isEmpty);
    });
  });
}
