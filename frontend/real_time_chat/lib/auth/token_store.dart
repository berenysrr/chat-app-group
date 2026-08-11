import '../services/token_storage.dart';

abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveAccessToken(String token);
  Future<void> clear();
}

/// Auth ekranlarının kullandığı güvenli depolamayı chat modülüne bağlar.
/// Böylece girişten sonra chat için ikinci bir token kaydı gerekmez.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({TokenStorage? storage}) : _storage = storage ?? TokenStorage();

  final TokenStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.getAccessToken();

  @override
  Future<String?> readRefreshToken() => _storage.getRefreshToken();

  @override
  Future<void> saveAccessToken(String token) => _storage.saveAccessToken(token);

  @override
  Future<void> clear() => _storage.clearTokens();
}

class MemoryTokenStore implements TokenStore {
  factory MemoryTokenStore({String? accessToken, String? refreshToken}) =>
      MemoryTokenStore._(accessToken, refreshToken);

  MemoryTokenStore._(this._accessToken, this._refreshToken);

  String? _accessToken;
  String? _refreshToken;

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> saveAccessToken(String token) async => _accessToken = token;

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}
