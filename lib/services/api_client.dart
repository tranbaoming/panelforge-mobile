import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: $message (code: $statusCode)';
}

class ApiClient {
  late final Dio _dio;

  ApiClient({Dio? customDio}) {
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
          },
        ),
      );

      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            // Cập nhật baseUrl động nếu có thay đổi
            options.baseUrl = ApiConfig.baseUrl;
            if (kDebugMode) {
              debugPrint('[API REQUEST] ${options.method} ${options.uri}');
              if (options.data != null) {
                debugPrint('[API REQUEST BODY] ${options.data}');
              }
            }
            return handler.next(options);
          },
          onResponse: (response, handler) {
            if (kDebugMode) {
              debugPrint('[API RESPONSE] ${response.statusCode} ${response.requestOptions.uri}');
            }
            return handler.next(response);
          },
          onError: (DioException e, handler) {
            if (kDebugMode) {
              debugPrint('[API ERROR] ${e.response?.statusCode}: ${e.message}');
              debugPrint('[API ERROR DATA] ${e.response?.data}');
            }
            return handler.next(e);
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

  ApiException _handleError(DioException e) {
    final status = e.response?.statusCode;
    final resData = e.response?.data;
    String message = 'Đã có lỗi xảy ra khi kết nối tới máy chủ.';

    if (resData is Map<String, dynamic>) {
      if (resData.containsKey('error') && resData['error'] is String) {
        message = resData['error'];
      } else if (resData.containsKey('message') && resData['message'] is String) {
        message = resData['message'];
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Hết thời gian chờ kết nối tới máy chủ. Vui lòng kiểm tra lại mạng.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Không thể kết nối đến máy chủ (${ApiConfig.baseUrl}). Hãy chắc chắn backend đang chạy.';
    }

    return ApiException(message, statusCode: status, data: resData);
  }
}

