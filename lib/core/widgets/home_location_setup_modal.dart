import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_colors.dart';
import '../services/location_service.dart';
import 'location_pin_picker.dart';
import 'notification_banner.dart';
import '../../models/user_model.dart';
import '../../state/attendance_settings_provider.dart';
import '../../state/auth_provider.dart';

class HomeLocationSetupModal extends ConsumerStatefulWidget {
  final UserModel user;
  final bool isMandatoryPrompt;

  const HomeLocationSetupModal({
    super.key,
    required this.user,
    this.isMandatoryPrompt = false,
  });

  static Future<bool?> show(
    BuildContext context,
    UserModel user, {
    bool isMandatoryPrompt = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !isMandatoryPrompt,
      builder: (ctx) => HomeLocationSetupModal(
        user: user,
        isMandatoryPrompt: isMandatoryPrompt,
      ),
    );
  }

  @override
  ConsumerState<HomeLocationSetupModal> createState() =>
      _HomeLocationSetupModalState();
}

class _HomeLocationSetupModalState extends ConsumerState<HomeLocationSetupModal> {
  bool _isLocating = false;

  Future<void> _useCurrentGpsLocation() async {
    setState(() => _isLocating = true);
    try {
      final result = await LocationService.getCurrentCoordinates();
      if (!mounted) return;

      if (!result.isSuccess || result.latitude == null || result.longitude == null) {
        setState(() => _isLocating = false);
        NotificationBanner.showError(
          context,
          result.errorMessage ?? 'Could not acquire GPS position. Try picking on the map.',
        );
        return;
      }

      await ref.read(authProvider.notifier).updateHomeLocation(
            latitude: result.latitude!,
            longitude: result.longitude!,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        NotificationBanner.showSuccess(
          context,
          'Home office location set to your current GPS position.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        NotificationBanner.showError(
          context,
          'Failed to update home office location: $e',
        );
      }
    }
  }

  Future<void> _pickOnMap() async {
    final radius =
        ref.read(attendanceSettingsProvider).value?.geofenceRadiusMeters ?? 200;
    final initialLat = widget.user.homeLatitude ?? 23.8103;
    final initialLng = widget.user.homeLongitude ?? 90.4125;

    final point = await LocationPinPicker.show(
      context,
      initialLocation: LatLng(initialLat, initialLng),
      title: 'Set Home Office Location',
      radiusMeters: radius,
    );

    if (point == null || !mounted) return;

    setState(() => _isLocating = true);
    try {
      await ref.read(authProvider.notifier).updateHomeLocation(
            latitude: point.latitude,
            longitude: point.longitude,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
        NotificationBanner.showSuccess(
          context,
          'Home office location pinned and saved successfully.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        NotificationBanner.showError(
          context,
          'Could not save home office location: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(authProvider).currentUser ?? widget.user;
    final hasLocation = currentUser.homeLatitude != null &&
        currentUser.homeLongitude != null &&
        !(currentUser.homeLatitude == 0.0 && currentUser.homeLongitude == 0.0);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: const Icon(
              Icons.home_work_rounded,
              color: Color(0xFF4F46E5),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Home Office Location',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Workplace geofence setup',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isMandatoryPrompt
                  ? 'Your organization requires a verified home or office location for remote attendance and field check-ins. Please configure your work location.'
                  : 'Set or update your designated home/office location for automated geofenced check-in and remote work verification.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 16),
            // Current Location status box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasLocation
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasLocation
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFDE68A),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasLocation
                        ? Icons.verified_rounded
                        : Icons.info_outline_rounded,
                    size: 20,
                    color: hasLocation
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasLocation ? 'Configured Location' : 'Location Not Set',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: hasLocation
                                ? const Color(0xFF065F46)
                                : const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasLocation
                              ? '${currentUser.homeLatitude!.toStringAsFixed(5)}, ${currentUser.homeLongitude!.toStringAsFixed(5)}'
                              : 'No geofence coordinates registered yet',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: hasLocation
                                ? const Color(0xFF047857)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Button 1: Current GPS Position
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLocating ? null : _useCurrentGpsLocation,
                icon: _isLocating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, size: 20),
                label: Text(
                  _isLocating
                      ? 'Acquiring GPS fix...'
                      : 'Use Current GPS Location',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Button 2: Map Pin Picker
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLocating ? null : _pickOnMap,
                icon: const Icon(Icons.map_outlined, size: 20, color: Color(0xFF4F46E5)),
                label: const Text(
                  'Select Location on Map',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      actions: [
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              widget.isMandatoryPrompt ? 'Remind Me Later' : 'Close',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
