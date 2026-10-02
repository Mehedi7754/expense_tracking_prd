class EmployeeSalaryProfile {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String department;
  final String designation;
  final double monthlySalary;
  final String currency;
  final int standardWorkingDays;
  final String effectiveFrom;
  final String? effectiveTo;

  const EmployeeSalaryProfile({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.department,
    required this.designation,
    required this.monthlySalary,
    this.currency = 'BDT',
    this.standardWorkingDays = 22,
    required this.effectiveFrom,
    this.effectiveTo,
  });

  factory EmployeeSalaryProfile.fromJson(Map<String, dynamic> json) {
    double parseDbl(dynamic val) {
      if (val == null) return 50000.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 50000.0;
    }

    return EmployeeSalaryProfile(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      userName: json['userName']?.toString() ?? json['user_name'] ?? '',
      userEmail: json['userEmail']?.toString() ?? json['user_email'] ?? '',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      monthlySalary: parseDbl(json['monthlySalary'] ?? json['monthly_salary']),
      currency: json['currency']?.toString() ?? 'BDT',
      standardWorkingDays: json['standardWorkingDays'] as int? ?? json['standard_working_days'] as int? ?? 22,
      effectiveFrom: json['effectiveFrom']?.toString() ?? json['effective_from']?.toString() ?? '',
      effectiveTo: json['effectiveTo']?.toString() ?? json['effective_to']?.toString(),
    );
  }
}

class DailyBreakdownItemModel {
  final String date;
  final String dayOfWeek;
  final bool isWeekend;
  final bool isHoliday;
  final String? holidayName;
  final bool isLeave;
  final String? leaveType;
  final bool isPaidLeave;
  final bool isFuture;
  final bool morningAttended;
  final String? morningTime;
  final double? morningLat;
  final double? morningLng;
  final String? morningAddress;
  final bool afternoonAttended;
  final String? afternoonTime;
  final double? afternoonLat;
  final double? afternoonLng;
  final String? afternoonAddress;
  final String status;
  final double presentWeight;
  final double deductionUnits;
  final String notes;

  const DailyBreakdownItemModel({
    required this.date,
    required this.dayOfWeek,
    this.isWeekend = false,
    this.isHoliday = false,
    this.holidayName,
    this.isLeave = false,
    this.leaveType,
    this.isPaidLeave = false,
    this.isFuture = false,
    this.morningAttended = false,
    this.morningTime,
    this.morningLat,
    this.morningLng,
    this.morningAddress,
    this.afternoonAttended = false,
    this.afternoonTime,
    this.afternoonLat,
    this.afternoonLng,
    this.afternoonAddress,
    required this.status,
    this.presentWeight = 0.0,
    this.deductionUnits = 0.0,
    this.notes = '',
  });

  bool get isPresent => status == 'present';
  bool get isHalfDay => status == 'half_day';
  bool get isAbsent => status == 'confirmed_absent';
  bool get isMissing => status == 'missing_record';

