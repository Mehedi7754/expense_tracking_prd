import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_back_button.dart';
import '../../models/attendance_model.dart';
import '../../repositories/attendance_repository.dart';
import '../../state/user_management_provider.dart';
import 'widgets/member_geo_location_modal.dart';

class EmployeeAttendanceDayScreen extends ConsumerStatefulWidget {
  final String userId;
  final String date;

  const EmployeeAttendanceDayScreen({
    super.key,
    required this.userId,
    required this.date,
  });

  @override
  ConsumerState<EmployeeAttendanceDayScreen> createState() =>
      _EmployeeAttendanceDayScreenState();
}

class _EmployeeAttendanceDayScreenState
    extends ConsumerState<EmployeeAttendanceDayScreen> {
  EmployeeDailyAttendance? _attendance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
      final user = users.where((item) => item.id == widget.userId).firstOrNull;
      if (user == null) throw StateError('Employee not found');
      final records = await ref
          .read(attendanceRepositoryProvider)
          .getAttendanceRecords(userId: widget.userId, date: widget.date);
      if (!mounted) return;
      final morning = records.where((record) => record.isMorning).firstOrNull;
      final afternoon =
          records.where((record) => record.isAfternoon).firstOrNull;
      final count = (morning == null ? 0 : 1) + (afternoon == null ? 0 : 1);
      setState(() {
        _attendance = EmployeeDailyAttendance(
          userId: user.id,
          userName: user.name,
          userEmail: user.email,
          department: user.department,
          designation: user.designation ?? user.role.displayName,
          role: user.role.displayName,
          avatarUrl: user.avatarUrl ?? '',
          date: widget.date,
          status:
              count == 2
                  ? 'present'
                  : count == 1
                  ? 'half_day'
                  : 'missing',
          morning: morning,
          afternoon: afternoon,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Attendance details could not be loaded.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendance = _attendance;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Attendance details'),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
              : attendance == null
              ? const Center(child: Text('Attendance details are unavailable.'))
              : MemberGeoLocationModal(
                employee: attendance,
                date: widget.date,
                fullPage: true,
              ),
    );
  }
}
