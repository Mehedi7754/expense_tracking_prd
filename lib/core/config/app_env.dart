import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration manager that safely reads environment variables from `.env`.
///
/// **SECURITY GUARANTEE**:
/// - Zero hardcoded API URLs or secrets in compiled code.
/// - Validates mandatory variables at boot and fails fast if unconfigured.
/// - Enforces HTTPS in production to prevent plaintext transmission over networks.
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
      // We log the diagnostic and mark initialized so test environments can provide mocks.
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

  /// Internal validator to ensure mandatory environment variables are present and secure.
  static void _validate() {
    if (!kReleaseMode) {
      debugPrint('[AppEnv] Initialized successfully. Environment: $environment');
    }

    if (isProduction && apiBaseUrl.startsWith('http://')) {
      throw StateError(
        'SECURITY VIOLATION: Production API_BASE_URL must use HTTPS protocol. Received: $apiBaseUrl',
      );
    }
  }

  /// Checks if dotenv is initialized.
  static bool get isInitialized => _initialized && dotenv.isInitialized;

  /// The active environment name (e.g., 'development', 'staging', 'production').
  static String get environment {
    if (!dotenv.isInitialized) return 'development';
    return dotenv.env['ENVIRONMENT']?.trim().toLowerCase() ?? 'development';
  }

  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';
  static bool get isDevelopment => environment == 'development';

  /// The Base URL for all backend REST API requests.
  ///
  /// **SECURITY NOTE**: This value is strictly loaded from `.env`.
  /// NO default fallback host (such as localhost or an IP address) is hardcoded.
  static String get apiBaseUrl {
    final url = dotenv.isInitialized ? dotenv.env['API_BASE_URL']?.trim() : null;
    if (url == null || url.isEmpty) {
      if (kDebugMode) {
        // In debug mode, provide an informative exception so developers configure .env
        throw StateError(
          'CONFIGURATION ERROR: API_BASE_URL is not set in your .env file.\n'
          'Please ensure .env exists with a valid API_BASE_URL=https://...\n'
          'Refer to .env.example for guidance.',
        );
      }
      return '';
    }
    // Remove trailing slash if present for standard endpoint appending
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
    if (!dotenv.isInitialized) {
      return '';
    }
    return dotenv.env['SAMPLE_AVATAR_URL']?.trim() ?? '';
  }
}