  factory DailyBreakdownItemModel.fromJson(Map<String, dynamic> json) {
    double parseDbl(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    final morningLoc = json['morningLocation'] as Map<String, dynamic>?;
    final afternoonLoc = json['afternoonLocation'] as Map<String, dynamic>?;

    return DailyBreakdownItemModel(
      date: json['date']?.toString() ?? '',
      dayOfWeek: json['dayOfWeek']?.toString() ?? '',
      isWeekend: json['isWeekend'] as bool? ?? false,
      isHoliday: json['isHoliday'] as bool? ?? false,
      holidayName: json['holidayName']?.toString(),
      isLeave: json['isLeave'] as bool? ?? false,
      leaveType: json['leaveType']?.toString(),
      isPaidLeave: json['isPaidLeave'] as bool? ?? false,
      isFuture: json['isFuture'] as bool? ?? false,
      morningAttended: json['morningAttended'] as bool? ?? false,
      morningTime: json['morningTime']?.toString(),
      morningLat: morningLoc != null ? parseDbl(morningLoc['lat']) : null,
      morningLng: morningLoc != null ? parseDbl(morningLoc['lng']) : null,
      morningAddress: morningLoc?['address']?.toString(),
      afternoonAttended: json['afternoonAttended'] as bool? ?? false,
      afternoonTime: json['afternoonTime']?.toString(),
      afternoonLat: afternoonLoc != null ? parseDbl(afternoonLoc['lat']) : null,
      afternoonLng: afternoonLoc != null ? parseDbl(afternoonLoc['lng']) : null,
      afternoonAddress: afternoonLoc?['address']?.toString(),
      status: json['status']?.toString() ?? 'upcoming',
      presentWeight: parseDbl(json['presentWeight']),
      deductionUnits: parseDbl(json['deductionUnits']),
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class SalaryCalculationModel {
  final String userId;
  final String userName;
  final String userEmail;
  final String department;
  final String designation;
  final String avatarUrl;
  final int month;
  final int year;
  final double monthlyBaseSalary;
  final String currency;
  final int calendarDaysInMonth;
  final int weekendDays;
  final int holidayDays;
  final int scheduledWorkingDays;
  final int configuredPayableWorkingDays;
  final double dailySalaryRate;
  final int presentDays;
  final int halfDays;
  final int paidLeaveDays;
  final int unpaidLeaveDays;
  final int missingLoginDays;
  final int confirmedAbsentDays;
  final double totalAbsenceDeductions;
  final double totalAdditions;
  final double totalPenalties;
  final double finalPayableSalary;
  final bool isConfirmed;
  final List<DailyBreakdownItemModel> dailyBreakdown;

  const SalaryCalculationModel({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.department,
    required this.designation,
    this.avatarUrl = '',
    required this.month,
    required this.year,
    required this.monthlyBaseSalary,
    this.currency = 'BDT',
    required this.calendarDaysInMonth,
    required this.weekendDays,
    required this.holidayDays,
    required this.scheduledWorkingDays,
    required this.configuredPayableWorkingDays,
    required this.dailySalaryRate,
    required this.presentDays,
    required this.halfDays,
    required this.paidLeaveDays,
    required this.unpaidLeaveDays,
    required this.missingLoginDays,
    required this.confirmedAbsentDays,
    required this.totalAbsenceDeductions,
    this.totalAdditions = 0.0,
    this.totalPenalties = 0.0,
    required this.finalPayableSalary,
    this.isConfirmed = false,
    this.dailyBreakdown = const [],
  });

  double get totalPresentEquivalent => presentDays + (halfDays * 0.5) + paidLeaveDays;
  double get totalAbsentEquivalent => confirmedAbsentDays + unpaidLeaveDays + missingLoginDays + (halfDays * 0.5);

  factory SalaryCalculationModel.fromJson(Map<String, dynamic> json) {
    double parseDbl(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    final rawBreakdown = json['dailyBreakdown'] as List<dynamic>? ?? [];

    return SalaryCalculationModel(
      userId: json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      userEmail: json['userEmail']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      month: json['month'] as int? ?? 1,
      year: json['year'] as int? ?? 2026,
      monthlyBaseSalary: parseDbl(json['monthlyBaseSalary']),
      currency: json['currency']?.toString() ?? 'BDT',
      calendarDaysInMonth: json['calendarDaysInMonth'] as int? ?? 30,
      weekendDays: json['weekendDays'] as int? ?? 8,
      holidayDays: json['holidayDays'] as int? ?? 0,
      scheduledWorkingDays: json['scheduledWorkingDays'] as int? ?? 22,
      configuredPayableWorkingDays: json['configuredPayableWorkingDays'] as int? ?? 22,
      dailySalaryRate: parseDbl(json['dailySalaryRate']),
      presentDays: json['presentDays'] as int? ?? 0,
      halfDays: json['halfDays'] as int? ?? 0,
      paidLeaveDays: json['paidLeaveDays'] as int? ?? 0,
      unpaidLeaveDays: json['unpaidLeaveDays'] as int? ?? 0,
      missingLoginDays: json['missingLoginDays'] as int? ?? 0,
      confirmedAbsentDays: json['confirmedAbsentDays'] as int? ?? 0,
      totalAbsenceDeductions: parseDbl(json['totalAbsenceDeductions']),
      totalAdditions: parseDbl(json['totalAdditions']),
      totalPenalties: parseDbl(json['totalPenalties']),
      finalPayableSalary: parseDbl(json['finalPayableSalary']),
      isConfirmed: json['isConfirmed'] as bool? ?? false,
      dailyBreakdown: rawBreakdown.map((e) => DailyBreakdownItemModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class OrgSalaryReportModel {
  final int month;
  final int year;
  final int totalEmployees;
  final String currency;
  final double totalBaseSalary;
  final double totalDeductions;
  final double totalPayable;
  final List<SalaryCalculationModel> employees;

  const OrgSalaryReportModel({
    required this.month,
    required this.year,
    required this.totalEmployees,
    this.currency = 'BDT',
    required this.totalBaseSalary,
    required this.totalDeductions,
    required this.totalPayable,
    required this.employees,
  });

  factory OrgSalaryReportModel.fromJson(Map<String, dynamic> json) {
    double parseDbl(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    final rawEmployees = json['employees'] as List<dynamic>? ?? [];

    return OrgSalaryReportModel(
      month: json['month'] as int? ?? 1,
      year: json['year'] as int? ?? 2026,
      totalEmployees: json['totalEmployees'] as int? ?? 0,
      currency: json['currency']?.toString() ?? 'BDT',
      totalBaseSalary: parseDbl(json['totalBaseSalary']),
      totalDeductions: parseDbl(json['totalDeductions']),
      totalPayable: parseDbl(json['totalPayable']),
      employees: rawEmployees.map((e) => SalaryCalculationModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class SalaryAdjustmentModel {
  final String id;
  final String userId;
  final String adjustmentType; // 'deduction' | 'addition' | 'override' | 'bonus' | 'penalty'
  final double amount;
  final String reason;
  final DateTime createdAt;

  const SalaryAdjustmentModel({
    required this.id,
    required this.userId,
    required this.adjustmentType,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  factory SalaryAdjustmentModel.fromJson(Map<String, dynamic> json) {
    double parseDbl(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return SalaryAdjustmentModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      adjustmentType: json['adjustmentType']?.toString() ?? 'addition',
      amount: parseDbl(json['amount']),
      reason: json['reason']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
