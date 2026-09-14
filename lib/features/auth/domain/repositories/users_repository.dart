import '../../../../core/error/result.dart';
import '../entities/user.dart';

abstract class UsersRepository {
  Future<Result<List<User>>> list();
  Future<Result<User>> save({required User user, String password = ''});
}
