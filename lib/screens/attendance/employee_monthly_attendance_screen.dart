import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_env.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_back_button.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_model.dart';
import '../../models/holiday_model.dart';
import '../../models/user_model.dart';
import '../../repositories/attendance_repository.dart';
import '../../repositories/leave_repository.dart';
import '../../repositories/salary_repository.dart';
import '../../state/attendance_settings_provider.dart';
import '../../state/user_management_provider.dart';

class EmployeeMonthlyAttendanceScreen extends ConsumerStatefulWidget {
  final String userId;
  final DateTime? initialMonth;

  const EmployeeMonthlyAttendanceScreen({
    super.key,
    required this.userId,
    this.initialMonth,
  });

  @override
  ConsumerState<EmployeeMonthlyAttendanceScreen> createState() =>
      _EmployeeMonthlyAttendanceScreenState();
}

class _EmployeeMonthlyAttendanceScreenState
    extends ConsumerState<EmployeeMonthlyAttendanceScreen> {
  late DateTime _month;
  UserModel? _employee;
  List<AttendanceRecordModel> _records = const [];
  List<LeaveRecordModel> _leaves = const [];
  List<HolidayModel> _holidays = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialMonth ?? DateTime.now();
    _month = DateTime(seed.year, seed.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(userManagementProvider.notifier).fetchUsers();
      final users = ref.read(userManagementProvider);
      final attendanceRepo = ref.read(attendanceRepositoryProvider);
      final leaveRepo = ref.read(leaveRepositoryProvider);
      final salaryRepo = ref.read(salaryRepositoryProvider);
      final results = await Future.wait([
        attendanceRepo.getAttendanceRecords(
          month: _month.month,
          year: _month.year,
        ),
        leaveRepo.getLeaves(userId: widget.userId),
        salaryRepo.getHolidays(_month.year),
      ]);
      if (!mounted) return;
      setState(() {
        _employee = users.where((user) => user.id == widget.userId).firstOrNull;
        _records =
            (results[0] as List<AttendanceRecordModel>)
                .where((record) => record.userId == widget.userId)
                .toList();
        _leaves =
            (results[1] as List<LeaveRecordModel>).where(_isApproved).toList();
        _holidays = results[2] as List<HolidayModel>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Monthly attendance could not be loaded. Please try again.';
      });
    }
  }

  bool _isApproved(LeaveRecordModel leave) =>
      !leave.isPending && !leave.isRejected;

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  List<_AttendanceDay> _days(List<int> weekends) {
    final count = DateUtils.getDaysInMonth(_month.year, _month.month);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(count, (index) {
      final date = DateTime(_month.year, _month.month, index + 1);
      final records =
          _records.where((record) {
              final recordDate = DateTime.tryParse(record.date);
              return recordDate != null &&
                  recordDate.year == date.year &&
                  recordDate.month == date.month &&
                  recordDate.day == date.day;
            }).toList()
            ..sort((a, b) => a.loginTime.compareTo(b.loginTime));
      final leave =
          _leaves.where((item) {
            final start = DateTime.tryParse(item.startDate);
            final end = DateTime.tryParse(item.endDate);
            return start != null &&
                end != null &&
                !date.isBefore(DateTime(start.year, start.month, start.day)) &&
                !date.isAfter(DateTime(end.year, end.month, end.day));
          }).firstOrNull;
      final future = date.isAfter(today);
      final offDay = weekends.contains(date.weekday);
      final holiday = _holidays.any((item) {
        final value = DateTime.tryParse(item.date);
        if (value == null) return false;
        return item.isRecurring
            ? value.month == date.month && value.day == date.day
            : value.year == date.year &&
                value.month == date.month &&
                value.day == date.day;
      });
      final status =
          records.isNotEmpty
              ? 'Present'
              : leave != null
              ? 'Approved leave'
              : holiday
              ? 'Holiday'
              : offDay
              ? 'Off day'
              : future
              ? 'Upcoming'
              : 'Absent';
      return _AttendanceDay(
        date: date,
        records: records,
        leave: leave,
        status: status,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(attendanceSettingsProvider).value;
    final weekends =
        settings?.weekendDays ?? const [DateTime.friday, DateTime.saturday];
    final days = _days(weekends);
    final scheduledWorkdays =
        days
            .where(
              (day) =>
                  !weekends.contains(day.date.weekday) &&
                  day.status != 'Holiday',
            )
            .length;
    final present = days.where((day) => day.records.isNotEmpty).length;
    final leaveCount =
        days
            .where(
              (day) =>
                  day.leave != null &&
                  day.records.isEmpty &&
                  !weekends.contains(day.date.weekday) &&
                  day.status != 'Holiday',
            )
            .length;
    final now = DateTime.now();
    final isCurrentMonth = now.year == _month.year && now.month == _month.month;
    final endOfPeriod =
        isCurrentMonth
            ? DateTime(now.year, now.month, now.day)
            : DateTime(_month.year, _month.month + 1, 0);
    final absent =
        days
            .where(
              (day) => day.status == 'Absent' && !day.date.isAfter(endOfPeriod),
            )
            .length;

    return Scaffold(
      backgroundColor:
          dark ? AppColors.darkBackground : const Color(0xFFF5F7FB),
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text(
          'Employee attendance',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor:
            dark ? AppColors.darkBackground : const Color(0xFFF5F7FB),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body:
          _loading && _employee == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _monthSelector(dark),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _StatusCard(message: _error!, onRetry: _load, dark: dark),
                    ],
                    if (_employee != null) ...[
                      const SizedBox(height: 14),
                      _EmployeeHeader(employee: _employee!, dark: dark),
                      const SizedBox(height: 14),
                      _MetricsGrid(
                        dark: dark,
                        items: [
                          _MetricData(
                            'Working days',
                            scheduledWorkdays,
                            Icons.work_outline_rounded,
                            const Color(0xFF4F46E5),
                          ),
                          _MetricData(
                            'Present days',
                            present,
                            Icons.check_circle_outline_rounded,
                            const Color(0xFF059669),
                          ),
                          _MetricData(
                            'Leave days',
                            leaveCount,
                            Icons.beach_access_outlined,
                            const Color(0xFF7C3AED),
                          ),
                          _MetricData(
                            'Absent so far',
                            absent,
                            Icons.event_busy_outlined,
                            const Color(0xFFDC2626),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
                        child: Text(
                          'Working days exclude configured weekends and holidays. Absences are counted through ${DateFormat('d MMM').format(endOfPeriod)}; future days are excluded.',
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.35,
                            color:
                                dark ? Colors.white54 : const Color(0xFF667085),
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_month),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: dark ? Colors.white : const Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...days.map((day) => _DayCard(day: day, dark: dark)),
                    ],
                    if (_loading && _employee != null)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _monthSelector(bool dark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: dark ? AppColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: dark ? AppColors.darkBorder : const Color(0xFFE8ECF3),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () => _moveMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _month,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                initialDatePickerMode: DatePickerMode.year,
              );
              if (date != null) {
                setState(() => _month = DateTime(date.year, date.month));
                _load();
              }
            },
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_month),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : const Color(0xFF101828),
                  ),
                ),
                Text(
                  'SELECT MONTH',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white54 : const Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () => _moveMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _AttendanceDay {
  final DateTime date;
  final List<AttendanceRecordModel> records;
  final LeaveRecordModel? leave;
  final String status;
  const _AttendanceDay({
    required this.date,
    required this.records,
    required this.leave,
    required this.status,
  });
}

class _EmployeeHeader extends StatelessWidget {
  final UserModel employee;
  final bool dark;
  const _EmployeeHeader({required this.employee, required this.dark});

  String _resolve(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = AppEnv.apiBaseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  @override
  Widget build(BuildContext context) {
    final path = employee.avatarUrl?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark ? AppColors.darkBorder : const Color(0xFFE8ECF3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFEEF0FF),
            backgroundImage: path.isEmpty ? null : NetworkImage(_resolve(path)),
            onBackgroundImageError: path.isEmpty ? null : (_, __) {},
            child:
                path.isEmpty
                    ? Text(
                      employee.name.isEmpty
                          ? '?'
                          : employee.name.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF5B5BD6),
                        fontWeight: FontWeight.w800,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: dark ? Colors.white : const Color(0xFF101828),
                  ),
                ),
                Text(
                  [
                    employee.department,
                    employee.email,
                  ].where((item) => item.trim().isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: dark ? Colors.white54 : const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _MetricData(this.label, this.value, this.icon, this.color);
}

class _MetricsGrid extends StatelessWidget {
  final bool dark;
  final List<_MetricData> items;
  const _MetricsGrid({required this.dark, required this.items});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: items.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisExtent: 78,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemBuilder: (context, index) {
      final item = items[index];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: dark ? AppColors.darkBorder : const Color(0xFFE8ECF3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 17, color: item.color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.value}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      color: dark ? Colors.white : const Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white60 : const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _DayCard extends StatelessWidget {
  final _AttendanceDay day;
  final bool dark;
  const _DayCard({required this.day, required this.dark});

  @override
  Widget build(BuildContext context) {
    final text = dark ? Colors.white : const Color(0xFF101828);
    final statusColor = switch (day.status) {
      'Present' => const Color(0xFF059669),
      'Approved leave' => const Color(0xFF7C3AED),
      'Absent' => const Color(0xFFDC2626),
      'Off day' => const Color(0xFF64748B),
      'Holiday' => const Color(0xFF0891B2),
      _ => const Color(0xFF2563EB),
    };
    final checkIn = day.records.where((record) => record.isMorning).firstOrNull;
    final checkOut =
        day.records.where((record) => record.isAfternoon).lastOrNull;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 7),
      color: dark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: dark ? AppColors.darkBorder : const Color(0xFFE8ECF3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE').format(day.date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color:
                              dark ? Colors.white54 : const Color(0xFF98A2B3),
                        ),
                      ),
                      Text(
                        '${day.date.day}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    DateFormat('d MMMM').format(day.date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: text,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    day.status,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (day.status == 'Present') ...[
              const Divider(height: 17),
              _SessionRow(
                label: 'Check-in',
                record: checkIn,
                icon: Icons.login_rounded,
                dark: dark,
              ),
              const SizedBox(height: 7),
              _SessionRow(
                label: 'Check-out',
                record: checkOut,
                icon: Icons.logout_rounded,
                dark: dark,
              ),
              if (day.records.isEmpty) const SizedBox.shrink(),
            ],
            if (day.leave != null) ...[
              const Divider(height: 17),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.beach_access_rounded,
                    size: 16,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${day.leave!.typeDisplayName} · Approved',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        Text(
                          '${DateFormat('d MMM').format(DateTime.tryParse(day.leave!.startDate) ?? day.date)} – ${DateFormat('d MMM').format(DateTime.tryParse(day.leave!.endDate) ?? day.date)}${day.leave!.reason.isEmpty ? '' : ' · ${day.leave!.reason}'}',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                dark ? Colors.white60 : const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (day.status == 'Absent') ...[
              const Divider(height: 17),
              Text(
                'No attendance recorded on this scheduled workday.',
                style: TextStyle(
                  fontSize: 10,
                  color: dark ? Colors.white60 : const Color(0xFF667085),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final String label;
  final AttendanceRecordModel? record;
  final IconData icon;
  final bool dark;
  const _SessionRow({
    required this.label,
    required this.record,
    required this.icon,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 15,
        color:
            record == null ? const Color(0xFF98A2B3) : const Color(0xFF5B5BD6),
      ),
      const SizedBox(width: 7),
      SizedBox(
        width: 66,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: dark ? Colors.white60 : const Color(0xFF667085),
          ),
        ),
      ),
      Expanded(
        child: Text(
          record?.formattedTime ?? 'Not recorded',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color:
                record == null
                    ? (dark ? Colors.white38 : const Color(0xFF98A2B3))
                    : (dark ? Colors.white : const Color(0xFF344054)),
          ),
        ),
      ),
      if (record != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            record!.workModeLabel,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4F46E5),
            ),
          ),
        ),
    ],
  );
}

class _StatusCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool dark;
  const _StatusCard({
    required this.message,
    required this.onRetry,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: dark ? AppColors.darkSurface : Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
