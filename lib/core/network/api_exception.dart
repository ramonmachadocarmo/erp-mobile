class ApiException implements Exception {
  const ApiException(this.statusCode, this.message, {this.isNetwork = false});

  final int? statusCode;
  final String message;
  final bool isNetwork;
}
