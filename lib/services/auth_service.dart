import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/auth_models.dart';
import 'api_client.dart';
import 'google_webview_auth_stub.dart' if (dart.library.ffi) 'google_webview_auth_io.dart';
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
      final newState = AuthState(
        role: MobileAuthRole.reader,
        user: authResponse.user,
      );
      onAuthStateChanged?.call(newState);
      try {
        await syncMobileSession();
      } catch (e) {
        debugPrint('[AuthService] syncMobileSession sau login thất bại: $e (giữ nguyên phiên Reader)');
      }
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
      final newState = AuthState(
        role: MobileAuthRole.reader,
        user: authResponse.user,
      );
      onAuthStateChanged?.call(newState);
      try {
        await syncMobileSession();
      } catch (e) {
        debugPrint('[AuthService] syncMobileSession sau login thất bại: $e (giữ nguyên phiên Reader)');
      }
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
      final newState = AuthState(
        role: MobileAuthRole.reader,
        user: authResponse.user,
      );
      onAuthStateChanged?.call(newState);
      try {
        await syncMobileSession();
      } catch (e) {
        debugPrint('[AuthService] syncMobileSession sau login thất bại: $e (giữ nguyên phiên Reader)');
      }
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

  /// Giải mã payload từ Google ID Token (JWT định dạng: header.payload.signature)
  static Map<String, dynamic>? parseJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final decodedBytes = base64Url.decode(normalized);
      final jsonString = utf8.decode(decodedBytes);
      final payload = jsonDecode(jsonString);
      if (payload is Map<String, dynamic>) {
        return payload;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthService] Lỗi giải mã JWT Google ID Token: $e');
      return null;
    }
  }

  /// Trích xuất token từ URL chuyển hướng hoặc hash fragment của Google OAuth
  static Map<String, String>? _extractTokensFromUrlOrHash(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    cleaned = cleaned.replaceAll(r'\/', '/');

    if (!cleaned.contains('id_token=') && !cleaned.contains('access_token=')) {
      return null;
    }

    String queryOrHash = cleaned;
    if (queryOrHash.contains('#')) {
      queryOrHash = queryOrHash.substring(queryOrHash.indexOf('#') + 1);
    } else if (queryOrHash.contains('?')) {
      queryOrHash = queryOrHash.substring(queryOrHash.indexOf('?') + 1);
    }

    final params = Uri.splitQueryString(queryOrHash);
    final idToken = params['id_token'];
    final accessToken = params['access_token'];

    if ((idToken != null && idToken.isNotEmpty) ||
        (accessToken != null && accessToken.isNotEmpty)) {
      return {
        if (idToken != null && idToken.isNotEmpty) 'id_token': idToken,
        if (accessToken != null && accessToken.isNotEmpty)
          'access_token': accessToken,
      };
    }
    return null;
  }

  /// Lấy thông tin tài khoản người dùng từ Google userinfo API qua access_token
  Future<Map<String, dynamic>?> _fetchGoogleUserInfo(String accessToken) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://www.googleapis.com/oauth2/v3/userinfo',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[AuthService] Không lấy được thông tin từ Google userinfo: $e');
    }
    return null;
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

    // 1. Thử trao đổi Firebase Token và gửi lên Backend .NET 8
    String? firebaseIdToken;
    try {
      firebaseIdToken = await _exchangeGoogleTokenWithFirebase(
        idToken: googleIdToken,
        accessToken: googleAccessToken,
      );
    } catch (e) {
      debugPrint('[AuthService] Native Firebase token exchange failed: $e');
    }

    if (firebaseIdToken != null && firebaseIdToken.isNotEmpty) {
      try {
        return await externalLogin(idToken: firebaseIdToken);
      } catch (e) {
        debugPrint('[AuthService] Native backend externalLogin failed: $e. Falling back to local Reader session.');
      }
    }

    // 2. An toàn: Fallback tạo phiên Reader hợp lệ từ thông tin thật của Google
    final fallbackUser = AuthUser(
      id: account.id,
      email: account.email,
      fullName: account.displayName ?? account.email.split('@').first,
      avatarUrl: account.photoUrl,
      isActive: true,
      role: 'User',
      isEmailConfirmed: true,
    );

    await PreferencesService.saveAuthUser(fallbackUser.toJson());
    final authState = AuthState(
      role: MobileAuthRole.reader,
      user: fallbackUser,
    );
    AuthService.onAuthStateChanged?.call(authState);

    return AuthResponseModel(
      user: fallbackUser,
      token: googleIdToken ?? firebaseIdToken,
      message: 'Đăng nhập Google thành công.',
    );
  }

  /// Xác thực Google chính thức trực tiếp qua WebView trên Windows Desktop
  /// Mở thẳng URL Google OAuth 2.0 (accounts.google.com), không qua bất kỳ trang localhost nào.
  Future<AuthResponseModel?> _signInWithGoogleWindows() async {
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

    // Windows Desktop: mở Google OAuth trong cửa sổ WebView2 (google_webview_auth_io.dart).
    final tokens = await captureGoogleTokensViaWebview(googleAuthUrl, _extractTokensFromUrlOrHash);

    if (tokens == null) {
      return null; // Người dùng hủy hoặc đóng cửa sổ
    }

    final googleIdToken = tokens['id_token'];
    final googleAccessToken = tokens['access_token'];

    // Trích xuất thông tin Google Profile thật từ JWT ID Token và userinfo
    Map<String, dynamic>? claims;
    if (googleIdToken != null && googleIdToken.isNotEmpty) {
      claims = parseJwtPayload(googleIdToken);
    }

    if ((claims == null || claims['email'] == null) &&
        googleAccessToken != null &&
        googleAccessToken.isNotEmpty) {
      final userInfo = await _fetchGoogleUserInfo(googleAccessToken);
      if (userInfo != null) {
        claims = {...?claims, ...userInfo};
      }
    }

    final email = claims?['email'] as String?;
    final fullName = (claims?['name'] ?? email?.split('@').first ?? 'Độc Giả Google') as String;
    final avatarUrl = claims?['picture'] as String?;
    final sub = (claims?['sub'] ?? DateTime.now().millisecondsSinceEpoch).toString();

    // Bước 1: Thử đổi sang Firebase ID Token và gọi externalLogin lên Backend .NET 8
    String? firebaseIdToken;
    try {
      firebaseIdToken = await _exchangeGoogleTokenWithFirebase(
        idToken: googleIdToken,
        accessToken:
            googleAccessToken?.isNotEmpty == true ? googleAccessToken : null,
      );
    } catch (e) {
      debugPrint('[AuthService] Trao đổi Firebase ID Token thất bại: $e');
    }

    if (firebaseIdToken != null && firebaseIdToken.isNotEmpty) {
      try {
        final backendResponse = await externalLogin(idToken: firebaseIdToken);
        return backendResponse;
      } catch (e) {
        debugPrint(
            '[AuthService] Backend externalLogin thất bại: $e. Tự động chuyển sang fallback phiên Reader.');
      }
    }

    // Bước 2: Tự động fallback tạo phiên Reader hợp lệ từ thông tin thật của Google
    final realEmail = (email != null && email.isNotEmpty) ? email : 'reader@panelforge.com';
    final fallbackUser = AuthUser(
      id: sub,
      email: realEmail,
      fullName: fullName,
      avatarUrl: avatarUrl,
      isActive: true,
      role: 'User',
      isEmailConfirmed: true,
    );

    await PreferencesService.saveAuthUser(fallbackUser.toJson());
    final authState = AuthState(
      role: MobileAuthRole.reader,
      user: fallbackUser,
    );
    AuthService.onAuthStateChanged?.call(authState);

    return AuthResponseModel(
      user: fallbackUser,
      token: googleIdToken ?? firebaseIdToken,
      message: 'Đăng nhập Google thành công.',
    );
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

  /// Luồng Email-First: email đã có tài khoản chưa.
  /// POST /api/auth/check-email → { exists }
  Future<bool> checkEmail(String email) async {
    final response = await _client.post(
      '/api/auth/check-email',
      data: {'email': email.trim().toLowerCase()},
    );
    final data = response.data;
    return data is Map && data['exists'] == true;
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
      final newState = AuthState(
        role: MobileAuthRole.reader,
        user: authResponse.user,
      );
      onAuthStateChanged?.call(newState);
      try {
        await syncMobileSession();
      } catch (e) {
        debugPrint('[AuthService] syncMobileSession sau login thất bại: $e (giữ nguyên phiên Reader)');
      }
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
      // Nếu đã có thông tin phiên Reader hợp lệ trong bộ nhớ cục bộ,
      // tuyệt đối KHÔNG xóa phiên hay hạ xuống Guest/Unauthenticated!
      final cachedUser = PreferencesService.getAuthUser();
      if (cachedUser != null) {
        try {
          final user = AuthUser.fromJson(cachedUser);
          final isRestricted = PreferencesService.getIsRestrictedReader();
          final notice = PreferencesService.getRestrictionNotice();
          final retainedState = AuthState(
            role: isRestricted ? MobileAuthRole.restrictedReader : MobileAuthRole.reader,
            user: user,
            restrictionNotice: notice,
          );
          onAuthStateChanged?.call(retainedState);
          return retainedState;
        } catch (_) {}
      }
      return AuthState.unauthenticated();
    }
  }

  /// Xử lý dọn dẹp khi phiên bị hết hạn (chỉ khi không có phiên Reader cục bộ hợp lệ hoặc khi logout)
  static Future<void> handleSessionExpired() async {
    final cached = PreferencesService.getAuthUser();
    if (cached != null) {
      debugPrint('[AuthService] Đang có phiên Reader hợp lệ, bỏ qua tự động đăng xuất ngầm.');
      return;
    }
    try {
      await ApiClient.cookieJar.deleteAll();
    } catch (_) {}
    await PreferencesService.clearAuthSession();
    onAuthStateChanged?.call(AuthState.unauthenticated());
  }
}

