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
            const SizedBox(height: 20),
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
    for (final u in kAuthenticDatabaseUsers) {
      if (u.avatarUrl != null && u.avatarUrl!.isNotEmpty && !avatarMap.containsKey(u.id)) {
        avatarMap[u.id] = u.avatarUrl!;
      }
    }

    List<EmployeeDailyAttendance> rawEmployees = overview?.employees ?? [];
    if (rawEmployees.isEmpty) {
      final sourceUsers = allUsers.isNotEmpty ? allUsers : kAuthenticDatabaseUsers;
      rawEmployees = sourceUsers
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

    final employees = rawEmployees.where((e) {
      final name = e.userName.toLowerCase();
      final email = e.userEmail.toLowerCase();
      return !name.contains('eleanor') &&
          !email.contains('eleanor') &&
          email != 'admin@pfis.com';
    }).toList();

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
    final weekendDays = settingsState.value?.weekendDays ?? [DateTime.friday, DateTime.saturday];
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
                  if (_showMap) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Live Geo-Location Pins',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2),
                        ),
                        Text(
                          '${records.where((r) => r.latitude != null).length} Verified Locations',
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
                        records: records,
                        onMarkerTap: _showRecordDetailsModal,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

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
            child: Row(
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
          ),
        ),
      ),
    );
  }
}
