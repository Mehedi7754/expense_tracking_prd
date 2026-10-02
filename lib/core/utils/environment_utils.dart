import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Centralized environment detection utility.
/// Eliminates duplicate `_isTestEnvironment()` functions across providers.
class EnvironmentUtils {
  EnvironmentUtils._();

  /// Returns `true` when running under `flutter test`.
  static bool get isTestEnvironment {
    if (kIsWeb) return false;
    return Platform.environment.containsKey('FLUTTER_TEST');
  }
}
