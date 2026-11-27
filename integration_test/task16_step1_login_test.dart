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
  const testPassword = String.fromEnvironment('TEST_PASSWORD');

  testWidgets('TASK-16 Step 1: Login on Windows stores credentials in secure storage', (tester) async {
    expect(testPassword, isNotEmpty, reason: 'Pass --dart-define=TEST_PASSWORD=...');

    await PreferencesService.init();
    await ApiClient.initCookieJar();

    await tester.pumpWidget(const ProviderScope(child: PanelForgeApp()));
    await tester.pump(const Duration(milliseconds: 500));

    final appSupportDir = await getApplicationSupportDirectory();
    final legacyCookieDir = Directory('${appSupportDir.path}${Platform.pathSeparator}.cookies');
    // ignore: avoid_print
    print('[TASK16_STEP1] appSupportDir=${appSupportDir.path}');
    // ignore: avoid_print
    print('[TASK16_STEP1] legacyCookieDirExists=${await legacyCookieDir.exists()}');
    expect(await legacyCookieDir.exists(), isFalse, reason: 'Legacy .cookies dir must be removed on init');

    // Confirm we are using the real FlutterSecureKeyValueStore, not InMemorySecureStore fallback.
    expect(
      SecureStorageService.store,
      isA<FlutterSecureKeyValueStore>(),
      reason: 'Windows must use FlutterSecureKeyValueStore (flutter_secure_storage_windows)',
    );

    final authService = AuthService();
    final resp = await authService.login(email: testEmail, password: testPassword);
    await tester.pump(const Duration(milliseconds: 500));

    expect(resp.requiresTwoFactor, isFalse);
    expect(resp.user?.email.toLowerCase(), testEmail.toLowerCase());

    final cachedUser = PreferencesService.getAuthUser();
    expect(cachedUser, isNotNull);
    expect(cachedUser!['email']?.toString().toLowerCase(), testEmail.toLowerCase());

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/me');
    final cookies = await ApiClient.cookieJar.loadForRequest(uri);
    final cookieNames = cookies.map((c) => c.name).toList()..sort();
    // ignore: avoid_print
    print('[TASK16_STEP1] savedCookieNames=$cookieNames');
    expect(cookieNames, contains('pf_access'));
    expect(cookieNames, contains('pf_refresh'));

    // Confirm secure storage has auth user entry persisted.
    final rawAuthInSecure = await SecureStorageService.store.read(SecureStorageService.keyAuthUser);
    expect(rawAuthInSecure, isNotNull);
    expect(rawAuthInSecure, isNotEmpty);
    // ignore: avoid_print
    print('[TASK16_STEP1] secureAuthUserPresent=true');
    // ignore: avoid_print
    print('[TASK16_STEP1] legacyCookieDirExistsAfterLogin=${await legacyCookieDir.exists()}');
    expect(await legacyCookieDir.exists(), isFalse);
  });
}
