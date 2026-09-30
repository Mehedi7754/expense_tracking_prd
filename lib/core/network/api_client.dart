import 'package:flutter/foundation.dart';
import '../config/app_env.dart';

/// Secure API response wrapper.
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int? statusCode;

  const ApiResponse.success(this.data, {this.statusCode = 200})
      : isSuccess = true,
        errorMessage = null;

  const ApiResponse.failure(this.errorMessage, {this.statusCode})
      : isSuccess = false,
        data = null;
}

/// Base secure API Client communicating with endpoints configured via `.env`.
///
/// **SECURITY PRACTICES**:
/// - Base URL is loaded exclusively from [AppEnv.apiBaseUrl].
/// - Zero hardcoded default URLs or fallback hosts.
/// - Authorization tokens are attached dynamically via Bearer headers.
/// - Request & Response logging redacts sensitive keys (passwords, tokens, pins).
class ApiClient {
  String? _authToken;

  ApiClient({String? authToken}) : _authToken = authToken;

  /// Updates or clears the current session authentication token.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Builds standard secure headers for API requests.
  Map<String, String> buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Platform': defaultTargetPlatform.name,
      'X-Client-Environment': AppEnv.environment,
    };

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// Base URL getter verifying environment configuration.
  String get baseUrl => AppEnv.apiBaseUrl;

  /// Redacts sensitive keys before logging.
  static Map<String, dynamic> redactSensitiveData(Map<String, dynamic> input) {
    const sensitiveKeys = {'password', 'token', 'access_token', 'refresh_token', 'secret', 'pin'};
    final redacted = <String, dynamic>{};
    for (final entry in input.entries) {
      if (sensitiveKeys.contains(entry.key.toLowerCase())) {
        redacted[entry.key] = '***REDACTED***';
      } else if (entry.value is Map<String, dynamic>) {
        redacted[entry.key] = redactSensitiveData(entry.value as Map<String, dynamic>);
      } else {
        redacted[entry.key] = entry.value;
      }
    }
    return redacted;
  }

  /// Diagnostic summary (safe for logging).
  @override
  String toString() {
    return 'ApiClient(baseUrl: $baseUrl, environment: ${AppEnv.environment}, authenticated: ${_authToken != null})';
  }
}
