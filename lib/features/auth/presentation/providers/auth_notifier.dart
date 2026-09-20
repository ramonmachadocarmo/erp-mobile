import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../core/error/failure.dart';
import '../../domain/access.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final accessProvider = Provider<Access>(
  (ref) => Access(ref.watch(authNotifierProvider).user),
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.read(unauthorizedHandlerProvider).listen(() {
      state = const AuthState(hydrated: true);
    });
    Future.microtask(_restore);
    return const AuthState();
  }

  Future<void> _restore() async {
    final user = await ref.read(restoreSessionUseCaseProvider).call();
    state = AuthState(user: user, hydrated: true);
  }

  /// Returns null on success, otherwise why the sign-in failed.
  Future<Failure?> login({required String email, required String password}) async {
    state = state.copyWith(loggingIn: true, clearError: true);
    final result = await ref
        .read(loginUseCaseProvider)
        .call(email: email, password: password);
    return result.when(
      ok: (user) {
        state = AuthState(user: user, hydrated: true);
        return null;
      },
      err: (failure) {
        state = AuthState(hydrated: true, loginError: failure.message);
        return failure;
      },
    );
  }

  Future<void> logout() async {
    await ref.read(logoutUseCaseProvider).call();
    state = const AuthState(hydrated: true);
  }
}
