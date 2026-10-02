import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/models/attendance_model.dart';
import 'package:expense_tracking_prd/models/salary_model.dart';
import 'package:expense_tracking_prd/models/holiday_model.dart';
import 'package:expense_tracking_prd/models/leave_model.dart';
import 'package:expense_tracking_prd/core/services/location_service.dart';

void main() {
  group('Attendance & Geo-Location Tracking Unit Tests', () {
    test('AttendanceRecordModel fromJson and coordinate formatting works properly', () {
      final json = {
        'id': 'att-123',
        'userId': 'usr-456',
        'userName': 'Fahim Ahmed',
        'userEmail': 'fahim@gw.com',
        'department': 'Engineering',
        'designation': 'Software Engineer',
        'date': '2026-10-02',
        'sessionType': 'morning',
        'loginTime': '2026-10-02T09:15:00.000Z',
        'latitude': 23.8103,
        'longitude': 90.4125,
        'addressText': 'Banani, Dhaka',
        'deviceInfo': 'Android',
        'status': 'present',
        'notes': 'On-time morning check-in',
        'createdAt': '2026-10-02T09:15:00.000Z',
      };

      final record = AttendanceRecordModel.fromJson(json);

      expect(record.id, 'att-123');
      expect(record.userId, 'usr-456');
      expect(record.userName, 'Fahim Ahmed');
      expect(record.isMorning, isTrue);
      expect(record.isAfternoon, isFalse);
      expect(record.hasValidLocation, isTrue);
      expect(record.formattedCoordinates, contains('23.8103° N'));
      expect(record.formattedCoordinates, contains('90.4125° E'));
      expect(record.addressText, 'Banani, Dhaka');
    });

    test('AttendanceRecordModel handles negative coordinates (S / W) correctly', () {
      final record = AttendanceRecordModel(
        id: 'att-neg',
        userId: 'usr-neg',
        date: '2026-10-02',
        sessionType: 'afternoon',
        loginTime: DateTime.parse('2026-10-02T14:30:00Z'),
        latitude: -33.8688,
        longitude: -151.2093,
        createdAt: DateTime.now(),
      );

      expect(record.isAfternoon, isTrue);
      expect(record.formattedCoordinates, contains('33.8688° S'));
      expect(record.formattedCoordinates, contains('151.2093° W'));
    });

    test('LocationResult handles success and failure gracefully', () {
      final success = LocationResult.success(
        latitude: 23.8103,
        longitude: 90.4125,
        addressText: 'Gulshan 2, Dhaka',
      );

      expect(success.isSuccess, isTrue);
      expect(success.latitude, 23.8103);
      expect(success.longitude, 90.4125);
      expect(success.addressText, 'Gulshan 2, Dhaka');

      final failure = LocationResult.failure(
        message: 'Permission denied',
        isPermissionDenied: true,
      );

      expect(failure.isSuccess, isFalse);
      expect(failure.isPermissionDenied, isTrue);
      expect(failure.errorMessage, 'Permission denied');
    });
  });

  group('Monthly Salary and Attendance-Based Deduction Calculation Tests', () {
    test('Daily Salary Rate calculation: Monthly Salary / Configured Payable Working Days', () {
      const double monthlyBase = 60000.0;
      const int payableDays = 20;

      final dailyRate = monthlyBase / payableDays;
      expect(dailyRate, 3000.0);
    });

    test('Final Payable Salary calculation: Monthly Salary - Total Unpaid Absence Deductions', () {
      const double monthlyBase = 50000.0;
      const int payableDays = 22;
      final double dailyRate = monthlyBase / payableDays;

      // 2 confirmed absent days
      const int confirmedAbsentDays = 2;
      final deductions = confirmedAbsentDays * dailyRate;
      final finalPayable = monthlyBase - deductions;

      expect(deductions, closeTo(4545.45, 0.05));
      expect(finalPayable, closeTo(45454.55, 0.05));
    });

    test('SalaryCalculationModel properly parses JSON and calculates present/absent equivalents', () {
      final json = {
        'userId': 'usr-789',
        'userName': 'Mehedi Hasan',
        'userEmail': 'mehedi@gw.com',
        'department': 'Management',
        'designation': 'Project Lead',
        'month': 10,
        'year': 2026,
        'monthlyBaseSalary': 80000.0,
        'currency': 'BDT',
        'calendarDaysInMonth': 31,
        'weekendDays': 8,
        'holidayDays': 2,
        'scheduledWorkingDays': 21,
        'configuredPayableWorkingDays': 21,
        'dailySalaryRate': 3809.52,
        'presentDays': 18,
        'halfDays': 2, // 1.0 day equivalent present, 1.0 deduction
        'paidLeaveDays': 1,
        'unpaidLeaveDays': 0,
        'missingLoginDays': 0,
        'confirmedAbsentDays': 1,
        'totalAbsenceDeductions': 7619.04, // (1 confirmed + 1 from half days) * 3809.52
        'totalAdditions': 5000.0, // Bonus
        'totalPenalties': 0.0,
        'finalPayableSalary': 77380.96, // 80000 - 7619.04 + 5000
        'isConfirmed': true,
        'dailyBreakdown': [
          {
            'date': '2026-10-01',
            'dayOfWeek': 'Thursday',
            'isWeekend': false,
            'isHoliday': false,
            'isLeave': false,
            'isPaidLeave': false,
            'morningAttended': true,
            'afternoonAttended': true,
            'status': 'present',
            'presentWeight': 1.0,
            'deductionUnits': 0.0,
            'notes': 'Full day attendance recorded',
          },
          {
            'date': '2026-10-02',
            'dayOfWeek': 'Friday',
            'isWeekend': true,
            'status': 'weekend',
            'notes': 'Weekend non-working day',
          },
        ],
      };

      final calc = SalaryCalculationModel.fromJson(json);

      expect(calc.userName, 'Mehedi Hasan');
      expect(calc.monthlyBaseSalary, 80000.0);
      expect(calc.dailySalaryRate, 3809.52);
      expect(calc.isConfirmed, isTrue);
      // Present: 18 full + (2 * 0.5) + 1 paid leave = 20.0
      expect(calc.totalPresentEquivalent, 20.0);
      // Absent: 1 confirmed + 0 unpaid leave + 0 missing + (2 * 0.5) = 2.0
      expect(calc.totalAbsentEquivalent, 2.0);
      expect(calc.finalPayableSalary, 77380.96);
      expect(calc.dailyBreakdown.length, 2);
      expect(calc.dailyBreakdown[0].status, 'present');
      expect(calc.dailyBreakdown[1].status, 'weekend');
    });

    test('Holidays and Leave models serialization', () {
      final holiday = HolidayModel(
        id: 'h-1',
        date: '2026-12-16',
        name: 'Victory Day',
        isRecurring: true,
      );

      final holidayJson = holiday.toJson();
      expect(holidayJson['name'], 'Victory Day');
      expect(holidayJson['isRecurring'], isTrue);

      final leave = LeaveRecordModel(
        id: 'l-1',
        userId: 'u-1',
        startDate: '2026-10-10',
        endDate: '2026-10-12',
        leaveType: 'sick',
        reason: 'Flu recovery',
        isApproved: true,
      );

      expect(leave.isPaid, isTrue);
      final leaveJson = leave.toJson();
      expect(leaveJson['leaveType'], 'sick');
      expect(leaveJson['isApproved'], isTrue);
    });
  });
}
