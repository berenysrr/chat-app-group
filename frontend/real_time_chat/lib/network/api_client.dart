import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/token_store.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.body});
  final int statusCode;
  final String message;
  final Object? body;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

class AuthenticatedApiClient {
  AuthenticatedApiClient({
    required String baseUrl,
    required this.tokens,
    http.Client? client,
    this.onSessionExpired,
  }) : baseUri = _normalizeBaseUrl(baseUrl),
       _client = client ?? http.Client();

  final Uri baseUri;
  final TokenStore tokens;
  final http.Client _client;
  final FutureOr<void> Function()? onSessionExpired;
  Future<bool>? _refreshInFlight;

  static Uri _normalizeBaseUrl(String value) {
    final uri = Uri.parse(value.trim());
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError.value(value, 'baseUrl', 'HTTP(S) URL gerekli');
    }
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: path);
  }

  Uri resolve(String path, [Map<String, String?> query = const {}]) {
    final clean = path.replaceFirst(RegExp(r'^/+'), '');
    final uri = baseUri.resolve(clean);
    final values = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    return values.isEmpty ? uri : uri.replace(queryParameters: values);
  }

  Future<Object?> get(String path, {Map<String, String?> query = const {}}) =>
      _request('GET', path, query: query);

  Future<Object?> post(String path, {Object? body}) =>
      _request('POST', path, body: body);

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String?> query = const {},
    Object? body,
    bool retried = false,
  }) async {
    final access = await tokens.readAccessToken();
    if (access == null || access.isEmpty) {
      throw const ApiException(401, 'Oturum gerekli.');
    }
    final response = await _client.send(
      http.Request(method, resolve(path, query))
        ..headers.addAll({
          'Authorization': 'Bearer $access',
          'Accept': 'application/json',
          if (body != null) 'Content-Type': 'application/json',
        })
        ..body = body == null ? '' : jsonEncode(body),
    );
    final materialized = await http.Response.fromStream(response);
    if (materialized.statusCode == 401 && !retried) {
      if (await _refresh()) {
        return _request(method, path, query: query, body: body, retried: true);
      }
    }
    final decoded = _decode(materialized.body);
    if (materialized.statusCode < 200 || materialized.statusCode >= 300) {
      throw ApiException(
        materialized.statusCode,
        _errorMessage(decoded, materialized.statusCode),
        body: decoded,
      );
    }
    return decoded;
  }

  Future<bool> _refresh() {
    final running = _refreshInFlight;
    if (running != null) return running;
    final operation = _performRefresh();
    _refreshInFlight = operation;
    return operation.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> refreshAccessToken() => _refresh();

  Future<bool> _performRefresh() async {
    final refresh = await tokens.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return _expireSession();
    try {
      final response = await _client.post(
        resolve('auth/refresh/'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );
      final decoded = _decode(response.body);
      if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
        return _expireSession();
      }
      final access = decoded['access'];
      if (access is! String || access.isEmpty) return _expireSession();
      await tokens.saveAccessToken(access);
      return true;
    } catch (_) {
      return _expireSession();
    }
  }

  Future<bool> _expireSession() async {
    await tokens.clear();
    await onSessionExpired?.call();
    return false;
  }

  static Object? _decode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _errorMessage(Object? body, int code) {
    if (body is Map<String, dynamic>) {
      final value = body['message'] ?? body['detail'];
      if (value is String && value.isNotEmpty) return value;
      final fields = body.entries
          .where((entry) => entry.value is String || entry.value is List)
          .map((entry) {
            final value = entry.value is List
                ? (entry.value as List).join(' ')
                : entry.value.toString();
            return '${entry.key}: $value';
          })
          .where((value) => value.isNotEmpty)
          .join('\n');
      if (fields.isNotEmpty) return fields;
    }
    return 'İstek başarısız oldu ($code).';
  }

  void close() => _client.close();
}
