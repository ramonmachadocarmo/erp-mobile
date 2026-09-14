sealed class Failure {
  const Failure(this.message);
  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Falha de conexão']);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Não autorizado']);
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erro no servidor']);
}
