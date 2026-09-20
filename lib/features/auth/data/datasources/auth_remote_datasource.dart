import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthRemoteDatasource {
  const AuthRemoteDatasource(this._client);

  final ApiClient _client;

  Future<({String token, UserModel user})> login({
    required String email,
    required String password,
  }) async {
    final body = await _client.post(
      '/api/identity/auth/login',
      body: {'email': email, 'password': password},
    );
    return (
      token: body['token'] as String,
      user: UserModel.fromJson(
        body['user'] as Map<String, dynamic>,
        menus: body['menu_permissions'],
      ),
    );
  }

  Future<UserModel> me() async {
    final body = await _client.get('/api/identity/auth/me');
    return UserModel.fromJson(body);
  }
}
