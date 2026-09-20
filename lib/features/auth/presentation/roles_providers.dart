import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../data/repositories/roles_repository_impl.dart';
import '../domain/entities/role.dart';
import '../domain/repositories/roles_repository.dart';

final rolesRepositoryProvider = Provider<RolesRepository>(
  (ref) => RolesRepositoryImpl(ref.watch(apiClientProvider)),
);

final rolesProvider = AsyncNotifierProvider<RolesNotifier, List<Role>>(RolesNotifier.new);

class RolesNotifier extends AsyncNotifier<List<Role>> {
  @override
  Future<List<Role>> build() =>
      ref.read(rolesRepositoryProvider).list().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(rolesRepositoryProvider).list().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save(Role role) async {
    (await ref.read(rolesRepositoryProvider).save(role)).getOrThrow();
    await reload();
  }

  Future<void> delete(String id) async {
    (await ref.read(rolesRepositoryProvider).delete(id)).getOrThrow();
    await reload();
  }
}

final rolePermissionsProvider = FutureProvider.autoDispose.family<RolePermissions, String>(
  (ref, id) => ref.read(rolesRepositoryProvider).permissions(id).then((r) => r.getOrThrow()),
);
