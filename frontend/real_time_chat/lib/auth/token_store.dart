abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveAccessToken(String token);
  Future<void> clear();
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
