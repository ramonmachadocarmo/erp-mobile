import '../../../../core/error/result.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Result<User>> login({required String email, required String password});

  Future<Result<User>> me();

  Future<User?> restore();

  Future<void> logout();
}
