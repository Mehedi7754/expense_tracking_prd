import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/app_env.dart';
import 'api_exceptions.dart';

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

/// Centralized API Client with environment-driven base URL, Bearer auth,
/// error handling, and robust HTTP methods.
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Duration timeout;

  String? _authToken;

  /// Global callback invoked on 401 Unauthorized responses.
  /// Set by AuthNotifier to trigger logout & redirect to login.
  static void Function()? onUnauthorized;

  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    Duration? timeout,
  })  : baseUrl = baseUrl ??
            (AppEnv.apiBaseUrl.isNotEmpty
                ? AppEnv.apiBaseUrl
                : AppEnv.defaultApiBaseUrl),
        _httpClient = httpClient ?? http.Client(),
        timeout = timeout ??
            Duration(
              seconds: AppEnv.isInitialized ? AppEnv.timeoutSeconds : 15,
            );

  String? _effectiveBaseUrl;

  String get effectiveBaseUrl => _effectiveBaseUrl ?? baseUrl;

  String? get authToken => _authToken;

  /// Updates or clears the current session authentication token.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  /// Builds standard secure headers for API requests.
  Map<String, String> _buildHeaders([Map<String, String>? additionalHeaders]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Client-Platform': defaultTargetPlatform.name,
      'X-Client-Environment': AppEnv.isInitialized ? AppEnv.environment : 'development',
    };

    // Forward the Coolify virtual host header so both domain and direct-IP requests route accurately
    final targetHost = Uri.tryParse(effectiveBaseUrl)?.host ?? '';
    if (targetHost == '163.227.239.97' || targetHost.contains('sslip.io')) {
      headers['Host'] = 'xqeqm4yyv7fqxryrkm6phk55.163.227.239.97.sslip.io';
    }

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// Public accessor for building headers.
  Map<String, String> buildHeaders({Map<String, String>? extraHeaders}) =>
      _buildHeaders(extraHeaders);

  Uri _buildUri(String targetBaseUrl, String endpoint, [Map<String, dynamic>? queryParams]) {
    final Uri uri;
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      uri = Uri.parse(endpoint);
    } else {
      final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      final fullUrl = '$targetBaseUrl$cleanEndpoint';
      uri = Uri.parse(fullUrl);
    }

    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }

    final stringParams = queryParams.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    return uri.replace(queryParameters: stringParams);
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    return _send(
      (activeUrl) => _httpClient.get(
        _buildUri(activeUrl, endpoint, queryParams),
        headers: _buildHeaders(headers),
      ),
    );
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    return _send(
      (activeUrl) => _httpClient.post(
        _buildUri(activeUrl, endpoint, queryParams),
        headers: _buildHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    return _send(
      (activeUrl) => _httpClient.put(
        _buildUri(activeUrl, endpoint, queryParams),
        headers: _buildHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    return _send(
      (activeUrl) => _httpClient.patch(
        _buildUri(activeUrl, endpoint, queryParams),
        headers: _buildHeaders(headers),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
  }) async {
    return _send(
      (activeUrl) => _httpClient.delete(
        _buildUri(activeUrl, endpoint, queryParams),
        headers: _buildHeaders(headers),
      ),
    );
  }

  Future<dynamic> _send(Future<http.Response> Function(String activeUrl) requestFn) async {
    try {
      final response = await requestFn(effectiveBaseUrl).timeout(timeout);
      return _processResponse(response);
    } on SocketException catch (e) {
      if (effectiveBaseUrl.contains('sslip.io') && !effectiveBaseUrl.contains('163.227.239.97')) {
        debugPrint('[ApiClient] DNS failure on sslip.io ($e). Retrying via direct IP: http://163.227.239.97/api/v1');
        _effectiveBaseUrl = 'http://163.227.239.97/api/v1';
        try {
          final fallbackResponse = await requestFn(_effectiveBaseUrl!).timeout(timeout);
          debugPrint('[ApiClient] Direct IP failover succeeded.');
          return _processResponse(fallbackResponse);
        } catch (_) {
          // Fall through to throw original exception
        }
      }
      throw NetworkException('Network error: ${e.message}');
    } on http.ClientException catch (e) {
      if (effectiveBaseUrl.contains('sslip.io') && !effectiveBaseUrl.contains('163.227.239.97')) {
        debugPrint('[ApiClient] Client error on sslip.io ($e). Retrying via direct IP: http://163.227.239.97/api/v1');
        _effectiveBaseUrl = 'http://163.227.239.97/api/v1';
        try {
          final fallbackResponse = await requestFn(_effectiveBaseUrl!).timeout(timeout);
          debugPrint('[ApiClient] Direct IP failover succeeded.');
          return _processResponse(fallbackResponse);
        } catch (_) {
          // Fall through to throw original exception
        }
      }
      throw NetworkException('Connection error: ${e.message}');
    } on TimeoutException {
      throw const ApiTimeoutException();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Unexpected client error: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      return decoded ?? <String, dynamic>{};
    }

    String errorMessage = 'Request failed with status $statusCode';
    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] != null) {
        errorMessage = decoded['message'].toString();
      } else if (decoded['error'] != null) {
        errorMessage = decoded['error'].toString();
      }
    }

    switch (statusCode) {
      case 400:
        throw ValidationException(errorMessage, statusCode: 400);
      case 401:
        // Bug 10: Trigger global session-expiry handler before throwing
        if (ApiClient.onUnauthorized != null) {
          ApiClient.onUnauthorized!();
        }
        throw UnauthorizedException(errorMessage);
      case 403:
        throw ForbiddenException(errorMessage);
      case 404:
        throw NotFoundException(errorMessage);
      case 422:
        Map<String, dynamic>? errors;
        if (decoded is Map<String, dynamic> && decoded['errors'] is Map<String, dynamic>) {
          errors = decoded['errors'] as Map<String, dynamic>;
        }
        throw ValidationException(errorMessage, errors: errors);
      case 500:
      case 502:
      case 503:
      case 504:
        throw ServerException(errorMessage);
      default:
        throw ApiException(errorMessage, statusCode: statusCode, data: decoded);
    }
  }

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

  @override
  String toString() {
    return 'ApiClient(baseUrl: $baseUrl, environment: ${AppEnv.isInitialized ? AppEnv.environment : "development"}, authenticated: ${_authToken != null})';
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
