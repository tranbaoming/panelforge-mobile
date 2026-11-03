import 'dart:async';
import 'dart:io';
import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/auth_models.dart';
import 'api_client.dart';
import 'preferences_service.dart';

/// Service quản lý toàn bộ tính năng Xác thực và Phiên làm việc (Session & Auth)
class AuthService {
  final ApiClient _client;

  /// Hook để đồng bộ trạng thái trực tiếp tới Riverpod Notifier khi có biến động phiên
  static ValueChanged<AuthState>? onAuthStateChanged;

  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  /// 1. Đăng nhập qua Email và Mật khẩu
  /// POST /api/auth/login
  Future<AuthResponseModel> login({
    required String email,
    required String password,
    String? rememberDeviceToken,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final deviceToken =
        rememberDeviceToken ?? PreferencesService.getRememberDeviceToken();

    final data = <String, dynamic>{
      'email': normalizedEmail,
      'password': password,
      if (deviceToken != null && deviceToken.isNotEmpty)
        'rememberDeviceToken': deviceToken,
    };

    final headers = <String, dynamic>{};
    if (deviceToken != null && deviceToken.isNotEmpty) {
      headers['X-Remember-Device-Token'] = deviceToken;
    }

    final response = await _client.post(
      '/api/auth/login',
      data: data,
      options: Options(headers: headers),
    );

    final authResponse = AuthResponseModel.fromJson(response.data);

    // Trường hợp yêu cầu xác thực 2FA (cookie pf_2fa đã được CookieJar tự động lưu)
    if (authResponse.requiresTwoFactor) {
      return authResponse;
    }

    // Đăng nhập thành công hoàn toàn
    if (authResponse.rememberDeviceToken != null) {
      await PreferencesService.setRememberDeviceToken(authResponse.rememberDeviceToken);
    }

    if (authResponse.user != null) {
      await PreferencesService.saveAuthUser(authResponse.user!.toJson());
      await syncMobileSession();
    }

    return authResponse;
  }

  /// 2. Xác thực mã 2FA TOTP (6 chữ số)
  /// POST /api/auth/verify-2fa
  Future<AuthResponseModel> verifyTwoFactor({
    required String code,
    String? email,
    bool rememberDevice = true,
    String? deviceName,
  }) async {
    final cleanCode = code.trim();
    final cleanEmail = email?.trim().toLowerCase();

    final data = <String, dynamic>{
      'code': cleanCode,
      if (cleanEmail != null && cleanEmail.isNotEmpty) 'email': cleanEmail,
      'rememberDevice': rememberDevice,
      'deviceName': deviceName ?? ApiClient.deviceDisplayName,
    };

    final response = await _client.post(
      '/api/auth/verify-2fa',
      data: data,
    );

    final authResponse = AuthResponseModel.fromJson(response.data);

    if (authResponse.rememberDeviceToken != null) {
      await PreferencesService.setRememberDeviceToken(authResponse.rememberDeviceToken);
    }

    if (authResponse.user != null) {
      await PreferencesService.saveAuthUser(authResponse.user!.toJson());
      await syncMobileSession();
    }

    return authResponse;
  }

  /// 3. Đăng nhập mạng xã hội (Google OAuth qua Firebase ID Token)
  /// POST /api/auth/external-login
  Future<AuthResponseModel> externalLogin({
    required String idToken,
  }) async {
    final response = await _client.post(
      '/api/auth/external-login',
      data: {'idToken': idToken},
    );

    final authResponse = AuthResponseModel.fromJson(response.data);

    if (authResponse.requiresTwoFactor) {
      return authResponse;
    }

    if (authResponse.rememberDeviceToken != null) {
      await PreferencesService.setRememberDeviceToken(authResponse.rememberDeviceToken);
    }

    if (authResponse.user != null) {
      await PreferencesService.saveAuthUser(authResponse.user!.toJson());
      await syncMobileSession();
    }

    return authResponse;
  }

  static const String _firebaseApiKey =
      'AIzaSyBkGqAD_U1zbqAEuKOPGmoN7nnVmR172FA';
  static const String _googleClientId =
      '499981361521-gv5po2uicg5pvj6qi7o2k1o0rbtuovu0.apps.googleusercontent.com';

  /// 3b. Đăng nhập Google chính thức:
  /// - Trên Android / iOS: Dùng GoogleSignIn native SDK lấy idToken thật.
  /// - Trên Windows Desktop: Dùng WebView nội bộ tải trang xác thực Google OAuth thật.
  /// - Đổi token Google sang Firebase ID Token thật và gửi lên Backend .NET 8 /api/auth/external-login.
  /// - Tuyệt đối không sinh dữ liệu giả lập. Nếu hủy chọn tài khoản thì trả về null.
  Future<AuthResponseModel?> signInWithGoogle() async {
    if (!kIsWeb && Platform.isWindows) {
      return await _signInWithGoogleWindows();
    } else {
      return await _signInWithGoogleNative();
    }
  }

  /// Trao đổi Google Token sang Firebase ID Token chính thức thông qua Google Identity Toolkit API
  Future<String> _exchangeGoogleTokenWithFirebase({
    String? idToken,
    String? accessToken,
    String? sessionId,
  }) async {
    final dio = Dio();
    final body = <String, dynamic>{
      'requestUri': 'http://localhost',
      'postBody':
          'id_token=${idToken ?? ''}&access_token=${accessToken ?? ''}&providerId=google.com',
      'returnSecureToken': true,
      'returnIdpCredential': true,
    };
    if (sessionId != null) {
      body['sessionId'] = sessionId;
    }

    final response = await dio.post(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=$_firebaseApiKey',
      data: body,
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    if (response.data is Map<String, dynamic> &&
        response.data['idToken'] != null) {
      return response.data['idToken'] as String;
    }
    throw Exception('Không nhận được Firebase ID Token hợp lệ từ Google.');
  }

  /// Xác thực Google Native trên Android / iOS
  Future<AuthResponseModel?> _signInWithGoogleNative() async {
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile', 'openid'],
      serverClientId: _googleClientId,
    );

    final account = await googleSignIn.signIn();
    if (account == null) {
      // Người dùng hủy chọn tài khoản
      return null;
    }

    final auth = await account.authentication;
    final googleIdToken = auth.idToken;
    final googleAccessToken = auth.accessToken;

    if (googleIdToken == null && googleAccessToken == null) {
      throw Exception('Không nhận được thông tin xác thực từ tài khoản Google.');
    }

    final firebaseIdToken = await _exchangeGoogleTokenWithFirebase(
      idToken: googleIdToken,
      accessToken: googleAccessToken,
    );

    return await externalLogin(idToken: firebaseIdToken);
  }

  /// Xác thực Google chính thức trực tiếp qua WebView trên Windows Desktop
  /// Mở thẳng URL Google OAuth 2.0 (accounts.google.com), không qua bất kỳ trang localhost nào.
  Future<AuthResponseModel?> _signInWithGoogleWindows() async {
    final isAvailable = await WebviewWindow.isWebviewAvailable();
    if (!isAvailable) {
      throw Exception(
          'WebView2 Runtime chưa được cài đặt trên hệ thống Windows.');
    }

    final nonce = DateTime.now().millisecondsSinceEpoch.toString();
    final googleAuthUrl = Uri.https(
      'accounts.google.com',
      '/o/oauth2/v2/auth',
      {
        'client_id': _googleClientId,
        'redirect_uri':
            'https://panel-forge-f84db.firebaseapp.com/__/auth/handler',
        'response_type': 'id_token token',
        'scope': 'openid email profile',
        'nonce': nonce,
        'prompt': 'select_account',
      },
    ).toString();

    final supportDir = await getApplicationSupportDirectory();
    final completer = Completer<Map<String, String>?>();
    bool isHandled = false;
    Timer? pollTimer;
    Webview? webview;

    void handleUrl(String url) async {
      if (isHandled) return;
      if (url.contains('id_token=') || url.contains('access_token=')) {
        isHandled = true;
        pollTimer?.cancel();

        try {
          await webview?.close();
        } catch (_) {}

        final uri = Uri.parse(url);
        String? idToken;
        String? accessToken;

        if (uri.hasFragment) {
          final params = Uri.splitQueryString(uri.fragment);
          idToken = params['id_token'];
          accessToken = params['access_token'];
        }
        idToken ??= uri.queryParameters['id_token'];
        accessToken ??= uri.queryParameters['access_token'];

        if (idToken != null && idToken.isNotEmpty) {
          if (!completer.isCompleted) {
            completer.complete({
              'id_token': idToken,
              'access_token': accessToken ?? '',
            });
          }
        } else {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        }
      }
    }

    try {
      webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 520,
          windowHeight: 720,
          title: 'Đăng nhập với Google • PanelForge',
          brightness: Brightness.dark,
          windows: WindowsWebviewOptions(
            userDataFolder: p.join(supportDir.path, 'WebView2'),
          ),
        ),
      );

      // Bắt URL khi WebView chuyển hướng
      await webview.setOnUrlRequestCallback((url) {
        handleUrl(url);
        return true;
      });

      // Lắng nghe URL định kỳ (250ms) bằng JavaScript evaluate
      pollTimer =
          Timer.periodic(const Duration(milliseconds: 250), (timer) async {
        if (isHandled || completer.isCompleted) {
          timer.cancel();
          return;
        }
        try {
          final currentUrl =
              await webview?.evaluateJavaScript('window.location.href');
          if (currentUrl is String && currentUrl.isNotEmpty) {
            handleUrl(currentUrl);
          }
        } catch (_) {
          // Bỏ qua khi trang đang load hoặc cửa sổ đang đóng
        }
      });

      // Bắt sự kiện người dùng chủ động đóng cửa sổ WebView bằng dấu X
      webview.onClose.then((_) {
        pollTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      await webview.launch(googleAuthUrl);

      final tokens = await completer.future;
      pollTimer.cancel();

      if (tokens == null) {
        return null; // Người dùng hủy hoặc đóng cửa sổ
      }

      final googleIdToken = tokens['id_token'];
      final googleAccessToken = tokens['access_token'];

      // Đổi sang Firebase ID Token cho Backend .NET 8
      final firebaseIdToken = await _exchangeGoogleTokenWithFirebase(
        idToken: googleIdToken,
        accessToken:
            googleAccessToken?.isNotEmpty == true ? googleAccessToken : null,
      );

      // Gửi Firebase ID Token chính thức vào Backend .NET 8
      return await externalLogin(idToken: firebaseIdToken);
    } finally {
      pollTimer?.cancel();
      if (webview != null) {
        try {
          await webview.close();
        } catch (_) {}
      }
    }
  }

  /// 4. Lấy thông tin tài khoản hiện tại từ Cookie HttpOnly pf_access
  /// GET /api/auth/me
  Future<AuthUser> getMe() async {
    final response = await _client.get('/api/auth/me');
    return AuthUser.fromJson(response.data);
  }

  /// 5. Lấy ngữ cảnh phân quyền điều hướng Landing Context
  /// GET /api/auth/me/landing-context
  Future<LandingContext> getLandingContext() async {
    final response = await _client.get('/api/auth/me/landing-context');
    return LandingContext.fromJson(response.data);
  }

  /// 6. Đăng ký tài khoản mới
  /// POST /api/auth/register
  Future<AuthResponseModel> register({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    final response = await _client.post(
      '/api/auth/register',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'fullName': fullName.trim(),
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phoneNumber': phoneNumber.trim(),
      },
    );

    return AuthResponseModel.fromJson(response.data);
  }

  /// 7. Kích hoạt tài khoản qua mã PIN email
  /// POST /api/auth/verify-email
  Future<AuthResponseModel> verifyEmail({
    required String email,
    required String token,
  }) async {
    final response = await _client.post(
      '/api/auth/verify-email',
      data: {
        'email': email.trim().toLowerCase(),
        'token': token.trim(),
      },
    );

    final authResponse = AuthResponseModel.fromJson(response.data);
    if (authResponse.user != null) {
      await PreferencesService.saveAuthUser(authResponse.user!.toJson());
      await syncMobileSession();
    }

    return authResponse;
  }

  /// 8. Gửi lại mã kích hoạt email
  /// POST /api/auth/resend-verification
  Future<String> resendVerification({required String email}) async {
    final response = await _client.post(
      '/api/auth/resend-verification',
      data: {'email': email.trim().toLowerCase()},
    );

    if (response.data is Map<String, dynamic> && response.data['message'] != null) {
      return response.data['message'].toString();
    }
    return 'Mã xác thực mới đã được gửi đến email của bạn nếu tài khoản hợp lệ.';
  }

  /// 9. Quên mật khẩu - yêu cầu gửi OTP đặt lại mật khẩu
  /// POST /api/auth/forgot-password
  Future<String> forgotPassword({required String email}) async {
    final response = await _client.post(
      '/api/auth/forgot-password',
      data: {'email': email.trim().toLowerCase()},
    );

    if (response.data is Map<String, dynamic> && response.data['message'] != null) {
      return response.data['message'].toString();
    }
    return 'Nếu email tồn tại trong hệ thống, mã xác thực đặt lại mật khẩu đã được gửi đến hộp thư của bạn.';
  }

  /// 10. Đặt lại mật khẩu với OTP
  /// POST /api/auth/reset-password
  Future<String> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final response = await _client.post(
      '/api/auth/reset-password',
      data: {
        'email': email.trim().toLowerCase(),
        'token': token.trim(),
        'newPassword': newPassword,
      },
    );

    if (response.data is Map<String, dynamic> && response.data['message'] != null) {
      return response.data['message'].toString();
    }
    return 'Đặt lại mật khẩu thành công. Bạn hiện có thể đăng nhập bằng mật khẩu mới.';
  }

