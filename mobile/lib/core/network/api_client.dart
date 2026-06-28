import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  ApiClient._();

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ))
    ..interceptors.add(_AuthInterceptor());

  static Dio get instance => _dio;
}

class _AuthInterceptor extends Interceptor {
  bool _isRefreshing = false;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await SecureStorage.getRefreshToken();
        if (refreshToken == null) {
          _isRefreshing = false;
          handler.next(err);
          return;
        }

        final response = await Dio().post(
          '${ApiConstants.baseUrl}${ApiConstants.refresh}',
          data: {'refresh_token': refreshToken},
        );

        final data = response.data['data'];
        await SecureStorage.saveTokens(data['access_token'], data['refresh_token']);

        // Retry original request
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer ${data['access_token']}';
        final retryResponse = await Dio().fetch(opts);
        _isRefreshing = false;
        handler.resolve(retryResponse);
        return;
      } catch (_) {
        await SecureStorage.clear();
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const ApiException(this.message, {this.code, this.statusCode});

  factory ApiException.fromDio(DioException e) {
    final statusCode = e.response?.statusCode;
    final body = e.response?.data;
    final message = (body is Map && body['error'] != null)
        ? body['error'] as String
        : e.message ?? 'Network error occurred';
    final code = body is Map ? body['code'] as String? : null;
    return ApiException(message, code: code, statusCode: statusCode);
  }

  @override
  String toString() => message;
}

extension DioExtension on Dio {
  Future<T> safeGet<T>(String path, {Map<String, dynamic>? params}) async {
    try {
      final res = await this.get(path, queryParameters: params);
      return res.data['data'] as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> safePost<T>(String path, {dynamic data}) async {
    try {
      final res = await this.post(path, data: data);
      return res.data['data'] as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<T> safePut<T>(String path, {dynamic data}) async {
    try {
      final res = await this.put(path, data: data);
      return res.data['data'] as T;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> safeDelete(String path) async {
    try {
      await this.delete(path);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final dio = ApiClient.instance;
