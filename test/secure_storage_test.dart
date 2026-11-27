import 'dart:convert';
import 'dart:io';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SecureStorageService.setStoreForTesting(null);
  });

  group('SecureCookieStorage & legacy .cookies migration (AUD-FL-02)', () {
    test('PersistCookieJar backed by SecureCookieStorage persists and deletes session cookies', () async {
      final memStore = InMemorySecureStore();
      final storage = SecureCookieStorage(store: memStore);
      final jar = PersistCookieJar(storage: storage, persistSession: true);
      final uri = Uri.parse('https://api.panelforge.com');

      await jar.saveFromResponse(uri, [
        Cookie('pf_access', 'jwt-access-secret')..httpOnly = true,
        Cookie('pf_refresh', 'jwt-refresh-secret')..httpOnly = true,
        Cookie('pf_2fa', '2fa-session-secret')..httpOnly = true,
      ]);

      // Verify data lives in SecureKeyValueStore
      expect(memStore.snapshot.isNotEmpty, isTrue);

      // Re-instantiate PersistCookieJar on the same SecureKeyValueStore (simulates app restart)
      final restartedJar = PersistCookieJar(storage: SecureCookieStorage(store: memStore), persistSession: true);
      final loaded = await restartedJar.loadForRequest(uri);
      final byName = {for (final c in loaded) c.name: c.value};
      expect(byName['pf_access'], 'jwt-access-secret');
      expect(byName['pf_refresh'], 'jwt-refresh-secret');
      expect(byName['pf_2fa'], '2fa-session-secret');

      // Delete all clears secure store entries
      await restartedJar.deleteAll();
      final afterDelete = await restartedJar.loadForRequest(uri);
      expect(afterDelete, isEmpty);
      expect(memStore.snapshot, isEmpty);
    });

    test('migrateLegacyCookieDir copies plaintext FileStorage cookies into secure storage and deletes .cookies',
        () async {
      final tempRoot = await Directory.systemTemp.createTemp('pf_legacy_cookies_test_');
      addTearDown(() async {
        if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
      });

      final legacyDir = Directory('${tempRoot.path}${Platform.pathSeparator}.cookies');
      await legacyDir.create(recursive: true);
      final uri = Uri.parse('https://api.panelforge.com');

      // Seed legacy plaintext FileStorage cookies
      final legacyJar = PersistCookieJar(storage: FileStorage(legacyDir.path), persistSession: true);
      await legacyJar.saveFromResponse(uri, [
        Cookie('pf_access', 'legacy-access-token')..httpOnly = true,
        Cookie('pf_refresh', 'legacy-refresh-token')..httpOnly = true,
      ]);
      expect(await legacyDir.exists(), isTrue);

      // Migrate into SecureCookieStorage
      final memStore = InMemorySecureStore();
      final secureStorage = SecureCookieStorage(store: memStore);
      final migratedCount = await secureStorage.migrateLegacyCookieDir(legacyDir);

      expect(migratedCount, greaterThan(0));
      expect(await legacyDir.exists(), isFalse);

      // Existing session cookies remain readable after migration
      final newJar = PersistCookieJar(storage: secureStorage, persistSession: true);
      final loaded = await newJar.loadForRequest(uri);
      final byName = {for (final c in loaded) c.name: c.value};
      expect(byName['pf_access'], 'legacy-access-token');
      expect(byName['pf_refresh'], 'legacy-refresh-token');
    });
  });

  group('SecureStorageService & SharedPreferences migration (AUD-FL-02)', () {
    test('migrates legacy authUser and rememberDeviceToken out of SharedPreferences without signing user out',
        () async {
      final memStore = InMemorySecureStore();
      SecureStorageService.setStoreForTesting(memStore);

      final legacyUser = {
        'id': 'user-legacy-1',
        'email': 'legacy@panelforge.com',
        'fullName': 'Legacy Reader',
        'isActive': true,
        'role': 'User',
      };
      SharedPreferences.setMockInitialValues({
        'panelforge_auth_user': jsonEncode(legacyUser),
        'panelforge_remember_device_token': 'legacy-device-token-123',
      });

      await PreferencesService.init();

      // User stays signed in and device token is preserved
      expect(PreferencesService.getAuthUser()?['id'], 'user-legacy-1');
      expect(PreferencesService.getRememberDeviceToken(), 'legacy-device-token-123');

      // Plaintext keys are removed from SharedPreferences
      final rawPrefs = await SharedPreferences.getInstance();
      expect(rawPrefs.getString('panelforge_auth_user'), isNull);
      expect(rawPrefs.getString('panelforge_remember_device_token'), isNull);

      // Values are persisted in secure store
      expect(memStore.snapshot[SecureStorageService.keyAuthUser], isNotNull);
      expect(memStore.snapshot[SecureStorageService.keyRememberDeviceToken], 'legacy-device-token-123');
    });

    test('new writes store credentials only in secure storage and clearUserScopedData deletes them', () async {
      final memStore = InMemorySecureStore();
      SecureStorageService.setStoreForTesting(memStore);
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.init();

      await PreferencesService.saveAuthUser({
        'id': 'u-sec',
        'email': 'sec@panelforge.com',
        'fullName': 'Secure User',
        'isActive': true,
        'role': 'User',
      });
      await PreferencesService.setRememberDeviceToken('sec-device-token');

      final rawPrefs = await SharedPreferences.getInstance();
      expect(rawPrefs.getString('panelforge_auth_user'), isNull);
      expect(rawPrefs.getString('panelforge_remember_device_token'), isNull);
      expect(PreferencesService.getAuthUser()?['id'], 'u-sec');
      expect(PreferencesService.getRememberDeviceToken(), 'sec-device-token');

      await PreferencesService.clearUserScopedData();
      expect(PreferencesService.getAuthUser(), isNull);
      expect(PreferencesService.getRememberDeviceToken(), isNull);
      expect(memStore.snapshot[SecureStorageService.keyAuthUser], isNull);
      expect(memStore.snapshot[SecureStorageService.keyRememberDeviceToken], isNull);
    });
  });
}
