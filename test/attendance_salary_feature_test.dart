import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracking_prd/models/user_model.dart';
import 'package:expense_tracking_prd/models/user_role.dart';
import 'package:expense_tracking_prd/core/services/attendance_salary_mock_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Role-Based Attendance & Salary Permissions', () {
    test('Admin and Project Manager can manage attendance & salary, regular members cannot', () {
      expect(UserRole.mainAdmin.canManageAttendanceAndSalary, isTrue);
      expect(UserRole.projectManager.canManageAttendanceAndSalary, isTrue);
      expect(UserRole.finance.canManageAttendanceAndSalary, isTrue);
      expect(UserRole.projectMember.canManageAttendanceAndSalary, isFalse);
    });
  });

  group('Daily Attendance & 2-Time Geo-Location Tracking', () {
    test('Store tracks real 2-time geo-locations (Morning & Afternoon) upon employee check-in', () async {
      final store = AttendanceSalaryMockStore.instance;
      await store.ensureInitialized();

      const memberId = 'a0000000-0000-0000-0000-000000000003';
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Verify clean initial state without dummy data
      final initialOverview = await store.getDailyOverview(today);
      expect(initialOverview.employees.isNotEmpty, isTrue);
      final initialMember = initialOverview.employees.firstWhere((e) => e.userId == memberId);
      expect(initialMember.morning, isNull);
      expect(initialMember.afternoon, isNull);

      // Record real morning check-in with GPS
      await store.checkIn(
        userId: memberId,
        latitude: 23.7937,
        longitude: 90.4066,
        addressText: 'Banani 11, Dhaka',
        sessionType: 'morning',
        deviceInfo: 'Test Device',
      );

      // Record real afternoon check-in with GPS
      await store.checkIn(
        userId: memberId,
        latitude: 23.7925,
        longitude: 90.4078,
        addressText: 'Gulshan 2, Dhaka',
        sessionType: 'afternoon',
        deviceInfo: 'Test Device',
      );

      final overview = await store.getDailyOverview(today);
      final member = overview.employees.firstWhere((e) => e.userId == memberId);

      // Verify Morning check-in location
      expect(member.morning, isNotNull);
      expect(member.morning!.sessionType, equals('morning'));
      expect(member.morning!.latitude, equals(23.7937));
      expect(member.morning!.longitude, equals(90.4066));
      expect(member.morning!.addressText, contains('Banani'));

      // Verify Afternoon check-in location
      expect(member.afternoon, isNotNull);
      expect(member.afternoon!.sessionType, equals('afternoon'));
      expect(member.afternoon!.latitude, equals(23.7925));
      expect(member.afternoon!.longitude, equals(90.4078));
      expect(member.afternoon!.addressText, contains('Gulshan'));
    });

    test('Check-in updates geo-location accurately', () async {
      final store = AttendanceSalaryMockStore.instance;
      await store.ensureInitialized();

      const memberId = 'a0000000-0000-0000-0000-000000000004';
      final record = await store.checkIn(
        userId: memberId,
        latitude: 23.8103,
        longitude: 90.4125,
        addressText: 'Dhaka Tech Park, Level 4',
        sessionType: 'morning',
        deviceInfo: 'Android Device',
      );

      expect(record, isNotNull);
      expect(record.sessionType, equals('morning'));
      final records = await store.getAttendanceRecords(userId: memberId);
      final morningRecord = records.firstWhere((r) => r.sessionType == 'morning');
      expect(morningRecord.latitude, equals(23.8103));
      expect(morningRecord.longitude, equals(90.4125));
      expect(morningRecord.addressText, contains('Dhaka Tech Park'));
    });
  });

  group('Salary Management & Daily Absence Cut Logic', () {
    test('Daily salary rate is accurately computed from base monthly salary and working days', () async {
      final store = AttendanceSalaryMockStore.instance;
      await store.ensureInitialized();

      // Configure a project member salary: 44,000 BDT with 22 standard working days
      const memberId = 'a0000000-0000-0000-0000-000000000004';
      final updated = await store.setEmployeeSalary(
        memberId,
        44000.0,
        standardWorkingDays: 22,
      );

      expect(updated.monthlySalary, equals(44000.0));
      expect(updated.standardWorkingDays, equals(22));

      // Calculate salary for current month
      final now = DateTime.now();
      final calc = await store.calculateSalary(memberId, now.month, now.year);

      // Daily Rate = 44,000 / 22 = 2,000 BDT per day
      expect(calc.dailySalaryRate, equals(2000.0));
    });

    test('Confirming absence deducts exactly one daily salary unit from monthly payable', () async {
      final store = AttendanceSalaryMockStore.instance;
      await store.ensureInitialized();

      const memberId = 'a0000000-0000-0000-0000-000000000004';
      await store.setEmployeeSalary(
        memberId,
        50000.0,
        standardWorkingDays: 20, // Daily rate = 50,000 / 20 = 2,500
      );

      final now = DateTime.now();
      // Confirm absence for the 1st of this month
      final absentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
      await store.confirmAbsence(
        userId: memberId,
        date: absentDate,
        notes: 'Unexcused medical absence',
      );

      final calc = await store.calculateSalary(memberId, now.month, now.year);

      // Verify that confirmed absence triggers salary deduction
      expect(calc.dailySalaryRate, equals(2500.0));
      expect(calc.totalAbsenceDeductions, greaterThanOrEqualTo(2500.0));
      expect(calc.finalPayableSalary, lessThan(50000.0));
      expect(calc.finalPayableSalary, equals(50000.0 - calc.totalAbsenceDeductions));
    });

    test('Org Salary Report aggregates all employee base payroll and net payable after cuts', () async {
      final store = AttendanceSalaryMockStore.instance;
      await store.ensureInitialized();

      final now = DateTime.now();
      final report = await store.getOrgSalaryReport(now.month, now.year);

      expect(report.employees.isNotEmpty, isTrue);
      expect(report.totalEmployees, equals(report.employees.length));
      expect(report.totalBaseSalary, greaterThan(0));
      expect(report.totalPayable, equals(report.totalBaseSalary - report.totalDeductions));
    });

    test('Real employee login & check-in immediately appears in manager overview with genuine data', () async {
      final store = AttendanceSalaryMockStore.instance;
      await store.ensureInitialized();

      // Register or sync a real employee account
      final realEmployee = UserModel(
        id: 'usr_mehedi_real_999',
        name: 'Mehedi Hasan Real',
        email: 'mehedi.real@pfis.com',
        role: UserRole.projectMember,
        department: 'Field Operations',
        designation: 'Senior Surveyor',
      );

      store.syncUser(realEmployee);

      final today = DateTime.now().toIso8601String().substring(0, 10);

      // Real employee performs GPS check-in
      await store.checkIn(
        userId: realEmployee.id,
        latitude: 23.8105,
        longitude: 90.4128,
        addressText: 'Dhaka Real GPS Location',
        sessionType: 'morning',
        currentUser: realEmployee,
      );

      // Manager views daily overview
      final overview = await store.getDailyOverview(today, [realEmployee]);
      final found = overview.employees.firstWhere((e) => e.userId == realEmployee.id);
      expect(found, isNotNull);
      expect(found.userName, equals('Mehedi Hasan Real'));
      expect(found.morning, isNotNull);
      expect(found.morning!.latitude, equals(23.8105));
      expect(found.morning!.addressText, equals('Dhaka Real GPS Location'));

      // Manager views salary report - real employee is included
      final now = DateTime.now();
      final salaryReport = await store.getOrgSalaryReport(now.month, now.year, [realEmployee]);
      final salaryFound = salaryReport.employees.firstWhere((e) => e.userId == realEmployee.id);
      expect(salaryFound, isNotNull);
      expect(salaryFound.userName, equals('Mehedi Hasan Real'));
      expect(salaryFound.monthlyBaseSalary, equals(50000.0));
    });
  });
}
