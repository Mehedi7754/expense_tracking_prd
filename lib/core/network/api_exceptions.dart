class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: [$statusCode] $message';
}

class NetworkException extends ApiException {
  const NetworkException([String message = 'Network connection failed. Please verify your internet or server status.'])
      : super(message, statusCode: null);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([String message = 'Session expired or invalid credentials.'])
      : super(message, statusCode: 401);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([String message = 'You do not have permission to perform this action.'])
      : super(message, statusCode: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException([String message = 'Requested resource was not found.'])
      : super(message, statusCode: 404);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;

  const ValidationException(String message, {this.errors, int statusCode = 422})
      : super(message, statusCode: statusCode, data: errors);
}

class ServerException extends ApiException {
  const ServerException([String message = 'Internal server error occurred. Please try again later.'])
      : super(message, statusCode: 500);
}

class ApiTimeoutException extends ApiException {
  const ApiTimeoutException([String message = 'The request timed out. Please check server responsiveness.'])
      : super(message, statusCode: 408);
}
