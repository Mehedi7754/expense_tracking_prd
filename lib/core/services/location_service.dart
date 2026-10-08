import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationResult {
  final bool isSuccess;
  final double? latitude;
  final double? longitude;
  final String addressText;
  final String? errorMessage;
  final bool isPermissionDenied;
  final bool isPermanentlyDenied;
  final bool isServiceDisabled;

  const LocationResult({
    required this.isSuccess,
    this.latitude,
    this.longitude,
    this.addressText = '',
    this.errorMessage,
    this.isPermissionDenied = false,
    this.isPermanentlyDenied = false,
    this.isServiceDisabled = false,
  });

  factory LocationResult.success({
    required double latitude,
    required double longitude,
    String? addressText,
  }) {
    final latText = '${latitude.toStringAsFixed(4)}° ${latitude >= 0 ? "N" : "S"}';
    final lngText = '${longitude.toStringAsFixed(4)}° ${longitude >= 0 ? "E" : "W"}';
    final formatted = addressText != null && addressText.isNotEmpty
        ? addressText
        : '$latText, $lngText';

    return LocationResult(
      isSuccess: true,
      latitude: latitude,
      longitude: longitude,
      addressText: formatted,
    );
  }

  factory LocationResult.failure({
    required String message,
    bool isPermissionDenied = false,
    bool isPermanentlyDenied = false,
    bool isServiceDisabled = false,
  }) {
    return LocationResult(
      isSuccess: false,
      errorMessage: message,
      isPermissionDenied: isPermissionDenied,
      isPermanentlyDenied: isPermanentlyDenied,
      isServiceDisabled: isServiceDisabled,
    );
  }
}

class LocationService {
  LocationService._();

  static const String _kOfflineQueueKey = 'gw_offline_attendance_queue';

  /// Proactively checks and requests location permission from the OS.
  static Future<LocationPermission> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission;
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  /// Opens the device's system Location Services settings.
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Opens the device's App Details settings page for permission grants.
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Requests location permissions if needed and retrieves verified GPS coordinates.
  /// Strictly requires genuine hardware GPS fix; never returns fake or placeholder coordinates.
  static Future<LocationResult> getCurrentCoordinates({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // 1. Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.failure(
            message: 'Location permission was denied. Geo-location is required for employee attendance tracking.',
            isPermissionDenied: true,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          message: 'Location permissions are permanently denied. Please allow location access in App Settings.',
          isPermissionDenied: true,
          isPermanentlyDenied: true,
        );
      }

      // 2. Check if device location services (GPS) are turned on
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failure(
          message: 'GPS / Location services are turned off on your device. Please turn on location to record verified attendance.',
          isServiceDisabled: true,
        );
      }

      // 3. Obtain real GPS position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeout,
          ),
        );
      } catch (_) {
        // In case of timeout with getCurrentPosition, attempt last known hardware position
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (position != null) {
        return LocationResult.success(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else {
        return LocationResult.failure(
          message: 'Unable to acquire accurate GPS position fix. Please verify device GPS is active with clear sky view.',
        );
      }
    } catch (e) {
      return LocationResult.failure(message: 'Location acquisition failed: $e');
    }
  }

  /// Queues an attendance check-in locally if network fails
  static Future<void> queueOfflineCheckIn({
    required String userId,
    required double latitude,
    required double longitude,
    required String sessionType,
    String? addressText,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kOfflineQueueKey) ?? [];
      final item = {
        'userId': userId,
        'latitude': latitude,
        'longitude': longitude,
        'sessionType': sessionType,
        'addressText': addressText ?? '',
        'timestamp': DateTime.now().toIso8601String(),
      };
      list.add(jsonEncode(item));
      await prefs.setStringList(_kOfflineQueueKey, list);
    } catch (_) {}
  }

  /// Retrieves all queued offline attendance check-ins without removing them
  static Future<List<Map<String, dynamic>>> getOfflineCheckIns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kOfflineQueueKey);
      if (list == null || list.isEmpty) return [];

      return list
          .map((item) {
            try {
              return jsonDecode(item) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clears all queued offline attendance check-ins
  static Future<void> clearOfflineCheckIns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kOfflineQueueKey);
    } catch (_) {}
  }

  /// Retrieves and clears all queued offline attendance check-ins
  static Future<List<Map<String, dynamic>>> popOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kOfflineQueueKey);
      if (list == null || list.isEmpty) return [];

      final parsed = list
          .map((item) {
            try {
              return jsonDecode(item) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      await prefs.remove(_kOfflineQueueKey);
      return parsed;
    } catch (_) {
      return [];
    }
  }
}
