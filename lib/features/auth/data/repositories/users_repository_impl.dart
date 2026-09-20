import '../../../../core/error/result.dart';
import '../../../../core/json.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/users_repository.dart';

class UsersRepositoryImpl implements UsersRepository {
  const UsersRepositoryImpl(this._client);

  final ApiClient _client;

  User _from(Map<String, dynamic> j) => userFrom(j);

  @override
  Future<Result<List<User>>> list() => guardApi(() async {
        final list = await _client.getList('/api/identity/users');
        return list.map(_from).toList();
      });

  @override
  Future<Result<User>> save({required User user, String password = ''}) => guardApi(() async {
        final body = <String, dynamic>{
          'name': user.name,
          'email': user.email,
          'role_id': user.roleId,
          if (password.isNotEmpty) 'password': password,
        };
        final json = user.id.isEmpty
            ? await _client.post('/api/identity/users', body: {...body, 'password': password})
            : await _client.put('/api/identity/users/${user.id}', body: body);
        return _from(json);
      });
}

User userFrom(Map<String, dynamic> j) => User(
      id: asString(j, 'id'),
      email: asString(j, 'email'),
      name: asString(j, 'name'),
      roleId: asString(j, 'role_id'),
      roleCode: asString(j, 'role_code'),
      roleName: asString(j, 'role_name'),
    );
