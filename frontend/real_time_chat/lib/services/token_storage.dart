import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // Memory cache fallback
  String? _memAccess;
  String? _memRefresh;

  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _memAccess = access;
    _memRefresh = refresh;
    try {
      await _storage.write(key: _accessTokenKey, value: access);
      await _storage.write(key: _refreshTokenKey, value: refresh);
    } catch (_) {
      // Fallback to memory storage if platform storage fails
    }
  }

  Future<void> saveAccessToken(String access) async {
    _memAccess = access;
    try {
      await _storage.write(key: _accessTokenKey, value: access);
    } catch (_) {}
  }

  Future<String?> getAccessToken() async {
    if (_memAccess != null) return _memAccess;
    try {
      _memAccess = await _storage.read(key: _accessTokenKey);
      return _memAccess;
    } catch (_) {
      return _memAccess;
    }
  }

  Future<String?> getRefreshToken() async {
    if (_memRefresh != null) return _memRefresh;
    try {
      _memRefresh = await _storage.read(key: _refreshTokenKey);
      return _memRefresh;
    } catch (_) {
      return _memRefresh;
    }
  }

  Future<void> clearTokens() async {
    _memAccess = null;
    _memRefresh = null;
    try {
      await _storage.delete(key: _accessTokenKey);
      await _storage.delete(key: _refreshTokenKey);
    } catch (_) {}
  }

  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
