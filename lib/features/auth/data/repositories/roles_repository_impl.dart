import '../../../../core/error/result.dart';
import '../../../../core/json.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_guard.dart';
import '../../domain/entities/role.dart';
import '../../domain/repositories/roles_repository.dart';

class RolesRepositoryImpl implements RolesRepository {
  const RolesRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<Role>>> list() => guardApi(() async {
        final list = await _client.getList('/api/identity/roles');
        return list.map(_role).toList();
      });

  @override
  Future<Result<Role>> save(Role role) => guardApi(() async {
        final json = role.id.isEmpty
            ? await _client.post(
                '/api/identity/roles',
                body: {'code': role.code, 'name': role.name},
              )
            : await _client.put(
                '/api/identity/roles/${role.id}',
                body: {'name': role.name},
              );
        return _role(json);
      });

  @override
  Future<Result<void>> delete(String id) =>
      guardApi(() => _client.delete('/api/identity/roles/$id'));

  @override
  Future<Result<RolePermissions>> permissions(String id) => guardApi(() async {
        final body = await _client.get('/api/identity/roles/$id/permissions');
        return RolePermissions(
          modules: _levels(body['modules'], 'module'),
          menus: _levels(body['menus'], 'menu_key'),
        );
      });

  @override
  Future<Result<void>> setPermissions(String id, RolePermissions permissions) =>
      guardApi(() async {
        await _client.put('/api/identity/roles/$id/permissions', body: {
          'modules': _entries(permissions.modules, 'module'),
          'menus': _entries(permissions.menus, 'menu_key'),
        });
      });

  Role _role(Map<String, dynamic> j) => Role(
        id: asString(j, 'id'),
        code: asString(j, 'code'),
        name: asString(j, 'name'),
        isMaster: asBool(j, 'is_master'),
        isSystem: asBool(j, 'is_system'),
      );

  Map<String, int> _levels(dynamic raw, String keyField) => {
        for (final e in asMapList(raw)) asString(e, keyField): asInt(e, 'level'),
      };

  // Levels of 0 are omitted: the server treats a missing entry as no access.
  List<Map<String, dynamic>> _entries(Map<String, int> levels, String keyField) => [
        for (final e in levels.entries)
          if (e.value > 0) {keyField: e.key, 'level': e.value},
      ];
}
