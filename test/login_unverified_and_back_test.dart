import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:panelforge/navigation/back_navigation.dart';
import 'package:panelforge/providers/api_providers.dart';
import 'package:panelforge/screens/auth/login_page.dart';
import 'package:panelforge/services/api_client.dart';
import 'package:panelforge/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Email đã có tài khoản nhưng chưa xác thực: backend trả 401 "Tài khoản chưa được kích hoạt...".
class _UnverifiedAuthService extends AuthService {
  int resendCalls = 0;

  @override
  Future<bool> checkEmail(String email) async => true;

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
    String? rememberDeviceToken,
  }) async {
    throw ApiException(
      'Tài khoản chưa được kích hoạt. Vui lòng kiểm tra email và nhập mã PIN để xác thực.',
      statusCode: 401,
    );
  }

  @override
  Future<String> resendVerification({required String email}) async {
    resendCalls++;
    return 'Đã gửi lại mã PIN.';
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.init();
  });

  test('ApiException hiển thị cho người dùng không kèm tiền tố hay mã HTTP', () {
    final e = ApiException('Sai mật khẩu.', statusCode: 401);
    expect('$e', 'Sai mật khẩu.');
  });

  testWidgets('Đăng nhập tài khoản chưa kích hoạt chuyển sang nhập PIN và gửi lại được mã', (tester) async {
    final fake = _UnverifiedAuthService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'reader@example.com');
    await tester.tap(find.text('Tiếp Theo'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'secret123');
    await tester.tap(find.text('Đăng Nhập'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nhập mã PIN xác thực'), findsOneWidget);
    expect(find.textContaining('(code:'), findsNothing);

    await tester.tap(find.text('Gửi lại mã PIN'));
    await tester.pumpAndSettle();
    expect(fake.resendCalls, 1);
    expect(find.text('Đã gửi lại mã PIN.'), findsOneWidget);
  });

  testWidgets('Nút ← trên trang mở thẳng (deep link) đi về trang dự phòng', (tester) async {
    final router = GoRouter(
      initialLocation: '/series/s1',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/series/:id',
          builder: (context, _) => Scaffold(
            body: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.popOrGo('/')),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
