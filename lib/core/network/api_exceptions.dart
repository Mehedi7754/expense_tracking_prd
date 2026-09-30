class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException(this.message, {this.statusCode, this.data});

  @override
  String toString() => 'ApiException: [$statusCode] $message';
}

class NetworkException extends ApiException {
  const NetworkException([super.message = 'Network connection failed. Please verify your internet or server status.'])
      : super(statusCode: null);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Session expired or invalid credentials.'])
      : super(statusCode: 401);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([super.message = 'You do not have permission to perform this action.'])
      : super(statusCode: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Requested resource was not found.'])
      : super(statusCode: 404);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;

  const ValidationException(super.message, {this.errors, int statusCode = 422})
      : super(statusCode: statusCode, data: errors);
}

class ServerException extends ApiException {
  const ServerException([super.message = 'Internal server error occurred. Please try again later.'])
      : super(statusCode: 500);
}

class ApiTimeoutException extends ApiException {
  const ApiTimeoutException([super.message = 'The request timed out. Please check server responsiveness.'])
      : super(statusCode: 408);
}
