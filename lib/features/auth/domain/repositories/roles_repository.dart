import '../../../../core/error/result.dart';
import '../entities/role.dart';

abstract class RolesRepository {
  Future<Result<List<Role>>> list();
  Future<Result<Role>> save(Role role);
  Future<Result<void>> delete(String id);
  Future<Result<RolePermissions>> permissions(String id);
  Future<Result<void>> setPermissions(String id, RolePermissions permissions);
}
