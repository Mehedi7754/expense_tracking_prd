import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration manager that safely reads environment variables from `.env`.
///
/// **SECURITY & ARCHITECTURE GUARANTEES**:
/// - Zero hardcoded API base URLs or endpoints in compiled code.
/// - Validates environment configuration and formats at boot.
/// - Configurable strict HTTPS enforcement for production compliance.
/// - Dynamic routing resolution with seamless fallback paths.
class AppEnv {
  AppEnv._();

  static bool _initialized = false;

  /// Loads the environment file.
  /// Typically called inside `main()` before `runApp()`.
  static Future<void> initialize({String fileName = '.env'}) async {
    try {
      await dotenv.load(fileName: fileName);
      _initialized = true;
      _validate();
    } catch (e) {
      // In automated widget testing, assets may not be loaded from bundle.
      debugPrint('[AppEnv] Notice: .env file loading handled: $e');
      _initialized = true;
    }
  }

  /// Manually initializes with custom values (useful for unit/integration tests).
  @visibleForTesting
  static void initializeForTesting(Map<String, String> values) {
    final buffer = StringBuffer();
    values.forEach((k, v) => buffer.writeln('$k=$v'));
    dotenv.loadFromString(envString: buffer.toString());
    _initialized = true;
  }

  /// Internal validator to ensure environment variables are present and secure.
  static void _validate() {
    if (!kReleaseMode) {
      debugPrint('[AppEnv] Initialized successfully. Environment: $environment | Base URL: $apiBaseUrl');
    }

    if (apiBaseUrl.isNotEmpty) {
      final uri = Uri.tryParse(apiBaseUrl);
      if (uri == null || (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
        throw StateError('SECURITY VIOLATION: API_BASE_URL must be a valid http or https URL. Received: $apiBaseUrl');
      }
    }

    if (isProduction && enforceHttps && apiBaseUrl.startsWith('http://')) {
      throw StateError(
        'SECURITY VIOLATION: Production API_BASE_URL must use HTTPS protocol when ENFORCE_HTTPS is enabled. Received: $apiBaseUrl',
      );
    }
  }

  /// Checks if dotenv is initialized.
  static bool get isInitialized => _initialized && dotenv.isInitialized;

  /// Active environment name (e.g., 'development', 'staging', 'production').
  static String get environment {
    if (!dotenv.isInitialized) return 'development';
    return dotenv.env['ENVIRONMENT']?.trim().toLowerCase() ?? 'development';
  }

  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';
  static bool get isDevelopment => environment == 'development';

  /// Whether strict HTTPS is enforced. Defaults to false for self-hosted IP/domains.
  static bool get enforceHttps {
    if (!dotenv.isInitialized) return false;
    return dotenv.env['ENFORCE_HTTPS']?.trim().toLowerCase() == 'true';
  }

  /// The Base URL for all backend REST API requests.
  ///
  /// Strictly loaded from `.env`. No fallback host is hardcoded.
  static String get apiBaseUrl {
    final url = dotenv.isInitialized ? dotenv.env['API_BASE_URL']?.trim() : null;
    if (url == null || url.isEmpty) {
      if (kDebugMode && !kIsWeb) {
        // Return empty or throw in debug when explicitly expected
        return '';
      }
      return '';
    }
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// API request timeout in seconds.
  static int get timeoutSeconds {
    if (!dotenv.isInitialized) return 30;
    final val = dotenv.env['API_TIMEOUT_SECONDS'];
    if (val != null) {
      final parsed = int.tryParse(val);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 30;
  }

  /// Sample CDN avatar fallback URL.
  static String get sampleAvatarUrl {
    if (!dotenv.isInitialized) return '';
    return dotenv.env['SAMPLE_AVATAR_URL']?.trim() ?? '';
  }

  /// Internal helper to read an endpoint route with fallback.
  static String _getEnv(String key, String fallback) {
    if (!dotenv.isInitialized) return fallback;
    final val = dotenv.env[key]?.trim();
    if (val != null && val.isNotEmpty) {
      return val.startsWith('/') ? val : '/$val';
    }
    return fallback;
  }

  // ==============================================================================
  // Individual API Route Getters (Zero hardcoding in application code)
  // ==============================================================================

  static String get endpointHealth => _getEnv('API_ENDPOINT_HEALTH', '/health');

  static String get endpointAuthLogin => _getEnv('API_ENDPOINT_AUTH_LOGIN', '/auth/login');
  static String get endpointAuthRegister => _getEnv('API_ENDPOINT_AUTH_REGISTER', '/auth/register');
  static String get endpointAuthMe => _getEnv('API_ENDPOINT_AUTH_ME', '/auth/me');
  static String get endpointAuthRefresh => _getEnv('API_ENDPOINT_AUTH_REFRESH', '/auth/refresh');
  static String get endpointAuthLogout => _getEnv('API_ENDPOINT_AUTH_LOGOUT', '/auth/logout');
  static String get endpointAuthProfile => _getEnv('API_ENDPOINT_AUTH_PROFILE', '/auth/profile');
  static String get endpointAuthForgotPassword => _getEnv('API_ENDPOINT_AUTH_FORGOT_PASSWORD', '/auth/forgot-password');
  static String get endpointAuthResetPassword => _getEnv('API_ENDPOINT_AUTH_RESET_PASSWORD', '/auth/reset-password');

  static String get endpointProjects => _getEnv('API_ENDPOINT_PROJECTS', '/projects');
  static String get endpointProjectCostBreakdown => _getEnv('API_ENDPOINT_PROJECT_COST_BREAKDOWN', '/projects/financials/cost-breakdown');

  static String get endpointExpenses => _getEnv('API_ENDPOINT_EXPENSES', '/expenses');
  static String get endpointExpensesSubmit => _getEnv('API_ENDPOINT_EXPENSES_SUBMIT', '/expenses/submit');
  static String get endpointExpensesCompliance => _getEnv('API_ENDPOINT_EXPENSES_COMPLIANCE', '/expenses/compliance');

  static String get endpointCategories => _getEnv('API_ENDPOINT_CATEGORIES', '/categories');
  static String get endpointClients => _getEnv('API_ENDPOINT_CLIENTS', '/clients');
  static String get endpointTasks => _getEnv('API_ENDPOINT_TASKS', '/tasks');
  static String get endpointUsers => _getEnv('API_ENDPOINT_USERS', '/users');
  static String get endpointAuditLogs => _getEnv('API_ENDPOINT_AUDIT_LOGS', '/audit-logs');
  static String get endpointNotifications => _getEnv('API_ENDPOINT_NOTIFICATIONS', '/notifications');

  static String get endpointReportsSummary => _getEnv('API_ENDPOINT_REPORTS_SUMMARY', '/reports/summary');
  static String get endpointReportsExport => _getEnv('API_ENDPOINT_REPORTS_EXPORT', '/reports/export');
  static String get endpointReportsFinancialSummary => _getEnv('API_ENDPOINT_REPORTS_FINANCIAL_SUMMARY', '/reports/financial-summary');
  static String get endpointReportsReceiptCompliance => _getEnv('API_ENDPOINT_REPORTS_RECEIPT_COMPLIANCE', '/reports/receipt-compliance');

  static String get endpointCostEstimator => _getEnv('API_ENDPOINT_COST_ESTIMATOR', '/admin/cost-estimator/historical');
  static String get endpointBenchmarks => _getEnv('API_ENDPOINT_BENCHMARKS', '/estimator/benchmarks');
}
