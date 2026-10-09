import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/location_permission_dialog.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/attendance_model.dart';
import '../../state/attendance_provider.dart';
import '../../state/attendance_settings_provider.dart';
import '../../state/auth_provider.dart';
import 'widgets/attendance_map_view.dart';

class MyAttendanceScreen extends ConsumerStatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  ConsumerState<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends ConsumerState<MyAttendanceScreen> {
  bool _hasInitialFetchTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await LocationService.requestLocationPermission();
      } catch (_) {}
      if (!mounted) return;
      final user = ref.read(authProvider).currentUser;
      if (user != null && user.id.isNotEmpty) {
        _hasInitialFetchTriggered = true;
        ref.read(attendanceProvider.notifier).fetchAttendanceRecords(userId: user.id, force: true);
      }
    });
  }

  Future<void> _handleManualCheckIn(String session) async {
    final success = await ref.read(attendanceProvider.notifier).checkIn(explicitSession: session);
    if (!mounted) return;

    if (success) {
      NotificationBanner.showSuccess(context, 'Attendance & GPS coordinates recorded successfully!');
    } else {
      final err = ref.read(attendanceProvider).errorMessage ?? 'Check-in failed';

      // Detect GPS/permission errors and show proper dialog
      final errLower = err.toLowerCase();
      final isPermanentlyDenied = errLower.contains('permanently denied') || errLower.contains('app settings');
      final isPermissionDenied = isPermanentlyDenied || errLower.contains('permission');
      final isServiceDisabled = errLower.contains('gps') || errLower.contains('location services are turned off');

      if (isServiceDisabled || isPermissionDenied) {
        LocationPermissionDialog.show(
          context,
          isServiceDisabled: isServiceDisabled,
          isPermanentlyDenied: isPermanentlyDenied,
        );
      } else {
        NotificationBanner.showWarning(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authProvider);
    final user = authState.currentUser;
    final attendanceState = ref.watch(attendanceProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      final newUser = next.currentUser;
      if (newUser != null && newUser.id.isNotEmpty && (previous?.currentUser?.id != newUser.id || !_hasInitialFetchTriggered)) {
        _hasInitialFetchTriggered = true;
        ref.read(attendanceProvider.notifier).fetchAttendanceRecords(userId: newUser.id, force: true);
      }
    });

    if (!_hasInitialFetchTriggered && user != null && user.id.isNotEmpty && !attendanceState.isLoading && attendanceState.records.isEmpty) {
      _hasInitialFetchTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(attendanceProvider.notifier).fetchAttendanceRecords(userId: user.id, force: true);
        }
      });
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final effectiveUserId = user?.id ?? '';
    final myRecords = attendanceState.records.where((r) =>
      r.userId.isEmpty ||
      effectiveUserId.isEmpty ||
      r.userId == effectiveUserId ||
      (user?.email != null && r.userEmail == user!.email)
    ).toList();

    bool isDateToday(AttendanceRecordModel r) {
      if (r.date == todayStr || r.date.startsWith(todayStr)) return true;
      final parsedDate = DateTime.tryParse(r.date);
      if (parsedDate != null && DateFormat('yyyy-MM-dd').format(parsedDate.toLocal()) == todayStr) return true;
      if (DateFormat('yyyy-MM-dd').format(r.loginTime.toLocal()) == todayStr) return true;
      return false;
    }

    AttendanceRecordModel? todayMorning;
    AttendanceRecordModel? todayAfternoon;

    for (final r in myRecords) {
      if (isDateToday(r)) {
        if (r.isMorning) todayMorning = r;
        if (r.isAfternoon) todayAfternoon = r;
      }
    }

    final currentHour = DateTime.now().hour;
    final isAdminRole = user?.role == null || !user!.role.requiresAttendanceCheckIn;
    final settings = ref.watch(attendanceSettingsProvider).value;
    final shift = settings?.getShiftForUser(effectiveUserId) ?? const AttendanceShift(id: 'shift_default', name: 'General Shift');
    final startH = shift.morningStartHour;
    final dividerH = shift.morningEndHour;
    final endH = shift.afternoonEndHour;
    final isWeekendToday = shift.weekendDays.contains(DateTime.now().weekday);

    String fmtH(int h) => '${(h % 12 == 0 ? 12 : h % 12).toString().padLeft(2, '0')}:00 ${h < 12 ? 'AM' : 'PM'}';
    final isMorningSlot = !isWeekendToday && currentHour >= startH && currentHour < dividerH;

    String currentSlotBadge;
    Color currentSlotBadgeColor;
    if (isAdminRole) {
      currentSlotBadge = 'Management Exempt';
      currentSlotBadgeColor = const Color(0xFF6366F1);
    } else if (isWeekendToday) {
      currentSlotBadge = '${shift.name} • Off-Day';
      currentSlotBadgeColor = const Color(0xFF10B981);
    } else if (isMorningSlot) {
      currentSlotBadge = '${shift.name} • Morning';
      currentSlotBadgeColor = const Color(0xFF2563EB);
    } else if (currentHour >= dividerH && currentHour < endH) {
      currentSlotBadge = '${shift.name} • Afternoon';
      currentSlotBadgeColor = const Color(0xFF0D9488);
    } else if (currentHour >= endH) {
      currentSlotBadge = '${shift.name} • Shift Over';
      currentSlotBadgeColor = const Color(0xFF64748B);
    } else {
      currentSlotBadge = '${shift.name} • Off Hours';
      currentSlotBadgeColor = const Color(0xFF64748B);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final u = ref.read(authProvider).currentUser;
          if (u != null && u.id.isNotEmpty) {
            await ref.read(attendanceProvider.notifier).fetchAttendanceRecords(userId: u.id, force: true);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAdminRole) ...[
                // Leadership / Super Admin Exemption Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                          : [const Color(0xFFEEF2FF), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.4 : 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              CupertinoIcons.shield_lefthalf_fill,
                              color: Color(0xFF6366F1),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${user?.role.displayName ?? "Executive"} Exemption Active',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Check-in is required exclusively for Managers & Employees',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(CupertinoIcons.info_circle_fill, color: Color(0xFF6366F1), size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'As Super Admin, your presence is pre-authorized. Daily attendance check-ins, late penalties, and payroll deductions apply exclusively to project managers and field employees.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.45,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(CupertinoIcons.chart_bar_alt_fill, size: 15),
                              label: const Text(
                                'Staff Attendance',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                              onPressed: () => context.push(RoutePaths.attendanceDashboard),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6366F1),
                                side: BorderSide(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 15),
                              label: const Text(
                                'Deduction Rules',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                              onPressed: () => context.push(RoutePaths.attendanceSettings),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // 1. TODAY'S SESSIONS CARD (Clean, Pure & Minimal for Manager / Employee)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Clean Date Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('EEE, MMM d, yyyy').format(DateTime.now()),
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: currentSlotBadgeColor.withValues(alpha: isDark ? 0.25 : 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                currentSlotBadge,
                                style: TextStyle(
                                  color: currentSlotBadgeColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Session 1: Morning Check-in
                      _buildSessionPill(
                        isDark: isDark,
                        title: 'Morning Session',
                        record: todayMorning,
                        onCheckIn: () => _handleManualCheckIn('morning'),
                        isSubmitting: attendanceState.isSubmitting,
                        icon: CupertinoIcons.sunrise_fill,
                        iconColor: const Color(0xFFF59E0B),
                        isCorrectTimeSlot: isMorningSlot,
                        timingHint: currentHour < startH
                            ? 'Opens ${fmtH(startH)}'
                            : (currentHour >= dividerH
                                ? 'Ended ${fmtH(dividerH)}'
                                : '${fmtH(startH)} - ${fmtH(dividerH)}'),
                      ),

                      const SizedBox(height: 10),

                      // Session 2: Evening Check-out
                      _buildSessionPill(
                        isDark: isDark,
                        title: 'Evening Session',
                        record: todayAfternoon,
                        onCheckIn: () => _handleManualCheckIn('afternoon'),
                        isSubmitting: attendanceState.isSubmitting,
                        icon: CupertinoIcons.sunset_fill,
                        iconColor: const Color(0xFF6366F1),
                        isCorrectTimeSlot: true,
                        timingHint: todayAfternoon != null
                            ? 'Logged at ${todayAfternoon.formattedTime}'
                            : 'Available anytime • Shift ends ${fmtH(endH)}',
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // 2. TODAY'S GPS MAP
              () {
                final todayGpsRecords = myRecords.where((r) => r.date == todayStr && r.latitude != null && r.longitude != null).toList();
                final recentGpsRecords = myRecords.where((r) => r.latitude != null && r.longitude != null).toList();
                final displayGpsRecords = todayGpsRecords.isNotEmpty ? todayGpsRecords : (recentGpsRecords.isNotEmpty ? [recentGpsRecords.first] : <AttendanceRecordModel>[]);

                if (displayGpsRecords.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todayGpsRecords.isNotEmpty ? 'Today\'s Location' : 'Latest Recorded Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AttendanceMapView(
                          records: displayGpsRecords,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              }(),

              // 3. ATTENDANCE HISTORY LIST
              Text(
                'History',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              if (myRecords.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No attendance history recorded yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else
                ...myRecords.map((r) => _buildHistoryRow(r, isDark)),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionPill({
    required String title,
    required AttendanceRecordModel? record,
    required VoidCallback onCheckIn,
    required bool isSubmitting,
    required IconData icon,
    required Color iconColor,
    required bool isCorrectTimeSlot,
    required String timingHint,
    bool isDark = false,
  }) {
    final hasLogged = record != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isDark
            ? (hasLogged ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFF1E293B))
            : (hasLogged ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? (hasLogged ? const Color(0xFF059669).withValues(alpha: 0.6) : const Color(0xFF334155))
              : (hasLogged ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.30 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  hasLogged
                      ? 'Logged at ${record.formattedTime}'
                      : timingHint,
                  style: TextStyle(
                    color: hasLogged
                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                        : (isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B)),
                    fontSize: 11,
                    fontWeight: hasLogged ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasLogged)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.30 : 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.60 : 0.35),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.checkmark_seal_fill, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 3.5),
                  Text(
                    title.toLowerCase().contains('morning') ? 'Present' : 'Checked Out',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isSubmitting ? null : onCheckIn,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCorrectTimeSlot
                        ? (title.toLowerCase().contains('morning') ? const Color(0xFF2563EB) : const Color(0xFF4F46E5))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: title.toLowerCase().contains('morning') ? const Color(0xFF2563EB) : const Color(0xFF4F46E5),
                      width: 1.2,
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCorrectTimeSlot ? CupertinoIcons.arrow_right_circle_fill : CupertinoIcons.clock_fill,
                              size: 13,
                              color: isCorrectTimeSlot
                                  ? Colors.white
                                  : (title.toLowerCase().contains('morning') ? const Color(0xFF2563EB) : const Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              title.toLowerCase().contains('morning') ? 'Punch In' : 'Punch Out',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isCorrectTimeSlot
                                    ? Colors.white
                                    : (title.toLowerCase().contains('morning') ? const Color(0xFF2563EB) : const Color(0xFF4F46E5)),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(AttendanceRecordModel r, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (r.isMorning ? const Color(0xFF4F46E5) : const Color(0xFF10B981)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              r.isMorning ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
              color: r.isMorning ? const Color(0xFF4F46E5) : const Color(0xFF10B981),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.formattedDate} • ${r.sessionType.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  r.formattedCoordinates,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                r.formattedTime,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  'Present',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
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
