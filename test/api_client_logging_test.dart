import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:panelforge/services/api_client.dart';

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
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('AuthInterceptor credential log redaction (AUD-FL-03)', () {
    late List<String> capturedLogs;
    late DebugPrintCallback originalDebugPrint;
    late Dio dio;

    setUp(() {
      capturedLogs = [];
      originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) capturedLogs.add(message);
      };

      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dio.httpClientAdapter = _OkAdapter();
      dio.interceptors.add(
        AuthInterceptor(
          dio: dio,
          cookieJar: CookieJar(),
          onSessionExpired: () {},
        ),
      );
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    test('redacts password, OTP, 2FA code, and tokens on auth requests', () async {
      await dio.post(
        '/api/auth/login',
        data: {
          'email': 'reader@panelforge.com',
          'password': 'SuperSecretPassword123!',
          'newPassword': 'NewSecretPassword456!',
          'currentPassword': 'OldSecretPassword789!',
          'code': '654321',
          'emailOtp': '998877',
          'idToken': 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.google-id-token',
          'rememberDeviceToken': 'device-secret-token-xyz',
          'nested': {
            'refreshToken': 'refresh-secret-abc',
            'twoFactorCode': '112233',
          },
        },
      );

      final allLogs = capturedLogs.join('\n');
      expect(allLogs, contains('reader@panelforge.com'));
      expect(allLogs, contains(AuthInterceptor.redactedValue));
      expect(allLogs, isNot(contains('SuperSecretPassword123!')));
      expect(allLogs, isNot(contains('NewSecretPassword456!')));
      expect(allLogs, isNot(contains('OldSecretPassword789!')));
      expect(allLogs, isNot(contains('654321')));
      expect(allLogs, isNot(contains('998877')));
      expect(allLogs, isNot(contains('google-id-token')));
      expect(allLogs, isNot(contains('device-secret-token-xyz')));
      expect(allLogs, isNot(contains('refresh-secret-abc')));
      expect(allLogs, isNot(contains('112233')));
    });

    test('redacts purchaseToken and receipt on payment requests', () async {
      await dio.post(
        '/api/wallet/google-play/verify',
        data: {
          'productId': 'pf_topup_50k',
          'purchaseToken': 'gpa-secret-purchase-token-999',
          'receipt': 'raw-receipt-payload-secret',
          'signature': 'sig-secret-value',
        },
      );

      final allLogs = capturedLogs.join('\n');
      expect(allLogs, contains('pf_topup_50k'));
      expect(allLogs, contains(AuthInterceptor.redactedValue));
      expect(allLogs, isNot(contains('gpa-secret-purchase-token-999')));
      expect(allLogs, isNot(contains('raw-receipt-payload-secret')));
      expect(allLogs, isNot(contains('sig-secret-value')));
    });

    test('redacts raw JSON string and non-JSON string on auth endpoints', () async {
      await dio.post(
        '/api/auth/verify-2fa',
        data: jsonEncode({'email': 'a@b.com', 'code': '777888'}),
      );
      await dio.post(
        '/api/auth/reset-password',
        data: 'raw-secret-string-token',
      );

      final allLogs = capturedLogs.join('\n');
      expect(allLogs, isNot(contains('777888')));
      expect(allLogs, isNot(contains('raw-secret-string-token')));
    });
  });
}
