import 'dart:convert';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/session_store.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._session);

  final AuthRemoteDatasource _remote;
  final SessionStore _session;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _remote.login(email: email, password: password);
      await _session.save(
        token: result.token,
        userJson: jsonEncode(result.user.toJson()),
      );
      return Ok(result.user.toEntity());
    } on ApiException catch (e) {
      return Err(_map(e));
    }
  }

  @override
  Future<Result<User>> me() async {
    try {
      final user = await _remote.me();
      return Ok(user.toEntity());
    } on ApiException catch (e) {
      return Err(_map(e));
    }
  }

  @override
  Future<User?> restore() async {
    final token = await _session.readToken();
    if (token == null) return null;
    final result = await me();
    return result.when(ok: (user) => user, err: (_) => null);
  }

  @override
  Future<void> logout() => _session.clear();

  Failure _map(ApiException e) {
    if (e.isNetwork) return NetworkFailure(e.message);
    if (e.statusCode == 401) return UnauthorizedFailure(e.message);
    return ServerFailure(e.message);
  }
}
