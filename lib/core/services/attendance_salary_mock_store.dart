import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/attendance_model.dart';
import '../../models/holiday_model.dart';
import '../../models/salary_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../state/user_management_provider.dart';

/// Resilient local storage and fallback mock store for Employee Attendance & Salary calculations.
/// Guarantees zero network errors on mobile and enables instant offline capability.
class AttendanceSalaryMockStore {
  AttendanceSalaryMockStore._();
  static final AttendanceSalaryMockStore instance = AttendanceSalaryMockStore._();

  static const String _kRecordsPrefKey = 'gw_real_attendance_records_v3';
  static const String _kSalariesPrefKey = 'gw_real_employee_salaries_v3';
  static const String _kHolidaysPrefKey = 'gw_real_holidays_v3';
  bool _initialized = false;
  final List<AttendanceRecordModel> _records = [];
  final Map<String, EmployeeSalaryProfile> _salaries = {};
  final List<HolidayModel> _holidays = [];
  final Map<String, UserModel> _knownUsers = {};

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 0. Load real users from custom cache and session
      final customUsersJson = prefs.getString('gw_custom_users_cache');
      if (customUsersJson != null && customUsersJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(customUsersJson);
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final u = UserModel.fromJson(item);
              _knownUsers[u.id] = u;
            }
          }
        } catch (_) {}
      }

      final sessionUserJson = prefs.getString('gw_session_user_data');
      if (sessionUserJson != null && sessionUserJson.isNotEmpty) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(sessionUserJson);
          final u = UserModel.fromJson(decoded);
          _knownUsers[u.id] = u;
        } catch (_) {}
      }

      // Ensure authentic database users are registered alongside custom/session users
      for (final u in kAuthenticDatabaseUsers) {
        if (!_knownUsers.containsKey(u.id)) {
          _knownUsers[u.id] = u;
        }
      }
      
      // 1. Load Salaries
      final salariesJson = prefs.getString(_kSalariesPrefKey);
      if (salariesJson != null && salariesJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(salariesJson);
        decoded.forEach((key, val) {
          if (val is Map<String, dynamic>) {
            _salaries[key] = EmployeeSalaryProfile.fromJson(val);
          }
        });
      }
      _seedDefaultSalariesIfEmpty();

      // 2. Load Real Attendance Records from device storage
      final recordsJson = prefs.getString(_kRecordsPrefKey);
      if (recordsJson != null && recordsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(recordsJson);
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final rec = AttendanceRecordModel.fromJson(item);
            _records.add(rec);
            if (!_knownUsers.containsKey(rec.userId)) {
              _knownUsers[rec.userId] = UserModel(
                id: rec.userId,
                name: rec.userName,
                email: rec.userEmail,
                department: rec.department,
                designation: rec.designation,
                role: UserRole.projectMember,
                avatarUrl: rec.avatarUrl,
              );
            }
          }
        }
      }

      // 3. Load Holidays
      final holidaysJson = prefs.getString(_kHolidaysPrefKey);
      if (holidaysJson != null && holidaysJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(holidaysJson);
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _holidays.add(HolidayModel.fromJson(item));
          }
        }
      }
      _seedDefaultHolidaysIfEmpty();
    } catch (e) {
      debugPrint('[AttendanceSalaryMockStore] Error initializing store: $e');
      _seedDefaultSalariesIfEmpty();
      _seedDefaultHolidaysIfEmpty();
    }
  }

  void syncUser(UserModel user) {
    _knownUsers[user.id] = user;
    if (!_salaries.containsKey(user.id)) {
      _salaries[user.id] = EmployeeSalaryProfile(
        id: 'sal-${user.id.length > 8 ? user.id.substring(0, 8) : user.id}',
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        department: user.department,
        designation: user.designation ?? user.role.displayName,
        monthlySalary: 50000.0,
        currency: 'BDT',
        standardWorkingDays: 22,
        effectiveFrom: '2026-01-01',
      );
      _saveSalaries();
    }
  }

  void syncUsers(List<UserModel> users) {
    for (final u in users) {
      syncUser(u);
    }
  }

  void _seedDefaultSalariesIfEmpty() {
    for (final user in _knownUsers.values) {
      if (!_salaries.containsKey(user.id)) {
        _salaries[user.id] = EmployeeSalaryProfile(
          id: 'sal-${user.id.length > 8 ? user.id.substring(0, 8) : user.id}',
          userId: user.id,
          userName: user.name,
          userEmail: user.email,
          department: user.department,
          designation: user.designation ?? user.role.displayName,
          monthlySalary: 50000.0,
          currency: 'BDT',
          standardWorkingDays: 22,
          effectiveFrom: '2026-01-01',
        );
      }
    }
  }

  void _seedDefaultHolidaysIfEmpty() {
    if (_holidays.isNotEmpty) return;
    _holidays.addAll([
      HolidayModel(id: 'hol-1', date: '2026-02-21', name: 'International Mother Language Day', isRecurring: true),
      HolidayModel(id: 'hol-2', date: '2026-03-26', name: 'Independence Day', isRecurring: true),
      HolidayModel(id: 'hol-3', date: '2026-04-14', name: 'Pohela Boishakh', isRecurring: true),
      HolidayModel(id: 'hol-4', date: '2026-05-01', name: 'May Day', isRecurring: true),
      HolidayModel(id: 'hol-5', date: '2026-12-16', name: 'Victory Day', isRecurring: true),
    ]);
  }

  Future<void> _saveRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _records.map((r) => r.toJson()).toList();
      await prefs.setString(_kRecordsPrefKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[AttendanceSalaryMockStore] Error persisting records: $e');
    }
  }

  Future<void> _saveSalaries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      _salaries.forEach((k, v) {
        map[k] = {
          'id': v.id,
          'userId': v.userId,
          'userName': v.userName,
          'userEmail': v.userEmail,
          'department': v.department,
          'designation': v.designation,
          'monthlySalary': v.monthlySalary,
          'currency': v.currency,
          'standardWorkingDays': v.standardWorkingDays,
          'effectiveFrom': v.effectiveFrom,
          'effectiveTo': v.effectiveTo,
        };
      });
      await prefs.setString(_kSalariesPrefKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[AttendanceSalaryMockStore] Error persisting salaries: $e');
    }
  }

  // ==================== ATTENDANCE METHODS ====================

  Future<AttendanceRecordModel> checkIn({
    required String userId,
    required double latitude,
    required double longitude,
    String? addressText,
    String? sessionType,
    String? deviceInfo,
    String? notes,
    UserModel? currentUser,
  }) async {
    await ensureInitialized();

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final session = (sessionType != null && sessionType.isNotEmpty)
        ? sessionType.toLowerCase()
        : (now.hour < 13 ? 'morning' : 'afternoon');

    if (currentUser != null) {
      syncUser(currentUser);
    }

    UserModel? resolvedUser = currentUser ?? _knownUsers[userId];
    if (resolvedUser == null) {
      try {
        resolvedUser = kAuthenticDatabaseUsers.firstWhere((u) => u.id == userId);
      } catch (_) {
        resolvedUser = UserModel(
          id: userId,
          name: 'Team Member',
          email: 'member@pfis.com',
          role: UserRole.projectMember,
          department: 'Field Operations',
        );
      }
      syncUser(resolvedUser);
    }

    // Remove any existing check-in for this user, date, and session
    _records.removeWhere((r) => r.userId == userId && r.date == today && r.sessionType == session);

    final record = AttendanceRecordModel(
      id: 'rec-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: resolvedUser.name,
      userEmail: resolvedUser.email,
      department: resolvedUser.department,
      designation: resolvedUser.designation ?? 'Member',
      avatarUrl: resolvedUser.avatarUrl ?? '',
      date: today,
      sessionType: session,
      loginTime: now,
      latitude: latitude,
      longitude: longitude,
      addressText: (addressText != null && addressText.isNotEmpty) ? addressText : 'Live Device Coordinates',
      deviceInfo: deviceInfo ?? 'Mobile GPS Sensor',
      status: 'present',
      notes: notes ?? 'Verified Check-in',
      createdAt: now,
    );

    _records.add(record);
    await _saveRecords();
    return record;
  }

  Future<List<AttendanceRecordModel>> getAttendanceRecords({
    String? userId,
    String? date,
    int? month,
    int? year,
    String? sessionType,
  }) async {
    await ensureInitialized();

    return _records.where((r) {
      if (userId != null && userId.isNotEmpty && r.userId != userId) return false;
      if (date != null && date.isNotEmpty && r.date != date) return false;
      if (sessionType != null && sessionType.isNotEmpty && r.sessionType != sessionType) return false;
      if (month != null || year != null) {
        final parsed = DateTime.tryParse(r.date);
        if (parsed != null) {
          if (month != null && parsed.month != month) return false;
          if (year != null && parsed.year != year) return false;
        }
      }
      return true;
    }).toList();
  }

  Future<DailyAttendanceOverview> getDailyOverview([String? date, List<UserModel>? explicitUsers]) async {
    await ensureInitialized();
    if (explicitUsers != null && explicitUsers.isNotEmpty) {
      syncUsers(explicitUsers);
    }

    final targetDate = (date != null && date.isNotEmpty)
        ? date
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    final employeeDailies = <EmployeeDailyAttendance>[];
    int presentCount = 0;
    int halfDayCount = 0;
    int missingCount = 0;

    final usersToProcess = <UserModel>[];
    final seenUserIds = <String>{};

    for (final u in _knownUsers.values) {
      if (seenUserIds.add(u.id)) {
        usersToProcess.add(u);
      }
    }

    final targetRecords = _records.where((r) => r.date == targetDate).toList();
    for (final rec in targetRecords) {
      if (seenUserIds.add(rec.userId)) {
        final u = UserModel(
          id: rec.userId,
          name: rec.userName,
          email: rec.userEmail,
          department: rec.department,
          designation: rec.designation,
          role: UserRole.projectMember,
          avatarUrl: rec.avatarUrl,
        );
        syncUser(u);
        usersToProcess.add(u);
      }
    }

    if (usersToProcess.isEmpty) {
      for (final u in kAuthenticDatabaseUsers) {
        if (seenUserIds.add(u.id)) usersToProcess.add(u);
      }
    }

    // Bug 1 & 5 Fix: Determine if selected date is a non-working day
    // (weekend = Fri/Sat in Bangladesh, or an official holiday)
    final targetDateObj = DateTime.tryParse(targetDate);
    final isWeekendDay = targetDateObj != null &&
        (targetDateObj.weekday == DateTime.friday ||
            targetDateObj.weekday == DateTime.saturday);
    final isHolidayDay = _holidays.any((h) =>
        h.date == targetDate ||
        (h.isRecurring &&
            targetDate.length >= 5 &&
            h.date.length >= 5 &&
            targetDate.endsWith(h.date.substring(4))));
    final isNonWorkingDay = isWeekendDay || isHolidayDay;

    for (final user in usersToProcess) {
      final userRecords = _records.where((r) => r.userId == user.id && r.date == targetDate).toList();

      AttendanceRecordModel? morning;
      AttendanceRecordModel? afternoon;

      for (final rec in userRecords) {
        if (rec.isMorning) morning = rec;
        if (rec.isAfternoon) afternoon = rec;
      }

      String status;
      if (isWeekendDay) {
        // Bug 1 Fix: Never penalise employees for being absent on a weekend
        status = 'weekend';
      } else if (isHolidayDay) {
        // Bug 5 Fix: Official holidays are non-working — not absences
        status = 'holiday';
      } else if (morning != null && afternoon != null) {
        status = 'present';
        presentCount++;
      } else if (morning != null || afternoon != null) {
        status = 'half_day';
        halfDayCount++;
      } else {
        final isConfirmed = userRecords.any((r) => r.status == 'confirmed_absent');
        status = isConfirmed ? 'confirmed_absent' : 'missing';
        missingCount++;
      }

      employeeDailies.add(EmployeeDailyAttendance(
        userId: user.id,
        userName: user.name,
        userEmail: user.email,
        department: user.department,
        designation: user.designation ?? user.role.displayName,
        avatarUrl: user.avatarUrl ?? '',
        role: user.role.displayName,
        date: targetDate,
        morning: morning,
        afternoon: afternoon,
        status: status,
      ));
    }

    return DailyAttendanceOverview(
      date: targetDate,
      totalEmployees: usersToProcess.length,
      presentCount: isNonWorkingDay ? 0 : presentCount,
      halfDayCount: isNonWorkingDay ? 0 : halfDayCount,
      missingCount: isNonWorkingDay ? 0 : missingCount,
      employees: employeeDailies,
    );
  }

  Future<bool> confirmAbsence({
    required String userId,
    required String date,
    String? notes,
  }) async {
    await ensureInitialized();

    _records.removeWhere((r) => r.userId == userId && r.date == date);

    UserModel user;
    try {
      user = kAuthenticDatabaseUsers.firstWhere((u) => u.id == userId);
    } catch (_) {
      user = UserModel(
        id: userId,
        name: 'Team Member',
        email: '',
        role: UserRole.projectMember,
        department: 'General',
      );
    }

    final confirmedRecord = AttendanceRecordModel(
      id: 'abs-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: user.name,
      userEmail: user.email,
      department: user.department,
      designation: user.designation ?? 'Member',
      date: date,
      sessionType: 'morning',
      loginTime: DateTime.tryParse('$date 09:00:00') ?? DateTime.now(),
      status: 'confirmed_absent',
      notes: notes ?? 'Confirmed Unpaid Absence by Manager/Admin',
      createdAt: DateTime.now(),
    );

    _records.add(confirmedRecord);
    await _saveRecords();
    return true;
  }

  // ==================== SALARY & DEDUCTION METHODS ====================

  Future<EmployeeSalaryProfile> getEmployeeSalary(String userId) async {
    await ensureInitialized();

    if (_salaries.containsKey(userId)) {
      return _salaries[userId]!;
    }

    UserModel? user = _knownUsers[userId];
    if (user == null) {
      try {
        user = kAuthenticDatabaseUsers.firstWhere((u) => u.id == userId);
      } catch (_) {
        final rec = _records.cast<AttendanceRecordModel?>().firstWhere((r) => r?.userId == userId, orElse: () => null);
        if (rec != null) {
          user = UserModel(
            id: userId,
            name: rec.userName,
            email: rec.userEmail,
            department: rec.department,
            designation: rec.designation,
            role: UserRole.projectMember,
          );
        } else {
          user = UserModel(
            id: userId,
            name: 'Employee',
            email: 'employee@pfis.com',
            role: UserRole.projectMember,
            department: 'Operations',
          );
        }
      }
      syncUser(user);
    }

    final profile = EmployeeSalaryProfile(
      id: 'sal-${userId.length > 8 ? userId.substring(0, 8) : userId}',
      userId: userId,
      userName: user.name,
      userEmail: user.email,
      department: user.department,
      designation: user.designation ?? user.role.displayName,
      monthlySalary: 50000.0,
      currency: 'BDT',
      standardWorkingDays: 22,
      effectiveFrom: '2026-01-01',
    );
    _salaries[userId] = profile;
    await _saveSalaries();
    return profile;
  }

  Future<EmployeeSalaryProfile> setEmployeeSalary(
    String userId,
    double monthlySalary, {
    int standardWorkingDays = 22,
    String currency = 'BDT',
  }) async {
    await ensureInitialized();

    final current = await getEmployeeSalary(userId);
    final updated = EmployeeSalaryProfile(
      id: current.id,
      userId: current.userId,
      userName: current.userName,
      userEmail: current.userEmail,
      department: current.department,
      designation: current.designation,
      monthlySalary: monthlySalary,
      currency: currency,
      standardWorkingDays: standardWorkingDays,
      effectiveFrom: current.effectiveFrom,
      effectiveTo: current.effectiveTo,
    );

    _salaries[userId] = updated;
    await _saveSalaries();
    return updated;
  }

  Future<SalaryCalculationModel> calculateSalary(String userId, int month, int year) async {
    await ensureInitialized();

    final profile = await getEmployeeSalary(userId);
    final monthlyBase = profile.monthlySalary;
    final payableWorkingDays = profile.standardWorkingDays > 0 ? profile.standardWorkingDays : 22;
    final dailyRate = monthlyBase / payableWorkingDays;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now = DateTime.now();

    final dailyBreakdown = <DailyBreakdownItemModel>[];
    double totalDeductionsUnits = 0.0;
    int scheduledWorkingDays = 0;
    int presentDaysCount = 0;
    int halfDaysCount = 0;
    int missingLoginDaysCount = 0;
    int confirmedAbsentDaysCount = 0;
    int weekendCount = 0;
    int holidayCount = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final dateObj = DateTime(year, month, day);
      final dateStr = DateFormat('yyyy-MM-dd').format(dateObj);
      final dayOfWeek = DateFormat('EEEE').format(dateObj);
      final isFuture = dateObj.isAfter(DateTime(now.year, now.month, now.day));
      final isToday = dateObj.year == now.year && dateObj.month == now.month && dateObj.day == now.day;

      // Weekend in Bangladesh: Friday & Saturday
      final isWeekend = dateObj.weekday == DateTime.friday || dateObj.weekday == DateTime.saturday;

      // Check Holiday
      HolidayModel? holiday;
      try {
        holiday = _holidays.firstWhere((h) => h.date == dateStr || (h.isRecurring && h.date.endsWith(dateStr.substring(4))));
      } catch (_) {}

      final isHoliday = holiday != null;

      if (isWeekend) {
        weekendCount++;
      } else if (isHoliday) {
        holidayCount++;
      } else {
        scheduledWorkingDays++;
      }

      // Check attendance records for this day
      final dayRecords = _records.where((r) => r.userId == userId && r.date == dateStr).toList();
      AttendanceRecordModel? mRec;
      AttendanceRecordModel? aRec;

      for (final r in dayRecords) {
        if (r.isMorning && r.status != 'confirmed_absent') mRec = r;
        if (r.isAfternoon && r.status != 'confirmed_absent') aRec = r;
      }

      final hasMorning = mRec != null;
      final hasAfternoon = aRec != null;
      final isConfirmedAbsent = dayRecords.any((r) => r.status == 'confirmed_absent');

      String status = 'upcoming';
      double presentWeight = 0.0;
      double deductionUnits = 0.0;

      if (isWeekend) {
        status = 'weekend';
      } else if (isHoliday) {
        status = 'holiday';
      } else if (isFuture) {
        status = 'upcoming';
      } else if (hasMorning && hasAfternoon) {
        status = 'present';
        presentWeight = 1.0;
        presentDaysCount++;
      } else if (hasMorning || hasAfternoon) {
        status = 'half_day';
        presentWeight = 0.5;
        deductionUnits = isToday ? 0.0 : 0.5; // Do not penalize current in-progress day!
        if (!isToday) halfDaysCount++;
      } else if (isToday) {
        status = 'upcoming'; // Scheduled workday currently in progress
      } else if (isConfirmedAbsent) {
        status = 'confirmed_absent';
        deductionUnits = 1.0; // Confirmed absent cut
        confirmedAbsentDaysCount++;
      } else {
        status = 'missing_record';
        deductionUnits = 1.0; // Unlogged absence cut
        missingLoginDaysCount++;
      }

      totalDeductionsUnits += deductionUnits;

      dailyBreakdown.add(DailyBreakdownItemModel(
        date: dateStr,
        dayOfWeek: dayOfWeek,
        isWeekend: isWeekend,
        isHoliday: isHoliday,
        holidayName: holiday?.name,
        isFuture: isFuture,
        morningAttended: hasMorning,
        morningTime: mRec?.formattedTime,
        morningLat: mRec?.latitude,
        morningLng: mRec?.longitude,
        morningAddress: mRec?.addressText,
        afternoonAttended: hasAfternoon,
        afternoonTime: aRec?.formattedTime,
        afternoonLat: aRec?.latitude,
        afternoonLng: aRec?.longitude,
        afternoonAddress: aRec?.addressText,
        status: status,
        presentWeight: presentWeight,
        deductionUnits: deductionUnits,
      ));
    }

    final totalDeductionAmount = totalDeductionsUnits * dailyRate;
    final finalPayable = (monthlyBase - totalDeductionAmount).clamp(0.0, double.infinity);

    return SalaryCalculationModel(
      userId: userId,
      userName: profile.userName,
      userEmail: profile.userEmail,
      department: profile.department,
      designation: profile.designation,
      month: month,
      year: year,
      monthlyBaseSalary: monthlyBase,
      calendarDaysInMonth: daysInMonth,
      weekendDays: weekendCount,
      holidayDays: holidayCount,
      scheduledWorkingDays: scheduledWorkingDays,
      configuredPayableWorkingDays: payableWorkingDays,
      dailySalaryRate: dailyRate,
      presentDays: presentDaysCount,
      halfDays: halfDaysCount,
      paidLeaveDays: 0,
      unpaidLeaveDays: 0,
      missingLoginDays: missingLoginDaysCount,
      confirmedAbsentDays: confirmedAbsentDaysCount,
      totalAbsenceDeductions: totalDeductionAmount,
      totalAdditions: 0.0,
      totalPenalties: 0.0,
      finalPayableSalary: finalPayable,
      dailyBreakdown: dailyBreakdown,
    );
  }

  Future<OrgSalaryReportModel> getOrgSalaryReport(int month, int year, [List<UserModel>? explicitUsers]) async {
    await ensureInitialized();
    if (explicitUsers != null && explicitUsers.isNotEmpty) {
      syncUsers(explicitUsers);
    }

    final calculations = <SalaryCalculationModel>[];
    double totalBase = 0;
    double totalDeductions = 0;
    double totalPayable = 0;

    final usersToProcess = <UserModel>[];
    final seenUserIds = <String>{};

    for (final u in _knownUsers.values) {
      if (seenUserIds.add(u.id)) {
        usersToProcess.add(u);
      }
    }

    for (final r in _records) {
      final parsed = DateTime.tryParse(r.date);
      if (parsed != null && parsed.month == month && parsed.year == year) {
        if (seenUserIds.add(r.userId)) {
          final u = UserModel(
            id: r.userId,
            name: r.userName,
            email: r.userEmail,
            department: r.department,
            designation: r.designation,
            role: UserRole.projectMember,
            avatarUrl: r.avatarUrl,
          );
          syncUser(u);
          usersToProcess.add(u);
        }
      }
    }

    if (usersToProcess.isEmpty) {
      for (final u in kAuthenticDatabaseUsers) {
        if (seenUserIds.add(u.id)) usersToProcess.add(u);
      }
    }

    for (final user in usersToProcess) {
      final calc = await calculateSalary(user.id, month, year);
      calculations.add(calc);
      totalBase += calc.monthlyBaseSalary;
      totalDeductions += calc.totalAbsenceDeductions;
      totalPayable += calc.finalPayableSalary;
    }

    return OrgSalaryReportModel(
      month: month,
      year: year,
      totalEmployees: calculations.length,
      totalBaseSalary: totalBase,
      totalDeductions: totalDeductions,
      totalPayable: totalPayable,
      employees: calculations,
    );
  }

  Future<List<HolidayModel>> getHolidays([int? year]) async {
    await ensureInitialized();
    return _holidays;
  }
}
