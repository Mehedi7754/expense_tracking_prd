import 'package:expense_tracking_prd/models/attendance_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'employee with no check-in shows no location instead of a fake office',
    () {
      const attendance = EmployeeDailyAttendance(
        userId: 'employee-1',
        userName: 'Employee One',
        userEmail: 'employee@example.com',
        department: 'Operations',
        designation: 'Field Officer',
        role: 'Project Member',
        date: '2026-11-02',
        status: 'weekend',
      );

      expect(attendance.locationSummary, 'No check-in location recorded');
    },
  );

  test(
    'employee location summary lists actual morning and afternoon work modes',
    () {
      final morning = AttendanceRecordModel(
        id: 'morning-1',
        userId: 'employee-1',
        date: '2026-11-02',
        sessionType: 'morning',
        loginTime: DateTime(2026, 11, 2, 9),
        createdAt: DateTime(2026, 11, 2, 9),
        workMode: 'home',
      );
      final afternoon = AttendanceRecordModel(
        id: 'afternoon-1',
        userId: 'employee-1',
        date: '2026-11-02',
        sessionType: 'afternoon',
        loginTime: DateTime(2026, 11, 2, 14),
        createdAt: DateTime(2026, 11, 2, 14),
        workMode: 'field',
      );
      final attendance = EmployeeDailyAttendance(
        userId: 'employee-1',
        userName: 'Employee One',
        userEmail: 'employee@example.com',
        department: 'Operations',
        designation: 'Field Officer',
        role: 'Project Member',
        date: '2026-11-02',
        status: 'present',
        morning: morning,
        afternoon: afternoon,
      );

      expect(attendance.locationSummary, 'AM Home · PM On Field');
    },
  );
}
