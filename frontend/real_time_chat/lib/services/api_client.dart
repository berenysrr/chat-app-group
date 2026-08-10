import 'package:dio/dio.dart';
import 'token_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  static const String baseUrl = 'http://localhost:8000';

  // Callback to notify app on unauthorized logout
  void Function()? onUnauthorized;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage().getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/api/auth/login/') &&
              !error.requestOptions.path.contains('/api/auth/register/') &&
              !error.requestOptions.path.contains('/api/auth/refresh/')) {
            final refreshed = await _refreshToken();
            if (refreshed) {
              try {
                // Retry original request with new token
                final newAccessToken = await TokenStorage().getAccessToken();
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccessToken';

                final cloneReq = await dio.request(
                  opts.path,
                  options: Options(method: opts.method, headers: opts.headers),
                  data: opts.data,
                  queryParameters: opts.queryParameters,
                );
                return handler.resolve(cloneReq);
              } catch (retryError) {
                return handler.reject(error);
              }
            } else {
              await TokenStorage().clearTokens();
              onUnauthorized?.call();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    final refresh = await TokenStorage().getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final tokenDio = Dio(BaseOptions(baseUrl: baseUrl));
      final response = await tokenDio.post(
        '/api/auth/refresh/',
        data: {'refresh': refresh},
      );

      if (response.statusCode == 200 && response.data != null) {
        final newAccess = response.data['access'];
        final newRefresh = response.data['refresh'] ?? refresh;
        if (newAccess != null) {
          await TokenStorage().saveTokens(
            access: newAccess,
            refresh: newRefresh,
          );
          return true;
        }
      }
    } catch (_) {}
    return false;
  }
}
