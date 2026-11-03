import 'dart:async';
import 'dart:io' show Platform, Directory;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (code: $statusCode)';
}

/// Interceptor phụ trách CSRF, User-Agent, Rate Limit (429) và Silent Refresh (401)
class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;
  final CookieJar cookieJar;
  final VoidCallback onSessionExpired;

  AuthInterceptor({
    required this.dio,
    required this.cookieJar,
    required this.onSessionExpired,
  });

  /// Các endpoint không thử silent refresh khi gặp 401 (do 401 là kết quả nghiệp vụ hợp lệ)
  static final RegExp _authEndpoints = RegExp(
    r'/api/auth/(login|register|verify-email|verify-2fa|disable-2fa|external-login|forgot-password|reset-password|resend-verification|refresh|logout)',
    caseSensitive: false,
  );

  static Completer<bool>? _refreshCompleter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 1. Chống CSRF: Bắt buộc header X-Requested-With ở mọi request
    options.headers['X-Requested-With'] = 'XMLHttpRequest';

    // 2. Nhận diện thiết bị: Gửi User-Agent rõ ràng theo hệ điều hành
    options.headers['User-Agent'] = ApiClient.getUserAgent();

    // 3. Cập nhật baseUrl động nếu có cấu hình tuỳ chỉnh
    options.baseUrl = ApiConfig.baseUrl;

    if (kDebugMode) {
      debugPrint('[API REQUEST] ${options.method} ${options.uri}');
      if (options.data != null) {
        debugPrint('[API REQUEST BODY] ${options.data}');
      }
    }

    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('[API RESPONSE] ${response.statusCode} ${response.requestOptions.uri}');
    }
    return handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;

    if (kDebugMode) {
      debugPrint('[API ERROR] $status: ${err.message}');
      debugPrint('[API ERROR DATA] ${err.response?.data}');
    }

    // 1. Phòng thủ Brute-force: Bắt lỗi 429 Too Many Requests
    if (status == 429) {
      const rateLimitMsg = 'Bạn đã thao tác quá nhanh. Vui lòng đợi 1 phút rồi thử lại.';
      return handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: rateLimitMsg,
        ),
      );
    }

    // 2. Xử lý 401 Unauthorized: Tự động silent refresh
    if (status == 401) {
      final path = err.requestOptions.path;
      final uri = err.requestOptions.uri.toString();

      // Bỏ qua nếu là endpoint auth nghiệp vụ (nhập sai pass, sai mã OTP,...)
      if (_authEndpoints.hasMatch(path) || _authEndpoints.hasMatch(uri)) {
        return handler.next(err);
      }

      // Đã thử refresh cho request này rồi mà vẫn 401 -> phiên thực sự hết hạn
      if (err.requestOptions.extra['is_retry'] == true) {
        onSessionExpired();
        return handler.next(err);
      }

      // Tiến hành silent refresh
      try {
        final refreshSuccess = await _performRefresh();
        if (refreshSuccess) {
          final retryOptions = err.requestOptions;
          retryOptions.extra['is_retry'] = true;
          retryOptions.headers['X-Requested-With'] = 'XMLHttpRequest';
          retryOptions.headers['User-Agent'] = ApiClient.getUserAgent();

          final retryResponse = await dio.fetch(retryOptions);
          return handler.resolve(retryResponse);
        } else {
          onSessionExpired();
          return handler.next(err);
        }
      } catch (_) {
        onSessionExpired();
        return handler.next(err);
      }
    }

    return handler.next(err);
  }

  /// Gọi POST /api/auth/refresh (gom nhiều request đồng thời thành 1 lượt gọi duy nhất)
  Future<bool> _performRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
            'User-Agent': ApiClient.getUserAgent(),
          },
        ),
      );

      // Đính kèm cùng CookieJar để tự động gửi cookie pf_refresh và lưu lại pf_access mới
      refreshDio.interceptors.add(CookieManager(cookieJar));

      final response = await refreshDio.post(
        '/api/auth/refresh',
        data: {},
      );

      final success = response.statusCode == 200;
      completer.complete(success);
      return success;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SilentRefresh] Token refresh failed: $e');
      }
      completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
}

