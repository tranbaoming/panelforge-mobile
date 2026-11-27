import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/screens/profile/settings_page.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, dynamic> Function(RequestOptions options) responder;

  _RecordingAdapter(this.responder);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = responder(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeTwoFactorAuthService extends AuthService {
  bool twoFactorEnabled;
  String? lastConfirmCode;
  String? lastDisableCode;
  String? lastDisablePassword;

  _FakeTwoFactorAuthService({required this.twoFactorEnabled});

  @override
  Future<TwoFactorSetupModel> enableTwoFactor() async {
    return const TwoFactorSetupModel(
      sharedKey: 'JBSWY3DPEHPK3PXP',
      authenticatorUri: 'otpauth://totp/PanelForge:reader@example.com?secret=JBSWY3DPEHPK3PXP&issuer=PanelForge',
      formattedKey: 'JBSW Y3DP EHPK 3PXP',
    );
  }

  @override
  Future<AuthResponseModel> confirmTwoFactorSetup(String code) async {
    lastConfirmCode = code;
    twoFactorEnabled = true;
    return AuthResponseModel(
      user: AuthUser(
        id: 'u-2fa',
        email: 'reader@example.com',
        fullName: 'Reader',
        isActive: true,
        twoFactorEnabled: true,
      ),
      message: 'Đã bật xác thực 2 bước thành công.',
    );
  }

  @override
  Future<String> disableTwoFactor(String code, String currentPassword) async {
    lastDisableCode = code;
    lastDisablePassword = currentPassword;
    twoFactorEnabled = false;
    return 'Đã tắt xác thực 2 bước.';
  }

  @override
  Future<AuthUser> getMe() async {
    return AuthUser(
      id: 'u-2fa',
      email: 'reader@example.com',
      fullName: 'Reader',
      isActive: true,
      twoFactorEnabled: twoFactorEnabled,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  group('TwoFactorSetupModel & AuthService 2FA unit tests', () {
    test('TwoFactorSetupModel.fromJson parses all fields and defaults safely', () {
      final model = TwoFactorSetupModel.fromJson({
        'sharedKey': 'SECRETKEY123',
        'authenticatorUri': 'otpauth://totp/PanelForge:a@b.com?secret=SECRETKEY123',
        'formattedKey': 'SECR ETKE Y123',
      });
      expect(model.sharedKey, 'SECRETKEY123');
      expect(model.authenticatorUri, 'otpauth://totp/PanelForge:a@b.com?secret=SECRETKEY123');
      expect(model.formattedKey, 'SECR ETKE Y123');

      final empty = TwoFactorSetupModel.fromJson({});
      expect(empty.sharedKey, '');
      expect(empty.authenticatorUri, '');
      expect(empty.formattedKey, '');
    });

    test('enableTwoFactor posts {} to /api/auth/enable-2fa and parses response', () async {
      final adapter = _RecordingAdapter((_) => {
            'sharedKey': 'ABCDEF123456',
            'authenticatorUri': 'otpauth://totp/PanelForge:u@e.com?secret=ABCDEF123456',
            'formattedKey': 'ABCD EF12 3456',
          });
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5044'))..httpClientAdapter = adapter;
      final service = AuthService(client: ApiClient(customDio: dio));

      final setup = await service.enableTwoFactor();

      expect(adapter.requests.single.path, '/api/auth/enable-2fa');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data, <String, dynamic>{});
      expect(setup.sharedKey, 'ABCDEF123456');
      expect(setup.formattedKey, 'ABCD EF12 3456');
    });

    test('confirmTwoFactorSetup sends code without email and rememberDevice=false, does not overwrite session',
        () async {
      await PreferencesService.setRememberDeviceToken('keep-existing-token');
      bool stateCallbackCalled = false;
      AuthService.onAuthStateChanged = (_) => stateCallbackCalled = true;
      addTearDown(() => AuthService.onAuthStateChanged = null);

      final adapter = _RecordingAdapter((_) => {
            'user': {
              'id': 'u-1',
              'email': 'reader@example.com',
              'fullName': 'Reader',
              'isActive': true,
              'twoFactorEnabled': true,
            },
            'message': 'Đã bật 2FA.',
          });
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5044'))..httpClientAdapter = adapter;
      final service = AuthService(client: ApiClient(customDio: dio));

      final res = await service.confirmTwoFactorSetup(' 123456 ');

      expect(adapter.requests.single.path, '/api/auth/verify-2fa');
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['code'], '123456');
      expect(body['rememberDevice'], false);
      expect(body.containsKey('email'), false);
      expect(res.user?.twoFactorEnabled, true);
      expect(res.message, 'Đã bật 2FA.');
      expect(stateCallbackCalled, false);
      expect(PreferencesService.getRememberDeviceToken(), 'keep-existing-token');
    });

    test('disableTwoFactor posts code & currentPassword and clears local rememberDeviceToken', () async {
      await PreferencesService.setRememberDeviceToken('old-remember-token');

      final adapter = _RecordingAdapter((_) => {
            'message': 'Đã tắt xác thực 2 bước thành công.',
          });
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:5044'))..httpClientAdapter = adapter;
      final service = AuthService(client: ApiClient(customDio: dio));

      final msg = await service.disableTwoFactor(' 654321 ', '');

      expect(adapter.requests.single.path, '/api/auth/disable-2fa');
      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect(body['code'], '654321');
      expect(body['currentPassword'], '');
      expect(msg, 'Đã tắt xác thực 2 bước thành công.');
      expect(PreferencesService.getRememberDeviceToken(), isNull);
    });
  });

  group('SettingsPage Security & 2FA widget tests', () {
    Future<void> pumpSettings(
      WidgetTester tester, {
      required bool twoFactorEnabled,
      _FakeTwoFactorAuthService? fakeAuth,
    }) async {
      await PreferencesService.saveAuthUser(
        AuthUser(
          id: 'u-2fa',
          email: 'reader@example.com',
          fullName: 'Reader',
          isActive: true,
          twoFactorEnabled: twoFactorEnabled,
        ).toJson(),
      );

      final service = fakeAuth ?? _FakeTwoFactorAuthService(twoFactorEnabled: twoFactorEnabled);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows CHƯA BẬT badge and setup button when 2FA is disabled', (WidgetTester tester) async {
      await pumpSettings(tester, twoFactorEnabled: false);

      expect(find.text('Bảo mật & phiên đăng nhập'), findsOneWidget);
      expect(find.text('Xác Thực 2 Bước (2FA)'), findsOneWidget);
      expect(
        find.text('Bảo vệ tài khoản bằng mã TOTP RFC 6238 từ ứng dụng Authenticator.'),
        findsOneWidget,
      );
      expect(find.text('CHƯA BẬT'), findsOneWidget);
      expect(find.text('ĐÃ BẬT'), findsNothing);
      expect(find.text('Cài đặt 2FA Authenticator'), findsOneWidget);
      expect(find.text('Tắt 2FA'), findsNothing);
    });

    testWidgets('shows ĐÃ BẬT badge and disable button when 2FA is enabled', (WidgetTester tester) async {
      await pumpSettings(tester, twoFactorEnabled: true);

      expect(find.text('Bảo mật & phiên đăng nhập'), findsOneWidget);
      expect(find.text('Xác Thực 2 Bước (2FA)'), findsOneWidget);
      expect(find.text('ĐÃ BẬT'), findsOneWidget);
      expect(find.text('CHƯA BẬT'), findsNothing);
      expect(find.text('Tắt 2FA'), findsOneWidget);
      expect(find.text('Cài đặt 2FA Authenticator'), findsNothing);
    });

    testWidgets('setup flow shows QR + formattedKey and turns badge to ĐÃ BẬT on confirm', (
      WidgetTester tester,
    ) async {
      final fake = _FakeTwoFactorAuthService(twoFactorEnabled: false);
      await pumpSettings(tester, twoFactorEnabled: false, fakeAuth: fake);

      await tester.tap(find.byKey(const ValueKey('2fa-action-button')));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('2fa-setup-code')), '123456');
      final confirmBtn = find.byKey(const ValueKey('2fa-setup-confirm'));
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(fake.lastConfirmCode, '123456');
      expect(find.text('ĐÃ BẬT'), findsOneWidget);
      expect(find.text('Tắt 2FA'), findsOneWidget);
    });

    testWidgets('disable flow submits code + password and turns badge to CHƯA BẬT', (
      WidgetTester tester,
    ) async {
      final fake = _FakeTwoFactorAuthService(twoFactorEnabled: true);
      await pumpSettings(tester, twoFactorEnabled: true, fakeAuth: fake);

      await tester.tap(find.byKey(const ValueKey('2fa-action-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('2fa-disable-code')), '654321');
      await tester.enterText(find.byKey(const ValueKey('2fa-disable-password')), 'MyPass123!');
      await tester.tap(find.byKey(const ValueKey('2fa-disable-confirm')));
      await tester.pumpAndSettle();

      expect(fake.lastDisableCode, '654321');
      expect(fake.lastDisablePassword, 'MyPass123!');
      expect(find.text('CHƯA BẬT'), findsOneWidget);
      expect(find.text('Cài đặt 2FA Authenticator'), findsOneWidget);
    });
  });
}
