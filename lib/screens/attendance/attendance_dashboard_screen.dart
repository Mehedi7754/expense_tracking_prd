import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/routing/route_paths.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/attendance_model.dart';
import '../../models/user_role.dart';
import '../../state/attendance_provider.dart';
import '../../state/auth_provider.dart';
import '../../state/attendance_settings_provider.dart';
import '../../state/user_management_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'my_attendance_screen.dart';
import 'widgets/attendance_map_view.dart';
import 'widgets/member_geo_location_modal.dart';

class AttendanceDashboardScreen extends ConsumerStatefulWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  ConsumerState<AttendanceDashboardScreen> createState() => _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends ConsumerState<AttendanceDashboardScreen> {
  bool _showMap = false;
  String _statusFilter = 'all'; // all, present, half_day, missing

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userManagementProvider.notifier).fetchUsers();
      ref.read(attendanceProvider.notifier).fetchDailyOverview(force: true);
      ref.read(attendanceProvider.notifier).fetchAttendanceRecords(force: true);
    });
  }

  void _changeDate(int dayDelta) {
    final state = ref.read(attendanceProvider);
    final current = DateTime.tryParse(state.selectedDate) ?? DateTime.now();
    final newDate = current.add(Duration(days: dayDelta));
    final str = DateFormat('yyyy-MM-dd').format(newDate);
    ref.read(attendanceProvider.notifier).setSelectedDate(str);
  }

  Future<void> _pickDate() async {
    final state = ref.read(attendanceProvider);
    final current = DateTime.tryParse(state.selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final str = DateFormat('yyyy-MM-dd').format(picked);
      ref.read(attendanceProvider.notifier).setSelectedDate(str);
    }
  }

  void _showRecordDetailsModal(AttendanceRecordModel record) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                AppAvatar(
                  imageUrl: (record.avatarUrl.isNotEmpty)
                      ? record.avatarUrl
                      : (ref.read(userManagementProvider).where((u) => u.id == record.userId).firstOrNull?.avatarUrl ?? ''),
                  name: record.userName,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.userName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        '${record.department} • ${record.designation}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (record.isMorning ? const Color(0xFF4F46E5) : const Color(0xFF10B981)).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record.isMorning ? 'Morning Session' : 'Afternoon Session',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: record.isMorning ? const Color(0xFF4F46E5) : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Work Mode & Geofence Origin Banner
            () {
              Color bannerBg;
              Color bannerBorder;
              Color bannerFg;
              IconData bannerIcon;
              String modeTitle;
              String modeSubtitle;

              if (record.isFieldDuty) {
                bannerBg = isDark ? const Color(0xFF312E81).withAlpha(100) : const Color(0xFFEEF2FF);
                bannerBorder = isDark ? const Color(0xFF4338CA) : const Color(0xFFC7D2FE);
                bannerFg = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5);
                bannerIcon = Icons.directions_car_rounded;
                modeTitle = 'On Field Duty Attendance';
                final site = record.fieldSite;
                final client = record.fieldClient;
                modeSubtitle = 'Site: ${site ?? "Site Not Specified"}${client != null ? " • Client: $client" : ""}';
              } else if (record.isHomeOffice) {
                bannerBg = isDark ? const Color(0xFF4C1D95).withAlpha(100) : const Color(0xFFF3E8FF);
                bannerBorder = isDark ? const Color(0xFF6B21A8) : const Color(0xFFE9D5FF);
                bannerFg = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE);
                bannerIcon = Icons.home_work_rounded;
                modeTitle = 'Home Office Attendance';
                modeSubtitle = 'Logged remotely from approved residential/home workstation';
              } else {
                // Office check-in
                final distText = record.geofenceDistanceText;
                if (record.isInsideGeofence) {
                  bannerBg = isDark ? const Color(0xFF064E3B).withAlpha(100) : const Color(0xFFECFDF5);
                  bannerBorder = isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0);
                  bannerFg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
                  bannerIcon = Icons.verified_rounded;
                  modeTitle = 'Office Attendance • Verified In-Range';
                  modeSubtitle = 'Device GPS within allowed perimeter${distText != null ? " (Distance: $distText)" : ""}';
                } else if (record.isOutsideGeofence) {
                  bannerBg = isDark ? const Color(0xFF7F1D1D).withAlpha(100) : const Color(0xFFFEF2F2);
                  bannerBorder = isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA);
                  bannerFg = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
                  bannerIcon = Icons.warning_amber_rounded;
                  modeTitle = 'Office Attendance • Outside Geofence';
                  modeSubtitle = 'Device logged outside allowed office boundary${distText != null ? " ($distText away)" : ""}';
                } else {
                  bannerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
                  bannerBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
                  bannerFg = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
                  bannerIcon = Icons.business_rounded;
                  modeTitle = 'Office Headquarters Attendance';
                  modeSubtitle = 'Office workstation session';
                }
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bannerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bannerBorder),
                ),
                child: Row(
                  children: [
                    Icon(bannerIcon, size: 24, color: bannerFg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            modeTitle,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: bannerFg),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            modeSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                            ),
                          ),
                          if (record.earlyDepartureReason != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Early Departure: ${record.earlyDepartureReason}',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }(),
            const SizedBox(height: 16),
            _buildDetailRow(
              icon: Icons.access_time_rounded,
              title: 'Login Timestamp',
              value: '${record.formattedDate} at ${record.formattedTime}',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.location_on_outlined,
              title: 'GPS Coordinates',
              value: record.formattedCoordinates,
              isDark: isDark,
            ),
            if (record.addressText.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDetailRow(
                icon: Icons.map_outlined,
                title: 'Address / Location',
                value: record.addressText,
                isDark: isDark,
              ),
            ],
            if (record.deviceInfo.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDetailRow(
                icon: Icons.smartphone_rounded,
                title: 'Device & Hardware',
                value: record.deviceInfo,
                isDark: isDark,
              ),
            ],
            if (record.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildDetailRow(
                icon: Icons.notes_rounded,
                title: 'Status Notes',
                value: record.notes,
                isDark: isDark,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Details', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUser = ref.watch(authProvider).currentUser;
    // Project Member perspective: only see their own attendance & geo-location
    if (currentUser != null && !currentUser.role.canManageAttendanceAndSalary) {
      return const MyAttendanceScreen();
    }

    final attendanceState = ref.watch(attendanceProvider);
    final allUsers = ref.watch(userManagementProvider);
    final overview = attendanceState.dailyOverview;
    final records = attendanceState.records;

    final avatarMap = <String, String>{};
    for (final u in allUsers) {
      if (u.avatarUrl != null && u.avatarUrl!.isNotEmpty) {
        avatarMap[u.id] = u.avatarUrl!;
      }
    }

    List<EmployeeDailyAttendance> rawEmployees = overview?.employees ?? [];
    if (rawEmployees.isEmpty && allUsers.isNotEmpty) {
      rawEmployees = allUsers
          .where((u) => u.isActive && u.role.requiresAttendanceCheckIn)
          .map((u) {
            final userRecords = records.where((r) => r.userId == u.id).toList();
            final hasMorning = userRecords.any((r) => r.isMorning);
            final hasAfternoon = userRecords.any((r) => !r.isMorning);
            String status = 'missing';
            if (hasMorning && hasAfternoon) {
              status = 'present';
            } else if (hasMorning || hasAfternoon) {
              status = 'half_day';
            }
            return EmployeeDailyAttendance(
              userId: u.id,
              userName: u.name,
              userEmail: u.email,
              department: u.department,
              designation: u.designation ?? u.role.displayName,
              avatarUrl: u.avatarUrl ?? '',
              role: u.role.displayName,
              date: attendanceState.selectedDate,
              status: status,
              morning: userRecords.where((r) => r.isMorning).firstOrNull,
              afternoon: userRecords.where((r) => !r.isMorning).firstOrNull,
            );
          })
          .toList();
    }
    final employees = rawEmployees;

    final totalStaff = employees.length;
    final presentCount = employees.where((e) => e.status == 'present').length;
    final halfDayCount = employees.where((e) => e.status == 'half_day').length;
    final missingCount = employees.where((e) => e.status == 'missing' || e.status == 'confirmed_absent').length;

    final filteredEmployees = employees.where((e) {
      if (_statusFilter == 'present') return e.status == 'present';
      if (_statusFilter == 'half_day') return e.status == 'half_day';
      if (_statusFilter == 'missing') return e.status == 'missing' || e.status == 'confirmed_absent';
      return true;
    }).toList();

    DateTime parsedDate = DateTime.tryParse(attendanceState.selectedDate) ?? DateTime.now();
    final formattedDateTitle = DateFormat('EEE, MMM d, yyyy').format(parsedDate);
    final settingsState = ref.watch(attendanceSettingsProvider);
    final currentSettings = settingsState.value;
    final weekendDays = currentSettings?.weekendDays ?? [DateTime.friday, DateTime.saturday];
    final isWeekend = weekendDays.contains(parsedDate.weekday);
    final isHoliday = employees.isNotEmpty && employees.every((e) => e.status == 'holiday');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          if (currentUser?.role == UserRole.mainAdmin)
            IconButton(
              icon: const Icon(Icons.access_time_rounded),
              tooltip: 'Office Timing Settings',
              onPressed: () => context.push(RoutePaths.attendanceSettings),
            ),
          IconButton(
            icon: Icon(_showMap ? Icons.map : Icons.map_outlined),
            tooltip: _showMap ? 'Hide Map' : 'Show Map',
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Attendance',
            onPressed: () {
              ref.read(userManagementProvider.notifier).fetchUsers();
              ref.read(attendanceProvider.notifier).fetchDailyOverview(force: true);
              ref.read(attendanceProvider.notifier).fetchAttendanceRecords(force: true);
              ref.read(attendanceProvider.notifier).syncOfflineCheckIns();
              NotificationBanner.showInfo(context, 'Attendance records refreshed');
            },
          ),
        ],
      ),
      body: attendanceState.isLoading && overview == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Office Timing Configuration Banner (Super Admin)
                  if (currentUser?.role == UserRole.mainAdmin) ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push(RoutePaths.attendanceSettings),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(isDark ? 20 : 6),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.25 : 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: Color(0xFF4F46E5),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Shift & Timing Rules',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Configure schedules, off-days & payroll',
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Manage',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // 1. DATE NAVIGATOR BAR
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 16 : 4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.chevron_left_rounded, size: 22),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _changeDate(-1),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      formattedDateTitle,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.arrow_drop_down_rounded, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.chevron_right_rounded, size: 22),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _changeDate(1),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  if (isWeekend) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF3B82F6).withAlpha(80) : const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.beach_access_rounded, size: 18, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Weekend Non-Working Day (Friday & Saturday) — Staff are excused and no salary cuts apply.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isHoliday) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E1065).withAlpha(50) : const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF8B5CF6).withAlpha(80) : const Color(0xFFDDD6FE)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.celebration_rounded, size: 18, color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Official Company Holiday — Non-working day with zero absence deductions.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 2. KPI METRICS CARDS
                  Row(
                    children: [
                      _buildMetricCard(
                        title: 'Total',
                        value: '$totalStaff',
                        color: const Color(0xFF64748B),
                        icon: Icons.people_outline_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _buildMetricCard(
                        title: 'Present',
                        value: '$presentCount',
                        color: const Color(0xFF10B981),
                        icon: Icons.check_circle_outline_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _buildMetricCard(
                        title: 'Half Day',
                        value: '$halfDayCount',
                        color: const Color(0xFFF59E0B),
                        icon: Icons.timelapse_rounded,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 6),
                      _buildMetricCard(
                        title: 'Absent',
                        value: '$missingCount',
                        color: const Color(0xFFEF4444),
                        icon: Icons.error_outline_rounded,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 3. INTERACTIVE MAP SECTION
                  () {
                    final combinedMapRecords = <AttendanceRecordModel>[...records];
                    if (overview?.employees != null) {
                      for (final emp in overview!.employees) {
                        if (emp.morning != null && !combinedMapRecords.any((r) => r.id == emp.morning!.id)) {
                          combinedMapRecords.add(emp.morning!);
                        }
                        if (emp.afternoon != null && !combinedMapRecords.any((r) => r.id == emp.afternoon!.id)) {
                          combinedMapRecords.add(emp.afternoon!);
                        }
                      }
                    }
                    final gpsRecords = combinedMapRecords.where((r) => r.latitude != null && r.longitude != null).toList();

                    if (!_showMap && gpsRecords.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Live Geo-Location Pins',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
                            ),
                            Text(
                              '${gpsRecords.length} Verified Locations',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 240,
                          width: double.infinity,
                          child: AttendanceMapView(
                            records: gpsRecords,
                            onMarkerTap: _showRecordDetailsModal,
                            officeLocation: (currentSettings != null && currentSettings.officeLatitude != 0)
                                ? LatLng(currentSettings.officeLatitude, currentSettings.officeLongitude)
                                : null,
                            officeRadiusMeters: currentSettings?.geofenceRadiusMeters,
                            officeName: currentSettings?.officeName,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }(),

                  // 4. STATUS CHIPS FILTER

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All (${employees.length})', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Full Day ($presentCount)', 'present'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Half Day ($halfDayCount)', 'half_day'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Missing / Absent ($missingCount)', 'missing'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 5. EMPLOYEE ATTENDANCE RECORDS LIST
                  if (filteredEmployees.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy_rounded, size: 48, color: isDark ? Colors.white30 : const Color(0xFF94A3B8)),
                          const SizedBox(height: 12),
                          const Text('No attendance records matching filter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        ],
                      ),
                    )
                  else
                    ...filteredEmployees.map((emp) => _buildEmployeeAttendanceCard(emp, isDark, avatarMap)),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 10 : 3),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 12, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
      selected: isSelected,
      selectedColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
      labelStyle: TextStyle(color: isSelected ? (isDark ? const Color(0xFF0F172A) : Colors.white) : null),
      onSelected: (_) => setState(() => _statusFilter = value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildEmployeeAttendanceCard(EmployeeDailyAttendance emp, bool isDark, [Map<String, String>? avatarMap]) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    final settingsState = ref.watch(attendanceSettingsProvider);
    final currentSettings = settingsState.value;
    final userShift = currentSettings?.getShiftForUser(emp.userId);
    final weekendDays = userShift?.weekendDays ?? currentSettings?.weekendDays ?? const [];

    final dateStr = ref.watch(attendanceProvider).selectedDate;
    final parsedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    final isWeekendForDate = weekendDays.contains(parsedDate.weekday);

    String effectiveStatus = emp.status;
    if (!isWeekendForDate && effectiveStatus == 'weekend') {
      effectiveStatus = 'missing';
    } else if (isWeekendForDate && (effectiveStatus == 'missing' || effectiveStatus.isEmpty)) {
      effectiveStatus = 'weekend';
    }

    if (effectiveStatus == 'present') {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Present';
      statusIcon = Icons.check_circle_rounded;
    } else if (effectiveStatus == 'half_day') {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Half Day';
      statusIcon = Icons.timelapse_rounded;
    } else if (effectiveStatus == 'confirmed_absent') {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'Absent';
      statusIcon = Icons.cancel_rounded;
    } else if (effectiveStatus == 'weekend') {
      statusColor = const Color(0xFF3B82F6);
      statusLabel = 'Weekend';
      statusIcon = Icons.beach_access_rounded;
    } else if (effectiveStatus == 'holiday') {
      statusColor = const Color(0xFF8B5CF6);
      statusLabel = 'Holiday';
      statusIcon = Icons.celebration_rounded;
    } else {
      statusColor = const Color(0xFF64748B);
      statusLabel = 'Not Logged';
      statusIcon = Icons.radio_button_unchecked_rounded;
    }

    final effectiveAvatar = emp.avatarUrl.isNotEmpty
        ? emp.avatarUrl
        : (avatarMap?[emp.userId] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 8 : 2),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => MemberGeoLocationModal.show(context, emp, ref.read(attendanceProvider).selectedDate),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppAvatar(
                      imageUrl: effectiveAvatar,
                      name: emp.userName,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.userName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${emp.department} • ${emp.designation.isEmpty ? emp.role : emp.designation}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark ? Colors.white30 : const Color(0xFFCBD5E1),
                    ),
                  ],
                ),
                if (emp.morning != null || emp.afternoon != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (emp.morning != null)
                        _buildLocationBadge(emp.morning!, true, isDark, currentSettings),
                      if (emp.afternoon != null)
                        _buildLocationBadge(emp.afternoon!, false, isDark, currentSettings),
                      if (emp.morning?.earlyDepartureReason != null)
                        _buildEarlyLeaveBadge(emp.morning!.earlyDepartureReason!, isDark),
                      if (emp.afternoon?.earlyDepartureReason != null &&
                          emp.afternoon?.earlyDepartureReason != emp.morning?.earlyDepartureReason)
                        _buildEarlyLeaveBadge(emp.afternoon!.earlyDepartureReason!, isDark),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBadge(
    AttendanceRecordModel record,
    bool isMorning,
    bool isDark,
    AttendanceSettingsState? settings,
  ) {
    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData icon;
    String text;

    final sessionTag = isMorning ? 'AM' : 'PM';

    if (record.isFieldDuty) {
      bgColor = isDark ? const Color(0xFF312E81).withAlpha(100) : const Color(0xFFEEF2FF);
      textColor = isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA);
      borderColor = isDark ? const Color(0xFF4338CA).withAlpha(120) : const Color(0xFFC7D2FE);
      icon = Icons.directions_car_rounded;
      final site = record.fieldSite;
      text = '$sessionTag: Field${site != null && site.isNotEmpty ? ' • $site' : ''}';
    } else if (record.isHomeOffice) {
      bgColor = isDark ? const Color(0xFF4C1D95).withAlpha(100) : const Color(0xFFF3E8FF);
      textColor = isDark ? const Color(0xFFD8B4FE) : const Color(0xFF6B21A8);
      borderColor = isDark ? const Color(0xFF6B21A8).withAlpha(120) : const Color(0xFFE9D5FF);
      icon = Icons.home_work_rounded;
      text = '$sessionTag: Home Office';
    } else {
      // Office Mode
      double? distMeters;
      if (settings != null && settings.officeLatitude != 0 && record.latitude != null && record.longitude != null) {
        distMeters = Geolocator.distanceBetween(
          record.latitude!,
          record.longitude!,
          settings.officeLatitude,
          settings.officeLongitude,
        );
      }

      final allowedRadius = settings?.geofenceRadiusMeters ?? 200.0;
      final isInside = record.isInsideGeofence || (distMeters != null && distMeters <= allowedRadius);
      final isOutside = record.isOutsideGeofence || (distMeters != null && distMeters > allowedRadius);
      final distText = record.geofenceDistanceText ??
          (distMeters != null
              ? (distMeters >= 1000
                  ? '${(distMeters / 1000).toStringAsFixed(1)}km'
                  : '${distMeters.toStringAsFixed(0)}m')
              : null);

      if (isOutside) {
        bgColor = isDark ? const Color(0xFF7F1D1D).withAlpha(90) : const Color(0xFFFEF2F2);
        textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);
        borderColor = isDark ? const Color(0xFF991B1B).withAlpha(120) : const Color(0xFFFECACA);
        icon = Icons.warning_amber_rounded;
        text = '$sessionTag: Office Outside${distText != null ? ' ($distText)' : ''}';
      } else if (isInside) {
        bgColor = isDark ? const Color(0xFF064E3B).withAlpha(90) : const Color(0xFFECFDF5);
        textColor = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
        borderColor = isDark ? const Color(0xFF047857).withAlpha(120) : const Color(0xFFA7F3D0);
        icon = Icons.verified_rounded;
        text = '$sessionTag: Office In-Range${distText != null ? ' ($distText)' : ''}';
      } else {
        bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
        textColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
        icon = Icons.business_rounded;
        text = '$sessionTag: Office';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarlyLeaveBadge(String reason, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF78350F).withAlpha(90) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF92400E).withAlpha(120) : const Color(0xFFFDE68A),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_run_rounded, size: 11, color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Early Leave: $reason',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