class ApiClient {
  late final Dio _dio;
  late final CookieJar _cookieJarInstance;

  static CookieJar? _cookieJar;
  static VoidCallback? onSessionExpiredCallback;

  /// CookieJar toàn cục được khởi tạo từ PersistCookieJar
  static CookieJar get cookieJar => _cookieJar ?? CookieJar();

  /// Khởi tạo thư mục và PersistCookieJar lưu trữ HttpOnly cookies
  static Future<CookieJar> initCookieJar() async {
    if (_cookieJar != null) return _cookieJar!;

    if (kIsWeb) {
      _cookieJar = CookieJar();
      return _cookieJar!;
    }

    try {
      final appSupportDir = await getApplicationSupportDirectory();
      final cookieDir = Directory('${appSupportDir.path}/.cookies');
      if (!await cookieDir.exists()) {
        await cookieDir.create(recursive: true);
      }
      _cookieJar = PersistCookieJar(
        storage: FileStorage(cookieDir.path),
        persistSession: true,
      );
    } catch (e) {
      debugPrint('[ApiClient] Khởi tạo PersistCookieJar thất bại: $e. Sử dụng CookieJar bộ nhớ tạm.');
      _cookieJar = CookieJar();
    }

    return _cookieJar!;
  }

  /// Trả về User-Agent chuẩn hóa nhận diện thiết bị
  static String getUserAgent() {
    String os = 'Unknown';
    try {
      if (kIsWeb) {
        os = 'Web';
      } else if (Platform.isAndroid) {
        os = 'Android';
      } else if (Platform.isIOS) {
        os = 'iOS';
      } else if (Platform.isWindows) {
        os = 'Windows';
      } else if (Platform.isMacOS) {
        os = 'macOS';
      } else if (Platform.isLinux) {
        os = 'Linux';
      }
    } catch (_) {}
    return 'PanelForge-Mobile/1.0 ($os; Flutter)';
  }

  /// Tên thiết bị hiển thị khi ghi nhớ 2FA
  static String get deviceDisplayName {
    try {
      if (kIsWeb) return 'Web Browser';
      if (Platform.isAndroid) return 'Android Phone';
      if (Platform.isIOS) return 'iPhone';
      if (Platform.isWindows) return 'Windows Device';
      if (Platform.isMacOS) return 'Mac Device';
      if (Platform.isLinux) return 'Linux Device';
    } catch (_) {}
    return 'Mobile Device';
  }

  ApiClient({Dio? customDio, CookieJar? customCookieJar}) {
    _cookieJarInstance = customCookieJar ?? cookieJar;

    if (customDio != null) {
      _dio = customDio;
    } else {
      _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
            'User-Agent': getUserAgent(),
          },
        ),
      );

      // Thêm CookieManager tự động xử lý cookie pf_access, pf_refresh, pf_2fa
      _dio.interceptors.add(CookieManager(_cookieJarInstance));

      // Thêm AuthInterceptor xử lý CSRF, 429 và Silent Refresh 401
      _dio.interceptors.add(
        AuthInterceptor(
          dio: _dio,
          cookieJar: _cookieJarInstance,
          onSessionExpired: () {
            onSessionExpiredCallback?.call();
          },
        ),
      );
    }
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(path, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ApiException _handleError(DioException e) {
    final status = e.response?.statusCode;
    final resData = e.response?.data;
    String message = 'Đã có lỗi xảy ra khi kết nối tới máy chủ.';

    if (status == 429) {
      message = 'Bạn đã thao tác quá nhanh. Vui lòng đợi 1 phút rồi thử lại.';
    } else if (resData is Map<String, dynamic>) {
      if (resData.containsKey('message') && resData['message'] is String) {
        message = resData['message'];
      } else if (resData.containsKey('error') && resData['error'] is String) {
        message = resData['error'];
      }
    } else if (e.error is String && (e.error as String).isNotEmpty) {
      message = e.error as String;
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Hết thời gian chờ kết nối tới máy chủ. Vui lòng kiểm tra lại mạng.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng hoặc thiết lập máy chủ.';
    }

    return ApiException(message, statusCode: status, data: resData);
  }
}
