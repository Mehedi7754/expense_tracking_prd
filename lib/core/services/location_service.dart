import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationResult {
  final bool isSuccess;
  final double? latitude;
  final double? longitude;
  final String addressText;
  final String? errorMessage;
  final bool isPermissionDenied;
  final bool isServiceDisabled;

  const LocationResult({
    required this.isSuccess,
    this.latitude,
    this.longitude,
    this.addressText = '',
    this.errorMessage,
    this.isPermissionDenied = false,
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
    bool isServiceDisabled = false,
  }) {
    return LocationResult(
      isSuccess: false,
      errorMessage: message,
      isPermissionDenied: isPermissionDenied,
      isServiceDisabled: isServiceDisabled,
    );
  }
}

class LocationService {
  LocationService._();

  static const String _kOfflineQueueKey = 'gw_offline_attendance_queue';

  /// Requests location permissions if needed and retrieves current GPS coordinates.
  /// Handles permission denied, GPS service disabled, and timeout safely.
  static Future<LocationResult> getCurrentCoordinates({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      // 1. Check if location services (GPS) are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services (GPS) are disabled');
        return LocationResult.failure(
          message: 'GPS / Location services are turned off on your device. Please enable location to record verified attendance.',
          isServiceDisabled: true,
        );
      }

      // 2. Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permission denied by employee');
          return LocationResult.failure(
            message: 'Location permission was denied. Geo-location is required for employee attendance tracking.',
            isPermissionDenied: true,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permission permanently denied');
        return LocationResult.failure(
          message: 'Location permissions are permanently denied in device settings. Please allow location access in App Settings.',
          isPermissionDenied: true,
        );
      }

      // 3. Acquire position with fallback and timeout
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint('[LocationService] High accuracy position timed out or failed ($e), falling back to last known position');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        return LocationResult.success(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else {
        return LocationResult.failure(
          message: 'Unable to acquire satellite GPS fix. Please ensure you are not indoors without GPS reception.',
        );
      }
    } catch (e) {
      debugPrint('[LocationService] Error fetching GPS position: $e');
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
      debugPrint('[LocationService] Queued offline attendance item (Total: ${list.length})');
    } catch (e) {
      debugPrint('[LocationService] Failed to queue offline check-in: $e');
    }
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
    } catch (e) {
      debugPrint('[LocationService] Error reading offline queue: $e');
      return [];
    }
  }

  /// Clears all queued offline attendance check-ins
  static Future<void> clearOfflineCheckIns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kOfflineQueueKey);
    } catch (e) {
      debugPrint('[LocationService] Error clearing offline queue: $e');
    }
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
    } catch (e) {
      debugPrint('[LocationService] Error reading offline queue: $e');
      return [];
    }
  }
}
