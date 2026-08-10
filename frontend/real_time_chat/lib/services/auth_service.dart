import 'package:dio/dio.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  Future<UserModel?> login(String username, String password) async {
    try {
      final response = await _client.dio.post(
        '/api/auth/login/',
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200 && response.data != null) {
        final access = response.data['access'];
        final refresh = response.data['refresh'];
        if (access != null && refresh != null) {
          await TokenStorage().saveTokens(access: access, refresh: refresh);
          final user = response.data['user'];
          return user is Map<String, dynamic> ? UserModel.fromJson(user) : null;
        }
      }
    } on DioException catch (e) {
      final msg =
          e.response?.data?['detail'] ?? 'Login failed. Check credentials.';
      throw Exception(msg);
    }
    return null;
  }

  Future<UserModel?> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      final response = await _client.dio.post(
        '/api/auth/register/',
        data: {'username': username, 'email': email, 'password': password},
      );

      if (response.statusCode == 201 && response.data != null) {
        final access = response.data['access'];
        final refresh = response.data['refresh'];
        if (access != null && refresh != null) {
          await TokenStorage().saveTokens(access: access, refresh: refresh);
        }
        if (response.data['user'] != null) {
          return UserModel.fromJson(response.data['user']);
        }
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String errorMsg = 'Registration failed.';
      if (data is Map) {
        final messages = data.values
            .expand((v) => v is List ? v : [v])
            .join(' ');
        if (messages.isNotEmpty) errorMsg = messages;
      }
      throw Exception(errorMsg);
    }
    return null;
  }

  Future<void> logout() async {
    try {
      final refresh = await TokenStorage().getRefreshToken();
      if (refresh != null) {
        await _client.dio.post('/api/auth/logout/', data: {'refresh': refresh});
      }
    } catch (_) {}
    await TokenStorage().clearTokens();
  }

  Future<UserModel?> getProfile() async {
    try {
      final response = await _client.dio.get('/api/users/me/');
      if (response.statusCode == 200 && response.data != null) {
        return UserModel.fromJson(response.data);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<UserModel?> updateProfile({String? username, String? email}) async {
    try {
      final data = <String, dynamic>{};
      if (username != null && username.isNotEmpty) data['username'] = username;
      if (email != null && email.isNotEmpty) data['email'] = email;

      final response = await _client.dio.patch('/api/users/me/', data: data);
      if (response.statusCode == 200 && response.data != null) {
        return UserModel.fromJson(response.data);
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String errorMsg = 'Update failed.';
      if (data is Map) {
        final messages = data.values
            .expand((v) => v is List ? v : [v])
            .join(' ');
        if (messages.isNotEmpty) errorMsg = messages;
      }
      throw Exception(errorMsg);
    }
    return null;
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _client.dio.get(
        '/api/users/',
        queryParameters: {'search': query},
      );
      final results = response.data is Map ? response.data['results'] : null;
      if (response.statusCode == 200 && results is List) {
        return results.map((json) => UserModel.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }
}
