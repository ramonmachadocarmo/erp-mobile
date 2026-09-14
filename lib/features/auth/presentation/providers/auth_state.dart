import '../../domain/entities/user.dart';

class AuthState {
  const AuthState({
    this.user,
    this.hydrated = false,
    this.loggingIn = false,
    this.loginError,
  });

  final User? user;
  final bool hydrated;
  final bool loggingIn;
  final String? loginError;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? hydrated,
    bool? loggingIn,
    String? loginError,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      hydrated: hydrated ?? this.hydrated,
      loggingIn: loggingIn ?? this.loggingIn,
      loginError: clearError ? null : (loginError ?? this.loginError),
    );
  }
}
