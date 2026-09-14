import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../data/repositories/users_repository_impl.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/users_repository.dart';

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepositoryImpl(ref.watch(apiClientProvider)),
);

final usersProvider = AsyncNotifierProvider<UsersNotifier, List<User>>(UsersNotifier.new);

class UsersNotifier extends AsyncNotifier<List<User>> {
  @override
  Future<List<User>> build() =>
      ref.read(usersRepositoryProvider).list().then((r) => r.getOrThrow());

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(usersRepositoryProvider).list().then((r) => r.getOrThrow()),
    );
  }

  Future<void> save({required User user, String password = ''}) async {
    (await ref.read(usersRepositoryProvider).save(user: user, password: password)).getOrThrow();
    await reload();
  }
}
