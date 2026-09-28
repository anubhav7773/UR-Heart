class SanctuaryException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const SanctuaryException(this.message, {this.statusCode, this.code});

  @override
  String toString() => 'SanctuaryException: $message (Status: $statusCode, Code: $code)';
}

class NetworkUnavailableException extends SanctuaryException {
  const NetworkUnavailableException([super.message = 'Unable to reach the sanctuary. Please check your connection.'])
      : super(statusCode: 0, code: 'NETWORK_UNAVAILABLE');
}

class UnauthorizedException extends SanctuaryException {
  const UnauthorizedException([super.message = 'Session expired. Please enter the sanctuary anew.'])
      : super(statusCode: 401, code: 'UNAUTHORIZED');
}

class ResourceNotFoundException extends SanctuaryException {
  const ResourceNotFoundException([super.message = 'The requested sanctuary entity does not exist.'])
      : super(statusCode: 404, code: 'NOT_FOUND');
}

class ServerException extends SanctuaryException {
  const ServerException([super.message = 'Sanctuary server encountered an unexpected reflection.'])
      : super(statusCode: 500, code: 'INTERNAL_ERROR');
}
