import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Base URL configured via --dart-define, or Vercel production by default.
const _envUrl = String.fromEnvironment('API_URL', defaultValue: '');
final String apiBaseUrl = _envUrl.isNotEmpty
    ? _envUrl
    : 'https://loyaltytoolor-xwwj.onrender.com';

/// Dio-based HTTP client singleton.
/// Call [init] once in main() before runApp().
class ApiService {
  ApiService._();

  static late Dio _dio;
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  /// Expose the Dio instance for direct use in repositories / providers.
  static Dio get dio => _dio;

  // ── Initialization ────────────────────────────────────────────────────

  /// Create and configure the shared [Dio] instance.
  static Future<void> init() async {
    _dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  // ── Interceptors ──────────────────────────────────────────────────────

  static Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  static Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Retry once on 502 (transient gateway error)
    if (err.response?.statusCode == 502) {
      final opts = err.requestOptions;
      if (opts.extra['_retried'] != true) {
        opts.extra['_retried'] = true;
        try {
          await Future.delayed(const Duration(seconds: 1));
          final response = await _dio.fetch(opts);
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }
      }
    }
    if (err.response?.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        // Retry the original request with the new token.
        final opts = err.requestOptions;
        final newToken = await getAccessToken();
        opts.headers['Authorization'] = 'Bearer $newToken';
        try {
          final response = await _dio.fetch(opts);
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }
      } else {
        await clearTokens();
      }
    }
    handler.next(err);
  }

  /// Attempt to exchange the refresh token for a new access token.
  static Future<bool> _tryRefreshToken() async {
    final refresh = await _storage.read(key: _refreshTokenKey);
    if (refresh == null) return false;

    try {
      final plainDio = Dio(BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      Response response;
      try {
        response = await plainDio.post(
          '/api/v1/auth/refresh',
          data: {'refresh_token': refresh},
        );
      } on DioException catch (e) {
        // Retry once on transient 502
        if (e.response?.statusCode == 502) {
          await Future.delayed(const Duration(seconds: 1));
          response = await plainDio.post(
            '/api/v1/auth/refresh',
            data: {'refresh_token': refresh},
          );
        } else {
          rethrow;
        }
      }

      final data = response.data as Map<String, dynamic>;
      final newAccess = data['access_token'] as String?;
      final newRefresh = data['refresh_token'] as String?;

      if (newAccess != null) {
        await setTokens(newAccess, newRefresh ?? refresh);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Auth helpers ──────────────────────────────────────────────────────

  /// POST /api/v1/auth/login and persist the returned tokens.
  static Future<Map<String, dynamic>> login(
    String phone,
    String password,
  ) async {
    final response = await _dio.post(
      '/api/v1/auth/login',
      data: {'phone': phone, 'password': password},
    );

    final data = response.data as Map<String, dynamic>;
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;

    if (access != null && refresh != null) {
      await setTokens(access, refresh);
    }

    return data;
  }

  /// Clear stored tokens (local logout).
  static Future<void> logout() async {
    await clearTokens();
  }

  /// Returns `true` when an access token exists in secure storage.
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  // ── Token storage ─────────────────────────────────────────────────────

  static Future<void> setTokens(String access, String refresh) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  /// Quick connectivity check — pings the API health endpoint.
  static Future<bool> isOnline() async {
    try {
      await _dio.get('/api/v1/health');
      return true;
    } catch (_) {
      return false;
    }
  }
}
