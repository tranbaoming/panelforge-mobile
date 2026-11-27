import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:panelforge/main.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/api_config.dart';
import 'package:panelforge/services/auth_service.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:panelforge/services/secure_storage_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testEmail = String.fromEnvironment('TEST_EMAIL', defaultValue: 'reader@panelforge.com');

  testWidgets('TASK-16 Step 2: Restart persists session and logout removes secure entries', (tester) async {
    await PreferencesService.init();
    await ApiClient.initCookieJar();

    await tester.pumpWidget(const ProviderScope(child: PanelForgeApp()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(SecureStorageService.store, isA<FlutterSecureKeyValueStore>());

    // 1. Confirm session persisted across app restart without logging in again.
    final cachedUser = PreferencesService.getAuthUser();
    expect(cachedUser, isNotNull, reason: 'Auth user must persist across restart via secure storage');
    expect(cachedUser!['email']?.toString().toLowerCase(), testEmail.toLowerCase());

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/me');
    final cookiesBeforeLogout = await ApiClient.cookieJar.loadForRequest(uri);
    final cookieNamesBefore = cookiesBeforeLogout.map((c) => c.name).toList()..sort();
    // ignore: avoid_print
    print('[TASK16_STEP2] persistedCookieNames=$cookieNamesBefore');
    expect(cookieNamesBefore, contains('pf_access'));
    expect(cookieNamesBefore, contains('pf_refresh'));

    // Verify the persisted cookie actually authenticates against live backend /api/auth/me.
    final authService = AuthService();
    final me = await authService.getMe();
    // ignore: avoid_print
    print('[TASK16_STEP2] getMeAfterRestartEmail=${me.email}');
    expect(me.email.toLowerCase(), testEmail.toLowerCase());

    // 2. Log out and confirm secure entries and cookies are removed.
    await authService.logout();
    await tester.pump(const Duration(milliseconds: 500));

    expect(PreferencesService.getAuthUser(), isNull);
    expect(PreferencesService.getRememberDeviceToken(), isNull);

    final cookiesAfterLogout = await ApiClient.cookieJar.loadForRequest(uri);
    // ignore: avoid_print
    print('[TASK16_STEP2] cookieCountAfterLogout=${cookiesAfterLogout.length}');
    expect(cookiesAfterLogout, isEmpty);

    final secureAuthAfter = await SecureStorageService.store.read(SecureStorageService.keyAuthUser);
    final secureDeviceAfter = await SecureStorageService.store.read(SecureStorageService.keyRememberDeviceToken);
    final secureCookieIndexAfter = await SecureStorageService.store.read('pf_cookie_v1___keys');
    // ignore: avoid_print
    print(
      '[TASK16_STEP2] afterLogout: authUserNull=${secureAuthAfter == null}, '
      'deviceTokenNull=${secureDeviceAfter == null}, cookieIndexNull=${secureCookieIndexAfter == null}',
    );
    expect(secureAuthAfter, isNull);
    expect(secureDeviceAfter, isNull);
    expect(secureCookieIndexAfter, isNull);

    final appSupportDir = await getApplicationSupportDirectory();
    final legacyCookieDir = Directory('${appSupportDir.path}${Platform.pathSeparator}.cookies');
    expect(await legacyCookieDir.exists(), isFalse);
  });
}