  /// 11. Quên thiết bị tin cậy 2FA
  /// POST /api/auth/forget-device
  Future<String> forgetDevice() async {
    final response = await _client.post('/api/auth/forget-device', data: {});
    await PreferencesService.setRememberDeviceToken(null);

    if (response.data is Map<String, dynamic> && response.data['message'] != null) {
      return response.data['message'].toString();
    }
    return 'Thiết bị này đã được xóa khỏi danh sách thiết bị tin cậy.';
  }

  /// 11b. Gửi mã OTP xác thực đổi mật khẩu qua email
  /// POST /api/auth/send-change-password-otp
  Future<String> sendChangePasswordOtp() async {
    final response = await _client.post('/api/auth/send-change-password-otp', data: {});
    if (response.data is Map<String, dynamic> && response.data['message'] != null) {
      return response.data['message'].toString();
    }
    return 'Mã xác thực OTP đã được gửi đến email của bạn.';
  }

  /// 11c. Đổi mật khẩu tài khoản
  /// POST /api/auth/change-password
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String emailOtp,
  }) async {
    final response = await _client.post(
      '/api/auth/change-password',
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'emailOtp': emailOtp.trim(),
      },
    );

    if (response.data is Map<String, dynamic> && response.data['message'] != null) {
      return response.data['message'].toString();
    }
    return 'Đổi mật khẩu thành công.';
  }

  /// 12. Đăng xuất: thu hồi refresh token trên Backend, xóa sạch cookie và dữ liệu cục bộ
  /// POST /api/auth/logout
  Future<String> logout() async {
    try {
      await _client.post('/api/auth/logout', data: {});
    } catch (e) {
      debugPrint('[AuthService] Lỗi gọi API logout (bỏ qua để tiếp tục xóa cục bộ): $e');
    }

    // Xóa sạch cookie trong bộ nhớ và file storage của CookieJar
    await ApiClient.cookieJar.deleteAll();

    // Xóa thông tin xác thực trong SharedPreferences
    await PreferencesService.clearAuthSession();

    // Chuyển người dùng về trạng thái unauthenticated để quay lại màn hình Login
    final unauthenticatedState = AuthState.unauthenticated();
    onAuthStateChanged?.call(unauthenticatedState);

    return 'Bạn đã đăng xuất khỏi PanelForge';
  }

  /// 12b. Cho phép người dùng chủ động tiếp tục ở chế độ Khách (Guest)
  void continueAsGuest() {
    onAuthStateChanged?.call(AuthState.guest());
  }

  /// 13. Đồng bộ phiên làm việc Mobile & Kiểm tra giới hạn quyền Web vs Mobile
  Future<AuthState> syncMobileSession() async {
    try {
      final user = await getMe();
      await PreferencesService.saveAuthUser(user.toJson());

      LandingContext? landing;
      try {
        landing = await getLandingContext();
      } catch (e) {
        debugPrint('[AuthService] Không thể lấy landing-context: $e');
      }

      MobileAuthRole role = MobileAuthRole.reader;
      String? notice;

      // Phân quyền cho Mobile: Nếu tài khoản là Admin/Producer/Studio member trên Web,
      // giới hạn trải nghiệm trên Mobile ở chế độ Độc giả (/catalog), kèm thông báo rõ ràng.
      if (landing != null && landing.isRestrictedWebRole) {
        role = MobileAuthRole.restrictedReader;
        final systemRole = landing.systemRole.isNotEmpty ? landing.systemRole : 'Quản trị/Sáng tác';
        notice =
            'Tài khoản của bạn có quyền $systemRole trên Web Studio (${landing.suggestedLanding}). Trên ứng dụng Mobile, bạn sẽ trải nghiệm ở chế độ Độc giả.';
        await PreferencesService.setIsRestrictedReader(true);
        await PreferencesService.setRestrictionNotice(notice);
      } else {
        await PreferencesService.setIsRestrictedReader(false);
        await PreferencesService.setRestrictionNotice(null);
      }

      final newState = AuthState(
        role: role,
        user: user,
        landingContext: landing,
        restrictionNotice: notice,
      );

      onAuthStateChanged?.call(newState);
      return newState;
    } catch (e) {
      debugPrint('[AuthService] syncMobileSession thất bại: $e');
      // Không thể xác thực người dùng -> chuyển về unauthenticated
      await handleSessionExpired();
      return AuthState.unauthenticated();
    }
  }

  /// Xử lý dọn dẹp khi phiên bị hết hạn (từ Silent Refresh hoặc AccessTokenGuard)
  static Future<void> handleSessionExpired() async {
    try {
      await ApiClient.cookieJar.deleteAll();
    } catch (_) {}
    await PreferencesService.clearAuthSession();
    onAuthStateChanged?.call(AuthState.unauthenticated());
  }
}

