import '../error/failure.dart';
import '../error/result.dart';
import 'api_exception.dart';

Failure mapApi(ApiException e) {
  if (e.isNetwork) return NetworkFailure(e.message);
  if (e.statusCode == 401) return UnauthorizedFailure(e.message);
  if (e.statusCode == 403) return const ServerFailure('Seu perfil não tem permissão para esta ação');
  return ServerFailure(e.message);
}

Future<Result<T>> guardApi<T>(Future<T> Function() fn) async {
  try {
    return Ok(await fn());
  } on ApiException catch (e) {
    return Err(mapApi(e));
  }
}
