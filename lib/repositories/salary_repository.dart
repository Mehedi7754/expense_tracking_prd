import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/holiday_model.dart';
import '../models/leave_model.dart';
import '../models/salary_model.dart';
import '../models/user_model.dart';

class SalaryRepository {
  final ApiClient _client;

  SalaryRepository(this._client);

  Future<EmployeeSalaryProfile> getEmployeeSalary(String userId) async {
    final response = await _client.get(ApiEndpoints.employeeSalary(userId));
    if (response is Map<String, dynamic>) {
      return EmployeeSalaryProfile.fromJson(response);
    }
    return EmployeeSalaryProfile(
      id: 'sal_$userId',
      userId: userId,
      userName: '',
      userEmail: '',
      department: '',
      designation: '',
      monthlySalary: 0,
      standardWorkingDays: 22,
      currency: 'BDT',
      effectiveFrom: DateTime.now().toIso8601String(),
    );
  }

  Future<EmployeeSalaryProfile> setEmployeeSalary(
    String userId,
    double monthlySalary, {
    int standardWorkingDays = 22,
    String currency = 'BDT',
  }) async {
    final response = await _client.post(
      ApiEndpoints.employeeSalary(userId),
      body: {
        'monthlySalary': monthlySalary,
        'standardWorkingDays': standardWorkingDays,
        'currency': currency,
      },
    );
    if (response is Map<String, dynamic>) {
      return EmployeeSalaryProfile.fromJson(response);
    }
    return EmployeeSalaryProfile(
      id: 'sal_$userId',
      userId: userId,
      userName: '',
      userEmail: '',
      department: '',
      designation: '',
      monthlySalary: monthlySalary,
      standardWorkingDays: standardWorkingDays,
      currency: currency,
      effectiveFrom: DateTime.now().toIso8601String(),
    );
  }

  Future<SalaryCalculationModel> calculateSalary(String userId, int month, int year) async {
    final url = '${ApiEndpoints.calculateSalary(userId)}?month=$month&year=$year';
    final response = await _client.get(url);
    if (response is Map<String, dynamic>) {
      return SalaryCalculationModel.fromJson(response);
    }
    return SalaryCalculationModel(
      userId: userId,
      userName: '',
      userEmail: '',
      department: '',
      designation: '',
      month: month,
      year: year,
      monthlyBaseSalary: 0,
      calendarDaysInMonth: 30,
      weekendDays: 0,
      holidayDays: 0,
      scheduledWorkingDays: 22,
      configuredPayableWorkingDays: 22,
      dailySalaryRate: 0,
      presentDays: 0,
      halfDays: 0,
      paidLeaveDays: 0,
      unpaidLeaveDays: 0,
      missingLoginDays: 0,
      confirmedAbsentDays: 0,
      totalAbsenceDeductions: 0,
      finalPayableSalary: 0,
    );
  }

  Future<bool> saveCalculation(String userId, int month, int year, {String? notes}) async {
    final response = await _client.post(
      ApiEndpoints.saveSalaryCalculation,
      body: {
        'userId': userId,
        'month': month,
        'year': year,
        if (notes != null) 'notes': notes,
      },
    );
    if (response is Map<String, dynamic>) {
      return response['success'] == true;
    }
    return false;
  }

  Future<OrgSalaryReportModel> getOrgSalaryReport(int month, int year, [List<UserModel>? explicitUsers]) async {
    final url = '${ApiEndpoints.salaryReport}?month=$month&year=$year';
    final response = await _client.get(url);
    if (response is Map<String, dynamic>) {
      return OrgSalaryReportModel.fromJson(response);
    }
    return OrgSalaryReportModel(
      month: month,
      year: year,
      totalEmployees: 0,
      totalBaseSalary: 0,
      totalDeductions: 0,
      totalPayable: 0,
      employees: const [],
    );
  }

  // --- Holidays ---
  Future<List<HolidayModel>> getHolidays([int? year]) async {
    String url = ApiEndpoints.holidays;
    if (year != null) url = '$url?year=$year';
    final response = await _client.get(url);
    if (response is List) {
      return response.map((e) => HolidayModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }

  Future<HolidayModel> addHoliday({
    required String date,
    required String name,
    bool isRecurring = false,
  }) async {
    final response = await _client.post(
      ApiEndpoints.holidays,
      body: {
        'date': date,
        'name': name,
        'isRecurring': isRecurring,
      },
    );
    if (response is Map<String, dynamic>) {
      return HolidayModel.fromJson(response);
    }
    throw const FormatException('Failed to add holiday');
  }

  Future<bool> deleteHoliday(String id) async {
    final response = await _client.delete(ApiEndpoints.holidayById(id));
    if (response is Map<String, dynamic>) {
      return response['success'] == true;
    }
    return false;
  }

  // --- Leaves ---
  Future<List<LeaveRecordModel>> getLeaves({String? userId, int? month, int? year}) async {
    final queryParams = <String, String>{};
    if (userId != null && userId.isNotEmpty) queryParams['userId'] = userId;
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    String url = ApiEndpoints.leaves;
    if (queryParams.isNotEmpty) {
      final qs = Uri(queryParameters: queryParams).query;
      url = '$url?$qs';
    }

    final response = await _client.get(url);
    if (response is List) {
      return response.map((e) => LeaveRecordModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }

  Future<LeaveRecordModel> addLeave({
    required String userId,
    required String startDate,
    required String endDate,
    required String leaveType,
    String? reason,
    bool isApproved = true,
  }) async {
    final response = await _client.post(
      ApiEndpoints.leaves,
      body: {
        'userId': userId,
        'startDate': startDate,
        'endDate': endDate,
        'leaveType': leaveType,
        if (reason != null) 'reason': reason,
        'isApproved': isApproved,
      },
    );
    if (response is Map<String, dynamic>) {
      return LeaveRecordModel.fromJson(response);
    }
    throw const FormatException('Failed to add leave record');
  }

  Future<bool> deleteLeave(String id) async {
    final response = await _client.delete(ApiEndpoints.leaveById(id));
    if (response is Map<String, dynamic>) {
      return response['success'] == true;
    }
    return false;
  }

  // --- Adjustments ---
  Future<List<SalaryAdjustmentModel>> getAdjustments(String userId, {int? month, int? year}) async {
    String url = ApiEndpoints.salaryAdjustments(userId);
    final qp = <String, String>{};
    if (month != null) qp['month'] = month.toString();
    if (year != null) qp['year'] = year.toString();
    if (qp.isNotEmpty) {
      url = '$url?${Uri(queryParameters: qp).query}';
    }

    final response = await _client.get(url);
    if (response is List) {
      return response.map((e) => SalaryAdjustmentModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }

  Future<SalaryAdjustmentModel> addAdjustment({
    required String userId,
    required String adjustmentType,
    required double amount,
    required String reason,
    int? month,
    int? year,
  }) async {
    final response = await _client.post(
      ApiEndpoints.addSalaryAdjustment,
      body: {
        'userId': userId,
        'adjustmentType': adjustmentType,
        'amount': amount,
        'reason': reason,
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      },
    );
    if (response is Map<String, dynamic>) {
      return SalaryAdjustmentModel.fromJson(response);
    }
    throw const FormatException('Failed to add salary adjustment');
  }
}

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  return SalaryRepository(ref.watch(apiClientProvider));
});
