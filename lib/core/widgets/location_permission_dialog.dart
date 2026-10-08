import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/location_service.dart';

class LocationPermissionDialog {
  LocationPermissionDialog._();

  /// Displays an interactive popup dialog prompting the employee to enable GPS
  /// or grant location permissions.
  static Future<void> show(
    BuildContext context, {
    required bool isServiceDisabled,
    bool isPermanentlyDenied = false,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isServiceDisabled
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isServiceDisabled
                    ? Icons.gps_off_rounded
                    : Icons.location_off_rounded,
                color: isServiceDisabled
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF4F46E5),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isServiceDisabled
                    ? 'Turn On Device Location'
                    : 'Location Access Needed',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          isServiceDisabled
              ? 'Device GPS / Location Services is currently turned off. To record genuine, verified employee attendance, please enable GPS in your device settings.'
              : isPermanentlyDenied
                  ? 'Location access is denied in system settings. Please open App Settings and set Location permissions to "While using the app".'
                  : 'Geo-location permission is required to accurately record your workplace attendance coordinates.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    if (isServiceDisabled) {
                      await LocationService.openLocationSettings();
                    } else {
                      await LocationService.openAppSettings();
                    }
                  },
                  child: Text(
                    isServiceDisabled ? 'Open GPS Settings' : 'Open App Settings',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
