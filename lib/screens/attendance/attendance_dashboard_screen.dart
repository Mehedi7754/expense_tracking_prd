import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/notification_banner.dart';
import '../../models/attendance_model.dart';
import '../../state/attendance_provider.dart';
import '../../state/auth_provider.dart';
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
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF4F46E5),
                  child: Text(
                    record.userName.isNotEmpty ? record.userName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
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

    final totalStaff = overview?.totalEmployees ?? allUsers.length;
    final presentCount = overview?.presentCount ?? 0;
    final halfDayCount = overview?.halfDayCount ?? 0;
    final missingCount = overview?.missingCount ?? 0;

    final employees = overview?.employees ?? [];
    final filteredEmployees = employees.where((e) {
      if (_statusFilter == 'present') return e.status == 'present';
      if (_statusFilter == 'half_day') return e.status == 'half_day';
      if (_statusFilter == 'missing') return e.status == 'missing' || e.status == 'confirmed_absent';
      return true;
    }).toList();

    DateTime parsedDate = DateTime.tryParse(attendanceState.selectedDate) ?? DateTime.now();
    final formattedDateTitle = DateFormat('EEE, MMM d, yyyy').format(parsedDate);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Attendance & Geo-Tracking', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.map : Icons.map_outlined),
            tooltip: _showMap ? 'Hide Map' : 'Show Map',
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Attendance',
            onPressed: () {
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  // 4. EMPLOYEE FILTER & STATUS CHIPS
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: attendanceState.selectedUserId,
                              isExpanded: true,
                              hint: const Text('Filter by Employee', style: TextStyle(fontSize: 13)),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Employees', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ),
                                ...allUsers.map((u) => DropdownMenuItem<String?>(
                                      value: u.id,
                                      child: Text(u.name, style: const TextStyle(fontSize: 13)),
                                    )),
                              ],
                              onChanged: (val) {
                                ref.read(attendanceProvider.notifier).setSelectedUser(val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

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
                    ...filteredEmployees.map((emp) => _buildEmployeeAttendanceCard(emp, isDark)),

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
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600)),
      selected: isSelected,
      selectedColor: const Color(0xFF4F46E5),
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      onSelected: (_) => setState(() => _statusFilter = value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildEmployeeAttendanceCard(EmployeeDailyAttendance emp, bool isDark) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (emp.status == 'present') {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Present';
      statusIcon = Icons.check_circle_rounded;
    } else if (emp.status == 'half_day') {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Half Day';
      statusIcon = Icons.timelapse_rounded;
    } else if (emp.status == 'confirmed_absent') {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'Absent';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFF64748B);
      statusLabel = 'Not Logged';
      statusIcon = Icons.radio_button_unchecked_rounded;
    }

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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF4F46E5),
                  child: Text(
                    emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
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
